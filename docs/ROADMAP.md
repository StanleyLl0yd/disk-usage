# DiskUsage Product Roadmap

This roadmap is the authoritative product-development sequence for DiskUsage after the repository-wide audit/refactor and security-hardening baseline.

It exists to keep future work focused, measurable, and consistent with the product identity instead of accumulating unrelated features or speculative architecture.

## Product direction

DiskUsage should feel like a polished, premium native macOS utility: calm, fast, obvious, and pleasant to use even during large scans.

The visual target is not to clone another disk analyzer. DaisyDisk may be used only as a reference for qualities such as focus, visual clarity, animation discipline, and overall polish. DiskUsage must keep its own visual identity, interaction model, composition, geometry, palette, typography, and details.

The intended DiskUsage identity is:

- minimal and calm;
- strongly native to macOS;
- light, airy, and visually quiet;
- based primarily on light-gray and warm-neutral surfaces, with restrained accent color;
- clear enough that important disk-usage information is immediately understandable;
- polished down to spacing, hover, focus, selection, empty, loading, error, and disabled states;
- useful without decorative complexity.

The working shorthand for this direction is **Zen UI**.

## Product principles

These principles apply throughout every roadmap stage.

1. Correct filesystem results and safe Trash behavior remain more important than appearance.
2. A polished interface must also be responsive; visual work that creates main-thread stalls is incomplete.
3. Prefer one obvious primary action over many equal-weight controls.
4. Use color as information and focus, not decoration.
5. Keep hierarchy visible through spacing, typography, contrast, and motion before adding borders or chrome.
6. Preserve the local-only, privacy-first product model.
7. Keep tree and sunburst views as representations of the same authoritative scan data.
8. Add product features only when they improve the disk-analysis workflow directly.
9. Do not add complexity to imitate competitors or satisfy a generic architecture pattern.
10. Measure performance work before and after when the claimed benefit is performance-related.

## Roadmap execution contract

Future feature, UX, visualization, and performance development must follow this roadmap.

- Read this file before starting product work.
- Work on the current roadmap stage unless the project owner explicitly changes priority.
- Do not begin a later stage while an earlier stage has unmet exit criteria, except for an explicit owner-approved exception.
- Keep pull requests narrowly aligned with one roadmap stage and preferably one coherent slice within that stage.
- Each product PR should identify its roadmap stage in the PR description.
- A feature outside the current roadmap must first be explicitly approved and either added here or documented as an intentional exception.
- Do not mark a stage complete until its exit criteria are satisfied by merged code and applicable verification.
- Do not silently rewrite completed roadmap goals to match an implementation after the fact.
- Changes to this roadmap should be deliberate product decisions, not incidental refactoring edits.
- Security, correctness, and release rules in `AGENTS.md` remain authoritative even when they constrain roadmap work.

## Baseline already completed

Before this roadmap begins, DiskUsage already has:

- a native SwiftUI/AppKit macOS application;
- home, root, and user-selected folder scans;
- allocated-size filesystem semantics;
- hierarchical `FolderUsage` results;
- tree and sunburst representations;
- scan cancellation and stale-result suppression;
- restricted-location reporting;
- reveal in Finder, copy path, and move-to-Trash actions;
- English and Russian localization;
- regression tests for core model/scanner behavior;
- repository-wide audit/refactor cleanup;
- hardened CI, CodeQL, secret scanning, dependency review, and protected `main`;
- Swift 6 language mode;
- Xcode 26.6 stable as the canonical CI/toolchain baseline;
- minimum supported macOS 14.0;
- pre-release version `0.1.0` (build `1`), with an owner-approved unsigned alpha binary distribution exception after R5.3 and `1.0.0` reserved for R7 release readiness.

The platform baseline was an explicit project-owner-approved priority before R1.2. It should be preserved rather than rebuilt.

## macOS support policy

The minimum deployment target is a product decision, not a promise to support an old macOS release indefinitely.

