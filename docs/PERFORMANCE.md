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

### R6.2 scanner CPU attribution

R6.2 profiled the unchanged R6.1 scanner baseline before selecting any runtime optimization. The source baseline was exact `main` commit `abcac2b18c698f9e997ec3ac485dd413fe3a8409`; the research workflow itself lived only on a temporary branch and changed no production runtime file.

The final attribution run used:

- GitHub-hosted `macos-26-arm64`, runner image `20260907.0351.1`;
- macOS 26.6.2 (`25G83`) and Xcode 26.6;
- `build-for-testing` before profiling so compilation was outside the trace;
- only `DiskScannerTests.testDiskScannerDisposableFilesystemSyntheticPerformance` through `test-without-building`;
- 8 XCTest iterations per capture;
- 3 independent 10-second `xcrun xctrace` Time Profiler captures;
- the same 4,096-file / 72-directory disposable fixture from R6.1;
- ephemeral `.trace` and exported XML files under the hosted runner temporary directory; raw profiling data was not uploaded or committed.

The initial repeated traces showed stable **inclusive stack presence**: path-related frames appeared in roughly 35–37% of scanner stacks, `Node.addFile` in roughly 21–23%, resource-value frames in roughly 19–20%, conversion in roughly 14%, and enumeration in roughly 3–4%. Those categories overlap, so their percentages must not be added or treated as exclusive CPU shares.

For the final attribution, each symbolized stack containing `DiskScanner.scan`, `Node.addFile`, or `Node.toFolderUsage` was walked from the sampled leaf toward the async root and assigned to the first recognized scanner phase. That produces mutually exclusive **nearest-labeled-phase** buckets. It is sampled, label-based call-stack attribution rather than a machine-independent wall-clock percentage.

| Nearest labeled phase | Capture 1 | Capture 2 | Capture 3 | Pooled, 9,187 scanner stacks |
| --- | ---: | ---: | ---: | ---: |
| Path processing | 32.05% | 30.55% | 32.56% | **31.71%** (2,913) |
| `Node.addFile` | 24.39% | 23.71% | 24.02% | **24.03%** (2,208) |
| Resource-value reads | 15.96% | 16.94% | 15.21% | **16.04%** (1,474) |
| `Node.toFolderUsage` | 14.10% | 15.26% | 14.23% | **14.54%** (1,336) |
| Filesystem enumeration | 3.17% | 3.62% | 3.96% | **3.59%** (330) |
| Unclassified scanner stack | 10.32% | 9.92% | 10.01% | **10.08%** (926) |

The ranking is stable across the three independent captures. Path processing is the largest labeled CPU phase for this synthetic scanner workload, with `Node.addFile` second. Frequent symbolized frames inside scanner stacks include `URL.standardizedFileURL`, `URLByStandardizingPath`, `_NSStandardizePathUsingCache`, NSString path standardization, filesystem-representation conversion, and Unicode normalization. `Node.addFile`, `Node.toFolderUsage`, string sorting/comparison, and `URL.resourceValues(forKeys:)` also appear as expected.

This evidence justifies investigating the narrow repeated path-normalization/path-derivation work before redesigning tree construction or resource reads. A follow-up change must preserve exact path and filesystem identity semantics and should add regression coverage for normalization/symlink behavior before altering scanner path handling.

The ordinary R6.1 CI run reported the scanner performance testcase completing in 2.856 seconds on that hosted runner. That console testcase duration was unprofiled, is not the exact `XCTClockMetric` mean, and is not directly comparable to the instrumented testcase durations observed during Time Profiler capture.

### R6.3 scanner path-standardization A/B

R6.3 tested the first narrow optimization selected by R6.2. The production change computes `item.standardizedFileURL` once for each regular-file path derivation, derives the parent path from that standardized URL, and reuses the same URL for the file path when a positive allocated-size file is added. It does not resolve symbolic links or change path identity, package traversal, hidden-file, allocation, cancellation, progress, or snapshot semantics.

Before changing production path handling, focused regression tests were added and proven against the unchanged R6.2 baseline. They protect lexical standardization of a non-standard scan-root path and the existing rule that a directory symlink encountered inside the scan scope does not cause duplicate traversal/publication of the target subtree. The same tests pass with the candidate.

The same-runner Time Profiler comparison used exact baseline `10d80e7913b18f9c0f4e9d65bca40f5df5687299` and the candidate runtime change at `ce37b0de2be4c82604867367d1bab8ebf1297021`. On one GitHub-hosted `macos-26-arm64` runner (image `20260907.0351.1`, macOS 26.6.2 / `25G83`, Xcode 26.6), each variant was built outside the trace and profiled with three independent 10-second captures, 8 XCTest iterations per capture, and the R6.1 4,096-file / 72-directory fixture. Raw `.trace` and XML files stayed ephemeral under the runner temporary directory.

