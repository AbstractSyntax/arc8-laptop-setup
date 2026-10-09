# Show laptop prep
# Edit GitHubOwner and GitHubRepo, push, then run:
#   irm https://github.com/OWNER/REPO/raw/main/setup.ps1 | iex
# Create a GitHub Release tagged "installers" and attach the assets named below.

$global:GitHubOwner = "AbstractSyntax"
$global:GitHubRepo = "arc8-laptop-setup"
$global:Branch = "main"
$global:ReleaseTag = "installers"
$global:CompanionAsset = "companion-win64.exe"
$global:AtemZip = "C:\ShowLaptopPrep\ATEM-Switchers.zip"
$global:StageTimerAsset = "Stagetimer-setup.exe"
$global:InputDirectorAsset = "InputDirector.zip"

$global:ScriptUrl = "https://github.com/$($global:GitHubOwner)/$($global:GitHubRepo)/raw/$($global:Branch)/setup.ps1"
$global:WallpaperUrl = "https://github.com/$($global:GitHubOwner)/$($global:GitHubRepo)/raw/$($global:Branch)/assets/wallpaper.jpg"
$global:ReleaseBase = "https://github.com/$($global:GitHubOwner)/$($global:GitHubRepo)/releases/download/$($global:ReleaseTag)"
$global:ProgramDataDir = "C:\ProgramData\ShowLaptopPrep"
$global:Failures = @()

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Continue"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ReleaseConfigured {
    if ($global:GitHubOwner -eq "OWNER" -or $global:GitHubRepo -eq "REPO") {
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($global:GitHubOwner) -or [string]::IsNullOrWhiteSpace($global:GitHubRepo)) {
        return $false
    }
    return $true
}

if ($env:OS -ne "Windows_NT") {
    Write-Host "This script only runs on Windows."
    exit 1
}

$global:WorkDir = Join-Path $env:TEMP "ShowLaptopPrep"
$global:WallpaperPath = Join-Path $global:ProgramDataDir "wallpaper.jpg"
$global:LogFile = Join-Path $global:WorkDir "log.txt"

if (-not (Test-IsAdmin)) {
    if (-not (Test-ReleaseConfigured)) {
        Write-Host "Edit GitHubOwner and GitHubRepo at the top of setup.ps1, push that file, then run the irm command."
        exit 1
    }
    Write-Host "Requesting administrator rights..."
    $command = "irm '$($global:ScriptUrl)' | iex"
    $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    try {
        Start-Process -FilePath $powershell -Verb RunAs -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            $command
        )
    } catch {
        Write-Host "Administrator approval was not granted. $($_.Exception.Message)"
        exit 1
    }
    exit
}

if (-not (Test-Path -LiteralPath $global:WorkDir)) {
    New-Item -ItemType Directory -Path $global:WorkDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $global:ProgramDataDir)) {
    New-Item -ItemType Directory -Path $global:ProgramDataDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    try {
        Add-Content -LiteralPath $global:LogFile -Value $line -ErrorAction Stop
    } catch {
    }
}

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Log "---- $Name ----"
    try {
        & $Action
        Write-Log "Done: $Name"
    } catch {
        Write-Log "FAILED: $Name -- $($_.Exception.Message)"
        $global:Failures += $Name
    }
}

function Set-Dword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
    } catch {
        Write-Log "Could not set $Name at ${Path}: $($_.Exception.Message)"
    }
}

function Set-StringValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        if ([string]::IsNullOrEmpty($Name)) {
            Set-Item -LiteralPath $Path -Value $Value
            return
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    } catch {
        Write-Log "Could not set $Name at ${Path}: $($_.Exception.Message)"
    }
}

