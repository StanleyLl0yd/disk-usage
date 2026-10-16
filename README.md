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

## Test builds
The owner approved unsigned **numeric-only** test builds. The current requested test release is `v0.2.1` (app version `0.2.1`, build `3`); the version and tag contain no alpha/beta/rc suffix. GitHub may label the release as a prerelease to indicate that real-device acceptance remains outstanding.

The app archive and DMG contain a universal `arm64` + `x86_64` app. Each published release also includes `SHA256SUMS`. Test binaries are **not Developer ID signed or notarized**, so macOS Gatekeeper may block a normal first launch. Verify the checksum first, and use only macOS's per-app override rather than disabling Gatekeeper globally. See [`docs/RELEASE.md`](docs/RELEASE.md).

The previous `v0.2.0` test release remains immutable and does not contain the UI refinements delivered by PRs #157 and #158. The `v0.2.1` test build includes those changes and is intended for real-Mac acceptance (issue #155).

The historic `v0.1.0-alpha.1` release remains bound to original commit `23355eeed05f777022a2f2aed19ccf90d6e55a27`; it does not contain the completed R5–R7 product.

## Verification
Run the `DiskUsage` shared scheme to build the app and execute the regression tests. CI uses Xcode 26.6 as the canonical toolchain. Repeatable presentation-performance workloads and profiling guidance are documented in [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md).

## Status & Roadmap
- Current app version: `0.2.1` (build `3`).
- Distribution policy: source plus owner-approved unsigned numeric test releases; signed/notarized binaries are not available yet.
- **R3 — Unified selection, navigation, and polished Tree view is complete.**
- **R4 — Sunburst 2.0: DiskUsage visual identity is complete.** All five R4 slices are implemented and verified, and the separate master exit review found no remaining R4 gap.
- **R5 — Core productivity workflow is complete.** R5.1–R5.5 are implemented and verified, the repository-wide exit review passed, and release tags `v*` are protected against update/deletion with the published `v0.1.0-alpha.1` still bound to its verified source commit.
- **R6 — Large-scale resilience and measured optimization is complete.** R6.1–R6.11 measured scanner, memory, derived presentation, publication, and real SwiftUI interaction at representative large synthetic/disposable scales; the evidence-driven runtime changes were kept narrow, rejected candidates stayed out of production, and the separate repository-wide exit review found no remaining R6 blocker.
- **R7 — Release-quality product polish is complete.** R7.1–R7.5 are implemented and verified, and the separate repository-wide exit review found no remaining R7 blocker across accessibility, keyboard interaction, localization and copy, state/action wiring, resize/high-DPI evidence, regression coverage, safety, privacy, or release integrity. See [`docs/ROADMAP.md`](docs/ROADMAP.md).
- Version `1.0.0` remains reserved for a separate explicit production-release decision; the approved numeric test release does not introduce Developer ID signing/notarization.

## Contributing
Pull requests and issues are welcome. For UI changes, include a short note or screenshot.

## Support the Project
Raising funds for the Apple Developer Program (USD 99/year) to ship signed/notarized builds, publish on the Mac App Store, and enable automatic updates.

You can help by starring the repo, filing feedback/issues, opening PRs, or checking my GitHub profile/repo description for donation links if you'd like to contribute financially.

## License
Copyright (c) 2025 **Stanley Lloyd**.

Licensed under the **PolyForm Noncommercial 1.0.0** license. Noncommercial use, copying, modification, and distribution are permitted. Commercial use requires a separate agreement; contact me for licensing. See `LICENSE` for full terms.