The mutually exclusive nearest-labeled-phase classifier showed the targeted path-processing bucket decrease in every capture:

| Variant | Capture 1 | Capture 2 | Capture 3 | Pooled |
| --- | ---: | ---: | ---: | ---: |
| R6.2 baseline | 32.46% | 33.53% | 33.83% | **33.27%** (3,460 / 10,401 scanner stacks) |
| R6.3 candidate | 26.10% | 28.00% | 28.60% | **27.55%** (2,947 / 10,694 scanner stacks) |

The pooled targeted bucket moved by **-5.72 percentage points**. As in R6.2, these values are sampled stack attribution, not wall-clock CPU percentages. Relative shares of other mutually exclusive buckets can rise when one bucket falls; that alone does not show those phases became slower in absolute time.

A separate research-only same-runner timing run supplied end-to-end supporting evidence without turning timing into a CI threshold. Both variants were built before measurement and warmed once. Six paired rounds then alternated baseline/candidate order; each timed `xcodebuild test-without-building` invocation executed three iterations of only the scanner synthetic performance test. Baseline mean/median were 13.252/13.133 seconds; candidate mean/median were 12.762/12.749 seconds. The candidate was faster in 5 of 6 pairs, with a mean paired delta of -0.491 seconds and an aggregate mean difference of **-3.70%**. Individual pair noise ranged from +1.48% to -10.10%.

That timing is runner-local whole-invocation evidence and includes test-launch/xcodebuild overhead; it is not a machine-independent scanner benchmark and does not justify a hard threshold or an exact product speedup claim. In combination with the repeated targeted Time Profiler reduction, however, it provides no sign that the narrow change merely moved cost into an end-to-end regression. The minimal optimization is therefore retained.

### R6.4 scanner allocation and retention evidence

R6.4 measured scanner memory behavior on the unchanged R6.3 production baseline at exact `main` commit `42974eb573d43361581dd0866084fc73ddc1d725`. The research harness and workflow lived only on temporary draft PR #94 and were closed without merge after evidence collection.

The final footprint run used:

- a GitHub-hosted macOS virtual machine running macOS 26.6.2 (`25G83`);
- Xcode 26.6 and Instruments 16.0 (`17F113`);
- disposable fixtures created outside the measured XCTest process;
- 8 top-level directories and 8 nested directories under each top-level directory, for 72 directories total;
- 4 KiB regular files, with isolated 4,096-file, 16,384-file, and 32,768-file workloads;
- a fresh XCTest host process for each workload size so fixture construction and a previous workload could not contaminate the starting footprint;
- `task_info(TASK_VM_INFO).phys_footprint` sampled every 5 ms during scanning;
- separate before, sampled-peak, completed-snapshot-held, and post-return observations;
- repeated full scans in the 16,384-file process and a cancel/rescan lifecycle in the 32,768-file process.

The observed hosted-runner values were:

| Workload | Before | Sampled peak / held | Increase from start |
| --- | ---: | ---: | ---: |
| 4,096 files, first full scan | 29.36 MiB | 30.63 MiB | +1.27 MiB |
| 16,384 files, first full scan | 30.08 MiB | 34.85 MiB | +4.77 MiB |
| 16,384 files, repeat 2 | 34.85 MiB | 35.13 MiB | +0.28 MiB |
| 16,384 files, repeat 3 | 35.13 MiB | 35.22 MiB | +0.09 MiB |
| 32,768 files, first full scan | 30.02 MiB | 39.53 MiB | +9.52 MiB |
| 32,768-file fixture, cancelled after 447 files | 39.53 MiB | 39.53 MiB | no sampled increase |
| 32,768-file full rescan after cancellation | 39.53 MiB | 39.66 MiB | +0.13 MiB |

The first full-scan footprint increase for 16,384 and 32,768 files was approximately linear for this fixture, at about 305 bytes per file of additional process physical footprint. This is a runner-local Debug/XCTest observation, not a stable per-file product-memory coefficient and not a CI threshold.

The 16,384-file process added only about 0.38 MiB after its first high-water across two more complete scans. The 32,768-file cancellation did not raise the existing sampled high-water, and the subsequent full rescan added about 0.13 MiB. Within the tested lifecycle there is therefore no evidence of unbounded process-footprint growth across repeated scan/cancel/rescan.

The post-return `phys_footprint` observation remained at the process high-water in these samples. That does **not** prove that completed snapshot objects remained live: malloc zones and VM pages can remain resident for reuse after objects are released. The repeated-run plateau is the useful retention signal. Likewise, no sampled peak above the completed-snapshot-held value was observed; a 5 ms footprint sampler cannot prove that shorter-lived transient allocations never exceeded that value.

