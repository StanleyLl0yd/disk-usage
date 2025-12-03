# DiskUsage – simple disk space analyzer for macOS

**Languages:** [English](README.md) | [Русский](README.ru.md)

DiskUsage is a small native macOS app written in Swift/SwiftUI.  
It helps you quickly see which folders take up the most space on your disk.

> I am developing this project in my free time and saving up for an Apple
> Developer Program subscription (99 USD/year) to sign, notarize and eventually
> publish the app on the Mac App Store.  
> See the “Support” section below if you’d like to help.

---

## Features

- Scan:
  - your home folder;
  - the entire disk `/` (only when explicitly requested);
  - any custom folder via standard folder picker.
- Group results by top-level subfolders under the selected root.
- Drill-down navigation:
  - click a row to go deeper into that folder;
  - “Back” button to move up a level.
- Show:
  - folder size with human-readable units (B / KB / MB / GB / TB);
  - percentage of total size under the current root;
  - folders that cannot be accessed due to permissions.
- Asynchronous scanning so the UI stays responsive.
- Localization:
  - English and Russian;
  - English is used for all non-Russian system locales.

---

## Tech stack

- macOS, Swift 5+
- SwiftUI
- MVVM:
  - `DiskScannerViewModel` as the ViewModel;
  - `DiskUsageService` as the scanning service.
- Swift Concurrency:
  - background scanning with `Task.detached`;
  - UI updates on `MainActor` only.
- Localization via String Catalog (`Localizable.xcstrings`).

---

## Requirements

- macOS 14+ (Sonoma) / 15+ (Sequoia) recommended.
- Xcode 16 / 26.1.1 or newer.

---

## Roadmap

- Progress indicator while scanning.
- Simple visual charts for largest folders.
- More options:
  - include/exclude hidden files;
  - include/exclude certain system areas;
  - minimum size threshold for displayed items.
- Accessibility improvements (VoiceOver, keyboard navigation).
- Sandbox and permissions polish for Mac App Store builds.

---

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
