# DiskUsage Product Roadmap

Status: **active**  
Current milestone: **M1 — Performance and scan-result foundation**

This document is the authoritative default roadmap for product, UI/UX, and performance work in DiskUsage. It is intentionally milestone-based: complete and verify the current milestone before beginning a later milestone unless the project owner explicitly changes priorities.

Repository safety, filesystem correctness, privacy, and security rules in `AGENTS.md` always take precedence over roadmap convenience.

## Product direction

DiskUsage should feel like a polished native macOS utility: calm, immediate, precise, and pleasant to use for long enough that the interface disappears behind the task.

The visual target is **Zen minimalism**:

- light-first, soft neutral surfaces built around light gray and restrained graphite tones;
- generous spacing and strong visual hierarchy without decorative clutter;
- subtle depth, separators, hover states, and transitions rather than heavy borders or cards;
- restrained color reserved for meaning, navigation, selection, warnings, and visualization differentiation;
- native macOS behavior, typography, focus handling, keyboard interaction, and accessibility;
- a small number of obvious primary actions instead of dense toolbars or persistent controls;
- animation only when it helps orientation or continuity.

DaisyDisk is a **quality and clarity reference, not a visual template**. DiskUsage may learn from its immediacy, focus, fluid drill-down, and ability to make storage understandable at a glance. Do not copy its artwork, color palette, layout, interaction details, typography, visual composition, terminology, or other distinctive presentation. DiskUsage must develop a recognizably independent identity.

## Product principles

1. **Correct before clever.** Never trade filesystem correctness or safe Trash behavior for visual polish.
2. **Fast by construction.** Expensive recursive transforms, sorting, and visualization preparation must not repeatedly execute on the main UI path.
3. **One obvious next action.** The screen should make the user's next useful action clear without teaching the interface.
4. **Progressive detail.** Show the important result first; expose paths, metadata, secondary actions, and diagnostics only when useful.
5. **Calm feedback.** Scanning, cancellation, restricted access, errors, selection, and deletion must be clear without modal noise.
6. **Native interaction.** Prefer standard macOS expectations for selection, keyboard shortcuts, drag and drop, Finder integration, context menus, and accessibility.
7. **Local and private.** No account, telemetry, advertising, tracking, upload, cloud requirement, or background network dependency.
8. **Measured optimization.** Optimize known costs first. More invasive memory or scanner architecture changes require profiling evidence.
9. **No automatic cleanup.** DiskUsage explains disk use and lets the user explicitly act; it does not decide what is safe to delete.
10. **Polish includes edge cases.** Empty states, inaccessible folders, tiny visualization segments, long Unicode paths, cancellation, errors, focus, resizing, and reduced motion are part of the product.

## Design system target

The redesign should converge on a small shared design system instead of one-off styling in each view.

### Color

Use semantic colors rather than hard-coded ad-hoc values. The intended character is:

- a very light neutral application background;
- slightly separated secondary surfaces;
- graphite primary text and softer secondary text;
- subtle neutral separators;
- one restrained primary accent;
- muted visualization colors with enough distinction for navigation;
- standard semantic warning/destructive meaning where macOS conventions matter.

Do not make the application monochrome at the expense of information. Visualization color should remain useful, but saturation should be controlled and the overall composition should stay calm.

### Spacing and shape

Use a consistent spacing rhythm based primarily on 4, 8, 12, 16, 24, and 32 pt. Prefer a small, consistent set of corner radii. Avoid nested rounded rectangles and excessive card layouts.

### Typography

Use system typography. Establish a clear hierarchy for:

- primary title/context;
- selected item or current scan target;
- body labels;
- secondary path/metadata;
- captions and status;
- monospaced digits for sizes, percentages, counts, and timing where alignment helps.

### Interaction states

Every interactive element that benefits from it should have coherent states for hover, pressed, selected, focused, disabled, loading, warning, and destructive action. Keyboard focus must not be treated as an afterthought.

## Milestone policy

- Work the milestones in order by default.
- A later milestone may be researched, but implementation should not begin before the current milestone exit criteria are met unless the project owner explicitly authorizes the exception.
- Bug fixes, security fixes, CI maintenance, dependency maintenance, and small correctness work may interrupt the sequence when necessary.
- Do not bundle unrelated roadmap milestones into one PR.
- Prefer narrowly reviewable slices inside a milestone.
- Update this document when a milestone is completed, materially re-scoped, reordered, or intentionally skipped.
- New significant product features that are not in this roadmap should be added here before implementation unless the project owner explicitly requests immediate implementation.
- Every UI-facing roadmap PR should include screenshots or another concrete visual verification when practical.
- Every performance claim should be supported by a reproducible measurement, profiling evidence, or a direct structural removal of known repeated work.

---

# M1 — Performance and scan-result foundation

**Goal:** make the existing product state trustworthy and cheap to render before the visual redesign builds on top of it.

## Scope

### M1.1 Correct scan summary

Preserve final scan metrics instead of discarding them with transient progress state. After a completed scan, present meaningful summary data such as:

- measured size;
- files scanned;
- useful item/folder count when the definition is unambiguous;
- elapsed scan time;
- restricted/inaccessible count when non-zero.

Do not label top-level `items.count` as the number of scanned items.

### M1.2 Off-main tree presentation preparation

Remove avoidable recursive sorting/transformation from SwiftUI state-update paths. The authoritative `FolderUsage` scan model must remain unchanged; derived presentation ordering may be prepared once per relevant input/sort change and published safely.

### M1.3 Sunburst geometry preparation

Stop rebuilding the full recursive segment set as incidental SwiftUI body work. Derive visualization geometry when the authoritative input/current navigation changes and reuse it until invalidated.

### M1.4 Performance regression fixtures

Add practical synthetic model coverage for deep and broad trees where it helps prove deterministic behavior and prevent accidental whole-tree work from returning to hot UI paths.

## Exit criteria

- final scan status reports real scan counts rather than top-level child count;
- no repeated whole-tree recursive sort caused merely by normal SwiftUI body recomputation;
- no repeated full sunburst geometry build caused merely by normal SwiftUI body recomputation;
- scanning/cancellation/stale-result behavior remains correct;
- existing filesystem and Trash regression tests remain green;
- Debug tests and Release build pass in CI;
- applicable security gates pass.

---

# M2 — Zen visual foundation

**Goal:** establish DiskUsage's own polished visual identity and simplify the application shell before adding more product surface.

## Scope

### M2.1 Semantic design tokens

Create the smallest useful shared representation for:

- surfaces/backgrounds;
- primary/secondary text;
- separators;
- accent and selection;
- visualization palette rules;
- spacing;
- corner radii;
- common animation timing where warranted.

Do not create a large design-framework abstraction. Use native SwiftUI/AppKit semantics where they already solve the problem.

### M2.2 Main window composition

Rework the main window around one dominant content area. The scan target, view switcher, essential scan actions, and status should be immediately understandable without competing for attention.

Desired character:

- more breathing room;
- less control density;
- fewer visible borders;
- stronger hierarchy;
- quiet light-gray surfaces;
- graceful window resizing;
- no dashboard-like collection of unrelated cards.

### M2.3 States as first-class UI

Polish:

- first-launch/empty state;
- scanning state;
- cancelling/cancelled state;
- completed summary;
- restricted-access state;
- error state;
- no-results state.

The restricted-access experience should explain what is missing without making the scan appear failed.

### M2.4 Toolbar and command hierarchy

Clarify primary actions: scan Home, scan disk, choose folder, rescan current target, cancel. Secondary actions should not crowd the main hierarchy.

## Exit criteria

- the application has a coherent reusable visual language rather than per-view ad-hoc styling;
- the main screen remains understandable at supported minimum window size and when enlarged;
- scanning and error states do not cause distracting layout jumps;
- EN/RU remain complete;
- keyboard focus and standard macOS affordances remain visible;
- the result looks recognizably like DiskUsage, not a DaisyDisk clone.

---

# M3 — Unified selection and visualization experience

**Goal:** turn the visualization into the visual centerpiece while making Tree and Map feel like two views of the same selected filesystem snapshot.

## Scope

### M3.1 Shared selection model

Introduce one non-filesystem-authoritative selection state shared by Tree and visualization. Changing representation should preserve the selected item when that item still exists.

Selection should support:

- clear visual highlight;
- keyboard focus where appropriate;
- selected-item details;
- consistent reveal/copy/Trash actions.

### M3.2 Radial Map redesign

Evolve the existing sunburst into a distinct DiskUsage radial map with restrained color and strong spatial clarity.

Required UX:

- hover feedback;
- selection feedback;
- smooth orientation-preserving drill-down;
- back/root navigation;
- compact contextual details;
- predictable behavior during window resizing;
- no visual implication that unrendered tiny segments represent free or missing disk space.

Consider using **Map** or another user-facing term if usability testing shows `Sunburst` is implementation jargon rather than useful product language.

### M3.3 Tiny-segment aggregation

Small segments that cannot be meaningfully rendered should be aggregated into a truthful `Other`/remainder representation or handled by another deterministic presentation strategy. Do not silently create misleading gaps.

### M3.4 Tree polish

Improve the tree for scanning large result sets:

- readable hierarchy;
- restrained path metadata;
- aligned sizes and percentages;
- subtle size visualization;
- clear selection/hover states;
- comfortable density;
- consistent context actions.

### M3.5 Selected-item detail surface

Provide a compact details surface only when useful. Candidate information:

- item name;
- path;
- measured allocated size;
- percentage of current/root context;
- file/folder distinction;
- Finder/copy/Trash actions.

Avoid turning this into a permanent inspector full of low-value metadata.

## Exit criteria

- Tree and radial Map operate on the same selection/action model;
- navigation and selection remain responsive on realistically large scan models;
- the visualization has no misleading unexplained angular gaps;
- destructive action behavior is identical from every representation;
- reduced-motion/accessibility behavior is considered for animations.

---

# M4 — Core productivity UX

**Goal:** add the highest-value workflows that help a user find and act on storage problems without becoming a generic cleaner.