function Enable-NativeHelpers {
    if ("ShowLaptopNative" -as [type]) {
        return
    }
    $code = @'
using System;
using System.Runtime.InteropServices;
public class ShowLaptopNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct STICKYKEYS {
        public int cbSize;
        public int dwFlags;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct FILTERKEYS {
        public int cbSize;
        public int dwFlags;
        public int iWaitMSec;
        public int iDelayMSec;
        public int iRepeatMSec;
        public int iBounceMSec;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct TOGGLEKEYS {
        public int cbSize;
        public int dwFlags;
    }
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetWallpaper(int uiAction, int uiParam, string pvParam, int fWinIni);
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    public static extern bool SetSticky(int uiAction, int uiParam, ref STICKYKEYS pvParam, int fWinIni);
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    public static extern bool SetFilter(int uiAction, int uiParam, ref FILTERKEYS pvParam, int fWinIni);
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    public static extern bool SetToggle(int uiAction, int uiParam, ref TOGGLEKEYS pvParam, int fWinIni);
}
'@
    Add-Type -TypeDefinition $code -Language CSharp
}

function Get-OfficeVersionText {
    $clickToRun = "not-installed"
    $cfg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
    if ($cfg -and $cfg.VersionToReport) {
        $clickToRun = [string]$cfg.VersionToReport
    }
    $powerPoint = "not-found"
    $candidates = @(
        (Join-Path $env:ProgramFiles "Microsoft Office\root\Office16\POWERPNT.EXE"),
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\root\Office16\POWERPNT.EXE")
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            $powerPoint = (Get-Item -LiteralPath $path).VersionInfo.FileVersion
            break
        }
    }
    return "ClickToRun=$clickToRun PowerPoint=$powerPoint"
}

function Update-ShowOffice {
    $c2r = $null
    $candidates = @(
        (Join-Path $env:ProgramFiles "Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe")
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            $c2r = $path
            break
        }
    }
    if (-not $c2r) {
        Write-Log "Office Click-to-Run was not found. Skipping the PowerPoint update."
        return
    }
    $before = Get-OfficeVersionText
    Write-Log "Office before: $before"
    $updateArgs = "/update user displaylevel=false forceappshutdown=true updatepromptuser=false"
    $proc = Start-Process -FilePath $c2r -ArgumentList $updateArgs -PassThru
    $deadline = (Get-Date).AddMinutes(30)
    $quietSince = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 15
        $current = Get-OfficeVersionText
        if ($current -ne $before) {
            Write-Log "Office version changed."
            break
        }
        $workers = @(Get-Process -Name "OfficeC2RClient" -ErrorAction SilentlyContinue)
        if ($workers.Count -gt 0) {
            $quietSince = $null
            Write-Log "Office update still running."
            continue
        }
        if (-not $quietSince) {
            $quietSince = Get-Date
        }
        $quietFor = (Get-Date) - $quietSince
        if ($quietFor.TotalSeconds -ge 180) {
            Write-Log "Office update client is idle and the version is unchanged."
            break
        }
    }
    if ((Get-Date) -ge $deadline) {
        Write-Log "Office update wait reached 30 minutes. Continuing."
    }
    if ($proc -and -not $proc.HasExited) {
        Write-Log "OfficeC2RClient launcher is still open."
    } elseif ($proc) {
        Write-Log "OfficeC2RClient launcher exit code $($proc.ExitCode)"
    }
    Write-Log ("Office after: " + (Get-OfficeVersionText))
}

function Move-DesktopToOld {
    $folders = @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("CommonDesktopDirectory")
    )
    foreach ($desk in $folders) {
        if ([string]::IsNullOrWhiteSpace($desk) -or -not (Test-Path -LiteralPath $desk)) {
            Write-Log "Desktop folder not found."
            continue
        }
        $old = Join-Path $desk "OLD"
        if (-not (Test-Path -LiteralPath $old)) {
            New-Item -ItemType Directory -Path $old | Out-Null
        }
        $items = @(Get-ChildItem -LiteralPath $desk -Force | Where-Object {
            $_.Name -ne "OLD" -and $_.Name -ne "desktop.ini"
        })
        foreach ($item in $items) {
            try {
                $target = Join-Path $old $item.Name
                if (Test-Path -LiteralPath $target) {
                    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
                    $target = Join-Path $old ("{0}-{1}{2}" -f $item.BaseName, $stamp, $item.Extension)
                }
                Move-Item -LiteralPath $item.FullName -Destination $target -Force
                Write-Log "Moved $($item.FullName)"
            } catch {
                Write-Log "Could not move $($item.FullName): $($_.Exception.Message)"
            }
        }
    }
}

