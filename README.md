# WinAuto (Core Edition)

> **Enterprise-grade Windows 11 configuration management in a single, self-contained PowerShell file.**

![Version](https://img.shields.io/badge/version-2.0.0-blue) ![Platform](https://img.shields.io/badge/platform-Windows%2011-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## Overview

**WinAuto** is more than just a setup script; it is a **portable IT Asset Management (ITAM) artifact** designed for professional environments. Unlike traditional RMM agents or complex SCCM task sequences, WinAuto offers a **zero-dependency** architecture that can run in air-gapped environments, on standalone workstations, or as part of a Golden Image sealing process.

It combines intelligent application orchestration, security hardening (CIS/NIST alignment), and system maintenance into a responsive, keyboard-driven dashboard.

### Why WinAuto?

| Feature | WinAuto | Traditional Scripts | RMM Agents |
| :--- | :--- | :--- | :--- |
| **Dependencies** | **None (Zero)** | Modules / Internet | Cloud Connectivity |
| **Execution** | **Portable File** | Complex Folder Structures | Installed Agent |
| **Security** | **HVCI / VBS Aware** | Basic Registry Tweaks | Varies by Vendor |
| **Auditability** | **CSV Export / Logs** | Transient Output | Cloud Dashboard |

---

## 🏗️ Self-Contained Architecture

WinAuto follows a **single-file delivery model**. 
- **`wa.ps1`**: The Core Logic engine. It contains all necessary functions, UI rendering code, and logic internally. It **embeds the application configuration**, requiring no external files.

**Key Benefits:**
1.  **Air-Gap Ready**: Copy the script to a USB drive and run it on a machine with no internet access.
2.  **Golden Image Sealing**: Perfect for "Sysprep" phases where you want to apply a consistent baseline before capturing an image.
3.  **Field Engineering**: A single tool for technicians to carry on their toolkit USBs.
4.  **Atomic Modularity**: Powered by individual `AtomicScripts` that can be run independently with standardized `-Reverse` support.

---

## 🛡️ Security & Compliance

WinAuto is built with an "Audit First" philosophy, aligning configuring settings with major security frameworks.

| Feature | CIS Control (v8) | NIST SP 800-53 | Implementation |
| :--- | :--- | :--- | :--- |
| **Real-Time Protection** | 10.1 | SI-3 | Enforces `DisableRealtimeMonitoring = 0` via WMI |
| **Memory Integrity (HVCI)** | 4.8 | SI-16 | Safe Registry injection for `HypervisorEnforcedCodeIntegrity` |
| **PUA Protection** | 10.1 | SI-3 | Enables Potentially Unwanted App blocking in Defender & Edge |
| **Firewall Enforcement** | 4.4 | SC-7 | Validates and enables all 3 Firewall Profiles (Domain/Private/Public) |
| **LSA Protection** | 4.8 | SC-3 | Configures `RunAsPPL` for Local Security Authority |
| **Windows Updates** | 7.4 | SI-2 | Enforces Auto-Update service and restart notifications |

> **Note**: WinAuto respects the "True Compliance State". If a setting is already correct, it skips the action (Idempotency).

---

## ⚡ Deployment Scenarios

### 1. New Device Provisioning (OOBE)
Run WinAuto immediately after the first login to:
- Install baseline applications (via `Install_RequiredApps-Config.json`).
- Harden security settings (HVCI, Firewall).
- Debloat UI (Taskbar, Widget cleanup).

### 2. Golden Image Preparation
Run WinAuto in "Audit Mode" or before Sysprep to ensure the base image complies with security standards. Use the **Maintenance** module to clean up temp files and optimize disks before capture.

### 3. Field Maintenance (Break/Fix)
Technicians can use the **Maintenance** dashboard to:
- Run standard SFC/DISM repairs.
- Force Windows Updates via USOClient.
- Reset Firewall states.

---

## 🚀 Quick Start

### Prerequisites
- **OS**: Windows 11 (Build 22000+) recommended.
- **Privileges**: **Administrator** rights are required (auto-checked on launch).
- **Execution Policy**: Script will attempt to set `Process` scope to `RemoteSigned`.

### Run It Now
Open an **Administrator PowerShell** window and paste:
```powershell
iex (irm https://raw.githubusercontent.com/KeithOwns/wa/main/wa.ps1)
```

### Alternative Execution

**Option A: Interactive Mode (TUI)**
If you have the file locally, run in Administrator PowerShell:
```powershell
.\wa.ps1
```

**Option B: CLI / Unattended Mode**
Run specific modules without user interaction (great for SCCM/Intune):
```powershell
# Run SmartRun logic silently
.\wa.ps1 -Module SmartRun -Silent

# Run only Configuration (Security/UI)
.\wa.ps1 -Module Config -Silent

# Run Application Installer only
.\wa.ps1 -Module Install -Silent
```

**Parameters:**
- `-Module <Name>`: Run a specific module (`SmartRun`, `Install`, `Config`, `Maintenance`).
- `-Silent`: Suppress the interactive dashboard and prompts.
- `-Verbose`: Show detailed logging output in the console.
- `-LogPath <Path>`: Specify a custom folder or file for logs (e.g., `C:\Logs\WA.log`).
- `-Config <Path>`: Load a custom JSON file for application installation, overriding the embedded list.

---

## 🎮 Dashboard Navigation

WinAuto features a unified, keyboard-driven text UI (TUI).

```text
    [ SmartRUN ]      [ Install ]      [ Configure ]      [ Maintain ]
```

*   **Arrow Keys (`^` `v`)**: Navigate between phases.
*   **Spacebar**: Execute the selected phase.
*   **Hotkeys**:
    *   `S`: **SmartRUN** (Orchestrated run based on logic).
    *   `I`: **Install** Apps.
    *   `C`: **Configure** Security & UI.
    *   `M`: **Maintain** System.
    *   `H`: **Help** / System Impact Manifest.
*   **Esc**: Exit.

---

## ⚙️ Configuration (JSON)

Application installation is driven by an **embedded JSON configuration** within `wa.ps1`. You can edit the `Get-WA_InstallAppList` function directly to modify the list of applications.

**Internal Schema:**
```json
{
  "BaseApps": [
    {
      "AppName": "Google Chrome",
      "Type": "WINGET",
      "WingetId": "Google.Chrome"
    },
    {
      "AppName": "Corporate VPN",
      "Type": "MSI",
      "Url": "https://intranet.corp/vpn.msi",
      "Arguments": "/quiet /norestart"
    }
  ]
}
```

---

## 📊 Logging & Audit

*   **Logs**: Stored in `.\logs\wa.log` (Rotated).
*   **CSV Export**: Press `Enter` on the Help screen to generate `scriptOUTLINE-wa.csv`. This file contains a detailed audit trail of every function, registry key, and command the script is capable of modifying.

---

## 📦 Included Scripts

WinAuto orchestrates the following Atomic Scripts, which can also be run independently:

| Script Name | Function | Type |
| :--- | :--- | :--- |
| **Installers** | | |
| `INSTALL_AdobeCC.ps1` | Installs Adobe Creative Cloud | WinGet (Atomic) |
| `INSTALL_BoxDrive.ps1` | Installs Box Drive | WinGet (Atomic) |
| `INSTALL_BoxOffice.ps1` | Installs Box for Office | EXE (Atomic) |
| `INSTALL_BoxTools.ps1` | Installs Box Tools | EXE (Atomic) |
| `INSTALL_AirMedia.ps1` | Installs Crestron AirMedia | WinGet (Atomic) |
| **Configuration** | | |
| `SET_RealTimeProt.ps1` | Disables Real-Time Protection | PS WMI |
| `SET_PUABlockApps.ps1` | Enables PUA Protection (Defender) | PS WMI |
| `SET_PUABlockDLs.ps1` | Enables PUA Protection (Edge) | Registry (HKCU) |
| `SET_MemoryInteg.ps1` | Enables Memory Integrity (HVCI) | Registry (HKLM) |
| `SET_KernelMode.ps1` | Enables Kernel Stack Protection | Registry (HKLM) |
| `SET_LocalSecurity.ps1` | Enables LSA Protection | Registry (HKLM) |
| `SET_FirewallON.ps1` | Enables All Firewall Profiles | PowerShell Cmdlt |
| `SET_ClassicMenu.ps1` | Restores Classic Context Menu | Registry (HKCU) |
| `SET_TaskbarSearch.ps1` | Sets Search to Icon Only | Registry (HKCU) |
| `SET_TaskViewOFF.ps1` | Hides Task View Button | Registry (HKCU) |
| `SET_MicrosoftUpd.ps1` | Enables MS Update Service | Registry (HKLM) |
| `SET_RestartIsReq.ps1` | Enables Restart Notifications | Registry (HKLM) |
| `SET_RestartApps.ps1` | Enables App Restart Persistence | Registry (HKCU) |
| **Maintenance** | | |
| `RUN_WingetUpgrade.ps1` | Updates All Apps via WinGet | Command Line |
| `RUN_OptimizeDisks.ps1` | Optimizes/Trims Disks | PowerShell Cmdlt |
| `RUN_SystemCleanup.ps1` | Cleans Temp Files | File System |
| `RUN_WindowsRepair.ps1` | Runs SFC & DISM Repair | Command Line |

---

## ⚠️ Disclaimer

This software modifies system configurations, registry keys, and security policies. While designed to be safe and idempotent:
1.  **Always test** in a non-production environment first.
2.  **Back up** critical data before running maintenance tasks.
3.  The authors are not responsible for any system instability or data loss.

---
*Maintained by the WinAuto Team | Open Source MIT License*
