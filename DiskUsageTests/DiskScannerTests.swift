import Foundation
import XCTest
@testable import DiskUsage

final class DiskScannerTests: XCTestCase {
    func testHiddenFilesSettingControlsEnumeration() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let visible = root.appendingPathComponent("visible.dat")
        let hidden = root.appendingPathComponent(".hidden.dat")
        let data = Data(repeating: 1, count: 4096)
        try data.write(to: visible)
        try data.write(to: hidden)

        let hiddenOff = await DiskScanner().scan(at: root, showHiddenFiles: false)
        let hiddenOn = await DiskScanner().scan(at: root, showHiddenFiles: true)

        let hiddenOffPaths = Set(flatten(hiddenOff.root).map(\.path))
        let hiddenOnPaths = Set(flatten(hiddenOn.root).map(\.path))

        XCTAssertTrue(hiddenOffPaths.contains(visible.path))
        XCTAssertFalse(hiddenOffPaths.contains(hidden.path))
        XCTAssertTrue(hiddenOnPaths.contains(visible.path))
        XCTAssertTrue(hiddenOnPaths.contains(hidden.path))
    }

    func testPackageContentsAreIncludedInScan() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let package = root.appendingPathComponent("Example.app", isDirectory: true)
        let contents = package.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let payload = contents.appendingPathComponent("payload.dat")
        try Data(repeating: 1, count: 4096).write(to: payload)

        let result = await DiskScanner().scan(at: root, showHiddenFiles: true)
        let paths = Set(flatten(result.root).map(\.path))

        XCTAssertTrue(paths.contains(package.path))
        XCTAssertTrue(paths.contains(contents.path))
        XCTAssertTrue(paths.contains(payload.path))
        XCTAssertGreaterThan(result.root.size, 0)
    }

    func testSummaryCountsRegularFilesDirectoriesAndAllocatedBytesTruthfully() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let populated = root.appendingPathComponent("populated", isDirectory: true)
        let empty = root.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: populated, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        let payload = populated.appendingPathComponent("payload.dat")
        let zero = populated.appendingPathComponent("zero.dat")
        try Data(repeating: 1, count: 4096).write(to: payload)
        XCTAssertTrue(FileManager.default.createFile(atPath: zero.path, contents: Data()))

        let zeroValues = try zero.resourceValues(
            forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        )
        XCTAssertEqual(zeroValues.isRegularFile, true)
        XCTAssertEqual(zeroValues.totalFileAllocatedSize ?? zeroValues.fileAllocatedSize ?? 0, 0)

        let scanner = DiskScanner()
        let result = await scanner.scan(at: root, showHiddenFiles: true)

        XCTAssertEqual(result.summary.filesScanned, 2)
        XCTAssertEqual(result.summary.foldersScanned, 2)
        XCTAssertEqual(result.summary.restrictedLocations, 0)
        XCTAssertEqual(result.summary.allocatedBytes, result.root.size)
        XCTAssertGreaterThan(result.summary.allocatedBytes, 0)
        XCTAssertGreaterThanOrEqual(result.summary.elapsed, .zero)
        XCTAssertEqual(scanner.progress.filesScanned, result.summary.filesScanned)
        XCTAssertEqual(scanner.progress.bytesFound, result.summary.allocatedBytes)
    }

    func testScannerPublishesStandardizedPathsForLexicalRoot() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let scope = root.appendingPathComponent("scope", isDirectory: true)
        let nested = scope.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let payload = nested.appendingPathComponent("payload.dat")
        try Data(repeating: 1, count: 4096).write(to: payload)

        let lexicalScope = scope
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("scope", isDirectory: true)
        let result = await DiskScanner().scan(at: lexicalScope, showHiddenFiles: true)
        let paths = flatten(result.root).map(\.path)

        XCTAssertEqual(result.root.path, scope.standardizedFileURL.path)
        XCTAssertTrue(paths.contains(nested.standardizedFileURL.path))
        XCTAssertTrue(paths.contains(payload.standardizedFileURL.path))
        XCTAssertFalse(paths.contains { $0.contains("/../") })
    }

    func testDirectorySymlinkDoesNotDuplicateTargetTraversal() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let payload = target.appendingPathComponent("payload.dat")
        try Data(repeating: 1, count: 4096).write(to: payload)

        let alias = root.appendingPathComponent("target-alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)

        let result = await DiskScanner().scan(at: root, showHiddenFiles: true)
        let paths = flatten(result.root).map(\.path)
        let aliasPayloadPath = alias.appendingPathComponent("payload.dat").path

        XCTAssertEqual(paths.filter { $0 == payload.standardizedFileURL.path }.count, 1)
        XCTAssertFalse(paths.contains(aliasPayloadPath))
        XCTAssertFalse(paths.contains { $0.hasPrefix(alias.path + "/") })
    }

    func testDiskScannerDisposableFilesystemSyntheticPerformance() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let topLevelCount = 8
        let nestedCount = 8
        let filesPerNestedFolder = 64
        let expectedFiles = Int64(topLevelCount * nestedCount * filesPerNestedFolder)
        let expectedFolders = Int64(topLevelCount + topLevelCount * nestedCount)

        try makeScannerPerformanceFixture(
            at: root,
            topLevelCount: topLevelCount,
            nestedCount: nestedCount,
            filesPerNestedFolder: filesPerNestedFolder
        )

        let verificationSummary = try XCTUnwrap(
            scanSynchronously(DiskScanner(), at: root),
            "Disposable scanner fixture must complete before performance measurement"
        )
        XCTAssertEqual(verificationSummary.filesScanned, expectedFiles)
        XCTAssertEqual(verificationSummary.foldersScanned, expectedFolders)
        XCTAssertEqual(verificationSummary.restrictedLocations, 0)
        XCTAssertGreaterThan(verificationSummary.allocatedBytes, 0)

        measure(metrics: [XCTClockMetric()]) {
            XCTAssertNotNil(
                scanSynchronously(DiskScanner(), at: root),
                "Measured disposable scan must complete"
            )
        }
    }

    func testDiskScannerDisposableFilesystemSyntheticMemoryPerformance() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let topLevelCount = 8
        let nestedCount = 8
        let filesPerNestedFolder = 64
        let expectedFiles = Int64(topLevelCount * nestedCount * filesPerNestedFolder)
        let expectedFolders = Int64(topLevelCount + topLevelCount * nestedCount)

        try makeScannerPerformanceFixture(
            at: root,
            topLevelCount: topLevelCount,
            nestedCount: nestedCount,
            filesPerNestedFolder: filesPerNestedFolder
        )

        let verificationSummary = try XCTUnwrap(
            scanSynchronously(DiskScanner(), at: root),
            "Disposable scanner fixture must complete before memory measurement"
        )
        XCTAssertEqual(verificationSummary.filesScanned, expectedFiles)
        XCTAssertEqual(verificationSummary.foldersScanned, expectedFolders)
        XCTAssertEqual(verificationSummary.restrictedLocations, 0)
        XCTAssertGreaterThan(verificationSummary.allocatedBytes, 0)

        measure(metrics: [XCTMemoryMetric()]) {
            XCTAssertNotNil(
                scanSynchronously(DiskScanner(), at: root),
                "Measured disposable scan must complete"
            )
        }
    }

    func testDiskScannerLargeDisposableFilesystemMemoryResearch() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let topLevelCount = 16
        let nestedCount = 8
        let filesPerNestedFolder = 128
        let expectedFiles = Int64(topLevelCount * nestedCount * filesPerNestedFolder)
        let expectedFolders = Int64(topLevelCount + topLevelCount * nestedCount)

        try makeScannerPerformanceFixture(
            at: root,
            topLevelCount: topLevelCount,
            nestedCount: nestedCount,
            filesPerNestedFolder: filesPerNestedFolder
        )

        let verificationSummary = try XCTUnwrap(
            scanSynchronously(DiskScanner(), at: root),
            "Large disposable scanner fixture must complete before memory measurement"
        )
        XCTAssertEqual(verificationSummary.filesScanned, expectedFiles)
        XCTAssertEqual(verificationSummary.foldersScanned, expectedFolders)
        XCTAssertEqual(verificationSummary.restrictedLocations, 0)
        XCTAssertGreaterThan(verificationSummary.allocatedBytes, 0)

        measure(metrics: [XCTMemoryMetric()]) {
            XCTAssertNotNil(
                scanSynchronously(DiskScanner(), at: root),
                "Measured large disposable scan must complete"
            )
        }
    }

    @MainActor
    func testLargeDisposableCancelRescanMemoryResearch() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try makeScannerPerformanceFixture(
            at: root,
            topLevelCount: 16,
            nestedCount: 8,
            filesPerNestedFolder: 128
        )

        let viewModel = DiskScannerViewModel()
        viewModel.scan(root, description: "R6.4 memory research")

        for _ in 0..<3 {
            try await Task.sleep(for: .milliseconds(20))
            viewModel.cancel()
            XCTAssertEqual(viewModel.lifecycle, .cancelled)
            XCTAssertTrue(viewModel.canRescan)
            XCTAssertTrue(viewModel.items.isEmpty)

            viewModel.rescan()
            XCTAssertEqual(viewModel.lifecycle, .scanning)
            XCTAssertFalse(viewModel.canRescan)
        }

        for _ in 0..<750 {
            if viewModel.lifecycle == .completed {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(viewModel.lifecycle, .completed)
        XCTAssertTrue(viewModel.canRescan)
        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertGreaterThan(viewModel.totalSize, 0)

        // Keep the completed authoritative snapshot retained long enough for
        // the external research-only RSS sampler to observe the steady state.
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(viewModel.lifecycle, .completed)
    }

    @MainActor
    func testLargeDisposableSingleViewModelScanMemoryResearch() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try makeScannerPerformanceFixture(
            at: root,
            topLevelCount: 16,
            nestedCount: 8,
            filesPerNestedFolder: 128
        )

        let viewModel = DiskScannerViewModel()
        viewModel.scan(root, description: "R6.4 memory control")

        for _ in 0..<750 {
            if viewModel.lifecycle == .completed {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(viewModel.lifecycle, .completed)
        XCTAssertTrue(viewModel.canRescan)
        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertGreaterThan(viewModel.totalSize, 0)

        // Matched retention hold for external RSS comparison with cancel/rescan.
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(viewModel.lifecycle, .completed)
    }

    @MainActor
    func testViewModelLifecycleTransitionsImmediatelyOnStartAndCancel() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let viewModel = DiskScannerViewModel()
        XCTAssertEqual(viewModel.lifecycle, .initial)
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertFalse(viewModel.canRescan)

        viewModel.scan(root)
        XCTAssertEqual(viewModel.lifecycle, .scanning)
        XCTAssertTrue(viewModel.isScanning)
        XCTAssertFalse(viewModel.canRescan)
        XCTAssertTrue(viewModel.items.isEmpty)

        viewModel.cancel()
        XCTAssertEqual(viewModel.lifecycle, .cancelled)
        XCTAssertFalse(viewModel.isScanning)
        XCTAssertTrue(viewModel.canRescan)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    @MainActor
    func testRescanRetainsCurrentTargetAcrossCancellation() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("scope", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let payload = target.appendingPathComponent("payload.dat")
        try Data(repeating: 1, count: 4096).write(to: payload)

        let viewModel = DiskScannerViewModel()
        viewModel.scan(target, description: "Test scope")
        viewModel.cancel()

        XCTAssertEqual(viewModel.lifecycle, .cancelled)
        XCTAssertEqual(viewModel.targetDescription, "Test scope")
        XCTAssertTrue(viewModel.canRescan)

        viewModel.rescan()

        XCTAssertEqual(viewModel.lifecycle, .scanning)
        XCTAssertEqual(viewModel.targetDescription, "Test scope")
        XCTAssertFalse(viewModel.canRescan)

        await waitForScanCompletion(viewModel)

        XCTAssertEqual(viewModel.lifecycle, .completed)
        XCTAssertEqual(viewModel.targetDescription, "Test scope")
        XCTAssertTrue(viewModel.canRescan)
        XCTAssertTrue(viewModel.items.contains { $0.path == payload.standardizedFileURL.path })
    }

    @MainActor
    func testDroppedDirectoryStartsAuthoritativeScan() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("dropped", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let payload = target.appendingPathComponent("payload.dat")
        try Data(repeating: 1, count: 4096).write(to: payload)

        let viewModel = DiskScannerViewModel()
        let result = viewModel.scanDroppedURLs([target])

        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(viewModel.lifecycle, .scanning)
        XCTAssertEqual(viewModel.targetDescription, target.standardizedFileURL.path)
        XCTAssertFalse(viewModel.canRescan)

        await waitForScanCompletion(viewModel)

        XCTAssertEqual(viewModel.lifecycle, .completed)
        XCTAssertTrue(viewModel.canRescan)
        XCTAssertTrue(viewModel.items.contains { $0.path == payload.standardizedFileURL.path })
    }

    @MainActor
    func testDroppedFileAndMultipleItemsAreRejectedWithoutChangingState() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("payload.dat")
        try Data(repeating: 1, count: 4096).write(to: file)
        let first = root.appendingPathComponent("first", isDirectory: true)
        let second = root.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)

        let viewModel = DiskScannerViewModel()

        XCTAssertEqual(viewModel.scanDroppedURLs([file]), .unsupportedItem)
        XCTAssertEqual(viewModel.lifecycle, .initial)
        XCTAssertFalse(viewModel.canRescan)

        XCTAssertEqual(viewModel.scanDroppedURLs([first, second]), .requiresSingleFolder)
        XCTAssertEqual(viewModel.lifecycle, .initial)
        XCTAssertFalse(viewModel.canRescan)
    }

    @MainActor
    func testDroppedFolderDoesNotReplaceActiveScanTarget() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let active = root.appendingPathComponent("active", isDirectory: true)
        let dropped = root.appendingPathComponent("dropped", isDirectory: true)
        try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dropped, withIntermediateDirectories: true)

        let viewModel = DiskScannerViewModel()
        viewModel.scan(active)

        XCTAssertEqual(viewModel.scanDroppedURLs([dropped]), .scanInProgress)
        XCTAssertEqual(viewModel.lifecycle, .scanning)
        XCTAssertEqual(viewModel.targetDescription, active.standardizedFileURL.path)

        viewModel.cancel()
    }

    @MainActor
    func testSelectionReconcilePreservesPathAcrossSnapshotReplacement() {
        let oldChild = FolderUsage(path: "/scope/child", size: 100, isFile: true)
        let oldParent = FolderUsage(path: "/scope", size: 100, children: [oldChild])
        let replacementChild = FolderUsage(path: "/scope/child", size: 80, isFile: true)
        let replacementParent = FolderUsage(path: "/scope", size: 80, children: [replacementChild])
        let selection = ItemSelectionState()

        selection.selectedPath = oldChild.path
        selection.reconcile(with: [replacementParent])

        XCTAssertEqual(selection.selectedPath, replacementChild.path)
        XCTAssertEqual(selection.selectedItem(in: [replacementParent]), replacementChild)
    }

    @MainActor
    func testSelectionReconcileClearsPathMissingFromSnapshot() {
        let child = FolderUsage(path: "/scope/child", size: 100, isFile: true)
        let parent = FolderUsage(path: "/scope", size: 100, children: [child])
        let sibling = FolderUsage(path: "/other", size: 50, isFile: true)
        let selection = ItemSelectionState()

        selection.selectedPath = child.path
        selection.reconcile(with: [parent, sibling])
        XCTAssertEqual(selection.selectedPath, child.path)

        selection.reconcile(with: [sibling])

        XCTAssertNil(selection.selectedPath)
        XCTAssertNil(selection.selectedItem(in: [sibling]))
    }

    @MainActor
    private func waitForScanCompletion(_ viewModel: DiskScannerViewModel) async {
        for _ in 0..<100 {
            if viewModel.lifecycle == .completed {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Scan did not complete")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeScannerPerformanceFixture(
        at root: URL,
        topLevelCount: Int,
        nestedCount: Int,
        filesPerNestedFolder: Int
    ) throws {
        let payload = Data(repeating: 0xA5, count: 4_096)

        for topIndex in 0..<topLevelCount {
            let top = root.appendingPathComponent("top-\(topIndex)", isDirectory: true)
            for nestedIndex in 0..<nestedCount {
                let nested = top.appendingPathComponent("nested-\(nestedIndex)", isDirectory: true)
                try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

                for fileIndex in 0..<filesPerNestedFolder {
                    let file = nested.appendingPathComponent("file-\(fileIndex).dat")
                    try payload.write(to: file)
                }
            }
        }
    }

    private func scanSynchronously(_ scanner: DiskScanner, at root: URL) -> CompletedScanSummary? {
        let semaphore = DispatchSemaphore(value: 0)
        let summary = LockedScanSummary()

        Task.detached {
            let result = await scanner.scan(at: root, showHiddenFiles: true)
            summary.store(result.summary)
            semaphore.signal()
        }

        switch semaphore.wait(timeout: .now() + 30) {
        case .success:
            return summary.load()
        case .timedOut:
            return nil
        }
    }

    private func flatten(_ item: FolderUsage) -> [FolderUsage] {
        [item] + item.children.flatMap(flatten)
    }
}

private final class LockedScanSummary: @unchecked Sendable {
    private let lock = NSLock()
    private var summary: CompletedScanSummary?

    func store(_ summary: CompletedScanSummary) {
        lock.lock()
        self.summary = summary
        lock.unlock()
    }

    func load() -> CompletedScanSummary? {
        lock.lock()
        defer { lock.unlock() }
        return summary
    }
}

final class SunburstPresentationStateTests: XCTestCase {
    @MainActor
    func testKeepsPublishedModelWhilePreparingReplacement() {
        let publishedTotal = Int64(SunburstPalette.count)
        let replacementPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("sunburst-replacement")
            .path
        let replacement = FolderUsage(path: replacementPath, size: publishedTotal + publishedTotal)
        let state = SunburstPresentationState()
        state.prepare(items: [], totalSize: publishedTotal, levels: 1)

        state.prepare(items: [replacement], totalSize: replacement.size, levels: 1)

        XCTAssertEqual(
            publishedTotal,
            state.model.totalSize,
            "Replacement preparation must preserve the published presentation until the new model is ready"
        )
        state.cancel()
    }
}
