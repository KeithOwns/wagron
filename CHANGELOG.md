# Changelog

All notable changes to WinAuto are documented here.

---

## [Unreleased]

### Fixed
- Install phase is now fully standalone — no external script files required to run.
  When an `ATOMIC_SCRIPT` installer is absent, the app is gracefully skipped with a
  clear warning instead of blocking the entire install phase.
- Fixed console UI double-newline glitch on the "Install Applications" header when
  the console width is exactly 60 columns. Applied `-NoNewline` fix.

---

## [stable] — Prior Stable Baseline (`STABLEwa.ps1`)

- Full WinAuto dashboard with SmartRUN, Install, Configure, and Maintain phases.
- Embedded atomic scripts for Configuration and Maintenance (no external files).
- Install phase listed Adobe CC, Box, Box for Office, Box Tools, and Crestron AirMedia.