A separate research-only Allocations capture successfully attached `xctrace` to the XCTest host for the 32,768-file full/cancel/rescan lifecycle. Raw `.trace` and XML data stayed ephemeral under the hosted runner temporary directory and were not uploaded or committed. The Allocations statistics reported roughly 233.1 MB of transient Heap + Anonymous VM activity, including about 220.4 MB of transient heap activity. Large typed churn included:

- immutable `CFString`: about 30.9 MB transient;
- resource-value dictionary storage: about 17.3 MB;
- `CFURL`: about 11.1 MB;
- `NSPathStore2`: about 6.8 MB;
- `Substring` array storage: about 6.2 MB;
- `_DictionaryStorage<String, Node>`: about 4.35 MB;
- `FolderUsage` array storage: about 3.16 MB;
- `Node` objects: about 2.47 MB.

These allocation totals cover the instrumented test-host lifecycle and include Foundation/XCTest overhead; they are diagnostic churn evidence rather than scanner-exclusive byte accounting. Some Allocations “persistent” rows were negative because the trace attached after process startup and could observe frees for allocations made before attachment. Those values are therefore not used as retained-memory totals.

The evidence shows substantial temporary URL/path/string/resource-value allocation churn, but the retained process footprint for the tested scanner lifecycle is bounded and reaches a rapid high-water plateau. R6.4 therefore does not justify a `Node.addFile` redesign, a cache or index, incremental-result architecture, or another memory-driven runtime change. Current memory behavior is accepted for the largest tested 32,768-file disposable workload. Any subsequent optimization must be selected from fresh measured hotspot evidence rather than from a presumed retention problem.


### R6.5 post-R6.3 scanner CPU re-attribution

R6.5 re-profiled the unchanged post-R6.3 production scanner before selecting any further runtime optimization. The production baseline was exact `main` commit `ecaefa8724022603b9536fccbd2246029b3f9867`. The temporary profiling workflow lived only on research draft PR #98, changed no production source or test code, and was closed without merge after evidence collection.

The final diagnostic run used the same R6.2/R6.3 nearest-labeled-phase classifier and the same canonical environment and fixture:

- GitHub-hosted `macos-26-arm64`, runner image `20260907.0351.1`;
- macOS 26.6.2 (`25G83`), Xcode 26.6, and xctrace 16.0 (`17F113`);
- `build-for-testing` before profiling;
- only `DiskScannerTests.testDiskScannerDisposableFilesystemSyntheticPerformance`;
- 8 XCTest iterations per capture;
- 3 independent 10-second Time Profiler captures;
- the 4,096-file / 72-directory disposable R6.1 fixture;
- ephemeral trace/XML data under runner temporary storage only.

Nearest-labeled-phase attribution for the refined run was:

| Nearest labeled phase | Capture 1 | Capture 2 | Capture 3 | Pooled, 8,527 scanner stacks |
| --- | ---: | ---: | ---: | ---: |
| `Node.addFile` | 26.97% (740) | 28.25% (869) | 26.23% (710) | **27.20% (2,319)** |
| Path processing | 24.78% (680) | 24.09% (741) | 26.34% (713) | **25.03% (2,134)** |
| Resource-value reads | 16.07% (441) | 17.26% (531) | 17.21% (466) | **16.86% (1,438)** |
| `Node.toFolderUsage` | 16.87% (463) | 15.86% (488) | 15.40% (417) | **16.04% (1,368)** |
| Filesystem enumeration | 4.85% (133) | 4.71% (145) | 3.84% (104) | **4.48% (382)** |
| Unclassified scanner stack | 10.46% (287) | 9.82% (302) | 10.97% (297) | **10.39% (886)** |

An earlier successful R6.5 run on the same production baseline independently produced the same ordering across another three captures: pooled `Node.addFile` 27.42%, path processing 24.38%, `Node.toFolderUsage` 17.01%, resource-value reads 16.15%, enumeration 4.49%, and unclassified work 10.55% across 8,860 scanner stacks. The two run sets therefore agree that `Node.addFile`, not path processing, is now the largest labeled bucket after R6.3. These values remain sampled stack attribution rather than machine-independent wall-clock CPU percentages.

The refined workflow also printed representative frames inside stacks assigned to the nearest-`Node.addFile` bucket. Repeatedly prominent work included dictionary lookup/set operations (`Dictionary.subscript.setter`, `Dictionary._Variant.setValue`, `__RawDictionaryStorage.find`), `Collection.split` and substring handling, and string comparison/Unicode normalization/normalized hashing. Smaller array growth and indexing frames also appeared.

This evidence supports a narrow follow-up experiment around `Node.addFile` component parsing and dictionary lookup behavior, with correctness coverage and before/after profiling. It does **not** justify a broader tree-construction redesign, caching/indexing, incremental-result architecture, or another memory-driven change. R6.4's bounded-retention conclusion remains unchanged.

### R6.6 terminal file-child lookup A/B