function Save-RemoteFile {
    param(
        [string]$Url,
        [string]$Dest
    )
    $parent = Split-Path -Parent $Dest
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Force
    }
    Write-Log "Downloading $Url"
    $downloaded = $false
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -MaximumRedirection 10
        $downloaded = $true
    } catch {
        Write-Log "Invoke-WebRequest failed: $($_.Exception.Message)"
        $curl = Join-Path $env:SystemRoot "System32\curl.exe"
        if (Test-Path -LiteralPath $curl) {
            & $curl -L --fail --retry 3 --retry-delay 2 -o $Dest $Url
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $Dest)) {
                $downloaded = $true
                Write-Log "Downloaded with curl.exe"
            }
        }
    }
    if (-not $downloaded -or -not (Test-Path -LiteralPath $Dest)) {
        throw "Download failed: $Url"
    }
    $length = (Get-Item -LiteralPath $Dest).Length
    if ($length -lt 1024) {
        throw "Download looks empty: $Dest"
    }
    Unblock-File -LiteralPath $Dest
    $mb = [math]::Round($length / 1MB, 1)
    Write-Log "Saved $Dest ($mb MB)"
}

function Test-ImageFile {
    param([string]$Path)
    $stream = [System.IO.File]::Open($Path, "Open", "Read", "Read")
    try {
        $bytes = New-Object byte[] 8
        $read = $stream.Read($bytes, 0, 8)
    } finally {
        $stream.Dispose()
    }
    if ($read -lt 8) {
        return $false
    }
    if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8) {
        return $true
    }
    if ($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47) {
        return $true
    }
    if ($bytes[0] -eq 0x42 -and $bytes[1] -eq 0x4D) {
        return $true
    }
    return $false
}

function Set-ShowWallpaper {
    if (-not (Test-ReleaseConfigured)) {
        throw "GitHubOwner and GitHubRepo are still the placeholders."
    }
    $tempImage = Join-Path $global:WorkDir "wallpaper.jpg"
    Save-RemoteFile -Url $global:WallpaperUrl -Dest $tempImage
    if (-not (Test-ImageFile -Path $tempImage)) {
        throw "Downloaded wallpaper is not a JPEG, PNG, or BMP. Add assets/wallpaper.jpg to the repo."
    }
    Copy-Item -LiteralPath $tempImage -Destination $global:WallpaperPath -Force
    Set-StringValue "HKCU:\Control Panel\Desktop" "Wallpaper" $global:WallpaperPath
    Set-StringValue "HKCU:\Control Panel\Desktop" "WallpaperStyle" "10"
    Set-StringValue "HKCU:\Control Panel\Desktop" "TileWallpaper" "0"
    Enable-NativeHelpers
    $applied = [ShowLaptopNative]::SetWallpaper(0x0014, 0, $global:WallpaperPath, 3)
    if (-not $applied) {
        Write-Log "SystemParametersInfo did not confirm the wallpaper. The registry value is still set."
    }
    $policy = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-StringValue $policy "Wallpaper" $global:WallpaperPath
    Set-StringValue $policy "WallpaperStyle" "4"
    Write-Log "Wallpaper set to $($global:WallpaperPath)"
}

function Disable-WindowsUpdate {
    $au = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Set-Dword $au "NoAutoUpdate" 1
    Set-Dword $au "AUOptions" 1
    Set-Dword $au "NoAutoRebootWithLoggedOnUsers" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 100
    foreach ($svc in @("wuauserv", "UsoSvc", "DoSvc")) {
        try {
            Stop-Service -Name $svc -Force -ErrorAction Stop
            Write-Log "Stopped service $svc"
        } catch {
            Write-Log "Could not stop ${svc}: $($_.Exception.Message)"
        }
        try {
            Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
            Write-Log "Disabled service $svc"
        } catch {
            Write-Log "Could not disable ${svc}: $($_.Exception.Message)"
        }
    }
}

function Disable-Notifications {
    $toastPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    $toastPolicyUser = "HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    Set-Dword $toastPolicy "NoToastApplicationNotification" 1
    Set-Dword $toastPolicyUser "NoToastApplicationNotification" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableNotificationCenter" 1
    Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableNotificationCenter" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableLockScreenAppNotifications" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0

    $noc = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
    Set-Dword $noc "NOC_GLOBAL_SETTING_TOASTS_ENABLED" 0
    Set-Dword $noc "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS" 0
    Set-Dword $noc "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" 0
    Set-Dword $noc "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0

    $content = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $contentNames = @(
        "SoftLandingEnabled",
        "SystemPaneSuggestionsEnabled",
        "SilentInstalledAppsEnabled",
        "SubscribedContent-310093Enabled",
        "SubscribedContent-338387Enabled",
        "SubscribedContent-338388Enabled",
        "SubscribedContent-338389Enabled",
        "SubscribedContent-338393Enabled",
        "SubscribedContent-353694Enabled",
        "SubscribedContent-353696Enabled",
        "SubscribedContent-353698Enabled"
    )
    foreach ($name in $contentNames) {
        Set-Dword $content $name 0
    }
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" 2
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" "EnableFeeds" 0
}

