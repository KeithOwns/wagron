<#
.SYNOPSIS
    WinAuto (Core Edition)
.DESCRIPTION
    A lightweight, single-file version of the WinAuto suite for Windows 11.
    Focuses purely on Configuration (Security/UI) and Maintenance (Updates/Repair).
    
    Usage: Copy and paste this script into an Administrator PowerShell window.
#>


# --- CLI PARAMETERS ---
param(
    [Parameter(Mandatory = $false)]
    [string]$Module,

    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$Config
    
    # Verbose is automatic due to [Parameter()] attributes
)

# Admin check (manual, for iex compatibility â€” #Requires does not work with Invoke-Expression)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run in an elevated PowerShell window."
    return
}

# Validate -Module (manual check for iex compatibility)
if ($Module -and $Module -notin @("SmartRun", "Install", "Config", "Maintenance", "Help")) {
    Write-Error "Invalid Module: '$Module'. Valid values: SmartRun, Install, Config, Maintenance, Help"
    return
}

$Global:Silent = $Silent
$Global:Module = $Module
$Global:Config = $Config
$Global:LogPath = $LogPath

# --- EXECUTION POLICY CONFIGURATION ---
# Ensures local scripts can run by setting policy to 'RemoteSigned'
try {
    $currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ($currentPolicy -ne "RemoteSigned") {
        Set-ExecutionPolicy -ExecutionPolicy "RemoteSigned" -Scope "LocalMachine" -Force -ErrorAction Stop
        Write-Host "Execution Policy set to 'RemoteSigned' for LocalMachine."
    }
}
catch {
    Write-Warning "Failed to set Execution Policy: $_"
}

# --- AUTO-UNBLOCK ROUTINE ---
# Removes 'Mark of the Web' from the script and its components to prevent "not digitally signed" errors.
try {
    if ($PSCommandPath) { Unblock-File -Path $PSCommandPath -ErrorAction SilentlyContinue }
    if ($PSScriptRoot) {
        Get-ChildItem -Path $PSScriptRoot -Filter "*.ps*" -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    }
}
catch {}

# --- INITIAL SETUP ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Global:ShowDetails = $false
$Global:WinAutoFirstLoad = $true

# --- SYSTEM PATHS ---
$Global:WinAutoLogDir = $null
$Global:WinAutoLogPath = $null

if ($LogPath) {
    if (Test-Path $LogPath -PathType Container) {
        $Global:WinAutoLogDir = $LogPath
    }
    else {
        # Assume full file path or new directory
        $Global:WinAutoLogDir = Split-Path $LogPath -Parent
        if (-not $Global:WinAutoLogDir) { $Global:WinAutoLogDir = $PWD.Path }
    }
}

if ($null -eq $Global:WinAutoLogDir) {
    # Use local 'logs' folder relative to script
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
    $Global:WinAutoLogDir = Join-Path $root "logs"
}

if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -ItemType Directory -Force -Path $Global:WinAutoLogDir | Out-Null }
$env:WinAutoLogDir = $Global:WinAutoLogDir

if ($LogPath -and (Test-Path $LogPath -PathType Leaf)) {
    # User provided an existing file
    $Global:WinAutoLogPath = $LogPath
}
elseif ($LogPath -and -not (Test-Path $LogPath)) {
    # User provided a new file path (folder logic handled earlier) or just a folder
    if ($LogPath -match "\.\w+$") {
        # Likely a file path
        $Global:WinAutoLogPath = $LogPath
    }
    else {
        # Likely a folder
        $Global:WinAutoLogPath = Join-Path $Global:WinAutoLogDir "wa.log"
    }
}
else {
    # Default behavior
    $Global:WinAutoLogPath = Join-Path $Global:WinAutoLogDir "wa.log"
}

# --- GLOBAL ERROR TRAP ---


# --- GLOBAL RESOURCES ---
# Centralized definition of ANSI colors and Unicode characters.

# --- ANSI Escape Sequences ---
$Esc = [char]0x1B
$Global:Reset = "$Esc[0m"
$Global:Bold = "$Esc[1m"

# Script Palette (Foreground)
$Global:FGCyan = "$Esc[96m"
$Global:FGBlue = "$Esc[94m"
$Global:FGDarkBlue = "$Esc[34m"
$Global:FGGreen = "$Esc[92m"
$Global:FGRed = "$Esc[91m"
$Global:FGYellow = "$Esc[93m"
$Global:FGDarkGray = "$Esc[90m"
$Global:FGDarkRed = "$Esc[31m"
$Global:FGDarkGreen = "$Esc[32m"
$Global:FGDarkCyan = "$Esc[36m"
$Global:FGMagenta = "$Esc[95m"


$Global:FGWhite = "$Esc[97m"
$Global:FGGray = "$Esc[37m"
$Global:FGDarkYellow = "$Esc[33m"

# --- LOGGING & REGISTRY ---
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO', [string]$Path = $Global:WinAutoLogPath)
    if (-not $Path) { $Path = "C:\Windows\Temp\WinAuto.log" }
    
    # Verbose Output (CLI Support)
    if ($Global:VerbosePreference -eq 'Continue') {
        Write-Host "[$Level] $Message" -ForegroundColor Gray
    }

    $logDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $Path -Value "[$timestamp] [$Level] $Message" -ErrorAction SilentlyContinue
}

# --- GLOBAL ERROR TRAP ---
trap {
    $msg = "CRITICAL UNHANDLED ERROR: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    try { Write-Log $msg -Level ERROR } catch { Write-Host "LOG FAIL: $msg" -ForegroundColor Red }
    Write-Error $msg
    return
}

# --- MANIFEST CONTENT ---
$Global:WinAutoManifestContent = @'
- wa.ps1: Functional Outline -
________________________________________________________
Pre-Run Setup
- Execution Policy check    | (Inline)
- Administrator check       | (Inline)
- Environment Setup         | (Inline: Variables, Logging, UI Types)
________________________________________________________
[S]martRUN
Method: Orchestration Loop
Actions:
- Install Apps Check        | Invoke-WA_InstallApps
- Configuration Check       | Invoke-WinAutoConfiguration -SmartRun
- Maintenance Check         | Invoke-WinAutoMaintenance -SmartRun
________________________________________________________
[I]nstall Applications
Method: Config Driven (Embedded JSON)
Actions:
- Read Config & Detect Type | Get-WA_InstallAppList
- Check Installed State     | Test-AppInstalled
- Install (Winget/MSI/EXE)  | Invoke-WA_InstallApps
________________________________________________________
[C]onfiguration
Security Actions:
- Real-Time Protection      | Invoke-WA_SetRealTimeProtection (Set-MpPreference)
- PUA Protection            | Invoke-WA_SetPUA (Set-MpPreference)
- Memory Integrity          | Invoke-WA_SetMemoryIntegrity (Registry)
- Kernel Stack Protection   | Invoke-WA_SetKernelStack (Registry)
- LSA Protection            | Invoke-WA_SetLSA (Reg: Control\Lsa)
- Windows Firewall          | Invoke-WA_SetFirewall (Set-NetFirewallProfile)
- SmartScreen (UIA)         | Invoke-WA_SetSmartScreen (UI Automation)
- Defender Remediation (UIA)| Invoke-WA_SetVirusThreatProtect (UI Automation)
UI & UX Actions:
- Taskbar/Search/Widgets    | Invoke-WA_SetTaskbarDefaults (Reg: HKCU/HKLM)
- Windows Update Config     | Invoke-WA_SetWindowsUpdateConfig (Reg: UX/Settings)
________________________________________________________

[M]aintenance
Orchestrated Maintenance:
- System Pre-Flight Check   | Invoke-WA_SystemPreCheck
- Windows Update (API/UI)   | Invoke-WA_WindowsUpdate
- SFC System Scan           | Invoke-WA_SFCRepair (Conditional: 30 days)
- DISM Repair               | Invoke-WA_SFCRepair (Triggered on corruption)
- WinGet/Store Updates      | Invoke-WA_WindowsUpdate
- Drive Opt (Trim/Defrag)   | Invoke-WA_OptimizeDisks (Conditional: 7 days)
- System Cleanup            | Invoke-WA_SystemCleanup (Conditional: 7 days)
'@
$Global:FGBlack = "$Esc[30m"

# Script Palette (Background)
$Global:BGDarkGreen = "$Esc[42m"
$Global:BGDarkGray = "$Esc[100m"
$Global:BGYellow = "$Esc[103m"
$Global:BGRed = "$Esc[41m"
$Global:BGDarkRed = "$Esc[41m"
$Global:BGDarkCyan = "$Esc[46m"
$Global:BGWhite = "$Esc[107m"

# --- Unicode Icons & Characters ---
$Global:Char_HeavyCheck = "[v]" 

$Global:Char_Warn = "!" 
$Global:Char_BallotCheck = "[v]" 

$Global:Char_Copyright = "(c)" 
$Global:Char_Finger = "->" 
$Global:Char_CheckMark = "v" 
$Global:Char_FailureX = "x" 
$Global:Char_RedCross = "x"
$Global:Char_HeavyMinus = "-" 
$Global:Char_EnDash = "-"

$Global:RegPath_WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# --- MANIFEST CONTENT ---

$Global:WinAutoManifestContent = @"
${FGDarkCyan}============================================================${Reset}
${FGDarkCyan}__________________________________________________________${Reset}
${FGCyan}ACTION${Reset}                   ${FGDarkGray}|${Reset} ${FGCyan}STAGE${Reset}    ${FGDarkGray}|${Reset} ${FGDarkCyan}SOURCE SCRIPT${Reset}
${FGDarkGray}----------------------------------------------------------${Reset}
Adobe Creative Cloud     ${FGDarkGray}|${Reset} ${FGDarkCyan}Install${Reset}  ${FGDarkGray}|${Reset} ${FGGray}INSTALL_AdobeCC.ps1${Reset}
Box Drive                ${FGDarkGray}|${Reset} ${FGDarkCyan}Install${Reset}  ${FGDarkGray}|${Reset} ${FGGray}INSTALL_BoxDrive.ps1${Reset}
Box for Office           ${FGDarkGray}|${Reset} ${FGDarkCyan}Install${Reset}  ${FGDarkGray}|${Reset} ${FGGray}INSTALL_BoxOffice.ps1${Reset}
Box Tools                ${FGDarkGray}|${Reset} ${FGDarkCyan}Install${Reset}  ${FGDarkGray}|${Reset} ${FGGray}INSTALL_BoxTools.ps1${Reset}
Crestron AirMedia        ${FGDarkGray}|${Reset} ${FGDarkCyan}Install${Reset}  ${FGDarkGray}|${Reset} ${FGGray}INSTALL_AirMedia.ps1${Reset}
Real-Time Protection     ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_RealTimeProt.ps1${Reset}
PUA Protection           ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_PUABlockApps.ps1${Reset}
PUA Protection (Edge)    ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_PUABlockDLs.ps1${Reset}
Memory Integrity         ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_MemoryInteg.ps1${Reset}
Kernel Stack Protection  ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_KernelMode.ps1${Reset}
LSA Protection           ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_LocalSecurity.ps1${Reset}
Windows Firewall         ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_FirewallON.ps1${Reset}
Classic Context Menu     ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_ClassicMenu.ps1${Reset}
Taskbar Search Box       ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_TaskbarSearch.ps1${Reset}
Task View Toggle         ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_TaskViewOFF.ps1${Reset}
Microsoft Update Service ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_MicrosoftUpd.ps1${Reset}
Restart Notifications    ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_RestartIsReq.ps1${Reset}
App Restart Persistence  ${FGDarkGray}|${Reset} ${FGBlue}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_RestartApps.ps1${Reset}
Get Updates              ${FGDarkGray}|${Reset} ${FGDarkBlue}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_UpdateSuite.ps1${Reset}
WinGet App Updates       ${FGDarkGray}|${Reset} ${FGDarkBlue}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_WingetUpgrade.ps1${Reset}
Drive Optimization       ${FGDarkGray}|${Reset} ${FGDarkBlue}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_OptimizeDisks.ps1${Reset}
Temp File Cleanup        ${FGDarkGray}|${Reset} ${FGDarkBlue}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_SystemCleanup.ps1${Reset}
SFC / DISM Repair        ${FGDarkGray}|${Reset} ${FGDarkBlue}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_WindowsRepair.ps1${Reset}
${FGDarkCyan}__________________________________________________________${Reset}
${FGDarkCyan}__________________________________________________________${Reset}
"@