R6.6 tested the smallest dictionary opportunity identified by R6.5: remove the lookup immediately before insertion of the terminal regular-file child in `Node.addFile`. Folder-component traversal, relative-path parsing, path standardization, resource-value reads, enumeration, conversion, cancellation, progress cadence, and the authoritative scan model are unchanged.

Focused disposable-filesystem coverage was added before the runtime candidate and proven on the unchanged exact baseline `b6251549cf615bb65c61501cfc35bf23ac79c720`. The tests-only head `94af88e59fb3cbb0df559458a9a01a98dcca668a` passed Debug tests and Release build. The focused test protects multiple files in one directory, identical terminal names in different directories, exactly one published file node per enumerated path, per-file allocated sizes, parent aggregation, root aggregation, and the completed summary's allocated-byte total. The same focused test also passed with the candidate.

Research draft PR #103 remained unmerged. Its exact measurement head was `693a0230d7c2706561201c4cca01dac9d1637702`; workflow run `35346964827`, job `105605717575`, used macOS 26.6.2 (`25G83`), Xcode 26.6, and xctrace 16.0 (`17F113`). Both baseline and candidate were built before measurement. Three independent 10-second Time Profiler captures per variant used 8 XCTest iterations of the existing 4,096-file / 72-directory fixture, with variant order alternated on the same hosted runner.

| Variant | Capture 1 `Node.addFile` | Capture 2 | Capture 3 | Pooled | Pooled `Dictionary._Variant.lookup` rows |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline | 24.84% (614 / 2,472) | 27.10% (773 / 2,852) | 25.42% (687 / 2,703) | **25.84% (2,074 / 8,027)** | **273** |
| Candidate | 25.50% (619 / 2,427) | 24.42% (684 / 2,801) | 24.78% (644 / 2,599) | **24.88% (1,947 / 7,827)** | **33** |

The targeted lookup signal fell in every capture. Pooled lookup frame occurrences moved from 279 to 38, while raw dictionary-find rows moved from 504 to 362. Setter work remains because direct dictionary assignment still performs insertion; setter rows rose from 449 to 534 and are not interpreted as an absolute slowdown because these are sampled stack counts. The pooled nearest-`Node.addFile` share moved by -0.96 percentage points. Other pooled nearest-labeled shares were close: path processing 25.90% → 25.90%, resource values 16.76% → 17.17%, `Node.toFolderUsage` 16.26% → 16.70%, enumeration 4.63% → 4.85%, and unclassified scanner work 10.61% → 10.50%.

A separate warmed six-pair whole-test timing comparison alternated baseline/candidate order on the same runner. Each timed invocation used three iterations of only the synthetic scanner performance testcase. Baseline mean/median were 18.909/18.587 seconds; candidate mean/median were 17.799/17.878 seconds. The candidate was faster in 4 of 6 pairs, with mean paired delta -1.109 seconds and aggregate mean difference -5.87%. Individual pair deltas ranged from -14.25% to +8.36%, so this is noisy runner-local supporting evidence rather than a machine-independent speedup claim.

The candidate is retained because the intended lookup cost fell sharply and repeatedly, focused correctness remained green, and end-to-end timing showed no regression signal. This result does not justify a folder-node cache/index, tree-construction redesign, component-parser rewrite, incremental-result architecture, or memory-driven change. Raw trace/XML/log/timing artifacts remained under runner temporary storage only and were not uploaded or committed.


### R6.7 large-snapshot presentation scaling

R6.7 measured the existing derived presentation transformations on the unchanged production baseline `1a6617d24e2819f91f8c03a780dc22f226e4cf6a` before selecting another runtime optimization. Research draft PR #107 was intentionally closed unmerged after evidence collection; it changed only temporary research tests/workflow code and no production source.

The successful scaling and profiling head was `0e512f56820e15a54ead3fd8bf051b3813d0f94f`, workflow run `35354259942`, job `105629892602`. The runner used GitHub-hosted `macos-26-arm64` image release `20260907.0351`, macOS 26.6.2 (`25G83`), Xcode 26.6, and xctrace 16.0 (`17F113`).

The research workload used deterministic in-memory `FolderUsage` snapshots only. Fixture construction and correctness checks were outside measured timing samples. Each timing point was warmed and measured five times. These are runner-local Debug/XCTest diagnostics, not hard CI thresholds or machine-independent product benchmarks.

| Transformation | ~16K nodes | ~64K nodes | ~128K nodes |
| --- | ---: | ---: | ---: |
| Tree recursive sort | 0.030937 s (16,380) | 0.112400 s (64,350) | 0.195720 s (128,700) |
| Search selective, 1 match | 0.077161 s | 0.249531 s | 0.451010 s |
| Search broad | 0.191152 s / 16,352 matches | 0.683990 s / 64,240 matches | **1.073799 s / 128,480 matches** |
| Largest Files top-100 | 0.058015 s (16,000 files) | 0.223265 s (64,000 files) | 0.365037 s (128,000 files) |
| Sunburst preparation | 0.011866 s (16,468) | 0.053669 s (65,620) | 0.102321 s (131,156) |

