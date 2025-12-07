# DiskUsage

**Languages:** [English](README.md) | [Русский](README.ru.md)

A native macOS app for analyzing disk space usage, built with SwiftUI.

Designed to be lightweight and privacy-friendly: scanning is performed locally on your Mac.

## Features

- **Two visualization modes:**
  - Tree view — hierarchical list with expandable folders
  - Sunburst view — circular chart (DaisyDisk-style)
- **Disk info bar** — shows total/used/free space with color-coded progress
- **Scan options:**
  - Home folder
  - Entire disk (`/`)
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

## Privacy & Permissions

DiskUsage does not require an account.

To scan protected locations (for example, parts of the system volume when selecting `/`),
macOS may request additional permissions.

If the app can’t see the sizes you expect, grant **Full Disk Access** in:

System Settings → Privacy & Security → Full Disk Access

## Setup

1. Open `DiskUsage.xcodeproj` in Xcode
2. Build and run
3. If needed, grant Full Disk Access (see **Privacy & Permissions**)

## Files

```
DiskUsageApp.swift         — App entry point
ContentView.swift          — Main UI container
TreeView.swift             — Tree visualization
SunburstView.swift         — Circular visualization
DiskScanner.swift          — File system scanner
DiskScannerViewModel.swift — State management
FolderUsage.swift          — Data model
Settings.swift             — App settings model
SettingsView.swift         — Settings UI
Utilities.swift            — Formatting helpers
Localizable.xcstrings      — Localization
DiskUsage.entitlements     — App entitlements
```

## Known Issues

- Sunburst hover detection needs improvement when moving between ring levels

## Roadmap

- Merge duplicate context menu logic.
- Simplify tree sorting and refresh logic.
- Extract a unified scanning state object.
- Remove progress state management from `DiskScanner.scan`.
- Eliminate manual size accumulation in `Node.addFile`.

## Contributing

Issues and pull requests are welcome.

Guidelines:

- Keep changes focused and well-described.
- For UI changes, add a brief note or screenshot in the PR.
- For larger refactors, consider opening an issue first.

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

## License

This project is licensed under the **PolyForm Noncommercial 1.0.0** license.

You may use, copy, modify, and distribute this software for **noncommercial**
purposes only.

**Commercial use is not permitted** without a separate agreement.
If you want to use DiskUsage (or parts of it) in a commercial product, service,
or internal company tooling, please contact me to obtain a commercial license.

See the `LICENSE` file for the full text.