$Global:WinAutoCSVContent = @'
ACTION,STAGE,SOURCE SCRIPT,METHOD,TECHNICAL DETAILS,REVERTIBLE,RESTART REQUIRED,IMPACT,FUNCTION
Execution Policy / Admin Check,Pre-Run Setup,wa.ps1,Inline,Set-ExecutionPolicy RemoteSigned -Scope Process,N/A,No,System,(Script Header)
Auto-Unblock,Pre-Run Setup,wa.ps1,Inline,Unblock-File (Self),N/A,No,System,(Script Header)
System Hardening Check,SmartRUN,CHECK_SystemHarden.ps1,Mixed,Checks Last Run date (30 days) to determine invalidation,N/A,No,Automation,Invoke-WinAutoConfiguration -SmartRun
Maintenance Cycle,SmartRUN,SET_ScheduleMaintn.ps1,Mixed,Checks Last Run dates (SFC=30d; Disk=7d; Clean=7d) to trigger tasks,N/A,No,Automation,Invoke-WinAutoMaintenance -SmartRun
Adobe Creative Cloud,Install,INSTALL_AdobeCC.ps1,ATOMIC_SCRIPT,Uses AtomicScript for WinGet install,No,No,System,Invoke-WA_InstallApps
Box Drive,Install,INSTALL_BoxDrive.ps1,ATOMIC_SCRIPT,Note: MSI has specific uninstall GUID issues,No,No,System,Invoke-WA_InstallApps
Box for Office,Install,INSTALL_BoxOffice.ps1,ATOMIC_SCRIPT,EXE installer with silent args,No,No,System,Invoke-WA_InstallApps
Box Tools,Install,INSTALL_BoxTools.ps1,ATOMIC_SCRIPT,EXE installer with silent args,No,No,System,Invoke-WA_InstallApps
Crestron AirMedia,Install,INSTALL_AirMedia.ps1,ATOMIC_SCRIPT,Uses AtomicScript for WinGet/Machine install,No,No,System,Invoke-WA_InstallApps
Real-Time Protection,Configure,SET_RealTimeProt.ps1,PS WMI,Set-MpPreference -DisableRealtimeMonitoring 0,Yes,No,Security,Invoke-WA_SetRealTimeProtection
PUA Protection,Configure,SET_PUABlockApps.ps1,PS WMI,Set-MpPreference -PUAProtection 1,Yes,No,Security,Invoke-WA_SetPUABlockApps
PUA Protection (Edge),Configure,SET_PUABlockDLs.ps1,Registry (HKCU),HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled (1),Yes,No,Security,Invoke-WA_SetPUABlockDLs
Memory Integrity,Configure,SET_MemoryInteg.ps1,Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity (Enabled=1),Yes,Yes,Security,Invoke-WA_SetMemoryInteg
Kernel Stack Protection,Configure,SET_KernelMode.ps1,Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks (Enabled=1),Yes,Yes,Security,Invoke-WA_SetKernelMode
LSA Protection,Configure,SET_LocalSecurity.ps1,Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL (1),Yes,Yes,Security,Invoke-WA_SetLocalSecurity
Windows Firewall,Configure,SET_FirewallON.ps1,PowerShell Cmdlt,Set-NetFirewallProfile -Enabled True,Yes,No,Security,Invoke-WA_SetFirewallON
Classic Context Menu,Configure,SET_ClassicMenu.ps1,Registry (HKCU),HKCU:\Software\Classes\CLSID\{86ca1aa0...}\InprocServer32,Yes,No,UI,Invoke-WA_SetClassicMenu
Taskbar Search Box,Configure,SET_TaskbarSearch.ps1,Registry (HKCU),HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\SearchboxTaskbarMode (3),Yes,No,UI,Invoke-WA_SetTaskbarSearch
Task View Toggle,Configure,SET_TaskViewOFF.ps1,Registry (HKCU),HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton (0),Yes,No,UI,Invoke-WA_SetTaskViewOFF
Microsoft Update Service,Configure,SET_MicrosoftUpd.ps1,Registry (HKLM),HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\AllowMUUpdateService (1),Yes,No,Config,Invoke-WA_SetMicrosoftUpd
Restart Notifications,Configure,SET_RestartIsReq.ps1,Registry (HKLM),HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\RestartNotificationsAllowed2 (1),Yes,No,Config,Invoke-WA_SetRestartIsReq
App Restart Persistence,Configure,SET_RestartApps.ps1,Registry (HKCU),HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\RestartApps (1),Yes,No,Config,Invoke-WA_SetRestartApps
Get Updates,Maintain,RUN_UpdateSuite.ps1,UI Automation,Automates Windows Update Settings and MS Store updates,No,No,Maintenance,Invoke-WA_WindowsUpdate
WinGet App Updates,Maintain,RUN_WingetUpgrade.ps1,Command Line,Checks for and updates all apps via WinGet,No,No,Maintenance,Invoke-WA_WingetUpgrade
Drive Optimization,Maintain,RUN_OptimizeDisks.ps1,PowerShell Cmdlt,Optimize-Volume -DriveLetter C -NormalPriority,No,No,Maintenance,Invoke-WA_OptimizeDisks
Temp File Cleanup,Maintain,RUN_SystemCleanup.ps1,File System,Clears Windows Temp and User Temp,No,No,Maintenance,Invoke-WA_SystemCleanup
SFC / DISM Repair,Maintain,RUN_WindowsRepair.ps1,Command Line,Runs SFC scan; if corruption found runs DISM,No,No,Maintenance,Invoke-WA_WindowsRepair
'@


# UI Automation Preparation
if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }
    catch {}
}

function Get-UIAElement {
    param(
        [System.Windows.Automation.AutomationElement]$Parent,
        [string]$Name,
        [string]$AutomationId,
        [System.Windows.Automation.ControlType]$ControlType,
        [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants,
        [int]$TimeoutSeconds = 5
    )
    
    $Conditions = @()
    if ($Name) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
    if ($AutomationId) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
    if ($ControlType) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType) }

    $Condition = if ($Conditions.Count -eq 1) { $Conditions[0] }
    elseif ($Conditions.Count -gt 1) { New-Object System.Windows.Automation.AndCondition($Conditions) }
    else { return $null }

    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($StopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $Result = $Parent.FindFirst($Scope, $Condition)
        if ($Result) { return $Result }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Invoke-UIAElement {
    param([System.Windows.Automation.AutomationElement]$Element)
    
    if (-not $Element) { return $false }
    
    try {
        if ($Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)) {
            $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            return $true
        }
    }
    catch {}

    try {
        if ($Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)) {
            $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle()
            return $true
        }
    }
    catch {}

    try {
        $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
        return $true
    }
    catch {}

    return $false
}

function Get-UIAToggleState {
    param([System.Windows.Automation.AutomationElement]$Element)
    try {
        $p = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        return $p.Current.ToggleState # 0=Off, 1=On, 2=Indeterminate
    }
    catch { return $null }
}




# --- SHARED UI FUNCTIONS ---

function Start-SecHealthUI {
    # Robust launch of Windows Security
    Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    try {
        Start-Process "windowsdefender:" -ErrorAction Stop
    }
    catch {
        try {
            # Fallback: Use Explorer to launch protocol
            Start-Process "explorer.exe" -ArgumentList "windowsdefender:"
        }
        catch {
            Write-LeftAligned "$FGRed$Char_Warn Failed to launch Windows Security.$Reset"
        }
    }
    Start-Sleep -Seconds 3

}

# --- OS VALIDATION ---
function Test-IsWindows11 {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -lt 22000) {
        Write-Warning "WinAuto is designed for Windows 11 (Build 22000+). Detected Build: $build."
        Write-Warning "Some features may fail."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
Test-IsWindows11

# --- CONSOLE SETTINGS ---
function Set-ConsoleSnapRight {
    param([int]$Columns = 60)
    
    # 1. Terminal Check
    if ($env:WT_SESSION) { return }

    try {
        $code = @"
        using System;
        using System.Runtime.InteropServices;
        namespace WinAutoNative {
            [StructLayout(LayoutKind.Sequential)]
            public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
            public class ConsoleUtils {
                [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
                [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
                [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
                [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
                [DllImport("user32.dll")] public static extern bool SystemParametersInfo(int uiAction, int uiParam, out RECT pvParam, int fWinIni);
            }
        }
"@
        if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }
        
        $hWnd = [WinAutoNative.ConsoleUtils]::GetConsoleWindow()
        if ($hWnd -eq [IntPtr]::Zero) { return }

        $buffer = $Host.UI.RawUI.BufferSize
        $window = $Host.UI.RawUI.WindowSize
        $targetHeight = $Host.UI.RawUI.MaxWindowSize.Height
        
        # 2. Resize Logic (Safe Order)
        if ($Columns -ne $window.Width) {
            if ($Columns -lt $window.Width) {
                # Shrinking: Set Window first
                $window.Width = $Columns; $Host.UI.RawUI.WindowSize = $window
                $buffer.Width = $Columns; $Host.UI.RawUI.BufferSize = $buffer
            }
            else {
                # Growing: Set Buffer first
                $buffer.Width = $Columns; $Host.UI.RawUI.BufferSize = $buffer
                $window.Width = $Columns; $Host.UI.RawUI.WindowSize = $window
            }
        }

        if ($buffer.Height -lt $targetHeight) {
            $buffer.Height = $targetHeight
            $Host.UI.RawUI.BufferSize = $buffer
        }
        $window.Height = $targetHeight
        $Host.UI.RawUI.WindowSize = $window

        # 3. SNAP-RIGHT LOGIC
        Start-Sleep -Milliseconds 150 # Brief pause for rendering

        # Get the WorkArea (Usable screen excluding Taskbar)
        $workArea = New-Object WinAutoNative.RECT
        $SPI_GETWORKAREA = 0x0030
        if ([WinAutoNative.ConsoleUtils]::SystemParametersInfo($SPI_GETWORKAREA, 0, [ref]$workArea, 0)) {
            $waHeight = $workArea.Bottom - $workArea.Top
            
            # Get actual pixel dimensions of the current window
            $winRect = New-Object WinAutoNative.RECT
            if ([WinAutoNative.ConsoleUtils]::GetWindowRect($hWnd, [ref]$winRect)) {
                $pixelW = $winRect.Right - $winRect.Left
                
                # Target: Flush to the right edge of the work area
                $targetX = $workArea.Right - $pixelW
                $targetY = $workArea.Top
                
                # Force movement
                [WinAutoNative.ConsoleUtils]::MoveWindow($hWnd, $targetX, $targetY, $pixelW, $waHeight, $true) | Out-Null
            }
        }
    }
    catch { }
}





# --- FORMATTING HELPERS ---
function Get-VisualWidth {
    param([string]$String)
    $Width = 0
    $Chars = $String.ToCharArray()
    for ($i = 0; $i -lt $Chars.Count; $i++) {
        if ([char]::IsHighSurrogate($Chars[$i])) { $Width += 2; $i++ } else { $Width += 1 }
    }
    return $Width
}

function Write-Centered {
    param([string]$Text, [int]$Width = 60, [string]$Color)
    $cleanText = $Text -replace "$Esc\[[0-9;]*m", ""
    $padLeft = [Math]::Floor(($Width - $cleanText.Length) / 2)
    if ($padLeft -lt 0) { $padLeft = 0 }
    if ($Color) { Write-Host (" " * $padLeft + "$Color$Text$Reset") }
    else { Write-Host (" " * $padLeft + $Text) }
}

function Write-LeftAligned {
    param([string]$Text, [int]$Indent = 2)
    Write-Host (" " * $Indent + $Text)
}

function Write-Boundary {
    param([string]$Color = $FGDarkCyan)
    Write-Centered "$Color$([string]'_' * 56)$Reset"
}

function Export-WinAutoCSV {
    $path = $PSScriptRoot
    if (-not $path) { $path = $PWD.Path }
    $file = Join-Path $path "scriptOUTLINE-wa.csv"
    $Global:WinAutoCSVContent | Set-Content -Path $file -Encoding UTF8 -Force
    # Invoke-Item $path # Optional: Open folder
}

# --- REGISTRY HELPERS ---
function Get-WinAutoLastRun {
    param([string]$Module)
    $path = "HKLM:\SOFTWARE\WinAuto"
    if (-not (Test-Path $path)) { return "Never" }
    $val = Get-ItemProperty -Path $path -Name "LastRun_$Module" -ErrorAction SilentlyContinue
    if ($val) { return $val."LastRun_$Module" }
    return "Never"
}

function Set-WinAutoLastRun {
    param([string]$Module)
    $path = "HKLM:\SOFTWARE\WinAuto"
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "LastRun_$Module" -Value (Get-Date).ToString() -Force | Out-Null
    }
    catch {
        Write-Log "Failed to update LastRun for $Module : $_" -Level WARN
    }
}

function Write-Header {
    param(
        [string]$Title,
        [switch]$NoBottom
    )
    Clear-Host
    Write-Host ""
    $WinAutoTitle = "WinAuto"
    Write-Centered "$Bold$FGCyan$WinAutoTitle$Reset"
    Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"
    if (-not $NoBottom) {
        Write-Boundary
    }
}

function Write-Footer {
    Write-Host "${FGCyan}$('_' * 60)${Reset}"
    $FooterText = "$Char_Copyright 2026 www.AIIT.support"
    Write-Centered "$FGCyan$FooterText$Reset"
}

function Write-FlexLine {
    param([string]$LeftIcon, [string]$LeftText, [string]$RightText, [bool]$IsActive, [int]$Width = 60, [string]$ActiveColor = "$BGDarkGreen")
    $Circle = "*"
    if ($IsActive) {
        $LeftDisplay = "$FGGray$LeftIcon $FGGray$LeftText$Reset"
        $RightDisplay = "$ActiveColor  $Circle$Reset$FGGray$RightText$Reset  "
        $LeftRaw = "$LeftIcon $LeftText"; $RightRaw = "  $Circle$RightText  " 
    }
    else {
        $LeftDisplay = "$FGDarkGray$LeftIcon $FGDarkGray$LeftText$Reset"
        $RightDisplay = "$BGDarkGray$FGBlack$Circle  $Reset${FGDarkGray}Off$Reset "
        $LeftRaw = "$LeftIcon $LeftText"; $RightRaw = "$Circle  Off "
    }
    $SpaceCount = $Width - ($LeftRaw.Length + $RightRaw.Length + 3) - 1
    if ($SpaceCount -lt 1) { $SpaceCount = 1 }
    Write-Host ("   " + $LeftDisplay + (" " * $SpaceCount) + $RightDisplay)
}

function Write-BodyTitle {
    param([string]$Title)
    Write-LeftAligned "$FGWhite$Char_HeavyMinus $Bold$Title$Reset"
}

# --- LOGGING & REGISTRY ---
# --- LOGGING & REGISTRY ---




function Get-LogReport {
    param([string]$Path = $Global:WinAutoLogPath)
    if (-not $Path -or -not (Test-Path $Path)) { return }
    $Content = @(Get-Content -Path $Path)
    # Count visual indicators and text tags
    $Errors = @($Content | Select-String -Pattern "\[ERROR\]").Count
    $Warnings = @($Content | Select-String -Pattern "\[WARNING\]").Count
    $Successes = @($Content | Select-String -Pattern "\[SUCCESS\]").Count
    Write-Host ""
    Write-Boundary
    Write-Centered "SESSION REPORT"
    Write-Boundary
    Write-LeftAligned "Log File: $Path"
    Write-Host ""
    Write-LeftAligned "Successes     : $Successes"
    Write-LeftAligned "Warnings      : $Warnings"
    Write-LeftAligned "Errors        : $Errors"
    Write-Boundary
}



function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            return $prop.$Name
        }
        return $null
    }
    catch { return $null }
}

