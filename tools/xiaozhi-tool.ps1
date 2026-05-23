param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectDir = (Split-Path -Parent $PSScriptRoot)
$settingsPath = Join-Path $PSScriptRoot "xiaozhi-tool.settings.json"
$buildScript = Join-Path $PSScriptRoot "build-st7789.ps1"
$flashScript = Join-Path $PSScriptRoot "flash-st7789.ps1"
$firmwareDir = Join-Path $projectDir "firmware"
$defaultSettings = [ordered]@{
    Port = "COM6"
    DisplayMode = "Standard"
}

function Read-Settings {
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            $saved = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            return [ordered]@{
                Port = if ($saved.Port) { [string]$saved.Port } else { $defaultSettings.Port }
                DisplayMode = if ($saved.DisplayMode -in @("Standard", "SevenPin")) { [string]$saved.DisplayMode } else { $defaultSettings.DisplayMode }
            }
        } catch {
            return [ordered]@{
                Port = $defaultSettings.Port
                DisplayMode = $defaultSettings.DisplayMode
            }
        }
    }
    return [ordered]@{
        Port = $defaultSettings.Port
        DisplayMode = $defaultSettings.DisplayMode
    }
}

function Get-FirmwarePath {
    param([string]$DisplayMode)
    $name = if ($DisplayMode -eq "SevenPin") {
        "xiaozhi-esp32s3-n16r8-st7789-240x240-7pin.bin"
    } else {
        "xiaozhi-esp32s3-n16r8-st7789-240x240.bin"
    }
    return (Join-Path $firmwareDir $name)
}

function T {
    param([string]$Encoded)
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Encoded))
}

$initialSettings = Read-Settings

if ($SelfTest) {
    $checks = @($buildScript, $flashScript, (Join-Path (Split-Path -Parent $projectDir) "use-espidf.ps1"))
    foreach ($path in $checks) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required tool file is missing: $path"
        }
    }
    Write-Host "DEFAULT_PORT=$($initialSettings.Port)"
    Write-Host "DISPLAY_MODE=$($initialSettings.DisplayMode)"
    Write-Host "FIRMWARE=$(Get-FirmwarePath $initialSettings.DisplayMode)"
    Write-Host "PORTS=$([string]::Join(',', [System.IO.Ports.SerialPort]::GetPortNames()))"
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = T "5bCP5pm6IEVTUDMyLVMzIOS4gOmUrue8luivkeS4jueDp+W9lQ=="
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 570)
$form.MinimumSize = New-Object System.Drawing.Size(680, 480)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$hardwareLabel = New-Object System.Windows.Forms.Label
$hardwareLabel.Location = New-Object System.Drawing.Point(18, 16)
$hardwareLabel.AutoSize = $true
$hardwareLabel.Text = T "56Gs5Lu2OiBFU1AzMi1TMyBOMTZSOCArIDEuNTQgVEZUIFNQSSBTVDc3ODkgMjQweDI0MA=="
$form.Controls.Add($hardwareLabel)

$portLabel = New-Object System.Windows.Forms.Label
$portLabel.Location = New-Object System.Drawing.Point(18, 56)
$portLabel.Size = New-Object System.Drawing.Size(52, 26)
$portLabel.Text = T "5Liy5Y+j"
$form.Controls.Add($portLabel)

$portBox = New-Object System.Windows.Forms.ComboBox
$portBox.Location = New-Object System.Drawing.Point(72, 52)
$portBox.Size = New-Object System.Drawing.Size(100, 28)
$portBox.DropDownStyle = "DropDown"
$form.Controls.Add($portBox)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(182, 51)
$refreshButton.Size = New-Object System.Drawing.Size(88, 30)
$refreshButton.Text = T "5Yi35paw5Liy5Y+j"
$form.Controls.Add($refreshButton)

