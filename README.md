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
- Local search by file/folder name or path over completed scan results.
- Transient Top 100 largest-files view derived from the completed scan.
- Settings for default view, language, delete confirmation, and hidden files.
- English and Russian localization.

## Requirements
- macOS 14.0+
- Xcode 26.6+
- Swift 6 language mode

## Setup
1. Open `DiskUsage.xcodeproj` in Xcode.
2. Build and run.
3. If scanning protected areas, grant **Full Disk Access** in System Settings → Privacy & Security.

## Alpha builds
The project owner approved unsigned alpha binary distribution before R5.4. Alpha artifacts are intentionally **not Developer ID signed and not notarized**, so macOS Gatekeeper may block a normal first launch.

Each prerelease publishes a universal `arm64` + `x86_64` app archive, a DMG, and `SHA256SUMS`. Verify the downloaded artifact before opening it and do not disable Gatekeeper globally. See [`docs/RELEASE.md`](docs/RELEASE.md) for the testing policy and safe launch guidance.

The first binary alpha, `v0.1.0-alpha.1`, is published from verified `main` commit `23355eeed05f777022a2f2aed19ccf90d6e55a27`, using app version `0.1.0` build `1`.

## Verification
Run the `DiskUsage` shared scheme to build the app and execute the regression tests. CI uses Xcode 26.6 as the canonical toolchain. Repeatable presentation-performance workloads and profiling guidance are documented in [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md).

## Status & Roadmap
- Current app version: `0.1.0` (build `1`).
- Distribution policy: source plus owner-approved unsigned alpha prereleases; signed/notarized binaries are not available yet.
- **R3 — Unified selection, navigation, and polished Tree view is complete.**
- **R4 — Sunburst 2.0: DiskUsage visual identity is complete.** All five R4 slices are implemented and verified, and the separate master exit review found no remaining R4 gap.
- **R5 — Core productivity workflow is complete.** R5.1–R5.5 are implemented and verified, the repository-wide exit review passed, and release tags `v*` are protected against update/deletion with the published `v0.1.0-alpha.1` still bound to its verified source commit.
- **R6 — Large-scale resilience and measured optimization is complete.** R6.1–R6.11 measured scanner, memory, derived presentation, publication, and real SwiftUI interaction at representative large synthetic/disposable scales; the evidence-driven runtime changes were kept narrow, rejected candidates stayed out of production, and the separate repository-wide exit review found no remaining R6 blocker.
- **R7 — Release-quality product polish is active.** R7.1–R7.3 are complete and exact-main verified. R7.4 resize/high-DPI runtime verification found no layout defect and retains the current responsive layout unchanged; R7.5 and the separate R7 exit review remain. See [`docs/ROADMAP.md`](docs/ROADMAP.md).
- Version `1.0.0` is reserved for release readiness after the planned product stages are complete and verified.

## Contributing
Pull requests and issues are welcome. For UI changes, include a short note or screenshot.

## Support the Project
Raising funds for the Apple Developer Program (USD 99/year) to ship signed/notarized builds, publish on the Mac App Store, and enable automatic updates.

You can help by starring the repo, filing feedback/issues, opening PRs, or checking my GitHub profile/repo description for donation links if you'd like to contribute financially.

## License
Copyright (c) 2025 **Stanley Lloyd**.

Licensed under the **PolyForm Noncommercial 1.0.0** license. Noncommercial use, copying, modification, and distribution are permitted. Commercial use requires a separate agreement; contact me for licensing. See `LICENSE` for full terms.
