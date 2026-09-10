# DiskUsage

**Languages:** [English](README.md) | [Русский](README.ru.md)

A fast, privacy-first disk space analyzer for macOS built with SwiftUI.

## Why DiskUsage
- Instant clarity: tree or sunburst view to spot space hogs quickly.
- Built-in actions: reveal in Finder, copy path, move to Trash.
- Works anywhere: scan home, full disk (`/`), or any folder.
- Minimal friction: local scanning, no accounts, no tracking.

## Core Features
- Disk info bar with total/used/free space.
- Sortable tree view with inline size bars.
- Sunburst view for at-a-glance hotspots.
- Settings for default view, language, delete confirmation, and hidden files.
- English and Russian localization.

## Requirements
- macOS 26.1+
- Xcode 26.1+

## Setup
1. Open `DiskUsage.xcodeproj` in Xcode.
2. Build and run.
3. If scanning protected areas, grant **Full Disk Access** in System Settings → Privacy & Security.

## Verification
Run the `DiskUsage` shared scheme to build the app and execute the regression tests.

## Status & Roadmap
- Current distribution: source-only.
- Active product/UI/performance roadmap: [`docs/PRODUCT_ROADMAP.md`](docs/PRODUCT_ROADMAP.md).
- Current roadmap milestone: **M1 — Performance and scan-result foundation**.
- Product direction: a polished native macOS disk analyzer with a calm, minimal Zen visual language and an independent identity.

## Contributing
Pull requests and issues are welcome. Product, UI/UX, and performance changes should follow the active roadmap and repository rules in `AGENTS.md`. For UI changes, include a short note or screenshot.

## Support the Project
Raising funds for the Apple Developer Program (USD 99/year) to ship signed/notarized builds, publish on the Mac App Store, and enable automatic updates.

You can help by starring the repo, filing feedback/issues, opening PRs, or checking my GitHub profile/repo description for donation links if you'd like to contribute financially.

## License
Copyright (c) 2025 **Stanley Lloyd**.

Licensed under the **PolyForm Noncommercial 1.0.0** license. Noncommercial use, copying, modification, and distribution are permitted. Commercial use requires a separate agreement; contact me for licensing. See `LICENSE` for full terms.