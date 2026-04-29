param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Continue"

# --- Self-elevation ---
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process pwsh `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $(if ($WhatIf) {'-WhatIf'})" `
        -Verb RunAs
    exit
}

# --- Core paths ---
$date = Get-Date -Format "yyyy-MM-dd_HH_mm_ss"
$BasePath = "C:\Users\Public\Automation"
$Downloads = Join-Path $BasePath "Downloads"
$LogPath = Join-Path $BasePath "setup.$date.log"
$StatePath = Join-Path $BasePath "state.json"

New-Item -ItemType Directory -Force -Path $BasePath, $Downloads | Out-Null

# --- Logging ---
function Write-Log {
    param($Msg, $Type="INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][$Type] $Msg"
    Write-Host $line
    Add-Content $LogPath $line
}

Write-Log "Starting provisioning"

# --- State ---
$State = if (Test-Path $StatePath) {
    Get-Content $StatePath | ConvertFrom-Json -AsHashtable
} else { @{} }

function Save-State { $State | ConvertTo-Json | Set-Content $StatePath }

function Run-Step($Name, $ScriptBlock) {
    if ($State[$Name]) {
        Write-Log "SKIP: $Name"
        return
    }

    Write-Log "RUN: $Name"

    if ($WhatIf) { return }

    try {
        & $ScriptBlock
        $State[$Name] = $true
        Save-State
    } catch {
        Write-Log "FAILED: $Name - $_" "ERROR"
    }
}

# --- Mode selection ---
if (-not $State.Mode) {
    Write-Host "1) VM with GPU passthrough"
    Write-Host "2) Bare-metal"

    do { $choice = Read-Host "Enter 1 or 2" }
    while ($choice -notin "1","2")

    $State.Mode = if ($choice -eq "1") { "VM" } else { "BareMetal" }
    Save-State
}

Write-Log "Mode: $($State.Mode)"

# --- Download helper ---
function Get-File($Url, $Out) {
    if (Test-Path $Out) { return }

    for ($i=0; $i -lt 3; $i++) {
        try {
            Invoke-WebRequest $Url -OutFile $Out -TimeoutSec 60
            return
        } catch {
            Start-Sleep 2
        }
    }

    throw "Download failed: $Url"
}

# =========================
# CORE SYSTEM SETUP BLOCKS
# =========================

Run-Step "winget" {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        $pkg = Join-Path $Downloads "winget.msixbundle"
        Get-File "https://aka.ms/getwinget" $pkg
        Add-AppxPackage $pkg
        Start-Sleep 5
    }
}

