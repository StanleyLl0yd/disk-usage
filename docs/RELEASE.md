# Alpha release testing

DiskUsage alpha binaries are intended for early testing before the full R5 workflow and R7 release-quality pass are complete.

## Current distribution policy

The first binary prereleases are intentionally **unsigned and not notarized** because Developer ID signing is not configured yet.

Each prerelease is built from an exact `main` commit and publishes:

- a universal `arm64` + `x86_64` `DiskUsage.app` archive;
- a DMG containing `DiskUsage.app` and an Applications shortcut;
- `SHA256SUMS` for the downloadable binary artifacts.

Do not treat an unsigned alpha as equivalent to a signed/notarized production release.

## Verify the download

Download `SHA256SUMS` together with the artifact you intend to test. Compute its SHA-256 digest and compare it with the matching line in `SHA256SUMS`.

For example:

```text
shasum -a 256 DiskUsage-0.1.0-alpha.1.dmg
```

Only use artifacts from the repository's GitHub Releases page and only when the digest matches.

## Gatekeeper

Because the alpha is unsigned and not notarized, macOS may block a normal first launch.

If you intentionally trust the verified GitHub release and choose to test it, use macOS's normal per-app override flow, such as Finder's **Open** action or the corresponding **Privacy & Security** option in System Settings.

Do **not** disable Gatekeeper globally and do not strip quarantine attributes as a general workaround.

## First alpha scope

`v0.1.0-alpha.1` is based on app version `0.1.0` build `1` after completion of R5.3.

It includes the completed scan, Tree/Sunburst, shared selection/actions, Trash, cancellation/rescan, Finder drag-and-drop, restricted-path reporting, and Full Disk Access guidance workflows.

R5.4 Search/filtering and R5.5 Largest Files are intentionally not included yet.