The table reports medians. Structural correctness was checked separately at every workload size: Tree preserved every node; selective Search returned exactly one expected deep target; broad Search returned the expected match count; Largest Files returned exactly 100 files in deterministic size-descending/path-ascending order; and Sunburst preserved total size, unique segment IDs, 84 ordinary segments, and 64 bounded aggregate segments for each tested shape.

Broad Search was the largest tested derived-preprocessor cost at the largest snapshot. On the same 128,700-node shape, selective Search with one match had a 0.451010-second median while broad Search with 128,480 matches had a 1.073799-second median. That difference is diagnostic evidence that high-match workloads add substantial match/result/sort work beyond traversal alone; it is not an exact product-latency claim.

The same successful workflow then collected three independent Time Profiler captures of repeated 128,700-node / 128,480-match broad Search work. A nearest-recognized Search-phase classifier produced stable sampled attribution:

| Search phase | Capture 1 | Capture 2 | Capture 3 | Pooled, 7,975 Search stacks |
| --- | ---: | ---: | ---: | ---: |
| Name/path matching | 47.78% (1,348) | 46.92% (1,204) | 52.51% (1,359) | **49.04% (3,911)** |
| Result sorting | 39.06% (1,102) | 39.48% (1,013) | 35.24% (912) | **37.96% (3,027)** |
| Search recursion | 13.15% (371) | 13.60% (349) | 12.25% (317) | **13.00% (1,037)** |

These values are sampled nearest-phase stack shares within symbolized Search stacks, not wall-clock CPU percentages. `SearchPresentationPreprocessor.collectMatches` appeared prominently in the captured stacks, but the phase classifier is preferred over raw top-frame counts because XCTest ancestor frames are also frequent in the attached test host.

The measured next hotspot is therefore **Search name/path matching**, with result sorting retained as an important secondary cost to monitor. This evidence does not justify a Search index/cache, duplicate snapshot, presentation-model redesign, concurrency change, UI redesign, or broader architecture work. A follow-up must test the smallest behavior-preserving matching-path change first, with focused coverage for current case-insensitive name and full-path semantics and same-runner before/after evidence. If the targeted matching cost does not credibly fall without regression, the candidate should be rejected rather than expanded.

Raw trace archives, exported XML, logs, temporary result files, and DerivedData remained under runner temporary storage and were not uploaded or committed. The temporary research workflow and research-only tests are absent from the clean final branch.

### R6.8 Search terminal-name matching A/B

R6.8 tested the smallest behavior-preserving Search matching candidate selected by R6.7: compute `(path as NSString).lastPathComponent` once per `FolderUsage.name` access and reuse that value instead of evaluating the same terminal component twice for ordinary nonempty names. Search traversal, case-insensitive terminal-name and full-path matching, result sorting/tie behavior, cancellation, snapshot authority, scanner behavior, concurrency, and UI behavior were unchanged.

Research draft PR #111 was intentionally closed unmerged after evidence collection. The exact production baseline was `5ef70dfac1d59a951ca55d0b499baa2fcfa22c70`. The successful research measurement head was `4cdca2a09d6d10195d5fc2f87500cb24b809d683`, workflow run `35575888250`, job `106257561456`. Workflow-only commits after the original candidate added a bounded watchdog around `xctrace record` after an earlier capture hung; they did not broaden or alter the production candidate.

Focused correctness passed on both variants. Coverage preserved case-insensitive terminal-name matching, case-insensitive full-path-only matching, deterministic equal-size/path sorting, unchanged source snapshots, the existing empty-terminal `FolderUsage.name` fallback, one-match selective identity, and broad 128,480-match identity/count on the deterministic 128,700-node fixture.

The successful same-runner timing run used six alternating baseline/candidate pairs with five warmed operation-only samples per variant and pair:

| Pair | Baseline median | Candidate median | Candidate delta |
| --- | ---: | ---: | ---: |
| 1 | 0.941515 s | 0.947161 s | +0.60% |
| 2 | 0.938001 s | 0.918385 s | -2.09% |
| 3 | 0.901158 s | 0.926964 s | +2.86% |
| 4 | 0.869180 s | 0.934851 s | +7.56% |
| 5 | 0.872380 s | 0.933977 s | +7.06% |
| 6 | 0.914575 s | 0.990389 s | +8.29% |

The candidate was faster in only **1 of 6** pairs. The baseline pooled median was **0.913574 s** and the candidate pooled median was **0.932928 s**, a runner-local difference of **+2.12%**. The workflow's mean paired delta was **+4.05%**. These values are diagnostic shared-runner evidence, not a machine-independent product-latency claim.

Three independent 10-second Time Profiler captures per variant did show the intended targeted reduction:

| Sampled Search signal | Baseline | Candidate |
| --- | ---: | ---: |
| Pooled symbolized Search stacks | 6,137 | 5,907 |
| Terminal-path rows/frames | 362 (5.90%) | 212 (3.59%) |
| `FolderUsage.name` rows/frames | 903 (14.71%) | 542 (9.18%) |
| Nearest name/path matching phase | 51.98% | 49.33% |
| Nearest result-sorting phase | 34.37% | 36.19% |
| Nearest Search-recursion phase | 13.65% | 14.47% |

The terminal-path sampled share fell by 2.31 percentage points, about 39% relative, and the `FolderUsage.name` sampled share fell by 5.54 percentage points, about 38% relative. These are sampled stack shares rather than wall-clock CPU percentages; increases in other relative phase shares do not by themselves prove those phases became slower.

The candidate is **rejected**. Although the targeted terminal-name extraction signal fell credibly, R6.8 required both that reduction and no repeated broad-Search end-to-end regression signal. The successful timing run instead had the candidate slower in 5 of 6 pairs, with +2.12% pooled-median and +4.05% mean paired deltas. The experiment is therefore not broadened to result sorting, indexing, caching, Search redesign, concurrency, UI, or scanner work, and no production source change is retained.

Raw `.trace`, exported XML, timing logs/results, DerivedData, temporary markers, and the baseline worktree remained under runner temporary storage only. No research workflow, heavy research-only test, raw profiling artifact, or candidate source change belongs in the clean final production branch.


### R6.9 large-snapshot presentation-state responsiveness

R6.9 measured the unchanged production `TreePresentationState`, `SearchPresentationState`, `LargestFilesPresentationState`, and `SunburstPresentationState` publication paths on the exact production baseline `695384f3a5c0a475f3b8292e8f3530ba841e448e`. Research draft PR #116 was intentionally closed unmerged after evidence collection; it changed only temporary research tests/workflow code and no production source.

The successful exact research head was `96adcdde3ead1996cdf5cc49bb3da9bdb3d61efc`, workflow run `35580023290`, job `106270493991`, on GitHub-hosted macOS 26.6.2 / Xcode 26.6. Fixture construction and the build occurred outside measured intervals. Real Combine subscribers observed the production `@Published` output and `isPreparing` properties, while a detached periodic probe measured delay until a minimal `MainActor.run` callback executed.

The deterministic in-memory fixtures and result checks were:

- Tree: 128,700 nodes in and 128,700 nodes published;
- broad Search: 128,700 nodes in and 128,480 matches published;
- Largest Files: 128,128 nodes in and the production top 100 files published in deterministic order;
- Sunburst: 131,156 nodes in, preserving total size with 84 ordinary segments + 64 aggregates = 148 visual segments.

Five rounds per workload produced:

| State workload | Completion median | Completion mean | Median of heartbeat p95 | Worst heartbeat max |
| --- | ---: | ---: | ---: | ---: |
| Tree | 0.202804 s | 0.201536 s | 0.147 ms | 1.050 ms |
| Search broad | 1.119759 s | 1.179166 s | 0.130 ms | 5.913 ms |
| Largest Files | 0.394748 s | 0.407823 s | 0.171 ms | 1.298 ms |
| Sunburst | 0.116911 s | 0.116494 s | 0.183 ms | 1.347 ms |

The same-run idle heartbeat was 328 samples / 0.052 ms median / 0.132 ms p95 / 0.551 ms max before workloads and 305 samples / 0.090 ms median / 0.147 ms p95 / 1.145 ms max afterward. Workload median p95 values therefore remained close to the same-run idle p95 values. The isolated 5.913 ms Search maximum was not repeated in the other Search rounds, whose maxima were 1.231, 0.208, 0.405, and 0.704 ms; that outlier's own p95 was 0.164 ms.

Observer delivery occurred in every round: Tree/Search/Largest Files each observed two output events and two preparing events per measured request; Sunburst observed one model event and two preparing events. Rapid Tree supersession also passed: a newer one-item replacement remained authoritative after the cancelled 128,700-node generation had time to finish, proving the stale generation did not publish over it.

The measurement decision is to **accept the current presentation-state publication/main-actor responsiveness at the largest tested snapshots**. There is no credible repeated workload-correlated main-actor stall, so R6.9 does not justify targeted Time Profiler follow-up or a production state/concurrency change. The separately recorded request-to-publication durations remain useful workload diagnostics but are not evidence of main-actor blocking.

Actual SwiftUI rendering and interaction were intentionally outside this slice. Tree expansion/navigation, Sunburst rendering/hit testing, or other view-level work should become another R6 slice only if the post-R6.9 master exit review finds a remaining measured requirement.

Raw result logs, DerivedData, temporary markers, and the research workflow/tests remained under runner temporary storage or on the closed research branch and are absent from the clean production branch.

### R6.10 large-snapshot SwiftUI interaction responsiveness

