param(
    [string]$Port = "COM6",
    [ValidateSet("Standard", "SevenPin")]
    [string]$DisplayMode = "Standard"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Port -notmatch "^COM[0-9]+$") {
    throw "Invalid serial port: $Port"
}

$projectDir = (Split-Path -Parent $PSScriptRoot)
$workspaceDir = (Split-Path -Parent $projectDir)
$environmentScript = Join-Path $workspaceDir "use-espidf.ps1"
$firmwareName = if ($DisplayMode -eq "SevenPin") {
    "xiaozhi-esp32s3-n16r8-st7789-240x240-7pin.bin"
} else {
    "xiaozhi-esp32s3-n16r8-st7789-240x240.bin"
}
$firmwarePath = Join-Path (Join-Path $projectDir "firmware") $firmwareName

if (-not (Test-Path -LiteralPath $firmwarePath)) {
    throw "Firmware not found for this display mode. Build it first: $firmwarePath"
}

. $environmentScript

Write-Host "Port: $Port"
Write-Host "Firmware: $firmwarePath"
Write-Host "Flashing started. Keep the board connected..."

& $env:PYTHON -m esptool --chip esp32s3 --port $Port --baud 460800 `
    --before default-reset --after hard-reset write-flash `
    --flash-mode dio --flash-freq 80m --flash-size 16MB `
    0x0 $firmwarePath

if ($LASTEXITCODE -ne 0) {
    throw "Flash failed with exit code $LASTEXITCODE. For connection failures, hold BOOT, press RESET once, and retry."
}

Write-Host "Flash completed. The board has restarted."