function Set-RegistryDword {
    param([string]$Path, [string]$Name, [int]$Value)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
        }
    }
    catch { throw $_ }
}

# --- TIMEOUT LOGIC ---
$Global:TickAction = {
    param($ElapsedTimespan, $ActionText = "CONTINUE", $Timeout = 10, $PromptCursorTop, $SelectionChar = $null, $PreActionWord = "to")
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }
    
    $Line = ""
    
    if ($ActionText -eq "DASHBOARD") {
        
        # User defined footer with colors
        # Use ^ v keys then press Space to RUN | Esc to EXIT
        $Line = "                       ${Global:FGYellow}Navigation${Global:Reset} ${Global:FGBlack}${Global:BGDarkCyan}KEYS${Global:Reset}                       `n   ${Global:FGBlack}${Global:BGDarkCyan} ^ ${Global:Reset}  ${Global:FGGray}arrow${Global:Reset}  ${Global:FGBlack}${Global:BGDarkCyan} v ${Global:Reset}  ${Global:FGGray}keys${Global:Reset} ${Global:FGYellow}->${Global:Reset}${Global:FGDarkGray}|${Global:Reset}${Global:FGBlack}${Global:BGYellow}Select${Global:Reset}${Global:FGDarkGray}|${Global:Reset}${Global:FGYellow}<-${Global:Reset} ${Global:FGDarkGray}|${Global:Reset} ${Global:FGBlack}${Global:BGDarkCyan}I${Global:Reset}${Global:FGWhite}nfo${Global:Reset} ${Global:FGDarkGray}|${Global:Reset} ${Global:FGBlack}${Global:BGDarkRed}Esc${Global:Reset} ${Global:FGGray}to${Global:Reset} ${Global:FGDarkRed}${Global:BGWhite}EXIT${Global:Reset}"
    }

    try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Host $Line } catch {}
}

function Wait-KeyPressWithTimeout {
    param([int]$Seconds = 10, [scriptblock]$OnTick)
    if ($Global:Silent) { return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 } }
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($StopWatch.Elapsed.TotalSeconds -lt $Seconds) {
        if ($OnTick) { & $OnTick $StopWatch.Elapsed }
        try {
            if ([Console]::KeyAvailable) { $StopWatch.Stop(); return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
        }
        catch {
            if ([Console]::IsInputRedirected) {
                try {
                    $code = [Console]::Read()
                    if ($code -ne -1) { return [PSCustomObject]@{ Character = [char]$code; VirtualKeyCode = $code } }
                }
                catch {}
            }
            break 
        }
        Start-Sleep -Milliseconds 100
    }
    $StopWatch.Stop(); return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 }
}

function Invoke-AnimatedPause {
    param([string]$ActionText = "CONTINUE", [int]$Timeout = 10, [string]$SelectionChar = $null, [string]$PreActionWord = "to", [int]$OverrideCursorTop)
    if ($Global:Silent) { return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 } }
    $PromptCursorTop = if ($OverrideCursorTop) { $OverrideCursorTop } else { [Console]::CursorTop }
    if ($Timeout -le 0) {
        & $Global:TickAction -ElapsedTimespan ([timespan]::Zero) -ActionText $ActionText -Timeout 0 -PromptCursorTop $PromptCursorTop -SelectionChar $SelectionChar -PreActionWord $PreActionWord
        return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    $LocalTick = { param($Elapsed) & $Global:TickAction -ElapsedTimespan $Elapsed -ActionText $ActionText -Timeout $Timeout -PromptCursorTop $PromptCursorTop -SelectionChar $SelectionChar -PreActionWord $PreActionWord }
    $res = Wait-KeyPressWithTimeout -Seconds $Timeout -OnTick $LocalTick; Write-Host ""; return $res
}

# --- CONFIGURATION FUNCTIONS ---

function Get-ThirdPartyAV {
    if ($Host.Name -match "ConsoleHost" -and [Environment]::OSVersion.Platform -eq "Win32NT") {
        try {
            $av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue | Where-Object { $_.displayName -notlike "*Windows Defender*" -and $_.displayName -notlike "*Microsoft Defender*" }
            return $av
        }
        catch {}
    }
    return $null
}


function Invoke-WA_SetSmartScreen {
    Write-Header "SMARTSCREEN FILTER (UIA)"
    
    # UIA Preparation
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-LeftAligned "$FGRed$Char_RedCross Failed to load UI Automation assemblies.$Reset"
            return
        }
    }

    # 1. Launch Windows Security at App & Browser Control
    Write-LeftAligned "Opening Windows Security..."
    try { Start-Process "windowsdefender://appbrowser" -ErrorAction Stop }
    catch { try { Start-Process "explorer.exe" -ArgumentList "windowsdefender://appbrowser" } catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Windows Security.$Reset"; return } }
    Start-Sleep -Seconds 2

    # 2. Find Window
    $timeout = 10
    $startTime = Get-Date
    $window = $null
    
    Write-LeftAligned "Searching for 'Windows Security' window..."
    
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if ($window) {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Window found.$Reset"
        
        # 3. Search for 'Turn on' button
        $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Turn on")
        
        # Search Descendants (deep search)
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked 'Turn on'.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGDarkYellow$Char_Warn 'Turn on' button found but not clickable.$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Char_RedCross Failed to click button: $($_.Exception.Message)$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGGray No 'Turn on' button found (Already enabled?).$Reset"
        }
        
        # Close Window
        try {
            $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
            if ($windowPattern) { $windowPattern.Close() }
        }
        catch {}
    }
    else {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Windows Security window.$Reset"
    }
}



function Invoke-WA_SetVirusThreatProtect {
    Write-Header "VIRUS & THREAT PROTECTION (UIA)"
    
    # UIA Preparation
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-LeftAligned "$FGRed$Global:Char_RedCross Failed to load UI Automation assemblies.$Reset"
            return
        }
    }

    # 1. Launch Windows Security
    Write-LeftAligned "Opening Windows Security..."
    try { Start-Process "windowsdefender://threat" -ErrorAction Stop }
    catch { try { Start-Process "explorer.exe" -ArgumentList "windowsdefender://threat" } catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Windows Security.$Reset"; return } }
    Start-Sleep -Seconds 2

    # 2. Find Window
    $timeout = 10
    $startTime = Get-Date
    $window = $null

    Write-LeftAligned "Searching for 'Windows Security' window..."

    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if ($window) {
        Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Window found.$Reset"
        
        # 3. Search for 'Turn on' (or 'Restart now') button
        $targets = @("Turn on", "Restart now")
        $button = $null
        
        foreach ($t in $targets) {
            $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $t)
            $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
            if ($button) { 
                Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Found '$t' button.$Reset"
                break 
            }
        }
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Clicked button.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGDarkYellow$Global:Char_Warn Button found but not clickable.$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Global:Char_RedCross Failed to click button: $($_.Exception.Message)$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGGray No 'Turn on' button found (Already enabled?).$Reset"
        }
        
        # Close Window
        # Commented out to match standalone behavior - closing might interrupt the click action
        # try {
        #    $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        #    if ($windowPattern) { $windowPattern.Close() }
        # }
        # catch {}
    }
    else {
        Write-LeftAligned "$FGRed$Global:Char_RedCross Timeout waiting for Windows Security window.$Reset"
    }
}



# --- ATTESTATION HELPERS (Global Access) ---
function Test-Reg { param($P, $N, $V) try { (Get-ItemProperty $P $N -EA 0).$N -eq $V } catch { $false } }

function Test-WinAutoAttestation {
    # Returns $true if ALL critical configuration items are currently compliant.
    # Used by SmartRUN to force specific repairs even if "Last Run" was recent.
    
    # 1. Registry Checks (Fast)
    # Edge PUA discovery is unreliable; ignoring in attestation
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    
    # 2. Context Menu
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = $false
    if (Test-Path $ctxPath) {
        $val = (Get-ItemProperty $ctxPath)."(default)"
        if ($val -eq "") { $s_Ctx = $true }
    }
    
    # 3. Widgets Check (TaskbarDa: 0=Hidden/Compliant, 1=Visible)
    $s_Wid = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0

    # 4. WMI Checks (Real-Time & Firewall) - Critical Security
    $s_RT = $false; $s_PUA = $false; $s_FW = $false
    try { 
        $mp = Get-MpPreference -ErrorAction SilentlyContinue
        $s_RT = $mp.DisableRealtimeMonitoring -eq $false
        $s_PUA = $mp.PUAProtection -eq 1
    }
    catch { $s_RT = $true; $s_PUA = $true } 
    
    try {
        $profiles = Get-NetFirewallProfile
        $allEnabled = $true

        foreach ($fwProfile in $profiles) {
            $isEnabled = $fwProfile.Enabled -eq $true
            if (-not $isEnabled) { $allEnabled = $false }

            if ($isEnabled) {
                Write-LeftAligned "$FGGreen$Char_BallotCheck  $($fwProfile.Name) Firewall: ENABLED$Reset"
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross  $($fwProfile.Name) Firewall: DISABLED$Reset"
            }
        }

        Write-Host ""

        # Summary status
        if ($allEnabled) {
            Write-LeftAligned "$FGGreen$Char_HeavyCheck All firewall profiles are ENABLED.$Reset"
        }
        else {
            Write-LeftAligned "$FGDarkYellow$Char_Warn One or more firewall profiles are DISABLED.$Reset"
        }
        $s_FW = $allEnabled

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Error detecting firewall state: $($_.Exception.Message)$Reset"
        $s_FW = $false
    }
    
    # Check Aggregate
    if (-not ($s_Mem -and $s_Kern -and $s_LSA -and $s_Task -and $s_View -and $s_MU -and $s_Rest -and $s_Pers -and $s_Ctx -and $s_Wid -and $s_RT -and $s_PUA -and $s_FW)) {
        return $false
    }
    return $true
}

# --- MAINTENANCE FUNCTIONS ---

function Invoke-WA_SystemPreCheck {
    Write-Header "SYSTEM PRE-FLIGHT CHECK"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-LeftAligned "$FGWhite OS: $($os.Caption) ($($os.Version))$Reset"
    $uptime = (Get-Date) - $os.LastBootUpTime
    $color = & { if ($uptime.Days -gt 7) { $FGRed } else { $FGGreen } }
    Write-LeftAligned "$FGWhite Uptime: $color$($uptime.Days) days$Reset"
    
    $drive = Get-Volume -DriveLetter C
    $freeGB = [math]::Round($drive.SizeRemaining / 1GB, 2)
    $dColor = & { if ($freeGB -lt 10) { $FGRed } else { $FGGreen } }
    Write-LeftAligned "$FGWhite Free Space (C:): $dColor$freeGB GB$Reset"
    
    $pending = $false
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $pending = $true }
    if ($pending) { Write-LeftAligned "$FGRed$Char_Warn REBOOT PENDING$Reset" } 
    else { Write-LeftAligned "$FGGreen$Char_BallotCheck System Ready$Reset" }
    
    $res = Invoke-AnimatedPause -Timeout 5
    if ($res.VirtualKeyCode -eq 27) { throw "UserCancelled" }
}