$displayLabel = New-Object System.Windows.Forms.Label
$displayLabel.Location = New-Object System.Drawing.Point(296, 56)
$displayLabel.Size = New-Object System.Drawing.Size(72, 26)
$displayLabel.Text = T "5bGP5bmV5o6l57q/"
$form.Controls.Add($displayLabel)

$displayBox = New-Object System.Windows.Forms.ComboBox
$displayBox.Location = New-Object System.Drawing.Point(370, 52)
$displayBox.Size = New-Object System.Drawing.Size(194, 28)
$displayBox.DropDownStyle = "DropDownList"
[void]$displayBox.Items.Add((T "5pmu6YCaIFNQSe+8iOaciSBDU++8iQ=="))
[void]$displayBox.Items.Add((T "N1BJTu+8iOaXoCBDU++8iQ=="))
$displayBox.SelectedIndex = if ($initialSettings.DisplayMode -eq "SevenPin") { 1 } else { 0 }
$form.Controls.Add($displayBox)

$compileButton = New-Object System.Windows.Forms.Button
$compileButton.Location = New-Object System.Drawing.Point(18, 102)
$compileButton.Size = New-Object System.Drawing.Size(142, 42)
$compileButton.Text = T "5LiA6ZSu57yW6K+R"
$form.Controls.Add($compileButton)

$flashButton = New-Object System.Windows.Forms.Button
$flashButton.Location = New-Object System.Drawing.Point(174, 102)
$flashButton.Size = New-Object System.Drawing.Size(142, 42)
$flashButton.Text = T "5LiA6ZSu54On5b2V"
$form.Controls.Add($flashButton)

$compileFlashButton = New-Object System.Windows.Forms.Button
$compileFlashButton.Location = New-Object System.Drawing.Point(330, 102)
$compileFlashButton.Size = New-Object System.Drawing.Size(160, 42)
$compileFlashButton.Text = T "57yW6K+R5bm254On5b2V"
$form.Controls.Add($compileFlashButton)

