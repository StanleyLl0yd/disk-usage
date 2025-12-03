# DiskUsage – simple disk space analyzer for macOS

DiskUsage is a small native macOS app written in Swift/SwiftUI that helps you see
which folders take up the most space on your disk. Lightweight and focused,
without extra clutter.

> I am developing this project in my free time and currently saving up for an
> Apple Developer Program subscription (99 USD/year) to:
> - sign and notarize the app;
> - publish it on the Mac App Store;
> - provide easier installation and automatic updates.  
> See the “Support” section below if you’d like to help.

---

## Features

- Scanning:
  - user’s home folder;
  - entire disk `/` (only when explicitly requested);
  - any custom folder via standard folder picker.
- Grouping:
  - aggregates size by top-level subfolders under the selected root.
- Drill-down navigation:
  - click a row to navigate deeper into that folder;
  - “Back” button to go up one level.
- Display:
  - folder sizes with human-readable units (B / KB / MB / GB / TB);
  - percentage of total size for each item under the current root;
  - list of folders that cannot be accessed due to permissions.
- Asynchronous scanning:
  - UI remains responsive during long scans;
  - previous scan can be cancelled when a new one is started.
- Localization:
  - English and Russian;
  - English is used for all non-Russian system locales.

---

## Tech stack

- macOS, Swift 5+
- SwiftUI
- MVVM architecture:
  - `DiskScannerViewModel` as the ViewModel;
  - `DiskUsageService` as the scanning service.
- Swift Concurrency:
  - `Task.detached` for filesystem scanning;
  - UI updates on `MainActor` only.
- Localization:
  - String Catalog (`Localizable.xcstrings`);
  - `String(localized: "key", defaultValue: "…")` for localized strings.

---

## Requirements

- macOS 14+ (Sonoma) / 15+ (Sequoia) recommended.
- Xcode 16 / 26.1.1 or newer (String Catalog and Swift Concurrency support).

---

## Building from source

1. Clone the repository:

   ```bash
   git clone https://github.com/USERNAME/DiskUsage.git
   cd DiskUsage
   ```

2. Open the project:

   ```bash
   open DiskUsage.xcodeproj
   ```

3. In Xcode:
   - select the `DiskUsage` scheme;
   - choose `My Mac` as the run destination;
   - press `Run` (`⌘R`).

The app will run locally without a Developer ID.  
For distribution outside your own Mac, a paid Apple Developer account is required
to sign and notarize the app.

---

## Localization

All user-facing strings are stored in a String Catalog:

- `Localizable.xcstrings` contains keys for both English and Russian.
- English is the development language and the default.
- Russian strings are used when the macOS system locale is set to Russian.

To edit translations:

1. Open `Localizable.xcstrings` in Xcode.
2. Select the desired language (English or Russian).
3. Edit the values for each key in the table.

To test localization:

- Xcode → `Product` → `Scheme` → `Edit Scheme…` → `Options` → `Application Language`.

---

## Roadmap

- Progress indicator while scanning (with clear “scanning…” feedback).
- Simple visual charts for largest folders.
- Additional options:
  - include or exclude hidden files;
  - include or exclude specific system areas;
  - minimum size threshold for displayed items.
- Accessibility improvements:
  - better VoiceOver descriptions;
  - keyboard navigation.
- Polishing sandbox behavior and permissions flow for Mac App Store.

---

## Support

Right now the app is only available as source code and local builds.

I am currently raising money for the Apple Developer Program (99 USD/year) to:

- ship signed and notarized builds that run cleanly on any Mac;
- publish DiskUsage on the Mac App Store;
- provide automatic updates and easier installation for non-technical users.

Ways to support:

- star this repository on GitHub;
- open issues with feedback, bug reports, or feature ideas;
- send pull requests with improvements;
- if you’d like to help financially, please check my GitHub profile or repository
  description for support links.

Any feedback and contributions are very welcome.