function Set-NoSounds {
    $schemes = "HKCU:\AppEvents\Schemes"
    if (Test-Path -LiteralPath $schemes) {
        Set-Item -LiteralPath $schemes -Value ".None"
    }
    $apps = "HKCU:\AppEvents\Schemes\Apps"
    if (Test-Path -LiteralPath $apps) {
        Get-ChildItem -LiteralPath $apps -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSChildName -eq ".Current") {
                Set-Item -LiteralPath $_.PSPath -Value "" -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Log "Windows sound scheme set to No Sounds."
}

function Disable-NightLight {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default`$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate"
    if (-not (Test-Path -LiteralPath $key)) {
        Write-Log "Night light has not been turned on. Leaving the default, which is off."
        return
    }
    $data = (Get-ItemProperty -LiteralPath $key -Name Data -ErrorAction SilentlyContinue).Data
    if (-not $data -or $data.Length -le 18) {
        Write-Log "Night light state was already off or unreadable."
        return
    }
    if ($data[18] -eq 0x15) {
        $data[18] = 0x13
        Set-ItemProperty -LiteralPath $key -Name Data -Value ([byte[]]$data)
        Write-Log "Night light turned off."
        return
    }
    Write-Log "Night light state was not the enabled pattern. Leaving it unchanged."
}

function Set-AccessibilityOff {
    # 498, 114, and 50 drop the On, hotkey, and confirm-hotkey bits from the default off values.
    Set-StringValue "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "498"
    Set-StringValue "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "114"
    Set-StringValue "HKCU:\Control Panel\Accessibility\ToggleKeys" "Flags" "50"
    Enable-NativeHelpers
    $sticky = New-Object ShowLaptopNative+STICKYKEYS
    $sticky.cbSize = 8
    $sticky.dwFlags = 498
    [void][ShowLaptopNative]::SetSticky(0x003B, $sticky.cbSize, [ref]$sticky, 3)
    $filter = New-Object ShowLaptopNative+FILTERKEYS
    $filter.cbSize = 24
    $filter.dwFlags = 114
    $filter.iWaitMSec = 1000
    $filter.iDelayMSec = 1000
    $filter.iRepeatMSec = 500
    $filter.iBounceMSec = 0
    [void][ShowLaptopNative]::SetFilter(0x0033, $filter.cbSize, [ref]$filter, 3)
    $toggle = New-Object ShowLaptopNative+TOGGLEKEYS
    $toggle.cbSize = 8
    $toggle.dwFlags = 50
    [void][ShowLaptopNative]::SetToggle(0x0035, $toggle.cbSize, [ref]$toggle, 3)
    Write-Log "Sticky Keys, Filter Keys, and Toggle Keys are off, including the shortcuts."
}

function Set-ShowPower {
    $high = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $listed = (& powercfg.exe /list | Out-String)
    if ($listed -notmatch $high) {
        & powercfg.exe -duplicatescheme $high | Out-Null
    }
    & powercfg.exe -setactive $high | Out-Null
    $changes = @(
        @("/change", "monitor-timeout-ac", "0"),
        @("/change", "monitor-timeout-dc", "0"),
        @("/change", "standby-timeout-ac", "0"),
        @("/change", "standby-timeout-dc", "0"),
        @("/change", "hibernate-timeout-ac", "0"),
        @("/change", "hibernate-timeout-dc", "0"),
        @("/change", "disk-timeout-ac", "0"),
        @("/change", "disk-timeout-dc", "0")
    )
    foreach ($change in $changes) {
        & powercfg.exe @change | Out-Null
    }
    & powercfg.exe -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 | Out-Null
    & powercfg.exe -setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 | Out-Null
    & powercfg.exe -setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
    & powercfg.exe -setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
    $usbSubgroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSetting = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    & powercfg.exe -setacvalueindex SCHEME_CURRENT $usbSubgroup $usbSetting 0 | Out-Null
    & powercfg.exe -setdcvalueindex SCHEME_CURRENT $usbSubgroup $usbSetting 0 | Out-Null
    & powercfg.exe -setactive SCHEME_CURRENT | Out-Null
    Set-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
    Set-StringValue "HKCU:\Control Panel\Desktop" "ScreenSaveActive" "0"
    Set-StringValue "HKCU:\Control Panel\Desktop" "ScreenSaveTimeOut" "0"
    Write-Log "Sleep, lid close, screensaver, USB suspend, and Fast Startup are set."
}

function Sync-Clock {
    try {
        Set-Service -Name w32time -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        $output = & "$env:SystemRoot\System32\w32tm.exe" /resync /force 2>&1
        Write-Log ("Time sync: " + (($output | Out-String).Trim()))
    } catch {
        Write-Log "Time sync failed: $($_.Exception.Message)"
    }
}

function Set-Win11Shell {
    $buildText = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    $build = 0
    [void][int]::TryParse([string]$buildText, [ref]$build)
    if ($build -lt 22000) {
        Write-Log "Windows 10 detected. Skipping the classic menu, left Start, and Copilot."
        return
    }
    $clsid = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (-not (Test-Path -LiteralPath $clsid)) {
        New-Item -Path $clsid -Force | Out-Null
    }
    Set-Item -LiteralPath $clsid -Value ""
    Write-Log "Classic Windows 10 right-click menu enabled."
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0
    Write-Log "Start menu aligned left."
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
    Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
    $packages = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Copilot" })
    foreach ($pkg in $packages) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "Removed app $($pkg.Name)"
        } catch {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "Removed app $($pkg.Name) for the current user."
            } catch {
                Write-Log "Could not remove $($pkg.Name): $($_.Exception.Message)"
            }
        }
    }
    $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Copilot" })
    foreach ($pkg in $provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
            Write-Log "Removed provisioned package $($pkg.DisplayName)"
        } catch {
            Write-Log "Could not remove provisioned $($pkg.DisplayName): $($_.Exception.Message)"
        }
    }
    Write-Log "Copilot policy is on. A later Windows update can restore the Store app. The policy keeps the feature off."
}

function Expand-ZipSafe {
    param(
        [string]$Zip,
        [string]$Dest
    )
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Dest)
}

function Find-SetupExe {
    param(
        [string]$Root,
        [string]$Prefer
    )
    $exes = @(Get-ChildItem -LiteralPath $Root -Filter *.exe -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch "vcredist|vc_redist|uninstall"
    })
    if ($Prefer) {
        $preferred = @($exes | Where-Object { $_.Name -match $Prefer })
        if ($preferred.Count -gt 0) {
            return $preferred[0].FullName
        }
    }
    if ($exes.Count -gt 0) {
        return $exes[0].FullName
    }
    return $null
}

function Start-LoggedInstaller {
    param(
        [string]$Name,
        [string]$File,
        [string]$ArgumentList
    )
    Write-Log "Running $Name"
    $proc = Start-Process -FilePath $File -ArgumentList $ArgumentList -Wait -PassThru
    $code = $proc.ExitCode
    Write-Log "$Name exit code $code"
    if ($code -ne 0 -and $code -ne 3010 -and $code -ne 1641) {
        throw "$Name exit code $code"
    }
}

function Install-ReleaseApp {
    param(
        [string]$Name,
        [string]$Asset,
        [string]$Kind
    )
    if (-not (Test-ReleaseConfigured)) {
        throw "GitHubOwner and GitHubRepo are still the placeholders."
    }
    $url = "$($global:ReleaseBase)/$Asset"
    $dest = Join-Path $global:WorkDir $Asset
    Save-RemoteFile -Url $url -Dest $dest
    if ($Kind -eq "companion") {
        Start-LoggedInstaller -Name $Name -File $dest -ArgumentList "/S /allusers /NORESTART"
        return
    }
    if ($Kind -eq "nsis") {
        Start-LoggedInstaller -Name $Name -File $dest -ArgumentList "/S"
        return
    }
    if ($Kind -eq "inputdirector") {
        $extract = Join-Path $global:WorkDir "inputdirector"
        Expand-ZipSafe -Zip $dest -Dest $extract
        $setup = Find-SetupExe -Root $extract -Prefer "Setup"
        if (-not $setup) {
            throw "No Input Director setup exe was found in the zip."
        }
        Start-LoggedInstaller -Name $Name -File $setup -ArgumentList "/S"
        return
    }
    throw "Unknown installer kind $Kind"
}

function Install-LocalAtem {
    if (-not (Test-Path -LiteralPath $global:AtemZip)) {
        throw "Copy ATEM-Switchers.zip to C:\ShowLaptopPrep\ before running this script. Include the Install ATEM exe, the hidden InstallerSupport.dat, and the BlackmagicSwitchers cab files."
    }
    Write-Log "Using local ATEM zip $($global:AtemZip)"
    $extract = Join-Path $global:WorkDir "atem"
    Expand-ZipSafe -Zip $global:AtemZip -Dest $extract
    $setup = Find-SetupExe -Root $extract -Prefer "Install"
    if (-not $setup) {
        throw "No ATEM installer exe was found in $($global:AtemZip)."
    }
    Start-LoggedInstaller -Name "ATEM Software Control" -File $setup -ArgumentList "/q /nosplash"
}

function Find-FirstPath {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    return $null
}

function Find-ByFilter {
    param(
        [string[]]$Roots,
        [string]$Filter
    )
    foreach ($root in $Roots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) {
            continue
        }
        $hit = Get-ChildItem -LiteralPath $root -Filter $Filter -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) {
            return $hit.FullName
        }
    }
    return $null
}

function Add-ShowFirewallRule {
    param(
        [string]$DisplayName,
        [string]$Program
    )
    if (-not $Program) {
        Write-Log "Firewall skip, program not found: $DisplayName"
        return
    }
    try {
        $existing = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Log "Firewall rule already exists: $DisplayName"
            return
        }
        New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Program $Program -Action Allow -Profile Private -Enabled True | Out-Null
        Write-Log "Firewall allow: $DisplayName -> $Program"
    } catch {
        Write-Log "Firewall rule failed for ${DisplayName}: $($_.Exception.Message)"
    }
}

function Set-ShowFirewall {
    $companion = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Companion\Companion.exe"),
        (Join-Path $env:ProgramFiles "companion\Companion.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\companion\Companion.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Companion\Companion.exe")
    )
    if (-not $companion) {
        $companion = Find-ByFilter @(
            (Join-Path $env:ProgramFiles "Companion"),
            (Join-Path $env:ProgramFiles "companion"),
            (Join-Path $env:LOCALAPPDATA "Programs")
        ) "Companion.exe"
    }
    $atem = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Blackmagic Design\Blackmagic ATEM Switchers\ATEM Software Control\ATEM Software Control.exe")
    )
    if (-not $atem) {
        $atem = Find-ByFilter @((Join-Path $env:ProgramFiles "Blackmagic Design")) "ATEM Software Control.exe"
    }
    $stage = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Stagetimer\Stagetimer.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Stagetimer\Stagetimer.exe")
    )
    if (-not $stage) {
        $stage = Find-ByFilter @(
            $env:ProgramFiles,
            ${env:ProgramFiles(x86)},
            (Join-Path $env:LOCALAPPDATA "Programs")
        ) "Stagetimer.exe"
    }
    $inputDirector = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Input Director\InputDirector.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Input Director\InputDirector.exe")
    )
    Add-ShowFirewallRule -DisplayName "Show Prep Companion" -Program $companion
    Add-ShowFirewallRule -DisplayName "Show Prep ATEM Software Control" -Program $atem
    Add-ShowFirewallRule -DisplayName "Show Prep Stagetimer" -Program $stage
    Add-ShowFirewallRule -DisplayName "Show Prep Input Director" -Program $inputDirector
    $helper = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Input Director\InputDirectorSessionHelper.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Input Director\InputDirectorSessionHelper.exe")
    )
    Add-ShowFirewallRule -DisplayName "Show Prep Input Director Session" -Program $helper
}

function Disable-StartupPrograms {
    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($key in $runKeys) {
        if (-not (Test-Path -LiteralPath $key)) {
            continue
        }
        $item = Get-Item -LiteralPath $key
        foreach ($name in @($item.Property)) {
            if ([string]::IsNullOrEmpty($name)) {
                continue
            }
            $value = (Get-ItemProperty -LiteralPath $key -Name $name).$name
            Write-Log "Removing startup entry $name = $value"
            Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue
        }
    }
    $disabledStartup = Join-Path $global:ProgramDataDir "DisabledStartup"
    if (-not (Test-Path -LiteralPath $disabledStartup)) {
        New-Item -ItemType Directory -Path $disabledStartup -Force | Out-Null
    }
    $startupFolders = @(
        [Environment]::GetFolderPath("Startup"),
        [Environment]::GetFolderPath("CommonStartup")
    )
    foreach ($folder in $startupFolders) {
        if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder)) {
            continue
        }
        $shortcuts = @(Get-ChildItem -LiteralPath $folder -Force | Where-Object { $_.Name -ne "desktop.ini" })
        foreach ($shortcut in $shortcuts) {
            try {
                $target = Join-Path $disabledStartup $shortcut.Name
                if (Test-Path -LiteralPath $target) {
                    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
                    $target = Join-Path $disabledStartup ("{0}-{1}{2}" -f $shortcut.BaseName, $stamp, $shortcut.Extension)
                }
                Move-Item -LiteralPath $shortcut.FullName -Destination $target -Force
                Write-Log "Moved startup shortcut $($shortcut.FullName)"
            } catch {
                Write-Log "Could not move startup shortcut $($shortcut.Name): $($_.Exception.Message)"
            }
        }
    }
    $approvedKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"
    )
    $disabled = [byte[]](0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    foreach ($key in $approvedKeys) {
        if (-not (Test-Path -LiteralPath $key)) {
            continue
        }
        $item = Get-Item -LiteralPath $key
        foreach ($name in @($item.Property)) {
            if ([string]::IsNullOrEmpty($name)) {
                continue
            }
            New-ItemProperty -Path $key -Name $name -Value $disabled -PropertyType Binary -Force | Out-Null
            Write-Log "Disabled startup approval $name"
        }
    }
    $edge = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe")
    )
    if ($edge) {
        Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "StartupBoostEnabled" 0
        Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 0
        Write-Log "Edge startup boost and background mode off."
    }
    $chrome = Find-FirstPath @(
        (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe")
    )
    if ($chrome) {
        Set-Dword "HKLM:\SOFTWARE\Policies\Google\Chrome" "BackgroundModeEnabled" 0
        Write-Log "Chrome background mode off."
    }
}

function Restart-ExplorerShell {
    Write-Log "Restarting Explorer."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
}

$buildText = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
Write-Log "Show laptop prep started on $env:COMPUTERNAME build $buildText"
Write-Log "Log file: $($global:LogFile)"
if (-not (Test-ReleaseConfigured)) {
    Write-Log "GitHubOwner and GitHubRepo are still placeholders. Installer and wallpaper downloads will fail. Windows settings will still be applied."
}

Invoke-Step "Update Office" { Update-ShowOffice }
Invoke-Step "Archive desktop" { Move-DesktopToOld }
Invoke-Step "Wallpaper" { Set-ShowWallpaper }
Invoke-Step "Windows Update" { Disable-WindowsUpdate }
Invoke-Step "Notifications" { Disable-Notifications }
Invoke-Step "Sounds" { Set-NoSounds }
Invoke-Step "Night light" { Disable-NightLight }
Invoke-Step "Accessibility" { Set-AccessibilityOff }
Invoke-Step "Power" { Set-ShowPower }
Invoke-Step "Clock" { Sync-Clock }
Invoke-Step "Windows 11 shell" { Set-Win11Shell }
Invoke-Step "Install Companion" {
    Install-ReleaseApp -Name "Bitfocus Companion" -Asset $global:CompanionAsset -Kind "companion"
}
Invoke-Step "Install ATEM" { Install-LocalAtem }
Invoke-Step "Install Stagetimer" {
    Install-ReleaseApp -Name "Stagetimer" -Asset $global:StageTimerAsset -Kind "nsis"
}
Invoke-Step "Install Input Director" {
    Install-ReleaseApp -Name "Input Director" -Asset $global:InputDirectorAsset -Kind "inputdirector"
}
Invoke-Step "Firewall" { Set-ShowFirewall }
Invoke-Step "Startup programs" { Disable-StartupPrograms }
Invoke-Step "Restart Explorer" { Restart-ExplorerShell }

Write-Log "---- Summary ----"
if ($global:Failures.Count -eq 0) {
    Write-Log "Finished with no failed steps."
} else {
    Write-Log ("Failed steps: " + ($global:Failures -join ", "))
}
Write-Log "Rebooting in 20 seconds."
& "$env:SystemRoot\System32\shutdown.exe" /r /t 20 /c "Show laptop prep finished"