function Invoke-WA_WindowsUpdate {
    Write-Header "WINDOWS UPDATE SCAN"

    # 1. WinGet Update (Command Line)
    Write-Centered "$Global:Char_EnDash WINGET UPDATE $Global:Char_EnDash" -Color "$Bold$FGCyan"
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Write-LeftAligned "Running winget upgrade..."
        Start-Process "winget.exe" -ArgumentList "upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent" -Wait -NoNewWindow
    }

    Write-Host ""
    Write-Centered "$Global:Char_EnDash STORE & SETTINGS $Global:Char_EnDash" -Color "$Bold$FGCyan"

    # 2. Windows Update Settings (UIA)
    Write-LeftAligned "Opening Windows Update Settings..."
    Start-Process "ms-settings:windowsupdate"

    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $settingsWindow = $null

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopWatch.Elapsed.TotalSeconds -lt 15) {
        # Try by Name
        $settingsWindow = Get-UIAElement -Parent $desktop -Name "Settings" -Scope "Children" -TimeoutSeconds 1
        if (-not $settingsWindow) { $settingsWindow = Get-UIAElement -Parent $desktop -Name "Windows Update" -Scope "Children" -TimeoutSeconds 1 }

        # Try by Process
        if (-not $settingsWindow) {
            $ssProc = Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ssProc) {
                $settingsWindow = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $ssProc.Id)))
            }
        }

        if ($settingsWindow) { break }
        Start-Sleep -Milliseconds 500
    }

    if ($settingsWindow) {
        try { $settingsWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 3

        $targetButtons = @(
            @{ Name = "Check for updates"; Id = "SystemSettings_MusUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "SystemSettings_MicrosoftUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "Check for updates" },
            @{ Name = "Download & install all"; Id = "SystemSettings_MusUpdate_DownloadAndInstallAll_Button" },
            @{ Name = "Install all"; Id = "SystemSettings_MusUpdate_InstallAll_Button" },
            @{ Name = "Restart now"; Id = "SystemSettings_MusUpdate_RestartNow_Button" },
            @{ Name = "Resume updates"; Id = "SystemSettings_MusUpdate_ResumeUpdates_Button" },
            @{ Name = "Retry all"; Id = "" },
            @{ Name = "Retry"; Id = "" },
            @{ Name = "Check updates"; Id = "" }
        )

        $buttonFound = $false

        # Priority 1: Exact AutomationId (Most reliable)
        foreach ($btnInfo in $targetButtons) {
            if ($btnInfo.Id) {
                $button = Get-UIAElement -Parent $settingsWindow -AutomationId $btnInfo.Id -Scope "Descendants" -TimeoutSeconds 1
                if ($button -and (Invoke-UIAElement -Element $button)) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (ID)$Reset"
                    $buttonFound = $true; break
                }
            }
        }

        # Priority 2: Exact Name
        if (-not $buttonFound) {
            foreach ($btnInfo in $targetButtons) {
                if ($btnInfo.Name) {
                    $button = Get-UIAElement -Parent $settingsWindow -Name $btnInfo.Name -Scope "Descendants" -TimeoutSeconds 1
                    if ($button -and (Invoke-UIAElement -Element $button)) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (Name)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        # Priority 3: Fuzzy search (Search for ANY button containing "update", "check", "install", or "retry")
        if (-not $buttonFound) {
            Write-LeftAligned "$FGGray Primary buttons not found. Attempting fuzzy search...$Reset"
            $allButtons = $settingsWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
            foreach ($btn in $allButtons) {
                $n = $btn.Current.Name
                if ($n -match "update" -or $n -match "check" -or $n -match "install" -or $n -match "retry") {
                    if (Invoke-UIAElement -Element $btn) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$n' (Fuzzy)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        if (-not $buttonFound) { Write-LeftAligned "$FGGray No actionable buttons found in Settings.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Settings window.$Reset" }

    # 3. Microsoft Store (UIA)
    Write-LeftAligned "Opening Microsoft Store Updates..."
    Start-Process "ms-windows-store://downloadsandupdates"

    $storeWindow = Get-UIAElement -Parent $desktop -Name "Microsoft Store" -Scope "Children" -TimeoutSeconds 10

    if ($storeWindow) {
        try { $storeWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 2

        $buttonTexts = @("Get updates", "Check for updates", "Update all")
        $buttonFound = $false
        foreach ($buttonText in $buttonTexts) {
            $button = Get-UIAElement -Parent $storeWindow -Name $buttonText -Scope "Descendants" -TimeoutSeconds 2
            if ($button -and (Invoke-UIAElement -Element $button)) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$buttonText'$Reset"
                $buttonFound = $true; break
            }
        }
        if (-not $buttonFound) { Write-LeftAligned "$FGGray No update button found in Store.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Store window.$Reset" }

    Write-Host ""
    Start-Sleep -Seconds 3
}



function Get-WA_InstallAppList {
    # --- EXTERNAL CONFIGURATION ---
    if ($Global:Config -and (Test-Path $Global:Config)) {
        try {
            Write-Log "Loading external configuration from: $Global:Config"
            $json = Get-Content -Raw $Global:Config -ErrorAction Stop
            if ($json) { 
                $obj = $json | ConvertFrom-Json -ErrorAction Stop
                if ($obj.BaseApps) { return $obj.BaseApps }
                return $obj # Fallback if user just provided a raw array
            }
        }
        catch {
            Write-Log "Failed to load external config: $($_.Exception.Message)" -Level ERROR
            Write-Warning "External config failed to load. Falling back to embedded defaults."
        }
    }

    # Hardcoded Configuration (Embedded Install_RequiredApps-Config.json)
    $jsonContent = @'
{
  "BaseApps": [
    {
      "AppName": "Adobe Creative Cloud",
      "MatchName": "*Adobe Creative Cloud*",
      "Type": "WINGET",
      "WingetId": "Adobe.CreativeCloud",
      "WingetScope": "machine",
      "CheckMethod": "Registry",
      "InstallOrder": 50
    },
    {
      "AppName": "Box",
      "MatchName": "*Box*",
      "Type": "WINGET",
      "WingetId": "Box.Box",
      "WingetScope": "machine",
      "CheckMethod": "Registry",
      "InstallOrder": 40
    },
    {
      "AppName": "Box for Office",
      "MatchName": "*Box for Office*",
      "Type": "WINGET",
      "WingetId": "Box.BoxForOffice",
      "CheckMethod": "Registry",
      "InstallOrder": 41
    },
    {
      "AppName": "Box Tools",
      "MatchName": "*Box Tools*",
      "Type": "WINGET",
      "WingetId": "Box.BoxTools",
      "CheckMethod": "Registry",
      "InstallOrder": 42
    }
  ],
  "LaptopApps": [
    {
      "AppName": "Crestron AirMedia",
      "MatchName": "*AirMedia*",
      "Type": "WINGET",
      "WingetId": "Crestron.AirMedia",
      "WingetScope": "machine",
      "CheckMethod": "Registry",
      "InstallOrder": 100
    }
  ]
}
'@

    try {
        $config = $jsonContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Log "Critical Error: Embedded JSON Configuration is invalid. Exception: $($_.Exception.Message)" -Level ERROR
        return $null 
    }

    # Device Type Detection
    $IsDesktop = $false
    try {
        $chassis = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
        if ($chassis -and ($chassis -contains 3 -or $chassis -contains 4 -or $chassis -contains 6 -or $chassis -contains 7 -or $chassis -contains 15 -or $chassis -contains 23 -or $chassis -contains 31)) { 
            $IsDesktop = $true 
        }
    }
    catch {}

    $AppList = @()
    if ($config.BaseApps) { $AppList += $config.BaseApps }
    if (-not $IsDesktop -and $config.LaptopApps) { $AppList += $config.LaptopApps }
    
    if ($AppList) {
        return ($AppList | Sort-Object InstallOrder)
    }
    return @()
}


function Test-WA_AppInstalled {
    param($App)
    $scopes = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    $pattern = if ($App.MatchName) { $App.MatchName } else { $App.AppName }
    foreach ($s in $scopes) {
        if (Test-Path $s) {
            foreach ($k in (Get-ChildItem $s -ErrorAction SilentlyContinue)) {
                $dn = $k.GetValue('DisplayName', $null)
                if ($dn -and $dn -like $pattern) { return $true }
            }
        }
    }
    return $false
}

function Test-WA_AllAppsInstalled {
    $AppList = Get-WA_InstallAppList
    if (-not $AppList -or $AppList.Count -eq 0) { return $true }  # No apps to install = all done
    foreach ($app in $AppList) {
        if (-not (Test-WA_AppInstalled -App $app)) { return $false }
    }
    return $true
}

function Test-WA_MaintenanceRecentlyComplete {
    # Check if all maintenance tasks were run within their thresholds
    $tasks = @(
        @{ Key = "Maintenance_SFC"; Days = 30 },
        @{ Key = "Maintenance_Disk"; Days = 7 },
        @{ Key = "Maintenance_Cleanup"; Days = 7 },
        @{ Key = "Maintenance_WinUpdate"; Days = 1 }
    )
    foreach ($task in $tasks) {
        $last = Get-WinAutoLastRun -Module $task.Key
        if ($last -eq "Never") { return $false }
        try {
            $date = Get-Date $last
            if ((Get-Date) -gt $date.AddDays($task.Days)) { return $false }
        }
        catch { return $false }
    }
    return $true
}

function Invoke-WA_InstallApps {
    param([switch]$SmartRun)
    Write-Header "APPLICATION INSTALLER"
    
    $AppList = Get-WA_InstallAppList
    
    if ($null -eq $AppList) {
        $msg = "Configuration Error: Embedded JSON is invalid or could not be parsed."
        Write-LeftAligned "$FGRed$Global:Char_Warn $msg$Reset"
        Write-Log $msg -Level ERROR
        return
    }
    
    if ($null -eq $AppList) { return } # Failed to download or parse

    
    # Helper: Test-AppInstalled (Inline for standalone)
    function Test-AppInstalled {
        param($App)
        # Registry Check
        $scopes = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
        $pattern = if ($App.PSObject.Properties['MatchName'] -and $App.MatchName) { $App.MatchName } else { $App.AppName }
        
        foreach ($s in $scopes) {
            if (Test-Path $s) {
                foreach ($k in (Get-ChildItem $s -ErrorAction SilentlyContinue)) {
                    $dn = $k.GetValue('DisplayName', $null)
                    if ($dn -and $dn -like $pattern) { return $true }
                }
            }
        }
        return $false
    }
    
    

    # --- CONFIRMATION PROMPT ---
    $AppsToInstall = @()
    foreach ($app in $AppList) {
        if (-not (Test-AppInstalled -App $app)) {
            $AppsToInstall += $app
        }
    }

    if (@($AppsToInstall).Count -gt 0) {
        Write-Host ""
        Write-LeftAligned "$FGYellow$Char_Warn $(@($AppsToInstall).Count) applications are missing or outdated.$Reset"
        
        $Confirmed = $true
        if (-not $Global:Silent -and -not $SmartRun) {
            Write-LeftAligned "Proceed with installation? [Y]es (Default) / [S]kip"
            $k = Wait-KeyPressWithTimeout -Seconds 30
            if ($k.Character -eq 's' -or $k.Character -eq 'S' -or $k.VirtualKeyCode -eq 27) {
                $Confirmed = $false
            }
        }
        
        if (-not $Confirmed) {
            Write-LeftAligned "Skipping installation as requested."
            return
        }
        
        # Proceed with Installation
        Write-LeftAligned "Processing $(@($AppList).Count) applications..."
    
        foreach ($app in $AppList) {
            Write-Host ""
            if (Test-AppInstalled -App $app) {
                Write-LeftAligned "$FGGreen$Global:Char_BallotCheck $($app.AppName) is already installed.$Reset"
                continue
            }

            Write-LeftAligned "$FGWhite$Global:Char_Finger Installing $($app.AppName)...$Reset"
        
            try {
                if ($app.Type -eq "WINGET") {
                    Write-LeftAligned "Installing via WinGet ($($app.WingetId))..."
                    $installArgs = "install --id $($app.WingetId) --exact --accept-package-agreements --accept-source-agreements --silent"
                    if ($app.PSObject.Properties['WingetScope'] -and $app.WingetScope) { $installArgs += " --scope $($app.WingetScope)" }
                
                    $p = Start-Process winget -ArgumentList $installArgs -NoNewWindow -PassThru -Wait
                    if ($p.ExitCode -eq 0) {
                        Write-LeftAligned "$FGGreen$Global:Char_CheckMark Installation Successful.$Reset"
                        Write-Log "Installed $($app.AppName) via WinGet." -Level INFO
                    }
                    else {
                        throw "WinGet exited with code $($p.ExitCode)"
                    }
                }
                elseif ($app.Type -eq "ATOMIC_SCRIPT") {
                    Write-LeftAligned "Running Atomic Script: $($app.Script)..."

                    $scriptName = $app.Script
                    $scriptPath = $null
                    
                    # Check paths (Standard Dev / Deployment structure)
                    $root = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
                    # Check dev path (scripts\AtomicScripts) and potential flat path
                    $pathsToCheck = @(
                        "scripts\AtomicScripts\Installers\$scriptName",
                        "AtomicScripts\Installers\$scriptName",
                        "scripts\AtomicScripts\$scriptName",
                        "AtomicScripts\$scriptName",
                        "$scriptName"
                    )
                    
                    foreach ($subPath in $pathsToCheck) {
                        $p = Join-Path $root $subPath
                        if (Test-Path $p) { $scriptPath = $p; break }
                    }

                    if (-not $scriptPath) {
                        Write-LeftAligned "$FGYellow$Global:Char_Warn Script not found: $scriptName - Skipping (place script alongside wa.ps1 to install).$Reset"
                        Write-Log "Skipped $($app.AppName): script '$scriptName' not found." -Level WARN
                        continue
                    }
                    
                    # Execute Atomic Script
                    # Using powershell.exe to ensure clean execution context and handle any bitness issues
                    $p = Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait -PassThru -NoNewWindow
                    
                    if ($p.ExitCode -eq 0) {
                        Write-LeftAligned "$FGGreen$Global:Char_CheckMark Installation Successful.$Reset"
                        Write-Log "Installed $($app.AppName) via AtomicScript." -Level INFO
                    }
                    else {
                        throw "Script exited with code $($p.ExitCode)"
                    }
                }
                elseif ($app.PSObject.Properties['Url'] -and $app.Url) {
                    # Download and Install (MSI/EXE)
                    $ext = if ($app.Type -eq "MSI") { ".msi" } else { ".exe" }
                    $tempFile = "$env:TEMP\WinAuto_Install$ext"
                    Write-LeftAligned "Downloading installer..."
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                    Invoke-WebRequest -Uri $app.Url -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
                
                    Write-LeftAligned "Running installer..."
                    # Handle PreInstallDelay if property exists
                    if ($app.PSObject.Properties['PreInstallDelay'] -and $app.PreInstallDelay) { Start-Sleep -Seconds $app.PreInstallDelay }
                
                    $procArgs = if ($app.PSObject.Properties['SilentArgs'] -and $app.SilentArgs) { $app.SilentArgs } else { "/quiet /norestart" }
                    if ($app.Type -eq "MSI") {
                        $msiArgs = "/i `"$tempFile`" $procArgs"
                        $p = Start-Process "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
                    }
                    else {
                        $p = Start-Process $tempFile -ArgumentList $procArgs -NoNewWindow -PassThru -Wait -ErrorAction Stop
                    }
                
                    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
                        Write-LeftAligned "$FGGreen$Global:Char_CheckMark Installation Successful.$Reset"
                        Write-Log "Installed $($app.AppName)." -Level INFO
                    }
                    else { throw "Installer exited with code $($p.ExitCode)" }
                
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-LeftAligned "   $FGRed$Global:Char_Warn Error: $($_.Exception.Message)$Reset"
                Write-Log "Failed to install $($app.AppName): $($_.Exception.Message)" -Level ERROR
            }
        }
    
        Invoke-AnimatedPause -Timeout 5 | Out-Null
    }
    else {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck All applications installed.$Reset"
    }
}

# --- MODULE HANDLERS ---

function Invoke-WinAutoConfiguration {
    param([switch]$SmartRun)
    Write-Header "WINDOWS CONFIGURATION PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Configuration"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"

    $SkipConfig = $false

    if ($SmartRun -and $lastRun -ne "Never") {
        # Check 30-day freshness
        $lastDate = Get-Date $lastRun
        if ((Get-Date) -lt $lastDate.AddDays(30)) {
            # TIME SAYS SKIP, BUT WE MUST AUDIT COMPLIANCE
            # If Attestation passes, we can safely skip REGISTRY items.
            Write-LeftAligned "$FGGray History valid. verifying system compliance..."
            if (Test-WinAutoAttestation) {
                Write-LeftAligned "$FGGreen$Global:Char_CheckMark System Compliant. Skipping Core Configuration...$Reset"
                $SkipConfig = $true
            }
            else {
                Write-LeftAligned "$FGRed$Global:Char_Warn DRIFT DETECTED. Forcing Re-Configuration.$Reset"
            }
        }
    }
    Write-Boundary

    Invoke-WA_SetPUABlockDLs

    if (-not $SkipConfig) {
        # Core Security (Embedded Standalone)
        Invoke-WA_SetMemoryInteg
        Invoke-WA_SetRealTimeProt
        Invoke-WA_SetPUABlockApps
        Invoke-WA_SetLocalSecurity
        Invoke-WA_SetFirewallON
        Invoke-WA_SetKernelMode
    }
    
    # UIA Remediation Steps (Only run if detected as disabled to minimize window popping)
    $runRT = $false
    $runSS = $false

    try {
        $mp = Get-MpPreference -ErrorAction SilentlyContinue
        if ($mp.DisableRealtimeMonitoring -eq $true) { $runRT = $true }
        # SmartScreen (App & Browser Control) often maps to EnableSmartScreen in MpPreference
        if ($mp.EnableSmartScreen -eq $false) { $runSS = $true }
    }
    catch { $runRT = $true; $runSS = $true }

    if ($runSS) { Invoke-WA_SetSmartScreen }
    if ($runRT) { Invoke-WA_SetVirusThreatProtect }
    
    if (-not $SkipConfig) {
        # UI & Performance (Embedded Standalone)
        Invoke-WA_SetClassicMenu
        Invoke-WA_SetTaskbarSearch
        Invoke-WA_SetTaskViewOFF
        
        # Updates & Persistence
        Invoke-WA_SetMicrosoftUpd
        Invoke-WA_SetRestartIsReq
        Invoke-WA_SetRestartApps
    
        # Restart Explorer to force refresh of Taskbar/Start Menu registry settings (Standard UI changes)
        Write-LeftAligned "Restarting Explorer to apply UI settings..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
            Start-Process explorer
        }
    }

    Write-Boundary
    Write-Centered "$FGGreen CONFIGURATION COMPLETE $Reset"
    Set-WinAutoLastRun -Module "Configuration"
    Start-Sleep -Seconds 2
}

function Invoke-WinAutoMaintenance {
    param([switch]$SmartRun)
    Write-Header "WINDOWS MAINTENANCE PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Maintenance"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"
    
    function Test-RunNeeded {
        param($Key, $Days)
        if (-not $SmartRun) { return $true }
        $last = Get-WinAutoLastRun -Module $Key
        if ($last -eq "Never") { return $true }
        $date = Get-Date $last
        if ((Get-Date) -gt $date.AddDays($Days)) { return $true }
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark Skipping $Key (Run < $Days days ago).$Reset"
        return $false
    }

    try {
        Write-Boundary
        Invoke-WA_SystemPreCheck
    
        if (Test-RunNeeded -Key "Maintenance_SFC" -Days 30) {
            Invoke-WA_WindowsRepair
            Set-WinAutoLastRun -Module "Maintenance_SFC"
        }
    
        if (Test-RunNeeded -Key "Maintenance_Disk" -Days 7) {
            Invoke-WA_OptimizeDisks
            Set-WinAutoLastRun -Module "Maintenance_Disk"
        }
    
        if (Test-RunNeeded -Key "Maintenance_Cleanup" -Days 7) {
            Invoke-WA_SystemCleanup
            Set-WinAutoLastRun -Module "Maintenance_Cleanup"
        }
    
        # Run Windows Update Action (Skip if run in last 24 hours)
        if (Test-RunNeeded -Key "Maintenance_WinUpdate" -Days 1) {
            Invoke-WA_WindowsUpdate
            Set-WinAutoLastRun -Module "Maintenance_WinUpdate"
        }

        Write-Host ""
        Write-Centered "$FGGreen MAINTENANCE COMPLETE $Reset"
        Set-WinAutoLastRun -Module "Maintenance"
        Start-Sleep -Seconds 2
    }
    catch {
        if ($_.Exception.Message -eq "UserCancelled") {
            Write-LeftAligned "$FGGray Operation Cancelled by User.$Reset"
            Start-Sleep -Seconds 1
        }
        else { throw $_ }
    }
}


# --- EMBEDDED ATOMIC SCRIPTS ---

function Invoke-WA_SetRealTimeProt {
    <#
.SYNOPSIS
    Enables or Disables Real-time Protection.
.DESCRIPTION
    Standardized for WinAuto. Checks for Tamper Protection before changes.
    Standalone version.
    Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Real-time Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "REAL-TIME PROTECTION"
    
    # --- PRE-CHECK: 3RD PARTY AV ---
    try {
        $avList = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue
        foreach ($av in $avList) {
            # 397568 is typical implementation for Defender, but name check is robust
            if ($av.displayName -and $av.displayName -notmatch "Windows Defender" -and $av.displayName -notmatch "Microsoft Defender Antivirus") {
                # UI Update: Show [-] in DarkGray for 3rd Party AV
                Write-LeftAligned "[$FGDarkGray-$Reset] Real-time Protection managed by $($av.displayName)."
                
                # Footer
                Write-Host ""
                $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
                return
            }
        }
    }
    catch {}

    # --- MAIN ---

    try {
        $target = if ($Reverse) { $true } else { $false }
        $status = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        $tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection

        if ($tp -eq 5) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Tamper Protection is ENABLED and blocking changes.$Reset"
        }
        else {
            Set-MpPreference -DisableRealtimeMonitoring $target -ErrorAction Stop

            # Verify
            $current = (Get-MpPreference).DisableRealtimeMonitoring
            if ($current -eq $target) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck  Real-time Protection is $status.$Reset"
            }
            else {
                Write-LeftAligned "$FGDarkYellow$Char_Warn Real-time Protection verification failed.$Reset"
            }
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetPUABlockApps {
    <#
.SYNOPSIS
    Enables or Disables PUA (Potentially Unwanted Application) Blocking.
.DESCRIPTION
    Standardized for WinAuto.
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables PUA blocking).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Force
    )
    # --- MAIN LOGIC ---
    Write-Header "PUA BLOCK APPS"

    try {
        $targetMp = if ($Reverse) { 0 } else { 1 }
        $statusText = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        # System-wide Defender PUA
        Set-MpPreference -PUAProtection $targetMp -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"

        # Verification
        $currentMp = (Get-MpPreference).PUAProtection
        if ($currentMp -ne $targetMp) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Verification failed for Defender PUA. Status: $currentMp$Reset"
        }

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetPUABlockDLs {
    <#
.SYNOPSIS
    Enables or Disables Edge SmartScreen PUA Protection.
.DESCRIPTION
    Standardized for WinAuto. Configures User-specific Edge SmartScreen PUA (Block downloads).
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables PUA blocking).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Force
    )
    # --- MAIN LOGIC ---
    Write-Header "PUA DOWNLOADS"

    try {
        $targetEdge = if ($Reverse) { 0 } else { 1 }
        $statusText = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        # User-specific Edge SmartScreen PUA (Block downloads)
        $edgeKeyPath = "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled"
        if (-not (Test-Path $edgeKeyPath)) {
            New-Item -Path $edgeKeyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $edgeKeyPath -Name "(default)" -Value $targetEdge -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetMemoryInteg {
    <#
.SYNOPSIS
    Enables Memory Integrity (Core Isolation) via Registry.
.DESCRIPTION
    Standardized for WinAuto.
    Sets HypervisorEnforcedCodeIntegrity 'Enabled' value to 1 (On) or 0 (Off).
    Requires System Restart.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Memory Integrity).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "MEMORY INTEGRITY REG"

    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    $Name = "Enabled"
    $Value = if ($Reverse) { 0 } else { 1 }
    $ActionStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        # Create Path if missing
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        # Set Value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
    
        # Add Tracking Keys (if enabling)
        if (-not $Reverse) {
            Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Memory Integrity Registry Key set to $ActionStr.$Reset"
        Write-LeftAligned "$FGDarkYellow$Char_Warn  A system restart is required to take effect.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
        Write-LeftAligned "$FGCyan  Hint: Tamper Protection might be blocking this.$Reset"
    }

}

# --- EMBEDDED ATOMIC SCRIPTS (Security Part 2) ---

function Invoke-WA_SetKernelMode {
    <#
.SYNOPSIS
    Enables 'Kernel-mode Hardware-enforced Stack Protection' in Windows Security via UI Automation.
.DESCRIPTION
    Launches Windows Security, navigates to Device Security > Core Isolation,
    and attempts to toggle 'Kernel-mode Hardware-enforced Stack Protection'.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Turns OFF Stack Protection).
#>

    & {
        param(
            [Parameter(Mandatory = $false)]
            [Alias('r')]
            [switch]$Reverse,
            [switch]$Force
        )

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # --- STANDALONE HELPERS ---
        $Esc = [char]0x1B
        $Reset = "$Esc[0m"
        $Bold = "$Esc[1m"
        $FGCyan = "$Esc[96m"
        $FGDarkBlue = "$Esc[34m"

        if (-not (Get-Command Write-Boundary -ErrorAction SilentlyContinue)) {
            function Write-Boundary {
                param([string]$Color = $FGDarkBlue)
                Write-Host "$Color$([string]'_' * 60)$Reset"
            }
        }

        if (-not (Get-Command Write-Header -ErrorAction SilentlyContinue)) {
            function Write-Header {
                param([string]$Title)
                Clear-Host
                Write-Host ""
                $WinAutoTitle = "- WinAuto -"
                $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
                Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
            
                Write-Boundary
            
                $SubText = $Title.ToUpper()
                $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
                Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
                Write-Boundary
            }
        }

        # Load .NET UIAutomation Assemblies
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-Error "Failed to load UIAutomation assemblies. Ensure .NET Framework is installed."
            exit 1
        }

        # --- HELPER FUNCTIONS ---

        function Write-Log {
            param(
                [string]$Message,
                [ConsoleColor]$Color = "White"
            )
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
        }

        function Get-UIAElement {
            param(
                [System.Windows.Automation.AutomationElement]$Parent,
                [string]$Name,
                [System.Windows.Automation.ControlType]$ControlType,
                [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants,
                [int]$TimeoutSeconds = 5
            )
        
            $Condition = if ($Name -and $ControlType) {
                $c1 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
                $c2 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
                New-Object System.Windows.Automation.AndCondition($c1, $c2)
            }
            elseif ($Name) {
                New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
            }
            elseif ($ControlType) {
                New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
            }
            else {
                throw "Must provide Name or ControlType"
            }

            $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            while ($StopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
                $Result = $Parent.FindFirst($Scope, $Condition)
                if ($Result) { return $Result }
                Start-Sleep -Milliseconds 500
            }
            return $null
        }

        function Invoke-UIAElement {
            param([System.Windows.Automation.AutomationElement]$Element)
        
            if (-not $Element) { return $false }
        
            # Try Invoke Pattern (Buttons, Links)
            try {
                $InvokePattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $InvokePattern.Invoke()
                return $true
            }
            catch {
                # Try Toggle Pattern (Switches)
                try {
                    $TogglePattern = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                    $TogglePattern.Toggle()
                    return $true
                }
                catch {
                    try {
                        # Fallback: SelectionItem (Tabs/Nav items)
                        $SelectionItem = $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                        $SelectionItem.Select()
                        return $true
                    }
                    catch {
                        Write-Log "Failed to invoke/toggle/select element: $_" "Red"
                        return $false
                    }
                }
            }
        }

        function Get-UIAToggleState {
            param([System.Windows.Automation.AutomationElement]$Element)
            try {
                $p = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                return $p.Current.ToggleState # On, Off, Indeterminate
            }
            catch { return $null }
        }

        # --- MAIN SCRIPT ---
        Write-Header "KERNEL STACK UIA"
        Write-Log "Starting Windows Security Automation (Kernel-mode Stack Protection)..." "Cyan"

        $MaxRetries = 5
        $RetryCount = 0
        $Success = $false

        while (-not $Success -and ($RetryCount -lt $MaxRetries)) {
            $RetryCount++
        
            # 1. Launch / Relaunch Windows Security
            Write-Log "Launching Windows Security (Iteration $RetryCount)..." "Gray"
        
            Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        
            Start-Process "windowsdefender:"
            Start-Sleep -Seconds 3

            # 2. Find the Main Window
            $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
            $Window = Get-UIAElement -Parent $Desktop -Name "Windows Security" -ControlType ([System.Windows.Automation.ControlType]::Window) -Scope "Children" -TimeoutSeconds 10

            if (-not $Window) {
                Write-Log "Could not find 'Windows Security' window. Retrying..." "Yellow"
                continue
            }
            Write-Log "Found 'Windows Security' window." "Green"
            try { $Window.SetFocus() } catch {}

            # 3. Navigate to "Device security"
            Write-Log "Navigating to 'Device security'..." "Gray"
            $DeviceSecBtn = Get-UIAElement -Parent $Window -Name "Device security" -Scope "Descendants" -TimeoutSeconds 5
        
            if ($DeviceSecBtn) {
                Invoke-UIAElement -Element $DeviceSecBtn | Out-Null
                Start-Sleep -Seconds 2
            }
            else {
                Write-Log "Could not find 'Device security' navigation item." "Red"
                continue
            }

            # 4. Navigate to "Core isolation details"
            Write-Log "Navigating to 'Core isolation details'..." "Gray"
            $CoreIsoLink = Get-UIAElement -Parent $Window -Name "Core isolation details" -Scope "Descendants" -TimeoutSeconds 5
        
            if ($CoreIsoLink) {
                Invoke-UIAElement -Element $CoreIsoLink | Out-Null
                Start-Sleep -Seconds 2
            }
            else {
                Write-Log "Could not find 'Core isolation details' link. Checking if already there..." "Yellow"
            }

            # 5. Find Target Toggle
            Write-Log "Looking for 'Kernel-mode Hardware-enforced Stack Protection' toggle..." "Gray"

            $Condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Kernel-mode Hardware-enforced Stack Protection")
            $AllElements = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $Condition)

            $TargetToggle = $null
        
            # Priority: CheckBox > Group > Button
            foreach ($El in $AllElements) {
                $Type = $El.Current.ControlType
                if ($Type -eq [System.Windows.Automation.ControlType]::CheckBox) {
                    $TargetToggle = $El
                    break
                }
            }
        
            if (-not $TargetToggle) {
                foreach ($El in $AllElements) {
                    $Type = $El.Current.ControlType
                    if ($Type -ne [System.Windows.Automation.ControlType]::Text -and $Type -ne [System.Windows.Automation.ControlType]::Pane) {
                        $TargetToggle = $El
                        break
                    }
                }
            }

            if ($TargetToggle) {
                Write-Log "Found Target Element ($($TargetToggle.Current.ControlType.ProgrammaticName)). Checking state..." "Cyan"
                $State = Get-UIAToggleState -Element $TargetToggle
            
                # Determine Desired State based on Reverse logic
                $DesiredState = if ($Reverse) { 0 } else { 1 }
                $ActionStr = if ($Reverse) { "OFF" } else { "ON" }

                # Mapping: 0=Off, 1=On, 2=Indeterminate
                if ($State -eq $DesiredState) {
                    Write-Log "Feature is already $ActionStr." "Green"
                    $Success = $true
                }
                elseif ($null -ne $State) {
                    # State matches 0 or 1 but is not desired
                    Write-Log "Feature is $(if($State -eq 1){'ON'}else{'OFF'}). Toggling $ActionStr..." "Cyan"
                 
                    $Toggled = $false
                    # Try Toggle Pattern first
                    if (Invoke-UIAElement -Element $TargetToggle) {
                        $Toggled = $true
                    }
                    else {
                        # Fallback to Invoke (Click) if Toggle fails
                        Write-Log "Toggle pattern failed. Attempting Invoke (Click)..." "Yellow"
                        try {
                            $Invoke = $TargetToggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                            $Invoke.Invoke()
                            $Toggled = $true
                        }
                        catch {
                            Write-Log "Invoke pattern also failed." "Red"
                        }
                    }

                    if ($Toggled) {
                        Write-Log "Action triggered. Waiting for update..." "Green"
                        Start-Sleep -Seconds 3
                     
                        $StateAfter = Get-UIAToggleState -Element $TargetToggle
                        if ($StateAfter -eq $DesiredState) {
                            Write-Log "Successfully verified state is $ActionStr." "Green"
                            $Success = $true
                        }
                        else {
                            Write-Log "State did not change. This is common if UAC is prompting or a reboot is pending." "Yellow"
                            # We assume success if we clicked it, as we can't automate the UAC prompt easily.
                            $Success = $true 
                        }
                    }
                    else {
                        Write-Log "Failed to interact with the toggle." "Red"
                    }
                }
                else {
                    # No toggle pattern (e.g. Button?)
                    Write-Log "Toggle state unknown (Element might be a Button). Attempting to Click..." "Yellow"
                    Invoke-UIAElement -Element $TargetToggle | Out-Null
                    $Success = $true
                }

            }
            else {
                Write-Log "Could not find 'Kernel-mode Hardware-enforced Stack Protection' toggle. Feature might not be supported on this hardware." "Red"
                $Success = $true 
            }
        }

        Write-Log "Automation complete." "Cyan"

        # --- FOOTER ---
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"
        $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
        Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
        Write-Host ""

    } @args
}

function Invoke-WA_SetLocalSecurity {
    <#
.SYNOPSIS
    Enables LSA Protection (RunAsPPL) via Registry.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'RunAsPPL' value to 1 (On) or 0 (Off) in HKLM\SYSTEM\CurrentControlSet\Control\Lsa.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables LSA Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "LSA PROTECTION REG"

    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    $Name = "RunAsPPL"
    $Value = if ($Reverse) { 0 } else { 1 }
    $ActionStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  LSA Protection (RunAsPPL) set to $ActionStr.$Reset"
        Write-LeftAligned "$FGDarkYellow$Char_Warn  A system restart is required to take effect.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetFirewallON {
    <#
.SYNOPSIS
    Enables Windows Firewall for all profiles.
.DESCRIPTION
    Standardized for WinAuto.
    Ensures Domain, Public, and Private firewall profiles are Enabled.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Firewall).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "WINDOWS FIREWALL"

    try {
        $target = if ($Reverse) { $false } else { $true }
    
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled $target -ErrorAction Stop
    
        $statusStr = if ($target) { "ENABLED" } else { "DISABLED" }
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Firewall (All Profiles) is $statusStr.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
    }

}

# --- EMBEDDED ATOMIC SCRIPTS (UI Config Part 3) ---

function Invoke-WA_SetClassicMenu {
    <#
.SYNOPSIS
    Restores the Classic Context Menu (Windows 10 Style).
.DESCRIPTION
    Standardized for WinAuto.
    Modifies HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32
    Restarts Explorer to apply.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Restores Windows 11 Menu).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "CLASSIC CONTEXT MENU"
    
    $Key = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    $Path = "$Key\InprocServer32"
    
    try {
        if ($Reverse) {
            # Remove key to restore Win11 default
            if (Test-Path $Key) {
                Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Restored Windows 11 Context Menu.$Reset"
                Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            else {
                Write-LeftAligned "$FGGray Windows 11 Menu is already active.$Reset"
            }
        }
        else {
            # Create Key for Classic Menu
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -Force | Out-Null
            }
            # Set default value to empty string
            Set-ItemProperty -Path $Path -Name "(default)" -Value "" -Force
         
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Enabled Classic Context Menu.$Reset"
            Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetTaskbarSearch {
    <#
.SYNOPSIS
    Sets Taskbar Search to 'Search icon only'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'SearchboxTaskbarMode' to 3 (Icon Only) or 1 (Box).
    Restarts Explorer to apply.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Sets to Search Box - Value 1).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "TASKBAR SEARCH CONFIG"

    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $Name = "SearchboxTaskbarMode"
    
    # 3 = Icon Only (WinAuto Default), 1 = Search Box (Default Win11)
    $Value = if ($Reverse) { 1 } else { 3 } 
    $ActionStr = if ($Reverse) { "BOX" } else { "ICON ONLY" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar Search set to $ActionStr.$Reset"
        Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetTaskViewOFF {
    <#
.SYNOPSIS
    Hides the Task View button from the Taskbar.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'ShowTaskViewButton' to 0 (Off).
    Restarts Explorer to apply.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Shows Task View).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "TASK VIEW TOGGLE"

    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $Name = "ShowTaskViewButton"
    
    $Value = if ($Reverse) { 1 } else { 0 } 
    $ActionStr = if ($Reverse) { "SHOWN" } else { "HIDDEN" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Task View button is $ActionStr.$Reset"
        Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

}


function Invoke-WA_SetMicrosoftUpd {
    <#
.SYNOPSIS
    Sets 'Receive updates for other Microsoft products'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'AllowMUUpdateService' registry key.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Disables the setting.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "MICROSOFT UPDATE"
    
    $Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $Name = "AllowMUUpdateService"
    $Value = if ($Reverse) { 0 } else { 1 } # 1=On
    $StatusStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck MS Update Service is $StatusStr.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetRestartIsReq {
    <#
.SYNOPSIS
    Sets 'Notify me when a restart is required'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'RestartNotificationsAllowed2' registry key.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Disables the setting.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "RESTART NOTIFICATIONS"
    
    $Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $Name = "RestartNotificationsAllowed2"
    $Value = if ($Reverse) { 0 } else { 1 } # 1=On
    $StatusStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Restart Notifications are $StatusStr.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_SetRestartApps {
    <#
.SYNOPSIS
    Sets 'Restart apps after signing in'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'RestartApps' registry key in Winlogon.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Disables the setting.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "APP RESTART PERSISTENCE"
    
    $Path = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $Name = "RestartApps"
    $Value = if ($Reverse) { 0 } else { 1 } # 1=On
    $StatusStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck App Restart Persistence is $StatusStr.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

}

# --- EMBEDDED ATOMIC SCRIPTS (Maintenance Part 4) ---

function Invoke-WA_WingetUpgrade {
    <#
.SYNOPSIS
    WinGet Application Updater.
.DESCRIPTION
    Updates all installed applications using Windows Package Manager (winget).
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. Upgrades cannot be reversed automatically.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )
    Write-Header "WINGET APP UPDATE"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: App upgrades cannot be reversed automatically.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    # Check for WinGet
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-LeftAligned "$FGRed$Char_Warn WinGet is not installed or not in PATH.$Reset"
        Write-LeftAligned "Please install App Installer from the Microsoft Store."
        return
    }

    Write-LeftAligned "$FGGray Running winget upgrade --all...$Reset"
    Write-Host ""

    try {
        $wingetArgs = @(
            "upgrade",
            "--all",
            "--include-unknown",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--silent"
        )
    
        Start-Process "winget.exe" -ArgumentList $wingetArgs -Wait -NoNewWindow
    
        Write-Host ""
        Write-LeftAligned "$FGGreen$Char_HeavyCheck WinGet update completed.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Update failed: $($_.Exception.Message)$Reset"
    }

}

function Invoke-WA_OptimizeDisks {
    <#
.SYNOPSIS
    Optimizes all fixed disks (TRIM for SSD, Defrag for HDD).
.DESCRIPTION
    Standardized for WinAuto.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. Optimization cannot be reversed.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )
    Write-Header "DISK OPTIMIZATION"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Disk optimization cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    try {
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
        foreach ($v in $volumes) {
            $drive = $v.DriveLetter
            Write-LeftAligned "$FGWhite$Char_HeavyMinus Drive $drive`: $Reset"
        
            $isSSD = $false
            $part = Get-Partition -DriveLetter $drive -ErrorAction SilentlyContinue
            if ($part) {
                $disk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
                if ($disk -and $disk.MediaType -eq 'SSD') { $isSSD = $true }
            }

            if ($isSSD) {
                Write-LeftAligned "  $FGYellow Type: SSD - Running TRIM...$Reset"
                Optimize-Volume -DriveLetter $drive -ReTrim | Out-Null
            }
            else {
                Write-LeftAligned "  $FGYellow Type: HDD - Running Defrag...$Reset"
                Optimize-Volume -DriveLetter $drive -Defrag | Out-Null
            }
            Write-LeftAligned "  $FGGreen$Char_HeavyCheck Optimization Complete.$Reset"
        }
    }
    catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    }

}

function Invoke-WA_SystemCleanup {
    <#
.SYNOPSIS
    Performs System & User Temp Cleanup.
.DESCRIPTION
    Standardized for WinAuto. Removes files from Temp folders.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. File deletion cannot be reversed.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )
    Write-Header "SYSTEM CLEANUP"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: File cleanup cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    try {
        $paths = @("$env:TEMP", "$env:WINDIR\Temp")
        $total = 0

        foreach ($p in $paths) {
            if (Test-Path $p) {
                Write-LeftAligned "$FGWhite$Char_HeavyMinus Cleaning: $p$Reset"
                try {
                    $items = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                    if ($items) {
                        $c = @($items).Count
                        $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                        Write-LeftAligned "  $FGGreen$Char_BallotCheck Removed $c items.$Reset"
                        $total += $c
                    }
                    else {
                        Write-LeftAligned "  $FGGray Already empty.$Reset"
                    }
                }
                catch {
                    Write-LeftAligned "  $FGRed$Char_Warn Partial cleanup failure.$Reset"
                }
            }
        }
    
        Write-Host ""
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Cleanup Complete. Total items removed: $total$Reset"

    }
    catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    }

}

function Invoke-WA_WindowsRepair {
    <#
.SYNOPSIS
    Windows System File Integrity & Repair Tool (SFC/DISM).
.DESCRIPTION
    Automated flow to check and repair Windows system files using SFC and DISM.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. System repairs cannot be reversed.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Invoke-SFCScan {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus System File Checker (SFC)$Reset"
        Write-LeftAligned "$FGGray Initializing sfc /scannow...$Reset"
    
        try {
            $rawOutput = & sfc /scannow 2>&1
            $sfcOutput = ($rawOutput -join " ") -replace '[^\x20-\x7E]', '' # Keep only printable ASCII
            Write-Host ""
        
            if ($sfcOutput -match "did not find any integrity violations") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck System files are healthy.$Reset"
                return "SUCCESS"
            }
            elseif ($sfcOutput -match "found corrupt files and successfully repaired them") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck Corrupt files were found and repaired.$Reset"
                return "REPAIRED"
            }
            elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") {
                Write-LeftAligned "$FGRed$Char_RedCross SFC found unfixable corruption.$Reset"
                return "FAILED"
            }
            else {
                Write-LeftAligned "$FGDarkMagenta$Char_Warn SFC completed with unknown status.$Reset"
                return "UNKNOWN"
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross SFC execution error: $errMsg$Reset"
            return "ERROR"
        }
    }

    function Invoke-DISMRepair {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus Deployment Image Servicing (DISM)$Reset"
        Write-LeftAligned "$FGYellow Starting online image repair...$Reset"
        Write-LeftAligned "$FGGray This may take several minutes.$Reset"
    
        try {
            $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
        
            if ($dismOutput -match "The restore operation completed successfully") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck DISM repair completed successfully.$Reset"
                return $true
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross DISM repair failed.$Reset"
                return $false
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross DISM execution error: $errMsg$Reset"
            return $false
        }
    }

    Write-Header "SYSTEM REPAIR FLOW"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: System repairs cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    $result = Invoke-SFCScan

    if ($result -eq "FAILED") {
        Write-Host ""
        Write-LeftAligned "$FGYellow Triggering DISM Repair to fix underlying component store...$Reset"
        $dismSuccess = Invoke-DISMRepair
    
        if ($dismSuccess) {
            Write-Host ""
            Write-LeftAligned "$FGYellow Re-running SFC to verify repairs...$Reset"
            Invoke-SFCScan | Out-Null
        }
    }

    Write-Host ""
    Write-Boundary
    Write-Centered "$FGGreen REPAIR FLOW COMPLETE $Reset"
    Write-Boundary

}

# --- END OF EMBEDDING ---

# --- MAIN EXECUTION ---
# Ensure log directory exists
if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -Path $Global:WinAutoLogDir -ItemType Directory -Force | Out-Null }
Write-Log "WinAuto Standalone Session Started" -Level INFO

# --- CLI CONTROLLER ---
if ($Silent -or $Module) {
    if ($Module) { Write-Log "Starting CLI Mode (Module: $Module)" }
    else { Write-Log "Starting CLI Mode (Silent Default)" }

    if (-not $Module -and $Silent) { $Module = "SmartRun" }

    switch ($Module) {
        "SmartRun" { 
            Invoke-WinAutoConfiguration -SmartRun
            Invoke-WinAutoMaintenance -SmartRun
            if (-not $Global:AllAppsInstalled) { Invoke-WA_InstallApps -SmartRun }
        }
        "Install" { Invoke-WA_InstallApps }
        "Config" { Invoke-WinAutoConfiguration }
        "Maintenance" { Invoke-WinAutoMaintenance }
        "Help" { Write-Host $Global:WinAutoManifestContent; exit 0 }
    }
    
    Write-Log "CLI Execution Complete."
    return
}

Set-ConsoleSnapRight -Columns 60


$MenuSelection = 0  # 0=Smart, 1=Config, 2=Maintenance
# Per-section expansion flags



$Global:WinAutoFirstLoad = $true

while ($true) {
    # Arrows (Updated Indices)
    # 0 = SmartRUN
    # 1 = Install
    # 2 = Config
    # 3 = Maintenance
    


    # Logic to Determine Skip States (Moved for Header Indicators)
    $Global:AnySkipped = $false
    
    # Config
    $lastConfigRun = Get-WinAutoLastRun -Module "Configuration"
    $configSkipped = $false
    if ($lastConfigRun -ne "Never") {
        $lastConfigDate = Get-Date $lastConfigRun
        if ((Get-Date) -lt $lastConfigDate.AddDays(30)) {
            $configSkipped = $true
            $Global:AnySkipped = $true 
        }
    }
    
    # Install
    $Global:AllAppsInstalled = Test-WA_AllAppsInstalled
    if ($Global:AllAppsInstalled) { $Global:AnySkipped = $true }
    
    # Maintain
    $Global:MaintenanceComplete = Test-WA_MaintenanceRecentlyComplete
    if ($Global:MaintenanceComplete) { $Global:AnySkipped = $true }

    $manualHeaderColor = if ($MenuSelection -eq 0) { $FGDarkGray } else { $FGDarkCyan }

    Clear-Host
    Write-Host ""
    Write-Centered "$Bold${FGCyan} - WinAuto - $Reset"
    Write-Boundary -Color $FGCyan
    if ($MenuSelection -eq 0) {
        # Align with 56-char boundary lines (2 space indent + 56 char block)
        Write-Host "  ${FGBlack}${BGYellow}                        SmartRUN                        ${Reset}"
    }
    else {
        Write-Centered "${FGDarkGray}SmartRUN${Reset}"
    }
    
    # SmartRUN Indicators
    $cInst = if (-not $Global:AllAppsInstalled) { $FGCyan } else { $FGDarkGray }
    $cConf = if (-not $configSkipped) { $FGCyan } else { $FGDarkGray }
    $cMaint = if (-not $Global:MaintenanceComplete) { $FGCyan } else { $FGDarkGray }
    Write-Centered "${cInst}Install${Reset} ${FGDarkGray}|${Reset} ${cConf}Configure${Reset} ${FGDarkGray}|${Reset} ${cMaint}Maintain${Reset}"



    Write-Host ""

    Write-Host ""
    Write-Host ""


    
    # SmartRun Details lines with Hotkeys
    
    # Header Line

    # Logic to Determine Skip State for Config
    # Logic to Determine Skip State for Config



    if ($MenuSelection -eq 0) {
        Write-Centered "${FGBlack}${BGDarkGray}__MANUAL-MODE-OFF__${Reset}"
        # Alternative: Write-Centered "${FGBlack}${BGDarkGray}  MANUAL-MODE-OFF  ${Reset}"
    }
    else {
        # Align with 56-char boundary lines (2 space indent + 56 char block)
        Write-Host "  ${Global:BGDarkCyan}${Global:FGBlack}                   __MANUAL-MODE-ON__                   ${Global:Reset}"
    }
    Write-Boundary # Separator

    # [I]nstall Applications (Pos 1)
    if ($MenuSelection -eq 1) {
        # Align with 56-char boundary lines (2 space indent + 56 char block)
        Write-Host "  ${FGBlack}${BGYellow}                  Install Applications                  ${Reset}"
    }
    else {
        Write-Centered "${manualHeaderColor}|${Reset} ${manualHeaderColor}I${Reset}${manualHeaderColor}nstall Applications${Reset} ${manualHeaderColor}|${Reset}"
    }
    Write-Host ""
    
    $iTopColor = if ($MenuSelection -eq 1) { $FGYellow } else { $FGWhite }
    Write-LeftAligned "${FGDarkGray}[${iTopColor}>${FGDarkGray}] ${iTopColor}INSTALL / ${FGDarkGray}[${FGDarkGreen}v${FGDarkGray}] ${iTopColor}INSTALLED    ${FGDarkGray}|${iTopColor} ATOMIC_SCRIPT$Reset" -Indent 2
    Write-Centered "${FGDarkGray}--------------------------------------------------------$Reset"

    $iDetailColor = if ($MenuSelection -eq 1) { $FGGray } else { $FGDarkGray }
    $appListDisplay = Get-WA_InstallAppList
    
    if ($appListDisplay) {
        foreach ($app in $appListDisplay) {
            $isInst = Test-WA_AppInstalled -App $app
            $icon = if ($isInst) { "${FGDarkGray}[${FGDarkGreen}v${FGDarkGray}]${Reset}" } else { "${FGDarkGray}[${FGYellow}>${FGDarkGray}]${Reset}" }
            $appColor = if ($isInst) { $FGDarkGray } else { $iDetailColor }
            $dName = "$icon ${appColor}$($app.AppName)${Reset}"
            $cleanName = "[v] $($app.AppName)"
            
            $dPadCount = 30 - $cleanName.Length
            if ($dPadCount -lt 1) { $dPadCount = 1 }
            $dPad = " " * $dPadCount
            
            # Right Column: Install Source (Atomic Script Name)
            $source = "Unknown"
            if ($app.PSObject.Properties['Script'] -and $app.Script) {
                $source = $app.Script
            }
            elseif ($app.PSObject.Properties['InstallerPath'] -and $app.InstallerPath) { 
                $source = Split-Path $app.InstallerPath -Leaf 
            }
            elseif ($app.PSObject.Properties['WinGetId'] -and $app.WinGetId) { 
                $source = $app.WinGetId 
            }
            elseif ($app.PSObject.Properties['Url'] -and $app.Url) { 
                # Extract filename from URL
                $source = Split-Path $app.Url -Leaf 
            }
            elseif ($app.PSObject.Properties['Source'] -and $app.Source) { 
                $source = $app.Source 
            }
            elseif ($app.PSObject.Properties['Type'] -and $app.Type) { 
                $source = $app.Type 
            }
            
            # Conditional Coloring for Script Name
            $sourceColor = if ($isInst) { $FGDarkGray } elseif ($MenuSelection -eq 1) { $FGYellow } else { $FGDarkGray }

            Write-LeftAligned "${dName}${Reset}$dPad${FGDarkGray}| ${sourceColor}$source${Reset}" -Indent 3
        }
    }
    else {
        Write-LeftAligned "${iDetailColor}- (Config not found in Downloads)${Reset}" -Indent 3
    }
    
    Write-Host ""
    Write-Boundary # Separator

    # [C]onfigure Operating System (Pos 2)
    if ($MenuSelection -eq 2) {
        # Align with 56-char boundary lines (2 space indent + 56 char block)
        Write-Host "  ${FGBlack}${BGYellow}               Configure Operating System               ${Reset}"
    }
    else {
        Write-Centered "${manualHeaderColor}|${Reset} ${manualHeaderColor}C${Reset}${manualHeaderColor}onfigure Operating System${Reset} ${manualHeaderColor}|${Reset}"
    }
    Write-Host ""
    
    $cTopColor = if ($MenuSelection -eq 2) { $FGYellow } else { $FGWhite }
    Write-LeftAligned "${FGDarkGray}[${cTopColor}>${FGDarkGray}] ${cTopColor}ENABLE / ${FGDarkGray}[${FGDarkGreen}v${FGDarkGray}] ${cTopColor}ENABLED        ${FGDarkGray}|${cTopColor} ATOMIC_SCRIPT$Reset" -Indent 3
    Write-Centered "${FGDarkGray}--------------------------------------------------------$Reset"
    
    # Config Details
    $cDetailColor = if ($MenuSelection -eq 2) { $FGGray } else { $FGDarkGray }
    
    # Helper to print item with status
    function Write-ColItem {
        param($Txt, $Met, $Status) 
        # Status: $true (Green 1), $false (Red 0), $null (Gray ?), "GreyOut" (DarkGray [ ])
        
        if ("GreyOut" -eq $Status) {
            $icon = "${FGDarkGray}[ ]${Reset}"
            $pad = " " * (28 - $Txt.Length); 
            Write-LeftAligned "$icon ${FGDarkGray}$Txt${Reset}$pad${FGDarkGray}| ${FGDarkGray}$Met${Reset}" -Indent 3  
        }
        elseif ("ForceRun" -eq $Status) {
            $icon = "${FGDarkGray}[${FGWhite}>${FGDarkGray}]${Reset}"
            $pad = " " * (28 - $Txt.Length); 
            Write-LeftAligned "$icon ${cDetailColor}$Txt${Reset}$pad${FGDarkGray}| ${cDetailColor}$Met${Reset}" -Indent 3  
        }
        else {
            $icon = if ($null -eq $Status) { "${FGDarkGray}[?]${Reset}" } elseif ($Status) { "${FGDarkGray}[${FGDarkGreen}v${FGDarkGray}]${Reset}" } else { "${FGDarkGray}[${cTopColor}>${FGDarkGray}]${Reset}" }
            $pad = " " * (28 - $Txt.Length); 
            Write-LeftAligned "$icon ${cDetailColor}$Txt${Reset}$pad${FGDarkGray}| ${cDetailColor}$Met${Reset}" -Indent 3  
        }
    }
    
    # --- LIVE STATUS CHECKS (Lightweight) ---
    $s_RT = $null; $s_PUA = $null; $s_FW = $null
    # if ($MenuSelection -eq 2) {
    # Always run checks for accurate dashboard
    try { 
        $av = Get-ThirdPartyAV
        $mp = Get-MpPreference -ErrorAction SilentlyContinue

        if ($av) {
            $s_RT = "GreyOut"
        }
        else {
            $s_RT = $mp.DisableRealtimeMonitoring -eq $false
        }

        if ($mp.PUAProtection -eq 1) {
            $s_PUA = $true
        }
        else {
            $s_PUA = "GreyOut"
        }
    }
    catch { 
        $s_RT = $false; $s_PUA = $false 
        Write-Log "Failed to query Defender Preferences via WMI: $($_.Exception.Message)" -Level WARN
    }
    
    try {
        $profiles = Get-NetFirewallProfile
        $allEnabled = $true

        foreach ($fwProfile in $profiles) {
            $isEnabled = $fwProfile.Enabled -eq $true
            if (-not $isEnabled) { $allEnabled = $false }
        }

        $s_FW = $allEnabled
    }
    catch { 
        $s_FW = $false 
        Write-Log "Failed to query Firewall Profiles: $($_.Exception.Message)" -Level WARN
    }

    # }
    
    # Registry Checks (Fast)
    function Test-Reg { param($P, $N, $V) try { (Get-ItemProperty $P $N -EA 0).$N -eq $V } catch { $false } }
    
    $s_Edge = "ForceRun"
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    

    # Classic Context Menu Check (InprocServer32 Default Value must be empty string)
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = $false
    if (Test-Path $ctxPath) {
        $val = (Get-ItemProperty $ctxPath)."(default)"
        if ($val -eq "") { $s_Ctx = $true }
    }
    
    # --- LIVE WMI CHECKS ---


    Write-ColItem "Real-Time Protection" "SET_RealTimeProt.ps1" $s_RT
    Write-ColItem "PUA Protection" "SET_DefenderPUA.ps1" $s_PUA
    Write-ColItem "PUA Protection (Edge)" "SET_EdgePUA.ps1" $s_Edge
    Write-ColItem "Memory Integrity" "SET_MemoryInteg.ps1" $s_Mem
    Write-ColItem "Kernel Stack Protection" "SET_KernelMode.ps1" $s_Kern
    Write-ColItem "LSA Protection" "SET_LocalSecurity.ps1" $s_LSA
    Write-ColItem "Windows Firewall" "SET_FirewallON.ps1" $s_FW
    Write-ColItem "Classic Context Menu" "SET_ClassicMenu.ps1" $s_Ctx
    Write-ColItem "Taskbar Search Box" "SET_TaskbarSearch.ps1" $s_Task
    Write-ColItem "Task View Toggle" "SET_TaskViewOFF.ps1" $s_View

    Write-ColItem "Microsoft Update Service" "SET_MicrosoftUpd.ps1" $s_MU
    Write-ColItem "Restart Notifications" "SET_RestartIsReq.ps1" $s_Rest
    Write-ColItem "App Restart Persistence" "SET_RestartApps.ps1" $s_Pers
    
    Write-Host ""
    
    

    
    Write-Boundary # Separator

    # [M]aintain Operating System (Pos 3)
    if ($MenuSelection -eq 3) {
        # Align with 56-char boundary lines (2 space indent + 56 char block)
        Write-Host "  ${FGBlack}${BGYellow}               Maintain Operating System                ${Reset}"
    }
    else {
        Write-Centered "${manualHeaderColor}|${Reset} ${manualHeaderColor}M${Reset}${manualHeaderColor}aintain Operating System${Reset} ${manualHeaderColor}|${Reset} "
    }
    Write-Host ""
    
    # Maintenance Details
    $mDetailColor = if ($MenuSelection -eq 3) { $FGGray } else { $FGDarkGray }
    
    function Write-MaintItem {
        param($Txt, $Met, $Key, [int]$Threshold = 7) 
        $prefix = "-"
        $statusColor = $mDetailColor
        if ($Key) {
            $last = Get-WinAutoLastRun -Module $Key
            if ($last -eq "Never") { $prefix = "!"; $statusColor = $FGDarkRed }
            else {
                try {
                    $days = ((Get-Date) - (Get-Date $last)).Days
                    $prefix = $days
                    if ($days -eq 0 -or $days -le $Threshold) { $statusColor = $FGDarkGreen } else { $statusColor = $FGDarkRed }
                }
                catch { $prefix = "!"; $statusColor = $FGDarkRed }
            }
        }
        $pad = " " * (28 - $Txt.Length); 
        Write-LeftAligned "${FGDarkGray}[${statusColor}$prefix${FGDarkGray}]${mDetailColor} $Txt${Reset}$pad${FGDarkGray}| ${mDetailColor}$Met${Reset}" -Indent 3  
    }

    $mTopColor = if ($MenuSelection -eq 3) { $FGYellow } else { $FGWhite }
    Write-LeftAligned "${FGDarkGray}[${mTopColor}#${FGDarkGray}]${mTopColor} OF DAYS SINCE LAST RUN      ${FGDarkGray}|${mTopColor} ATOMIC_SCRIPT$Reset" -Indent 3
    Write-Centered "${FGDarkGray}--------------------------------------------------------$Reset"
    Write-MaintItem "Get Updates" "RUN_UpdateSuite.ps1" "Maintenance_WinUpdate" -Threshold 1
    Write-MaintItem "WinGet App Updates" "RUN_WingetUpgrade.ps1" "Maintenance_WinUpdate" -Threshold 1
    Write-MaintItem "Drive Optimization" "RUN_OptimizeDisks.ps1" "Maintenance_Disk" -Threshold 7
    Write-MaintItem "Temp File Cleanup" "RUN_SystemCleanup.ps1" "Maintenance_Cleanup" -Threshold 7
    Write-MaintItem "SFC / DISM Repair" "RUN_WindowsRepair.ps1" "Maintenance_SFC" -Threshold 30

    Write-Host ""
    Write-Host ""
    Write-Boundary -Color $FGYellow

    $PromptRow = [Console]::CursorTop
    
    # Dynamic Footer Prompt Logic (Standard View Only now)
    $Act = "DASHBOARD"
    $Sel = $null
    $Pre = ""

    # Timeout logic: Only on first load
    $ActionText = "DASHBOARD" # Unused variable but kept for readability if referenced elsewhere
    $TimeoutSecs = 0
    if ($Global:WinAutoFirstLoad) {
        $TimeoutSecs = 5
        $Global:WinAutoFirstLoad = $false
    }

    $res = Invoke-AnimatedPause -ActionText $Act -Timeout $TimeoutSecs -SelectionChar $Sel -PreActionWord $Pre -OverrideCursorTop $PromptRow

    # --- NAVIGATION LOGIC ---
    if ($res.VirtualKeyCode -eq 38) {
        # Up
        $MenuSelection--
        if ($MenuSelection -lt 0) { $MenuSelection = 3 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 40) {
        # Down
        $MenuSelection++
        if ($MenuSelection -gt 3) { $MenuSelection = 0 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 39) {
        # Right (Visual Feedback or expand logic if we had distinct expansions, keeping placeholder)
        continue
    }
    elseif ($res.VirtualKeyCode -eq 37) {
        # Left
        continue
    }
    
    if ($res.VirtualKeyCode -eq 27) {
        # Esc or X -> Exit
        Write-LeftAligned "$FGGray Exiting - WinAuto -...$Reset"
        Start-Sleep -Seconds 1
        break
    }
    elseif ($res.VirtualKeyCode -eq 13) {
        # Enter Handling (Mapped to Spacebar logic logic effectively, or just loop if user insists on space)
        # We will ignore Enter or treat it as Space to be safe, but Space is the primary.
        $res.Character = ' '
        $res.VirtualKeyCode = 32
    }
    

    
    if ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        # Space Action Logic (Context Sensitive)
        $Target = $MenuSelection
        
        # GLOBAL: Run Windows Update Check FIRST
        # Invoke-WA_WindowsUpdate (Moved to Maintenance Phase)
        
        if ($Target -eq 0) {
            # [S]mart Run -> EXECUTE
            if (-not $Global:AllAppsInstalled) { Invoke-WA_InstallApps -SmartRun }
            Invoke-WinAutoConfiguration -SmartRun
            Set-WinAutoLastRun -Module "Configuration"
            if (-not $Global:MaintenanceComplete) { Invoke-WinAutoMaintenance -SmartRun }
        }
        elseif ($Target -eq 1) {
            # [I]nstall -> EXECUTE (Manual overrides check)
            Invoke-WA_InstallApps
        }
        elseif ($Target -eq 2) {
            # [C]onfig -> EXECUTE
            Invoke-WinAutoConfiguration
            Set-WinAutoLastRun -Module "Configuration"
        }
        elseif ($Target -eq 3) {
            # [M]aintenance -> EXECUTE (Manual overrides check)
            Invoke-WinAutoMaintenance
        }
        
        # Pause slightly if we toggled, or if we ran (though ran usually has its own pauses)
        Start-Sleep -Milliseconds 200
        continue
    }
    elseif ($res.Character -eq 'I' -or $res.Character -eq 'i') {
        Clear-Host
        Write-Host ""
        Write-Centered "$Bold$FGCyan - WinAuto - $Reset"
        Write-Boundary -Color $FGCyan
        Write-Centered "$Bold$FGCyan SmartRUN - Reference Map $Reset"
        Write-Host ""
        # Display manifest with body lines in DarkGray
        $Global:WinAutoManifestContent -split "`n" | ForEach-Object {
            $line = $_.TrimEnd()
            if ($line -match "wa\.ps1: Functional Outline") {
                Write-Centered $line
            }
            elseif ($line.Trim() -match "^-") {
                Write-Host $line
            }
            else {
                Write-Host $line
            }
        }
        Write-Host ""
        Write-Host "                       ${Global:FGYellow}Navigation${Global:Reset} ${Global:FGBlack}${Global:BGDarkCyan}KEYS${Global:Reset}                       `n  ${Global:FGBlack}${Global:BGDarkCyan}Enter${Global:Reset} ${Global:FGGray}to export CSV${Global:Reset} ${Global:FGDarkGray}|${Global:Reset} ${Global:FGYellow}->${Global:Reset}${Global:FGDarkGray}|${Global:Reset}${Global:FGBlack}${Global:BGYellow}Space${Global:Reset}${Global:FGDarkGray}|${Global:Reset}${Global:FGYellow}<-${Global:Reset} ${Global:FGGray}to return${Global:Reset} ${Global:FGDarkGray}|${Global:Reset} ${Global:FGBlack}${Global:BGDarkCyan}Esc${Global:Reset} ${Global:FGGray}to${Global:Reset} ${Global:FGDarkRed}${Global:BGWhite}EXIT${Global:Reset}"
        while ($true) {
            $mk = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($mk.Character -eq ' ' -or $mk.VirtualKeyCode -eq 32 -or $mk.Character -eq 'I' -or $mk.Character -eq 'i') { break }
            if ($mk.VirtualKeyCode -eq 27) { 
                # Esc pressed - exit script
                Write-Host ""
                Write-Centered "Copyright (c) 2026 WinAuto"
                Write-Host ""
                return
            }
            if ($mk.VirtualKeyCode -eq 13) {
                # Enter pressed - export CSV
                Export-WinAutoCSV
                Write-Centered "$FGGreen Exported CSV to Script Directory! $Reset"
                Start-Sleep -Seconds 2
            }
        }
    }
    else {
        # Any other key loop back
        Start-Sleep -Milliseconds 100
        continue
    }
}

# Get-LogReport
Write-Host ""
Write-Footer
# Invoke-AnimatedPause -ActionText "EXIT" -Timeout 0 | Out-Null
Write-Host ""
Write-Centered "Copyright (c) 2026 WinAuto"
Write-Host ""

