# Atomic Script Installers

Place application installer scripts here. `wa.ps1` will automatically find and run them when executing the **Install Applications** phase.

## Naming Convention

Scripts must match the `Script` field in the embedded app config inside `wa.ps1`:

| App | Script Filename |
|-----|----------------|
| Adobe Creative Cloud | `INSTALL_AdobeCC.ps1` |
| Box | `INSTALL_BoxDrive.ps1` |
| Box for Office | `INSTALL_BoxOffice.ps1` |
| Box Tools | `INSTALL_BoxTools.ps1` |
| Crestron AirMedia | `INSTALL_AirMedia.ps1` |

## Behavior Without Scripts

If a script file is not present, `wa.ps1` will **gracefully skip** that app and log a warning. The install phase will still run for all other apps.
