# Repository Agent Rules

These rules apply to all automated coding agents and repository maintenance work in DiskUsage.

## Project identity and priorities

DiskUsage is a native, privacy-first disk space analyzer for macOS built with SwiftUI and AppKit.

Preserve these priorities, in order:

1. File-system and scan correctness.
2. Safety of user file operations.
3. UI responsiveness and cancellation.
4. User privacy and macOS security boundaries.
5. Clear and predictable UX.
6. Minimal implementation complexity.

DiskUsage is a local utility. It must remain useful without an account, network connection, cloud service, or backend.

Do not add unrelated system-cleaner, optimizer, antivirus, cloud-storage, telemetry, or account functionality without an explicit product decision.

## Product boundaries

The core product responsibilities are:

- scan the user's home directory, root filesystem, or a user-selected folder;
- represent scanned disk usage as a hierarchical model;
- present the result through tree and sunburst views;
- report inaccessible locations honestly;
- reveal an item in Finder;
- copy an item's path;
- move an explicitly selected item to the macOS Trash;
- preserve local application settings.

Do not silently expand these responsibilities.

In particular, do not add automatic cleanup, background deletion, duplicate-file deletion, permanent deletion, privileged helpers, network scanning, or remote file operations without an explicit product decision.

## Privacy

DiskUsage is local-first and privacy-first.

Do not add:

- analytics;
- advertising;
- tracking;
- telemetry;
- user accounts;
- remote logging;
- cloud synchronization;
- upload of file names, paths, directory structure, scan results, or file contents;
- background network communication.

File-system paths and scan results are potentially sensitive user data.

Do not log full user paths or directory contents unless required for explicit local debugging and never persist such debugging data in production.

Do not commit personal scan output or real user file-system paths as fixtures or examples.

## File-system authority and scan model

`DiskScanner` is the authoritative filesystem traversal layer.

`FolderUsage` is a derived snapshot of a completed scan. It is not an independent source of filesystem truth.

SwiftUI views must render scan state and request actions; they must not independently enumerate, mutate, or reinterpret the filesystem.

Keep scan semantics explicit.

A scan must distinguish between:

- successfully observed filesystem data;
- inaccessible or restricted locations;
- cancelled or incomplete work.

Never present inaccessible data as successfully measured.

Do not invent sizes for unreadable files or directories.

The scan tree represents a snapshot. The filesystem may change after scanning, so code must not assume that a scanned path still exists or still has the same size when a later user action occurs.

## Size semantics

DiskUsage currently measures file usage from filesystem-reported allocated-size resource values.

Do not silently change from allocated size to logical file size, apparent size, compressed size, or another size definition.

Any intentional change to size semantics must update:

- the scanner;
- user-visible wording where necessary;
- regression tests;
- relevant documentation.

Do not assume that the sum of scanned files must equal the volume-level "used space" value.

Volume capacity and scanner totals may legitimately differ because of filesystem metadata, snapshots, clones, purgeable space, inaccessible data, allocation behavior, and other filesystem-level effects.

Do not claim exact physical disk consumption beyond what the available macOS filesystem APIs can support.

## Path and identity rules

Use standardized filesystem URLs or paths consistently.

`FolderUsage.id` is path-based. Do not casually change path identity semantics because SwiftUI identity, tree mutation, navigation, and deletion logic depend on them.

Do not compare unrelated filesystem objects only by display name.

Do not resolve or follow symbolic links, aliases, packages, mount points, or other filesystem indirections differently without explicitly reviewing the correctness, cycle, duplication, security, and UX consequences.

Changes to hidden-file, package, symlink, mount-point, or filesystem-boundary behavior require focused regression coverage.

## Scan concurrency

Filesystem traversal is potentially slow and must not block the main actor or SwiftUI rendering.

Keep expensive directory enumeration, resource-value lookup, tree construction, and equivalent scanning work off the UI execution path.

Main-actor work should be limited to publishing UI state and performing AppKit/SwiftUI operations that require it.