- Keep the oldest supported macOS version while supporting it remains low-cost and does not materially constrain product quality, UX, performance, accessibility, security, or use of appropriate current SwiftUI/AppKit APIs.
- The default trigger to raise the minimum deployment target is the combination of both conditions: the affected macOS version is estimated to represent roughly **less than 5% of the relevant active Mac installed base**, and retaining support has developed a **meaningful compatibility cost**.
- Meaningful compatibility cost includes API workarounds, duplicate implementation or UI paths, disproportionate testing/CI burden, degraded performance or accessibility, or blocking a materially better current-platform implementation.
- Falling below roughly 5% by itself is not an automatic reason to drop support while compatibility remains effectively free.
- Conversely, a significant compatibility burden should trigger an explicit support review even before the 5% threshold is reached; any exception to the default rule requires a deliberate project-owner decision.
- Installed-base estimates must use the best reasonably reliable current evidence available at the time; do not present third-party estimates as exact Apple figures when Apple does not publish equivalent version-level data.
- Any deployment-target change must be explicit, reviewed, verified by CI, and synchronized across the Xcode project, README requirements, roadmap, and repository platform invariants.

For the current baseline, macOS 14.0 Sonoma remains supported because the project builds and tests cleanly without compatibility workarounds. It should not block adoption of materially better platform APIs later merely to preserve support for a small legacy share.

---

# R1 — Scale, responsiveness, and truthful scan summary

**Status: COMPLETE**

R1 removes known presentation-path performance risks and makes completed scan information accurate before the major visual redesign begins.

## Scope

### R1.1 Tree presentation preprocessing — COMPLETE

- Stop performing expensive recursive whole-tree sorting repeatedly on the main/UI path.
- Compute presentation ordering once per relevant input/sort change, off the UI path when the work is meaningfully expensive.
- Preserve the authoritative `FolderUsage` model and existing sort semantics.
- Avoid creating a second filesystem truth or mutable presentation copy that can diverge from the scan result.

### R1.2 Sunburst presentation preprocessing — COMPLETE

- Stop rebuilding and recursively sorting the entire sunburst segment graph on every avoidable SwiftUI body evaluation.
- Introduce a derived, non-authoritative presentation model or cache only where it has measurable value.
- Keep geometry deterministic for a given scan result and navigation state.
- Keep visualization work outside filesystem authority.

### R1.3 Accurate completed-scan summary — COMPLETE

A completed scan should retain and present meaningful summary data instead of conflating top-level item count with scanned file count.

At minimum retain or derive:

- scanned allocated size;
- files scanned;
- useful item/folder count where it can be computed without disproportionate cost;
- restricted-location count;
- elapsed scan time.

Wording must make clear what each number represents.

### R1.4 Performance evidence — COMPLETE

- Add the smallest practical measurements or repeatable test fixture needed to detect obvious regressions in expensive presentation transformations.
- Prefer synthetic/temp data over real user filesystem data.
- Do not introduce a heavyweight benchmark framework unless existing tools are insufficient.

## R1 exit criteria

R1 is complete when:

- recursive tree sorting is no longer an avoidable repeated main-thread cost;
- sunburst segment preparation is no longer an avoidable repeated full-tree UI cost;
- completed scan statistics report real scan counts rather than only top-level children;
- cancellation, Trash, sorting, tree/sunburst consistency, and localization remain correct;
- Debug tests and Release build pass in CI;
- the PR records before/after evidence for any claimed performance improvement.

R1 completion evidence is preserved in the merged R1.1–R1.4 changes and in [`docs/PERFORMANCE.md`](PERFORMANCE.md), which defines the repeatable synthetic Tree and Sunburst measurement workloads and profiling procedure.

---

# R2 — Zen design system and application shell

**Status: COMPLETE**

R2 establishes the visual system before individual views are heavily polished. The goal is consistency, not a large theme abstraction.

## Scope

### R2.1 Visual tokens

Define a small native design vocabulary for repeated values such as:

- primary and secondary backgrounds;
- subtle elevated/surface backgrounds;
- primary, secondary, muted, warning, and destructive text roles;
- restrained accent usage;
- soft separators;
- corner-radius scale;
- spacing scale;
- typography roles;
- numeric presentation where monospaced digits improve scan readability.

Prefer semantic SwiftUI/AppKit system colors where they provide correct macOS behavior. Do not hard-code an unnecessarily large custom palette.

### R2.2 Zen palette

The default light appearance should center on:

- light-gray and warm-neutral surfaces;
- dark graphite text rather than pure black where appropriate;
- very low visual noise;
- restrained accent colors reserved for selection, state, and data differentiation.