R6.10 exercised the unchanged production `TreeView` and `SunburstView` through real AppKit-delivered keyboard/mouse interaction against deterministic large in-memory snapshots. The exact production baseline remained `0cda06c0ba11f6808abcbe675f14fc8f9eb76d7d`; research PR #120 changed only temporary tests/workflows and is intentionally kept out of production.

Final interaction evidence was collected at exact research head `4b1ac25fe3eec2fe90e9bcb7663a026187e5744b` in workflow `35597760914`, job `106326520765`. Fixture construction and sorting occurred before measured interaction intervals. Structural checks passed for:

- Tree: 128,700 nodes;
- Sunburst: 131,156 nodes, total size 262,080;
- Sunburst presentation: 148 ordinary segments + 64 aggregates = 212 visual segments;
- repeated Tree expansion/navigation/selection and Sunburst selection/navigation/leaf hit-testing.

The same-run idle heartbeat p95 was 0.212 ms before and 0.115 ms after. Five repeated interaction rounds produced:

| Interaction | Duration median | Duration max | Median of heartbeat p95 | Worst heartbeat max |
| --- | ---: | ---: | ---: | ---: |
| Tree initial host/layout/display | 0.522787 s | 0.647015 s | 526.350 ms | 720.666 ms |
| Tree expand level 1 | 0.122993 s | 0.169176 s | 118.601 ms | 152.676 ms |
| Tree expand level 2 | 0.130959 s | 0.196135 s | 125.612 ms | 189.069 ms |
| Tree expand level 3 | 0.124108 s | 0.141094 s | 116.758 ms | 136.179 ms |
| Tree parent/left navigation | 0.000586 s | 0.000639 s | 0.090 ms | 2.188 ms |
| Sunburst initial host/layout/display | 0.040063 s | 0.046990 s | 47.211 ms | 66.281 ms |
| Sunburst ready/select | 0.189813 s | 0.236225 s | 54.726 ms | 101.865 ms |
| Sunburst navigation level 1 | 0.053062 s | 0.073308 s | 25.111 ms | 39.487 ms |
| Sunburst navigation level 2 | 0.016921 s | 0.018947 s | 8.042 ms | 11.274 ms |
| Sunburst leaf selection | 0.015429 s | 0.016455 s | 0.105 ms | 0.846 ms |

Unlike the R6.9 presentation-state measurements, Tree host/expansion work therefore shows a repeated main-actor stall that is far above the same-run idle heartbeat. Sunburst remains materially lighter for the tested presentation shape.

Because the Tree stall repeated, R6.10 collected targeted Time Profiler evidence before selecting any optimization. Exact-head workflow `35597760873`, job `106326517723`, produced three successful 10-second captures with 9,700 / 9,570 / 9,521 symbolized stack rows. Per-stack inclusive presence was stable:

- `OutlineListCoordinator.diffRows(of:to:)`: 47.31% / 47.58% / 48.86%;
- `OutlineListCoordinator.update(...)` / `withSelectionUpdateGuard`: 49.25% / 49.23% / 51.07%;
- `ModifiedViewList.applyNodes` / `DynamicViewList.WrappedList.applyNodes`: 28.29% / 29.40% / 30.50%;
- AttributeGraph update/input machinery: 32.07% / 30.96% / 30.51%;
- AppKit `NSView` layout: 63.39% / 64.24% / 61.80%;
- app `TreeView` / `ItemRow` / `SizeBar`: 2.87% / 2.79% / 2.69%;
- `FolderUsage` projection: 0.06% / 0.06% / 0.04%;
- DiskUsage formatting: 0.30% / 0.34% / 0.32%.

These categories overlap because they report whether a symbol category is present anywhere in a sampled stack; they are not additive CPU percentages. Raw frame-occurrence counts are likewise not CPU percentages.

The measured hotspot is therefore specifically the SwiftUI `List` + `OutlineGroup` update/diff/layout path, centered on `OutlineListCoordinator` and framework layout/AttributeGraph machinery rather than obvious DiskUsage row formatting or `FolderUsage` projection work. R6.10 does **not** justify a speculative custom Tree, virtualization architecture, cache/index, scanner change, or broad UI rewrite.

Decision: open narrow follow-up #121 to test the smallest production change that can reduce the measured Tree outline diff/update/layout cost while preserving selection/navigation correctness. R6.10 itself retains no production runtime change. Raw traces/XML/logs/DerivedData and the research-only workflow/tests remain ephemeral or on the unmerged research branch and are absent from the clean final production diff.

### R6.11 narrow Tree outline update experiments

R6.11 kept production source unchanged while testing two native, research-only hypotheses against exact production baseline `29ede5fb1a15116940424302d3f6b68cda854d96`.