There must be at most one authoritative active scan for a `DiskScannerViewModel`.

Starting, cancelling, replacing, or completing a scan must not allow stale asynchronous work to overwrite newer UI state.

Cancellation is part of correctness.

Long-running traversal must check cancellation regularly and yield often enough to keep cancellation responsive.

A cancelled scan must not later publish itself as a successful completed scan.

Progress reporting must be throttled or sampled. Do not publish SwiftUI state for every discovered filesystem entry.

Do not use `@unchecked Sendable` as a substitute for reasoning about ownership and synchronization.

Any shared mutable scanning state must have an explicit synchronization strategy.

## Resource usage

Assume users may scan millions of filesystem entries.

Avoid unnecessary whole-tree copies, repeated recursive transformations, duplicate indexes, unbounded caches, and per-entry retained temporary objects.

Do not optimize by sacrificing correctness, cancellation, or filesystem safety.

Performance changes must be justified by an observable or measurable cost.

Prefer bounded or incremental work where practical.

Do not run expensive recursive sorting, layout preparation, or data transformation repeatedly on the main actor when the same result can be safely computed once or off the UI path.

## File operations

User file operations are security-sensitive.

The destructive operation currently supported by the product is moving an explicitly selected item to the macOS Trash.

Do not replace Trash behavior with permanent deletion such as:

- `FileManager.removeItem`;
- `unlink`;
- `rm`;
- shell scripts;
- recursive permanent deletion;
- privileged deletion.

Permanent deletion requires an explicit product decision and separate safety review.

A file operation must target exactly the item explicitly selected by the user.

Do not derive a destructive target from display text, partial path matching, stale selection state, or a parent directory unless that parent is the explicitly selected item.

Update the in-memory tree only after the operating-system file operation succeeds.

On failure:

- preserve the scanned model;
- surface the error clearly;
- do not pretend space was freed.

Deletion confirmation behavior is controlled by the user setting and must remain consistent across tree and sunburst views.

Tests for destructive operations must use disposable temporary directories and files. Never run destructive tests against real user data.

## macOS security boundaries

Respect macOS TCC, Full Disk Access, SIP, sandbox, and filesystem permission boundaries.

Never attempt to bypass system privacy controls.

When access is denied, report the location as restricted or otherwise incomplete rather than fabricating a result.

Full Disk Access must remain a user-controlled macOS permission.

Do not introduce privileged helpers, authorization services, private entitlements, or security-boundary bypasses merely to make scanning appear more complete.

Changes to:

- `DiskUsage.entitlements`;
- App Sandbox configuration;
- Hardened Runtime;
- code signing;
- Full Disk Access behavior;
- filesystem capabilities

are security and release changes, not routine refactoring.

Review them explicitly.

## Settings and persistence

`AppSettings` owns persisted application preferences.

Preserve existing `UserDefaults` keys and enum raw values unless an intentional migration is provided.

Do not reset existing settings during ordinary refactoring.

A setting exposed in the UI must affect actual application behavior.

Do not retain non-functional or misleading settings.

Changes to language handling must preserve predictable startup and restart behavior.

## UI architecture

SwiftUI views are presentation code.

Keep filesystem traversal and destructive filesystem mutation out of view implementations.

Prefer one authoritative action path for each operation so that tree and sunburst views behave identically.

Shared actions such as reveal, copy path, and move to Trash should not diverge between representations.

Tree and sunburst views must render the same authoritative `FolderUsage` data.

Changing representation must not change scan semantics or filesystem behavior.

Do not let visualization-specific state become authoritative application state.

## Sunburst and tree correctness

Sorting and visualization may reorder or filter presentation, but they must not modify the authoritative scan model.

Displayed sizes and percentages must derive from the same underlying `FolderUsage` values.

Sunburst geometry must remain derived presentation state.

Navigation into a sunburst node must not mutate the scan tree.

Deleting an item must update all representations consistently.

Do not hide significant scan errors merely because one visualization has no natural place to display them.

## Localization