function Install-Package($id) {
    Write-Log "Installing $id"
    winget install -e --id $id --silent `
        --accept-package-agreements --accept-source-agreements
}

function Get-LatestGitHubRelease {
    param(
        [string]$Repo,
        [string]$AssetPattern
    )

    $api = "https://api.github.com/repos/$Repo/releases/latest"

    $release = Invoke-RestMethod -Uri $api -Headers @{
        "User-Agent" = "PowerShell"
    }

    $asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1

    if (-not $asset) {
        throw "No asset matching $AssetPattern in $Repo"
    }

    return $asset.browser_download_url
}

Run-Step "packages" {
    @(
        "Microsoft.PowerShell",
        "Git.Git",
        "GitHub.cli",
        "M2Team.NanaZip",
        "REALiX.HWiNFO",
        "Brave.Brave"
    ) | ForEach-Object { Install-Package $_ }
}

Run-Step "repo" {
    $Repo = Join-Path $BasePath "Win11-Virt"

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git missing"
    }

    if (Test-Path $Repo) {
        git -C $Repo pull
    } else {
        git clone https://github.com/almostlight/Win11-Virt $Repo
    }
}

Run-Step "ssh" {
    if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    }
    Set-Service sshd -StartupType Automatic
    Start-Service sshd
}

Run-Step "rdp" {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" -Value 0

    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

# =========================
# VM FEATURES
# =========================

if ($State.Mode -eq "VM") {

    Run-Step "virtio" {
        $file = Join-Path $Downloads "virtio.exe"
        Get-File "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe" $file
        Start-Process $file -ArgumentList "/quiet" -Wait
    }

    Run-Step "lookingglass" {
        $lgDir = Join-Path $Downloads "lg"

        $existing = Get-ChildItem $lgDir -Recurse -Filter "looking-glass-host-setup.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($existing) {
            Write-Log "Looking Glass already extracted/available, skipping download" "SUCCESS"
            Start-Process $existing.FullName -Wait
            return
        }

        $zip = Join-Path $Downloads "lg.zip"
        Get-File "https://looking-glass.io/artifact/stable/host" $zip

        $dir = Join-Path $Downloads "lg"
        Expand-Archive $zip $dir -Force

        $exe = Get-ChildItem $dir -Recurse -Filter "looking-glass-host-setup.exe" | Select-Object -First 1

        if ($exe) { Start-Process $exe.FullName -Wait }
    }
}

# =========================
# UI / SYSTEM TWEAKS
# =========================

Run-Step "ui" {
    $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    New-Item $p -Force | Out-Null
    Set-ItemProperty $p AppsUseLightTheme 0
    Set-ItemProperty $p SystemUsesLightTheme 0

    $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    New-Item $p -Force | Out-Null
    Set-ItemProperty $p TaskbarAl 0
}

Run-Step "keyboard" {
    $lang = New-WinUserLanguageList en-US
    $lang[0].InputMethodTips.Clear()
    $lang[0].InputMethodTips.Add("0415:00000415")
    Set-WinUserLanguageList $lang -Force
}

# =========================
# DEBLOAT
# =========================

Run-Step "debloat" {
    $apps = @(
        "Microsoft.XboxApp","Microsoft.XboxGamingOverlay","Microsoft.XboxGameOverlay",
        "Microsoft.XboxSpeechToTextOverlay","Microsoft.GamingApp","Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo","Microsoft.BingNews","Microsoft.BingWeather","Microsoft.GetHelp",
        "Microsoft.Getstarted","Microsoft.MicrosoftOfficeHub","Microsoft.People",
        "Microsoft.PowerAutomateDesktop","Microsoft.Todos","Microsoft.WindowsFeedbackHub",
        "MicrosoftTeams","Microsoft.SkypeApp","Microsoft.YourPhone"
    )

    foreach ($a in $apps) {
        Get-AppxPackage -Name $a -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
}

# =========================
# VIRTUAL DISPLAY DRIVER
# =========================

Run-Step "vdd" {
    $vddInstallPath = "C:\Program Files\VDD_Control"
    $vddExe = Get-ChildItem $vddInstallPath -Recurse -Filter "VDD Control.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($vddExe) {
        Write-Log "VDD already installed at $($vddExe.FullName), skipping download/install" "SUCCESS"
        return
    }

    if (-not (Test-Path $vddInstallPath)) {
        New-Item $vddInstallPath -ItemType Directory -Force | Out-Null
    }

    $vddUrl = Get-LatestGitHubRelease `
        -Repo "VirtualDrivers/Virtual-Display-Driver" `
        -AssetPattern "VDD.Control.*.zip"

    $zip = Join-Path $env:TEMP "vdd.zip"
    Invoke-WebRequest $vddUrl -OutFile $zip

    Expand-Archive $zip $vddInstallPath -Force
    Remove-Item $zip -Force

    $exe = Get-ChildItem $vddInstallPath -Recurse -Filter "VDD Control.exe" | Select-Object -First 1

    if ($exe) { Start-Process $exe.FullName }
}

# =========================
# NVCLEANSTALL
# =========================

Run-Step "nvclean" {

    $path = Join-Path $Downloads "NVCleanstall.exe"

    if (Test-Path $path) {
        Remove-Item $path -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Downloading NVCleanstall..." "INFO"

    Get-File "https://sourceforge.net/projects/nvcleanstall/files/latest/download" $path
    
    Start-Sleep -s 10

    Write-Log "Launching NVCleanstall..." "SUCCESS"
    Start-Process $path
}

# =========================
# DDU
# =========================

Run-Step "ddu" {
    $path = Join-Path $Downloads "DDU.exe"
    Invoke-WebRequest "https://www.wagnardsoft.com/DDU/download/DDU%20v18.0.8.5.exe" -OutFile $path
}

# =========================
# AUTOLOGON
# =========================

Run-Step "autologon" {
    $dir = Join-Path $Downloads "Autologon"
    New-Item $dir -ItemType Directory -Force | Out-Null

    Invoke-WebRequest "https://live.sysinternals.com/Autologon.exe" -OutFile "$dir\Autologon.exe"
    Invoke-WebRequest "https://live.sysinternals.com/Autologon64.exe" -OutFile "$dir\Autologon64.exe"

    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" AutoAdminLogon "1"
}

# =========================
# WINFSP
# =========================

Run-Step "winfsp" {
    $msi = Join-Path $Downloads "winfsp.msi"
    $url = Get-LatestGitHubRelease -Repo "winfsp/winfsp" -AssetPattern "*.msi"

    Invoke-WebRequest $url -OutFile $msi
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet" -Wait
}

# =========================
# QUICK ACCESS PINNING
# =========================

Run-Step "quickaccess" {
    $shell = New-Object -ComObject Shell.Application
    foreach ($p in @($Downloads, $BasePath)) {
        if (Test-Path $p) {
            ($shell.Namespace($p)).Self.InvokeVerb("pintohome")
        }
    }
}

# =========================
# CLEANUP
# =========================

Run-Step "cleanup" {
    if ($State.Values -notcontains $false) {
        Remove-Item $StatePath -Force
        Write-Log "State removed"
    }
}

Run-Step "open log" { 
    $openLog = Read-Host "nWould you like to open the log file? (y/N)" 
    if ($openLog -eq 'Y' -or $openLog -eq 'y') { 
        notepad $LogPath 
    } 
}

# Explorer restart
Stop-Process explorer -Force
Start-Process explorer.exe

Write-Log "Provisioning complete"