Dark Mode must remain coherent if supported by the current system appearance. Do not create a light-only design that becomes unreadable in Dark Mode.

### R2.3 Main window composition

Refine the application shell so that it has a clear visual hierarchy:

- a calm compact header/toolbar area;
- one visually dominant content region;
- secondary scan/status information that does not compete with the data;
- consistent placement of primary scan actions;
- reduced button/chrome density.

### R2.4 State polish

Design all common states intentionally:

- first launch / no scan;
- scanning;
- completed scan;
- cancelled scan;
- restricted/incomplete scan;
- errors;
- disabled controls;
- hover, focus, keyboard focus, and selection.

## R2 non-goals

- Do not copy DaisyDisk's exact layout, radial styling, palette, spacing, animations, iconography, or interaction patterns.
- Do not add ornamental effects solely to look premium.
- Do not introduce a generalized theming framework unless the concrete UI requires it.

## R2 exit criteria

R2 is complete when the application has one coherent visual language across its shell, controls, states, typography, spacing, and surfaces, with EN/RU strings and macOS accessibility behavior preserved.

---

# R3 — Unified selection, navigation, and polished Tree view

**Status: COMPLETE**

R3 turns the tree from a functional hierarchy into a first-class analysis workspace.

## Scope

### R3.1 Unified selection model

- Add one non-filesystem-authoritative selected-item state shared by tree and sunburst where practical.
- Selection must never change filesystem identity or scan semantics.
- Deleting a selected item must clear or move selection predictably.

### R3.2 Item detail presentation

Provide a compact, calm selected-item detail surface showing useful information such as:

- name;
- full path;
- allocated size;
- percent of the relevant scan scope;
- available actions.

Do not turn this into a large inspector full of low-value metadata.

### R3.3 Tree polish

- Refine row spacing and density.
- Make hierarchy and file/folder distinction obvious without visual clutter.
- Refine size bars and percentages.
- Improve truncation behavior for long names and paths.
- Ensure hover, selected, focused, and expanded states are visually deliberate.
- Preserve good performance for deep and large trees.

### R3.4 Keyboard and action consistency

Where macOS conventions make sense, support predictable keyboard/focus behavior for selection and safe actions.

Context-menu and visible actions must call the same authoritative operations.

## R3 exit criteria

R3 is complete when tree navigation and selection feel intentional, keyboard/mouse behavior is predictable, actions are discoverable, and large result sets remain responsive.

---

# R4 — Sunburst 2.0: DiskUsage visual identity

**Status: COMPLETE**

R4 creates the main visual signature of DiskUsage while staying clearly distinct from existing disk analyzers.

## Scope

### R4.1 Derived segment model — COMPLETE

Build the sunburst from precomputed derived presentation data established by R1 rather than expensive ad-hoc view recomputation.

### R4.2 Visual language — COMPLETE

The sunburst should use:

- restrained, harmonious data colors;
- neutral surrounding UI;
- clear selection and hover emphasis;
- sufficient contrast without a saturated rainbow appearance;
- consistent depth cues;
- smooth but subtle transitions.

### R4.3 Interaction — COMPLETE

- hover feedback;
- selected-segment state;
- useful compact tooltip/detail feedback;
- predictable drill-down;
- polished Back/root/breadcrumb navigation;
- context actions consistent with Tree view.

### R4.4 Small-segment handling — COMPLETE

Replace unexplained visual gaps caused by tiny omitted arcs with a deliberate policy such as bounded aggregation into an `Other` representation when appropriate.

The aggregation is presentation-only and must never change authoritative scan totals.

### R4.5 Motion — COMPLETE

Use short native-feeling animations for navigation and state changes.

Respect reduced-motion accessibility settings where applicable. Animation must never delay a destructive action or obscure state correctness.

## R4 exit criteria

R4 is complete when the sunburst is visually distinctive to DiskUsage, understandable without instruction, responsive on large results, and synchronized with the same selection/actions as Tree view.

---

# R5 — Core productivity workflow

**Status: COMPLETE**

R5 adds the high-value capabilities that make repeated real-world disk analysis efficient.

## Scope

### R5.1 Rescan current target — COMPLETE

- Retain the current scan target explicitly.
- Add a clear Rescan action.
- Preserve one-authoritative-scan and stale-result guarantees.