$folderButton = New-Object System.Windows.Forms.Button
$folderButton.Location = New-Object System.Drawing.Point(504, 102)
$folderButton.Size = New-Object System.Drawing.Size(126, 42)
$folderButton.Text = T "5omT5byA5Zu65Lu255uu5b2V"
$form.Controls.Add($folderButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(18, 162)
$statusLabel.Size = New-Object System.Drawing.Size(700, 25)
$statusLabel.Text = T "5bCx57uq"
$form.Controls.Add($statusLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(18, 194)
$logBox.Size = New-Object System.Drawing.Size(706, 316)
$logBox.Anchor = "Top,Bottom,Left,Right"
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

$script:currentJob = $null
$script:currentAction = ""
$script:flashAfterBuild = $false

function Current-DisplayMode {
    if ($displayBox.SelectedIndex -eq 1) { return "SevenPin" }
    return "Standard"
}

function Append-Log {
    param([string]$Line)
    if ([string]::IsNullOrEmpty($Line)) { return }
    $logBox.AppendText($Line + [Environment]::NewLine)
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}

function Save-Settings {
    $settings = [ordered]@{
        Port = $portBox.Text.Trim().ToUpperInvariant()
        DisplayMode = Current-DisplayMode
    }
    $json = $settings | ConvertTo-Json
    [System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Refresh-Ports {
    $selected = $portBox.Text.Trim().ToUpperInvariant()
    if (-not $selected) { $selected = $initialSettings.Port }
    $ports = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
    if ($selected -and $selected -notin $ports) { $ports += $selected }
    $portBox.Items.Clear()
    foreach ($port in $ports | Sort-Object -Unique) { [void]$portBox.Items.Add($port) }
    $portBox.Text = $selected
    $statusLabel.Text = if ($ports.Count -gt 0) { (T "5bey5qOA5rWL5Liy5Y+jOiA=") + [string]::Join(", ", $ports) } else { T "5pyq5qOA5rWL5Yiw5Liy5Y+j77yM5Y+v5omL5bel6L6T5YWlIENPTSDnq6/lj6M=" }
}

function Set-Busy {
    param([bool]$Busy)
    $compileButton.Enabled = -not $Busy
    $flashButton.Enabled = -not $Busy
    $compileFlashButton.Enabled = -not $Busy
    $refreshButton.Enabled = -not $Busy
    $displayBox.Enabled = -not $Busy
    $portBox.Enabled = -not $Busy
}

function Start-Action {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$ChildArguments,
        [bool]$ThenFlash = $false
    )

    if ($script:currentJob) { return }
    Save-Settings
    $script:currentAction = $Name
    $script:flashAfterBuild = $ThenFlash
    Set-Busy $true
    $statusLabel.Text = $Name + (T "IOato+WcqOaJp+ihjC4uLg==")
    Append-Log ""
    Append-Log "===== $Name ====="
    $script:currentJob = Start-Job -ScriptBlock {
        param($File, $Arguments)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $File @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Child process exit code: $LASTEXITCODE"
        }
    } -ArgumentList $ScriptPath, (,$ChildArguments)
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$timer.Add_Tick({
    if (-not $script:currentJob) { return }
    foreach ($line in @(Receive-Job -Job $script:currentJob)) {
        Append-Log ([string]$line)
    }
    if ($script:currentJob.State -in @("Completed", "Failed", "Stopped")) {
        $succeeded = ($script:currentJob.State -eq "Completed")
        $completedAction = $script:currentAction
        $thenFlash = $script:flashAfterBuild
        Remove-Job -Job $script:currentJob -Force
        $script:currentJob = $null
        $script:flashAfterBuild = $false
        Set-Busy $false
        if ($succeeded) {
            $statusLabel.Text = $completedAction + (T "IOWujOaIkA==")
            Append-Log ($completedAction + " " + (T "5a6M5oiQ44CC"))
            if ($thenFlash) {
                Start-Action (T "54On5b2V5Zu65Lu2") $flashScript @("-Port", $portBox.Text.Trim().ToUpperInvariant(), "-DisplayMode", (Current-DisplayMode)) $false
            }
        } else {
            $statusLabel.Text = $completedAction + (T "IOWksei0pe+8jOivt+afpeeci+aXpeW/lw==")
            Append-Log ($completedAction + " " + (T "5aSx6LSl44CC"))
        }
    }
})
$timer.Start()

$refreshButton.Add_Click({ Refresh-Ports })
$compileButton.Add_Click({
    Start-Action (T "57yW6K+R5Zu65Lu2") $buildScript @("-DisplayMode", (Current-DisplayMode)) $false
})
$flashButton.Add_Click({
    Start-Action (T "54On5b2V5Zu65Lu2") $flashScript @("-Port", $portBox.Text.Trim().ToUpperInvariant(), "-DisplayMode", (Current-DisplayMode)) $false
})
$compileFlashButton.Add_Click({
    Start-Action (T "57yW6K+R5Zu65Lu2") $buildScript @("-DisplayMode", (Current-DisplayMode)) $true
})
$folderButton.Add_Click({
    New-Item -ItemType Directory -Force -Path $firmwareDir | Out-Null
    Start-Process explorer.exe -ArgumentList $firmwareDir
})
$form.Add_FormClosing({
    Save-Settings
    if ($script:currentJob) {
        Stop-Job -Job $script:currentJob
        Remove-Job -Job $script:currentJob -Force
    }
})

$portBox.Text = $initialSettings.Port
Refresh-Ports
Append-Log ((T "6buY6K6k5Liy5Y+jOiA=") + $initialSettings.Port)
Append-Log (T "6YCJ5oup5bGP5bmV5o6l57q/5qih5byP5ZCO77yM54K55Ye757yW6K+R5oiW54On5b2V44CC")
[void]$form.ShowDialog()
