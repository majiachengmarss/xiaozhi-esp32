param(
    [ValidateSet("Standard", "SevenPin")]
    [string]$DisplayMode = "Standard"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectDir = (Split-Path -Parent $PSScriptRoot)
$workspaceDir = (Split-Path -Parent $projectDir)
$environmentScript = Join-Path $workspaceDir "use-espidf.ps1"
$sdkconfigPath = Join-Path $projectDir "sdkconfig"
$ninjaPath = "C:/Users/Mars/Desktop/AI/robot/espidf_tools/tools/ninja/1.12.1/ninja.exe"
$firmwareDir = Join-Path $projectDir "firmware"
$firmwareName = if ($DisplayMode -eq "SevenPin") {
    "xiaozhi-esp32s3-n16r8-st7789-240x240-7pin.bin"
} else {
    "xiaozhi-esp32s3-n16r8-st7789-240x240.bin"
}
$firmwarePath = Join-Path $firmwareDir $firmwareName

function Invoke-Checked {
    param(
        [string]$Description,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "== $Description =="
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE"
    }
}

function Set-KconfigSymbol {
    param(
        [ref]$Text,
        [string]$Symbol,
        [bool]$Enabled
    )

    $line = if ($Enabled) { "$Symbol=y" } else { "# $Symbol is not set" }
    $pattern = "(?m)^(?:$([regex]::Escape($Symbol))=.*|# $([regex]::Escape($Symbol)) is not set)\r?$"
    if ([regex]::IsMatch($Text.Value, $pattern)) {
        $Text.Value = [regex]::Replace($Text.Value, $pattern, $line)
    } else {
        $Text.Value = $Text.Value.TrimEnd() + [Environment]::NewLine + $line + [Environment]::NewLine
    }
}

function Set-St7789Configuration {
    $text = [System.IO.File]::ReadAllText($sdkconfigPath)

    foreach ($match in [regex]::Matches($text, "(?m)^CONFIG_BOARD_TYPE_[A-Z0-9_]+=y\r?$")) {
        $symbol = $match.Value.Trim() -replace "=y$", ""
        if ($symbol -ne "CONFIG_BOARD_TYPE_BREAD_COMPACT_WIFI_LCD") {
            Set-KconfigSymbol ([ref]$text) $symbol $false
        }
    }
    Set-KconfigSymbol ([ref]$text) "CONFIG_BOARD_TYPE_BREAD_COMPACT_WIFI_LCD" $true

    foreach ($match in [regex]::Matches($text, "(?m)^CONFIG_LCD_(?:ST7789|ST7735|ST7796|ILI9341|GC9A01|CUSTOM)[A-Z0-9_]*=y\r?$")) {
        $symbol = $match.Value.Trim() -replace "=y$", ""
        Set-KconfigSymbol ([ref]$text) $symbol $false
    }

    $displaySymbol = if ($DisplayMode -eq "SevenPin") {
        "CONFIG_LCD_ST7789_240X240_7PIN"
    } else {
        "CONFIG_LCD_ST7789_240X240"
    }
    Set-KconfigSymbol ([ref]$text) $displaySymbol $true
    Set-KconfigSymbol ([ref]$text) "CONFIG_OLED_SSD1306_128X32" $false
    Set-KconfigSymbol ([ref]$text) "CONFIG_OLED_SSD1306_128X64" $false
    Set-KconfigSymbol ([ref]$text) "CONFIG_OLED_SH1106_128X64" $false

    [System.IO.File]::WriteAllText($sdkconfigPath, $text, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $environmentScript)) {
    throw "ESP-IDF environment script was not found: $environmentScript"
}
if (-not (Test-Path -LiteralPath $ninjaPath)) {
    throw "Ninja was not found: $ninjaPath"
}

. $environmentScript
$env:HTTP_PROXY = "http://127.0.0.1:7892"
$env:HTTPS_PROXY = "http://127.0.0.1:7892"
$env:IDF_SKIP_CHECK_SUBMODULES = "1"
$env:IDF_COMPONENT_CACHE_PATH = Join-Path $projectDir ".c"

Push-Location $projectDir
try {
    if (-not (Test-Path -LiteralPath $sdkconfigPath)) {
        Invoke-Checked "Initialize ESP32-S3 target" {
            & $env:PYTHON "$env:IDF_PATH\tools\idf.py" "-DCMAKE_MAKE_PROGRAM=$ninjaPath" set-target esp32s3
        }
    }

    Set-St7789Configuration
    $modeText = if ($DisplayMode -eq "SevenPin") { "ST7789 240x240 / 7PIN" } else { "ST7789 240x240 / Standard SPI" }
    Write-Host "Hardware: ESP32-S3 N16R8 + $modeText"

    Invoke-Checked "Build firmware" {
        & $env:PYTHON "$env:IDF_PATH\tools\idf.py" "-DCMAKE_MAKE_PROGRAM=$ninjaPath" `
            "-DBOARD_NAME=bread-compact-wifi-lcd" "-DBOARD_TYPE=bread-compact-wifi-lcd" build
    }
    Invoke-Checked "Merge firmware image" {
        & $env:PYTHON "$env:IDF_PATH\tools\idf.py" "-DCMAKE_MAKE_PROGRAM=$ninjaPath" merge-bin
    }

    New-Item -ItemType Directory -Force -Path $firmwareDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectDir "build\merged-binary.bin") -Destination $firmwarePath -Force
    Write-Host ""
    Write-Host "Build completed: $firmwarePath"
} finally {
    Pop-Location
}