### R5.2 Drag and drop — COMPLETE

Allow a directory dragged from Finder onto an appropriate application target to become the scan target.

Reject unsupported drag content clearly and safely.

### R5.3 Full Disk Access UX — COMPLETE

When restricted paths indicate incomplete analysis:

- explain the condition concisely;
- provide an appropriate route to the macOS Full Disk Access settings when possible;
- never imply that DiskUsage can grant permission itself;
- make the return-and-rescan workflow obvious.

### R5.4 Search and filtering — COMPLETE

Add fast local search of completed scan results by useful properties such as file/folder name or path.

Search must not rescan the filesystem and must remain a derived view of the authoritative snapshot.

### R5.5 Largest Files — COMPLETE

Add a focused way to find the largest files in the completed scan scope.

Requirements:

- results derive from the current authoritative scan;
- ordering is deterministic;
- actions use the same reveal/copy/Trash paths as Tree and Sunburst;
- the feature remains bounded and responsive for very large scans.

## R5 exit criteria

R5 is complete when a user can scan, inspect, search, identify large files, act on them safely, and rescan without unnecessary repeated setup.

R5 completion was verified by the separate repository-wide exit review tracked in #82 and master issue #69. The final closure commit `104c2a55146055299def52f2888cfec2144182cf` passed Debug/Release, Actions Policy, Gitleaks, SonarCloud Quality Gate, CodeQL Actions, and CodeQL Swift. Repository ruleset `Protect release tags` is active for `refs/tags/v*`, prohibits tag update/deletion without bypass actors, permits creation of future release tags, and the published `v0.1.0-alpha.1` remains bound to exact source commit `23355eeed05f777022a2f2aed19ccf90d6e55a27`.

## Owner-approved prerelease distribution exception

After R5.3, the project owner explicitly approved an unsigned `v0.1.0-alpha.1` binary prerelease before R5.4.

- This slice is release engineering only and must not add R5.4/R5.5 product functionality.
- Artifacts must be built from an exact verified `main` commit and bound to the immutable prerelease tag.
- The alpha is intentionally unsigned and not notarized; no Developer ID, signing, or notarization secrets are introduced.
- The release publishes a universal app archive, DMG, and SHA-256 checksums with explicit Gatekeeper guidance.
- The prerelease was successfully published and verified from exact `main` commit `23355eeed05f777022a2f2aed19ccf90d6e55a27`; execution returned to R5.4 Search and filtering.

This exception did not itself mark R5 complete and does not complete the R7 release-quality stage.

---

# R6 — Large-scale resilience and measured optimization

**Status: IN PROGRESS**

R6 is evidence-driven. It must not become speculative performance engineering.
## Scope

### R6.1 Large-scale scan measurement baseline — COMPLETE

Establish repeatable end-to-end scanner evidence before changing runtime behavior:

- use a deterministic disposable filesystem fixture whose creation is outside the measured block;
- record scanner wall-clock evidence with the existing XCTest measurement approach without a brittle CI threshold;
- verify the fixture's file/folder counts and allocated-byte semantics separately from timing;
- document Time Profiler, Allocations, Hangs/responsiveness, and repeated scan/cancel/rescan investigation procedures;
- do not introduce a runtime optimization in this slice.

R6.1 merged through #88 and closed through #87. The exact completion main was `abcac2b18c698f9e997ec3ac485dd413fe3a8409`; the slice added the disposable 4,096-file / 72-directory scanner baseline without changing production runtime behavior.

### R6.2 Scanner CPU hotspot attribution — COMPLETE

Use the R6.1 workload to identify actual scanner CPU costs before choosing an optimization:

- build the test bundle outside the profiling interval;
- use Time Profiler against only the synthetic scanner workload;
- repeat captures rather than selecting one favorable sample;
- keep raw traces ephemeral and publish only aggregate/symbol evidence;
- distinguish overlapping inclusive call-stack presence from mutually exclusive attribution;
- do not change production runtime behavior in the measurement slice.

