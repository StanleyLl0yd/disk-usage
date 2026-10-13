# Unsigned numeric test releases

DiskUsage uses numeric-only `0.x.y` version and tag identifiers for owner-approved test builds. The current release request is **`v0.2.0`**, app version **`0.2.0`**, build **`2`**. No alpha, beta, rc, or other channel suffix is appended to a new version number. The GitHub Release is marked as a **prerelease** to show that real-device acceptance is still pending, not to encode a channel into the version.

R1–R7 and the post-R7 audit are complete. This is a **test distribution**, not a signed/notarized production `1.0.0` release.

## Distribution and integrity

Test binaries intentionally have **no Developer ID signature and no notarization** because the signing infrastructure and production release approval are separate matters. Apple Silicon toolchains may embed an ad-hoc linker signature; it does not represent a trusted Developer ID identity.

The release is built from an exact, fully verified `main` commit using Xcode 26.6. GitHub Actions must pass macOS CI, Security, CodeQL Swift/Actions and the configured quality checks before the release job publishes any binaries. The immutable `v*` tag must point to that exact source commit. Existing tags/releases are never overwritten.

Each release publishes:

- `DiskUsage-0.2.0.app.zip`: universal `arm64` + `x86_64` app archive
- `DiskUsage-0.2.0.dmg`: app and Applications shortcut
- `SHA256SUMS`: SHA-256 digests of the ZIP and DMG

## Verify a downloaded build

Download the artifact and `SHA256SUMS` together from the repository's official [GitHub Releases](https://github.com/StanleyLl0yd/disk-usage/releases) page, then run:

```bash
shasum -a 256 -c SHA256SUMS
```

Both listed files must match if both are present. If only one artifact was downloaded, compare its computed `shasum -a 256 <filename>` against the corresponding line of `SHA256SUMS`.

Never run an artifact whose digest does not match.

## Gatekeeper

Because test binaries lack Developer ID signing and notarization, macOS may prevent a normal first launch. After verifying the official GitHub download, use Finder's per-app **Open** action or the corresponding **Privacy & Security** control in System Settings if macOS offers it.

Do **not** disable Gatekeeper globally, remove system quarantine attributes as a general workaround, or weaken macOS security settings.

## Real-device acceptance

These checks require a real Mac and are not covered merely by a successful GitHub-hosted CI run.

- Launch and quit the ZIP/DMG-installed app on arm64 and, if available, x86_64.
- Scan Home, a user-selected folder and an accessible disk root; verify sizes, progress, completion, restricted-path reporting and Full Disk Access guidance.
- Cancel/rescan while a large scan is active, then repeat to check stale result handling.
- Exercise Tree, Sunburst, Search and Largest Files; resize windows, test keyboard navigation/focus and inspect Retina behavior.
- Verify Finder reveal/copy actions and confirm that Move to Trash uses explicit confirmation and does not permanently remove the target.
- Switch English/Russian, check plural count formatting, restart from Settings and verify state recovery.
- Record crashes, permission-related failures, visual clipping and unexpected filesystem changes.

Report findings against exact `v0.2.0` and the release source SHA, with macOS version and Mac architecture.

## Historical release

The previously published `v0.1.0-alpha.1` is an immutable historical binary built from `23355eeed05f777022a2f2aed19ccf90d6e55a27` (version `0.1.0`, build `1`). It is not a substitute for testing the current R7-complete product.
