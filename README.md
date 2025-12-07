# DiskUsage

**Languages:** [English](README.md) | [Русский](README.ru.md)

A native macOS app for analyzing disk space usage, built with SwiftUI.

> I am developing this project in my free time and raising funds for the Apple
> Developer Program subscription (99 USD/year) to sign, notarize, and eventually
> publish the app on the Mac App Store. See the **Support** section if you'd
> like to help.

## Features

- **Two visualization modes:**
  - Tree view — hierarchical list with expandable folders
  - Sunburst view — circular chart (DaisyDisk-style)
- **Disk info bar** — shows total/used/free space with color-coded progress
- **Scan options:**
  - Home folder
  - Entire disk (/)
  - Custom folder
- **File operations:**
  - Show in Finder
  - Copy path
  - Move to Trash (with size recalculation)
- **Settings:**
  - Default view mode
  - Language (System/English/Russian)
  - Confirm before delete
  - Show hidden files
- **Full localization:** English & Russian

## Requirements

- macOS 14.0+
- Xcode 15+
- Full Disk Access (for scanning system folders)

## Setup

1. Open `DiskUsage.xcodeproj` in Xcode
2. Build and run
3. Grant Full Disk Access in System Settings → Privacy & Security → Full Disk Access

## Files

```
DiskUsageApp.swift       — App entry point
ContentView.swift        — Main UI container
TreeView.swift           — Tree visualization
SunburstView.swift       — Circular visualization
DiskScanner.swift        — File system scanner
DiskScannerViewModel.swift — State management
FolderUsage.swift        — Data model
Settings.swift           — App settings model
SettingsView.swift       — Settings UI
Utilities.swift          — Formatting helpers
Localizable.xcstrings    — Localization
DiskUsage.entitlements   — App entitlements
```

## Known Issues

- Sunburst hover detection needs improvement when moving between ring levels

## Support

Right now the app is only available as source code and local builds.

I am currently raising money for the Apple Developer Program (99 USD/year) to:

- ship signed and notarized builds that run cleanly on any Mac;
- publish DiskUsage on the Mac App Store;
- provide automatic updates and easier installation.

You can support the project by:

- starring this repository;
- opening issues with feedback or bug reports;
- sending pull requests with improvements;
- checking my GitHub profile or repository description for donation/support links
  if you’d like to help financially.

Any feedback and contributions are very welcome.