Three independent final Time Profiler captures produced 9,187 symbolized scanner stacks. Nearest-labeled-phase attribution was stable: path processing 31.71%, `Node.addFile` 24.03%, resource-value reads 16.04%, `Node.toFolderUsage` conversion 14.54%, enumeration 3.59%, and unclassified scanner work 10.08%. These values are sampled stack attribution, not machine-independent wall-clock percentages. Full methodology and evidence are recorded in [`docs/PERFORMANCE.md`](PERFORMANCE.md) and tracked in #89.

The measured first optimization target is repeated path normalization/path derivation. Tree construction remains the second-largest labeled phase, but R6 must test the narrower path opportunity before considering a broader internal-tree redesign.

### R6.3 Reduce redundant scanner path normalization — COMPLETE

R6.3 kept the first R6.2 optimization deliberately narrow:

- focused lexical-normalization and directory-symlink regression coverage was proven against the unchanged R6.2 baseline before changing scanner path handling;
- the scanner now standardizes each regular-file URL once for path derivation and reuses that standardized URL for both parent and file paths;
- no symlink resolution, package, hidden-file, allocation, cancellation, progress, or authoritative-snapshot semantics changed;
- same-runner Time Profiler A/B reduced the targeted path-processing bucket from 33.27% to 27.55% pooled across three captures per variant, a -5.72 percentage-point change in sampled nearest-labeled-phase attribution;
- separate six-pair whole-test invocation timing was directionally consistent (candidate faster in 5/6 pairs; runner-local aggregate mean -3.70%) and showed no end-to-end regression signal;
- raw profiling/timing data and the temporary research workflows were not retained in the final product diff.

These percentages are measurement evidence for this workload, not machine-independent wall-clock CPU shares or a promise of an exact product speedup. Full methodology is recorded in [`docs/PERFORMANCE.md`](PERFORMANCE.md).

### R6.4 Establish scanner allocation and retention evidence — COMPLETE

R6.4 remains measurement-only and does not change production scanner behavior.

- disposable 4,096-, 16,384-, and 32,768-file workloads were exercised with repeated complete scan/cancel/rescan lifecycles;
- the largest tested workload was 32,768 regular files;
- runner-local `phys_footprint` sampling distinguished the process high-water/plateau from transient allocation churn as far as the available tooling permits;
- after the initial high-water, repeated complete scans and the 32,768-file cancel/rescan sequence showed only small additional footprint movement and no evidence of unbounded growth;
- a research-only Allocations `xctrace --attach` capture confirmed substantial temporary URL/path/string/resource-value allocation churn while raw trace/XML data remained ephemeral and outside the final branch;
- the observed retained process footprint is bounded for the tested lifecycle, so no memory-driven `Node.addFile` redesign, cache/index, incremental-result architecture, or alternative tree construction is justified by R6.4 evidence.

Full methodology, runner-local measurements, limitations, and allocation evidence are recorded in [`docs/PERFORMANCE.md`](PERFORMANCE.md). Final documentation PR #95 merged as exact `main` `8cf883d28f1c4feb6d701ac345e22417c169b49e`; its merged tree is content-equivalent to fully green PR head `26ce54a0e4b5d18f8d2454cbc80752ffdb562693`, with successful macOS CI, Actions Policy, Gitleaks, Dependency Review, CodeQL Swift, and CodeQL Actions gates and no review threads. R6.4 is therefore complete. The next R6 slice must be selected from current measured evidence; absent a memory-retention problem, the safest next step is measurement-only post-R6.3 CPU re-attribution before proposing another runtime optimization.


### R6.5 Re-attribute scanner CPU after R6.3 — MEASUREMENT COMPLETE / PENDING EXIT VERIFICATION

R6.5 re-profiled the unchanged post-R6.3 production scanner before selecting another optimization.

- research draft PR #98 was measurement-only and was closed without merge;
- two successful three-capture Time Profiler run sets agreed that `Node.addFile` is now the largest labeled scanner bucket after R6.3, with path processing second;
- the final diagnostic set pooled 8,527 scanner stacks: `Node.addFile` 27.20%, path processing 25.03%, resource-value reads 16.86%, `Node.toFolderUsage` 16.04%, enumeration 4.48%, and unclassified scanner work 10.39%;
- representative nearest-`Node.addFile` frames point to dictionary lookup/set, path-component splitting/substring handling, and string hashing/comparison/Unicode normalization;
- these are sampled nearest-labeled stack shares, not machine-independent wall-clock CPU percentages;
- no production runtime behavior changed, and raw profiling artifacts/workflow code remain outside the final branch.