User-visible application text must use the string catalog unless a value is intentionally language-independent.

Maintain English and Russian localization together.

Do not introduce a new visible English-only or Russian-only string into an otherwise localized UI.

Keep localization keys stable when possible.

Changing localization infrastructure must not erase or silently invalidate existing translations.

## Dependencies

DiskUsage currently relies on Apple system frameworks and does not require third-party runtime dependencies.

Keep it dependency-light.

Add a third-party package only for a concrete current requirement that cannot be implemented more simply and safely with Foundation, SwiftUI, AppKit, or other appropriate Apple frameworks.

Do not add dependencies merely for trivial helpers, formatting, collections, or architectural patterns.

Any dependency addition must consider:

- binary size;
- maintenance;
- security;
- privacy;
- licensing;
- minimum macOS version;
- Swift/Xcode compatibility.

## Project and release configuration

Treat the application bundle identifier as a release identity.

Do not change `PRODUCT_BUNDLE_IDENTIFIER`, signing identity, entitlements, versioning, minimum macOS support, or distribution configuration as incidental cleanup.

The Xcode project, English README, and Russian README must agree on supported macOS and Xcode requirements.

Do not silently raise the deployment target.

Do not commit local Xcode user state such as `xcuserdata`.

Do not add unrelated files to the application Resources build phase.

Keep generated build products, derived data, local signing artifacts, credentials, and developer-specific configuration out of the repository.

Preserve the repository license unless an explicit licensing change is requested.

## Verification

For changes that affect buildable source or Xcode configuration, run an applicable macOS build before completion.

A baseline non-signing verification command is:

```text
xcodebuild \
  -project DiskUsage.xcodeproj \
  -scheme DiskUsage \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Release-sensitive changes should also verify the Release configuration where the available environment supports it.

Never claim a build or test passed unless it actually ran successfully.

If verification cannot run because the available environment is not macOS, does not have a compatible Xcode version, or lacks another required capability, state that explicitly.

## Regression coverage

When practical, pure filesystem and model behavior should be covered independently of SwiftUI.

High-value regression areas include:

- hierarchical size accumulation;
- `FolderUsage.removing`;
- deterministic sorting;
- cancellation;
- stale-scan suppression;
- hidden-file behavior;
- package behavior;
- symbolic-link behavior;
- inaccessible paths;
- empty directories and zero-size files;
- very deep trees;
- Unicode file names;
- safe Trash behavior using temporary fixtures.

A bug fix in scanner, model, file-operation, or settings behavior should add the smallest practical regression test that proves the corrected behavior.

Do not use a user's real home directory or root filesystem as an automated test fixture.

## Change discipline

Prefer the smallest correct change.

Do not introduce additional architecture layers merely because they are common in larger Swift applications.

Keep filesystem logic, application state, and presentation separated where that separation has concrete value.

Avoid speculative protocols, repositories, service locators, coordinators, dependency containers, and other abstractions without a current requirement.

Remove duplication when there is one genuine shared responsibility, but do not create an abstraction merely to satisfy DRY.

Do not mix unrelated feature work with cleanup or behavior-preserving refactoring.

## Comments and documentation

Keep source-code comments minimal, necessary, current, and English-only.

Remove stale, redundant, narrative, and commented-out historical code.

Comments should explain only non-obvious:

- filesystem behavior;
- concurrency constraints;
- safety requirements;
- platform limitations;
- compatibility reasons;
- invariants.

Prefer clear Swift code over explanatory comments.

When behavior, permissions, minimum system requirements, settings, or user-visible capabilities change, update both `README.md` and `README.ru.md` where applicable.

## Repository-wide audit and deep refactoring

For a full repository audit, cleanup, optimization, simplification, or deep-refactoring task, read and follow `docs/agent/AUDIT_REFACTOR.md` in full before editing.

The DiskUsage-specific correctness, privacy, filesystem-safety, and macOS-security rules in this file remain mandatory throughout that process and take precedence over generic simplification goals.