Candidate #1 used native hierarchical `List(data, children:, selection:)` in the test host while preserving the same 128,700-node fixture, AppKit keyboard interaction, selection binding, rows, focus/search behavior, and correctness assertions. The initial A/B run `35601949795` / job `106339898207` appeared favorable with paired expansion median -12.14% and candidate faster 4/6. The independent exact-head repetition `35602624796` / job `106342397306` at `c189d4b8b452aa635ba53e5fdb2a478fb56a30af` did not reproduce that signal:

| Candidate #1 metric | Delta / result |
| --- | ---: |
| Initial host/layout | -0.61% |
| Expand level 1 | +4.05% |
| Expand level 2 | +5.14% |
| Expand level 3 | +16.05% |
| Candidate faster pairs | 3 / 6 |
| Paired expansion median | +6.65% |
| Paired expansion mean | +5.50% |
| Correctness | PASS |

Targeted profiler workflow `35602625025` / job `106342093554` completed two baseline and two candidate captures before baseline round 3 stalled and the job was cancelled. Median per-stack presence across those complete captures was:

| Stack category | Baseline | Candidate |
| --- | ---: | ---: |
| Outline diff | 46.62% | 46.17% |
| Outline update / selection guard | 48.77% | 48.21% |
| Modified/DynamicViewList nodes | 29.66% | 30.00% |
| AttributeGraph update/input | 28.99% | 31.25% |
| AppKit `NSView` layout | 59.58% | 63.72% |
| SwiftUI outline-list machinery | 32.68% | 33.83% |
| SwiftUI / AttributeGraph aggregate | 59.29% | 61.98% |
| DiskUsage Tree/row views | 2.57% | 2.61% |

These percentages overlap and are per-stack presence rather than additive CPU shares. The partial profiler does not show a narrow hotspot reduction that would override the failed timing reproduction.

Candidate #2 preserved production `List(selection:)` + `Section` + `OutlineGroup` composition and removed only `selectedPath == item.path` from test-only row construction by passing `isSelected: false`. Exact-head workflow `35607984738` / job `106359704235` at `669ce58a83977a57381e2a1c32aee91ffd2088b8` passed all 6 baseline + 6 candidate invocations and all selection/navigation assertions:

| Candidate #2 metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Initial host/layout median | 0.630261 s | 0.654996 s | +3.92% |
| Expand level 1 median | 0.154034 s | 0.139781 s | -9.25% |
| Expand level 2 median | 0.167014 s | 0.163311 s | -2.22% |
| Expand level 3 median | 0.160083 s | 0.166147 s | +3.79% |

The paired expansion result was candidate faster 3/6, median -0.38%, mean -2.65%. Idle heartbeat was effectively unchanged. This does not establish a repeatable positive signal, so no targeted profiler follow-up was run for candidate #2.

Decision: reject both candidates and retain the unchanged production Tree. The remaining measured stall is dominated by SwiftUI/AppKit outline diff/update/layout machinery at the extreme synthetic scale, while app row/projection/formatting work remains small. R6 explicitly accepts this cost instead of introducing a custom Tree, speculative virtualization, cache/index, scanner change, or broader UI architecture. Revisit larger Tree architecture only if new product-level evidence justifies its interaction/accessibility/selection and maintenance trade-offs.

### R7.4 window resize and high-DPI runtime evidence

R7.4 verified the unchanged production layout against exact verified production base `1e08788262959bab460c201c742d4a5bd8cf3a53`. Research PR #137 is measurement-only and remains unmerged.

At exact research head `3b7ea526e6f907a08e2230d8fcb22a4f0b7eea09`, focused workflow `36120392705`, job `108024249964`, hosted the current production `ContentView`, `TreeView`, and `SunburstView` through AppKit `NSHostingView` / `NSWindow` using only small in-memory synthetic `FolderUsage` data. The single focused test exercised every production surface at 800×600, 1000×720, and 1440×900 logical points.

The runtime assertions required:

- hosted bounds that respect the declared shell/Sunburst minimum geometry rather than collapsing;
- a non-empty hit-testable hosted region;
- a positive native AppKit window backing scale;
- supplementary 2× bitmap output with the expected pixel dimensions;
- visible sampled rendered content for Tree and Sunburst at 2×;
- no crash, invalid geometry, stale presentation failure, or zero-sized primary analysis region across the tested sizes.

`testR74ProductionViewsLayoutAcrossSupportedWindowSizes()` passed with 0 failures. A separate AppKit probe on the same GitHub macOS runner printed `nativeBackingScale=1.0`, so this CI environment does **not** provide physical Retina backing. The successful 2× bitmap path is therefore supplementary high-DPI rendering evidence only; it must not be described as native Retina-hardware coverage.

Decision: **accept the current responsive layout unchanged**. The tested minimum and representative larger logical sizes showed no concrete clipping/collapse defect, so R7.4 retains no production layout change, framework, instrumentation, or permanent test/workflow harness. Research-only tests/workflows stay outside production.

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