The measured next candidate is a **narrow `Node.addFile` component-parsing/dictionary-lookup experiment** with correctness coverage and same-runner before/after evidence. This result does not justify a broader internal-tree redesign, cache/index, incremental-result architecture, or memory-driven optimization. Mark R6.5 COMPLETE only after the final documentation PR and merged exact-main applicable gates succeed.

Then continue profiling representative large synthetic or disposable filesystem trees and identify actual bottlenecks in:

- enumeration;
- resource-value reads;
- Node construction;
- `FolderUsage` conversion;
- memory retention;
- result publication;
- tree expansion/navigation;
- sunburst preparation/rendering;
- search/largest-file indexing introduced by R5;
- repeated scan/cancel/rescan cycles.

Possible optimizations such as incremental result presentation, bounded indexes, alternative internal tree construction, or progressive visualization may be introduced only when measurements justify them and correctness semantics remain explicit.

## R6 exit criteria

R6 is complete when the largest practical tested workloads have documented behavior, known hotspots have either been fixed or explicitly accepted, and no optimization compromises correctness, cancellation, safety, or privacy.

---

# R7 — Release-quality product polish

**Status: PLANNED / UNSIGNED ALPHA EXCEPTION APPROVED**

R7 remains the full release-quality stage. A narrow owner-approved unsigned alpha distribution exception is active after R5.3; it does not waive R7 polish, signing/notarization decisions, or R7 exit criteria.

## Scope before binary release

- final visual consistency pass;
- accessibility review;
- keyboard navigation review;
- EN/RU localization review;
- empty/error/restricted-state review;
- high-DPI and window-resize behavior;
- product copy and README alignment;
- regression pass across Home, root, selected-folder, cancellation, restricted paths, Trash, Tree, Sunburst, Search, Largest Files, and Rescan.

## Scope after explicit binary-release decision

Release-integrity work required by `AGENTS.md` must remain appropriate to the chosen distribution path. Immutable release tags and artifact verification apply to the unsigned alpha. Developer ID signing, notarization, signing credentials, and related verification remain deferred until those capabilities are explicitly available and approved.

## R7 exit criteria

R7 is complete when the application is not only functionally complete but consistently polished, accessible, localized, verified, and ready for the chosen distribution path.

---

# Deferred ideas

The following are intentionally outside the active roadmap unless separately approved:

- duplicate-file deletion;
- automatic cleanup recommendations that perform changes without explicit user selection;
- permanent deletion;
- privileged helpers;
- cloud or remote disk analysis;
- telemetry or accounts;
- background monitoring of filesystem usage;
- generic system-cleaner or optimizer functionality.

These are not assumed future stages.

# Current execution point

**R1 — Scale, responsiveness, and truthful scan summary is complete.** All R1 slices are implemented and verified, including repeatable synthetic performance evidence.

**R2 — Zen design system and application shell is complete.** All R2 slices are implemented and verified, and the final master exit review found no remaining visual-system gap.

**R3 — Unified selection, navigation, and polished Tree view is complete.** All R3 slices are implemented and verified, including unified selection, compact item details, polished Tree presentation, native keyboard/focus behavior, and shared authoritative actions.

**R4 — Sunburst 2.0: DiskUsage visual identity is complete.** All five R4 slices are implemented and verified, and the separate master exit review found no remaining visual, interaction, responsiveness, synchronization, accessibility, safety, or verification gap.

**R5 — Core productivity workflow is complete.** R5.1–R5.5 are implemented and verified, the full repository-wide exit review passed, final exact-main verification is green, and release-tag immutability is enforced for `v*` while the published `v0.1.0-alpha.1` remains bound to its verified source commit.

**R6 — Large-scale resilience and measured optimization is in progress.** R6.1–R6.4 are complete. R6.5 post-R6.3 CPU re-attribution is measurement-complete and pending final documentation/exact-main verification: two independent three-capture run sets now place `Node.addFile` first and path processing second, with the refined run pooling 27.20% vs 25.03%. The measured next candidate, after R6.5 exit verification, is a narrow `Node.addFile` component-parsing/dictionary-lookup experiment; no broader tree-architecture or memory-driven redesign is justified.