## Scope

### M4.1 Rescan

Remember the current scan target for the active session and provide an obvious rescan action. Rescan must preserve existing concurrency, cancellation, and stale-result guarantees.

### M4.2 Largest files

Provide a bounded, useful way to inspect the largest files in the completed scan regardless of nesting depth.

Requirements:

- derived from the same authoritative scan snapshot;
- deterministic ordering;
- no second filesystem crawl;
- bounded presentation rather than an unnecessary duplicate full index unless measurement justifies one;
- reveal/copy/Trash use the same authoritative action path.

### M4.3 Search and filter

Search completed scan results by filename/path without rescanning the filesystem. Keep memory cost explicit and avoid maintaining redundant unbounded indexes unless profiling justifies them.

### M4.4 Drag and drop

Accept a directory dropped from Finder as a scan target when the platform APIs make the behavior predictable and safe.

### M4.5 Restricted-access workflow

When restricted paths exist, provide a clear route to the appropriate macOS Privacy & Security settings where technically supported, explain that Full Disk Access remains user-controlled, and make rescan easy after the user returns.

### M4.6 Keyboard productivity

Add sensible native shortcuts for common actions where they do not conflict with standard macOS conventions. Candidate actions include choose folder, rescan, cancel, reveal, copy path, search, and moving the explicitly selected item to Trash with existing confirmation behavior.

## Exit criteria

- current target can be rescanned without choosing it again;
- largest-file discovery works without a second filesystem traversal;
- search is responsive on realistically large completed scan models;
- drag-and-drop and keyboard interaction feel native rather than bolted on;
- restricted-access recovery is understandable without documentation;
- no feature introduces automatic or permanent deletion.

---

# M5 — Scale, accessibility, and final polish

**Goal:** remove the remaining rough edges revealed by realistic use and make the application feel finished rather than merely feature-complete.

## Scope

### M5.1 Measure real scale

Profile representative large scans for:

- scan throughput;
- cancellation latency;
- peak memory;
- completed-model memory;
- tree interaction latency;
- radial Map preparation/navigation;
- search latency.

Use measurements to decide whether scanner/model architecture needs further work. Do not redesign the scanner solely because a more sophisticated architecture is possible.

### M5.2 Memory optimization when justified

If profiling shows a material problem, reduce avoidable per-entry retained state, duplicate strings/indexes, or intermediate tree memory while preserving path identity and current size semantics.

### M5.3 Accessibility

Audit and improve:

- VoiceOver labels/value descriptions;
- keyboard-only navigation;
- focus order;
- contrast;
- color-independent meaning;
- Reduce Motion;
- text truncation/tooltips for long paths;
- accessibility of the radial visualization and equivalent access to its information through Tree/Search.

### M5.4 Window and layout polish

Exercise minimum/large window sizes, long Russian and English strings, long paths, unusual Unicode names, zero/empty results, and high item counts. Remove clipping, accidental jumps, ambiguous disabled states, and inconsistent spacing.

### M5.5 Interaction polish

Review every recurring action for:

- hover;
- focus;
- click target size;
- keyboard equivalent;
- confirmation behavior;
- success/error feedback;
- animation continuity;
- contextual help only where needed.

## Exit criteria

- no known high-impact UI stall remains in normal large-scan workflows;
- no optimization is justified only by speculation;
- the app is usable with keyboard-only navigation for core workflows;
- visualization meaning does not depend solely on color;
- EN/RU layouts are polished at supported window sizes;
- known UX rough edges are either fixed or explicitly documented with rationale.

---

# M6 — Binary release readiness

**Goal:** prepare distribution only when the project intentionally moves beyond source-only development.

This milestone is **deferred until the project owner explicitly begins binary distribution**.

Potential scope at that time:

- application version/build-number policy;
- Developer ID signing or the selected distribution identity;
- notarization and stapling;
- reproducible release procedure;
- immutable release tags;
- checksums and artifact provenance/attestation where supported;
- download/update UX if distribution model requires it;
- final privacy/security review of packaged artifacts;
- documentation aligned with the real supported distribution channel.

Do not introduce release secrets or release infrastructure before this milestone is intentionally activated.

---

## Explicit non-goals unless the project owner changes direction

The roadmap does not include:

- automatic cleanup recommendations that delete without explicit selection;
- permanent deletion;
- duplicate-file removal engine;
- antivirus/anti-malware features;
- RAM/CPU/system optimizer functionality;
- cloud storage management;
- accounts or synchronization;
- analytics, telemetry, advertising, or tracking;
- privileged helpers solely to bypass macOS privacy boundaries;
- a third-party UI framework for styling convenience.

## Definition of a polished DiskUsage experience

The roadmap is successful when a user can open DiskUsage, understand what to scan without instruction, watch a calm and responsive scan, immediately recognize where disk space went, move between overview and detail without losing context, find unusually large files quickly, recover cleanly from restricted access, and act on an explicitly selected item with confidence.

The final interface should feel deliberate down to spacing, focus, hover, animation, wording, error presentation, long-path handling, and destructive confirmation—while remaining visually quiet and technically simple.