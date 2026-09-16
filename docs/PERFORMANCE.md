# DiskUsage performance verification

This document defines the lightweight, repeatable performance evidence used by the project. It complements correctness tests; it is not a promise of a fixed runtime on every Mac or GitHub-hosted runner.

## Principles

- Use deterministic synthetic `FolderUsage` data or disposable temporary filesystem fixtures, never real user filesystem contents.
- Keep performance measurements in the existing XCTest target and canonical Xcode toolchain.
- Measure derived presentation transformations directly, and measure scanner work only against disposable fixtures whose setup is outside the measured block.
- Keep structural correctness assertions separate from timing thresholds.
- Do not fail CI merely because a shared runner is slower than another runner.
- Add a hard regression threshold only when there is enough stable historical data to justify one.
- Prefer Instruments / `xctrace` for investigation of CPU, allocation, hangs, and call-tree hotspots.

## Synthetic fixtures

### Scanner disposable-filesystem fixture

`DiskScannerTests.testDiskScannerDisposableFilesystemSyntheticPerformance` uses a deterministic temporary filesystem tree created before the measured block:

- 8 top-level directories;
- 8 nested directories under each top-level directory;
- 64 regular 4 KiB files in each nested directory;
- 4,096 files and 72 directories total;
- roughly 16 MiB of file payload before filesystem allocation effects;
- a UUID-named temporary root so no real or machine-specific user path is embedded.

A verification scan runs before timing and asserts the expected file and directory counts, no restricted locations, and non-zero allocated bytes. The measured operation is a fresh end-to-end `DiskScanner.scan(...)` over the already-created fixture, including enumeration, resource-value reads, path handling, internal `Node` construction, and final `FolderUsage` conversion.

The timing harness uses a detached scan task plus a bounded semaphore wait only to bridge the asynchronous scanner into XCTest's existing `XCTClockMetric` measurement API. There is deliberately no fixed wall-clock pass/fail threshold.

This fixture is a CI-safe baseline, not a claim that 4,096 files represent the largest real scan. Larger local disposable trees should be used for Instruments work when needed, while keeping committed CI workloads bounded.

### Tree presentation fixture

`FolderUsageTests.testTreePresentationPreprocessorSyntheticPerformance` uses a deterministic four-level 8-way tree:

- 8 roots;
- 8 children per non-leaf node;
- 4,680 total nodes;
- deterministic paths and sizes;
- the fixture is built before the measured block.

The measured operation is the complete recursive `TreePresentationPreprocessor.sorted(..., by: .sizeDesc)` transformation. A separate structural assertion confirms the resulting presentation still contains all 4,680 nodes.

### Search presentation fixture

`FolderUsageTests.testSearchPresentationPreprocessorSyntheticPerformance` reuses the same 4,680-node tree. The query is the full path of one deepest leaf, so the measured block must traverse the completed snapshot and produce exactly one match without touching the filesystem.

The measured operation is `SearchPresentationPreprocessor.matches(..., sortedBy: .sizeDesc)`, including snapshot traversal and result ordering.

### Largest Files fixture

`FolderUsageTests.testLargestFilesPresentationPreprocessorSyntheticPerformance` uses a dynamically rooted synthetic snapshot containing:

- 12 top-level folders;
- 1,000 file children per folder;
- 12,000 files and 12,012 total nodes;
- deterministic allocated-size values;
- a temporary base path so the fixture does not embed a real or machine-specific user path.

The measured operation is `LargestFilesPresentationPreprocessor.largestFiles(in:)`. The implementation traverses the snapshot once and keeps a bounded top-100 candidate heap; assertions confirm that exactly 100 files are returned in deterministic size-descending/path-ascending order.

### Sunburst presentation fixture

`FolderUsageTests.testSunburstPresentationPreprocessorSyntheticPerformance` uses a shape chosen specifically to exercise the current 1-degree visibility cutoff without making the benchmark accidentally trivial:

- 4 roots;
- 4 children per root;
- 4 groups per child;
- 128 leaf files per group;
- 8,276 total nodes;
- 8,192 leaf entries are sorted and visited at the deepest measured level;
- 84 ordinary visible segments plus 64 bounded aggregate segments are emitted by the current four-level geometry rules.

The many sub-degree leaves are intentionally represented through bounded `Other` aggregates rather than individual arcs. The preprocessor still sorts and evaluates the leaf entries, keeping the fixture representative of the presentation work that R1.2 moved out of SwiftUI `body` evaluation.

## What the measurements protect

Before R1.1, recursive Tree sorting could be triggered from the main/UI presentation path. R1.1 moved that work into cancellable derived preprocessing that runs only when the source snapshot or sort option changes.

Before R1.2, Sunburst segment construction and recursive sorting were invoked from SwiftUI body evaluation. R1.2 moved that work into cancellable derived preprocessing keyed to the relevant snapshot/navigation inputs.

R5.4 added local Search as another derived snapshot transformation, and R5.5 added the bounded Largest Files derivation. Both remain presentation-only and off the filesystem-authority path.

R6.1 adds the first repeatable end-to-end scanner workload. It intentionally measures the current scanner as a whole before any R6 runtime optimization so that later work starts from evidence rather than an assumed hotspot.

The XCTest measurements provide repeatable workloads for scanner and derived presentation work. Their primary purpose is to make future before/after profiling comparable and to expose obvious algorithmic regressions during development without introducing brittle CI wall-clock gates.

## Running the measurements

Run the normal test target in Xcode or from the canonical command used by CI. XCTest reports wall-clock measurements for the scanner, Tree, Search, Largest Files, and Sunburst synthetic performance tests.

When comparing an optimization:

1. use the same Mac, Xcode version, build configuration, and fixture;
2. run the measurement multiple times before and after the change;
3. compare distributions rather than one fastest sample;
4. record the observed before/after result in the pull request;
5. confirm ordinary correctness tests and Release build still pass.

Do not interpret one GitHub-hosted runner result as a stable machine-independent benchmark.

## R6 scanner profiling matrix

The committed scanner XCTest is the repeatable wall-clock baseline. Use Instruments when a change needs attribution to a specific phase or resource cost.

### Time Profiler

Profile a scan of a disposable tree large enough to produce a stable call tree. Inspect actual cost before proposing optimization, especially around:

- `FileManager` enumeration;
- `URL.resourceValues(forKeys:)`;
- path standardization/component processing;
- internal `Node` dictionary construction and size accumulation;
- child sorting and recursive `Node.toFolderUsage()` conversion.

Do not add per-entry timing instrumentation to production traversal merely to profile these phases; that instrumentation can materially distort the workload.

### Allocations

Use Allocations with disposable data to inspect peak/retained memory across:

- enumeration and temporary URL/resource-value objects;
- internal `Node` lifetime;
- completed `FolderUsage` snapshot creation;
- derived Tree/Search/Largest Files/Sunburst preparation after publication.

Any proposal for caching, incremental presentation, or alternative tree construction must show why the measured retention/allocation cost justifies the extra state.

### Hangs and responsiveness

Use Hangs or equivalent responsiveness analysis when investigating UI stalls. Filesystem traversal and expensive recursive preparation must remain off the main actor. Progress publication should remain sampled rather than per-entry.

### Repeated scan/cancel/rescan

Exercise disposable targets through repeated start/cancel/rescan cycles when investigating lifecycle cost. Verify that cancellation remains responsive, one authoritative scan is preserved, and stale generations never publish over a newer scan.

## Instruments / xctrace

For deeper investigation, profile a Debug or Release build with Apple Instruments. Time Profiler and Allocations are the first choices for scanner and presentation preprocessing; Hangs can help diagnose UI responsiveness.

A command-line trace may also be captured with `xcrun xctrace` using an installed Instruments template. Exact template names can vary by Xcode installation, so list the local templates first rather than hard-coding a machine-specific template path.

Do not commit trace archives that contain real user filesystem paths or other local data. Use synthetic or disposable fixtures whenever a trace is intended to be shared or attached to a review.
