import Foundation
import XCTest
import Combine
@testable import DiskUsage

final class FolderUsageTests: XCTestCase {
    func testRemovingNestedItemUpdatesAncestorSizesAndPreservesSiblings() {
        let target = FolderUsage(path: "/root/a/target", size: 20, isFile: true)
        let kept = FolderUsage(path: "/root/a/kept", size: 40, isFile: true)
        let folderA = FolderUsage(path: "/root/a", size: 60, children: [target, kept])
        let folderB = FolderUsage(path: "/root/b", size: 40)
        let root = FolderUsage(path: "/root", size: 100, children: [folderA, folderB])

        let updated = root.removing(path: target.path)

        XCTAssertEqual(updated?.size, 80)
        XCTAssertEqual(updated?.children.count, 2)
        XCTAssertEqual(updated?.children[0].size, 40)
        XCTAssertEqual(updated?.children[0].children, [kept])
        XCTAssertEqual(updated?.children[1], folderB)
    }

    func testRemovingUnknownPathLeavesSnapshotUnchanged() {
        let child = FolderUsage(path: "/root/file", size: 10, isFile: true)
        let root = FolderUsage(path: "/root", size: 10, children: [child])

        XCTAssertEqual(root.removing(path: "/root/missing"), root)
    }

    func testRemovingUsesPathComponentBoundaries() {
        let aFile = FolderUsage(path: "/root/a/file", size: 10, isFile: true)
        let abFile = FolderUsage(path: "/root/ab/file", size: 20, isFile: true)
        let a = FolderUsage(path: "/root/a", size: 10, children: [aFile])
        let ab = FolderUsage(path: "/root/ab", size: 20, children: [abFile])
        let root = FolderUsage(path: "/root", size: 30, children: [a, ab])

        let updated = root.removing(path: abFile.path)

        XCTAssertEqual(updated?.size, 10)
        XCTAssertEqual(updated?.children[0], a)
        XCTAssertEqual(updated?.children[1].path, ab.path)
        XCTAssertTrue(updated?.children[1].children.isEmpty == true)
    }

    func testSizeSortUsesPathAsDeterministicTieBreaker() {
        let b = FolderUsage(path: "/root/b", size: 10)
        let a = FolderUsage(path: "/root/a", size: 10)

        XCTAssertEqual(SortOption.sizeDesc.sorted([b, a]).map(\.path), [a.path, b.path])
        XCTAssertEqual(SortOption.sizeAsc.sorted([b, a]).map(\.path), [a.path, b.path])
    }

    func testNameSortUsesPathAsDeterministicTieBreakerWhenCaseInsensitiveComparisonMatches() {
        let lower = FolderUsage(path: "/root/a", size: 10)
        let upper = FolderUsage(path: "/root/A", size: 10)

        XCTAssertEqual(SortOption.name.sorted([lower, upper]).map(\.path), [upper.path, lower.path])
    }

    func testTreePresentationPreprocessorSortsEveryLevelWithoutChangingSource() {
        let small = FolderUsage(path: "/root/a/small", size: 10, isFile: true)
        let large = FolderUsage(path: "/root/a/large", size: 90, isFile: true)
        let largerFolder = FolderUsage(path: "/root/a", size: 100, children: [small, large])
        let smallerFolder = FolderUsage(path: "/root/b", size: 50)
        let source = [smallerFolder, largerFolder]

        let prepared = TreePresentationPreprocessor.sorted(source, by: .sizeDesc)

        XCTAssertEqual(prepared?.map(\.path), [largerFolder.path, smallerFolder.path])
        XCTAssertEqual(prepared?.first?.children.map(\.path), [large.path, small.path])
        XCTAssertEqual(source.map(\.path), [smallerFolder.path, largerFolder.path])
        XCTAssertEqual(source[1].children.map(\.path), [small.path, large.path])
    }

    func testSearchPresentationPreprocessorMatchesNameAndPathCaseInsensitivelyAndSorts() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("search-matching")
        let documentsURL = rootURL.appendingPathComponent("Documents")
        let photosURL = rootURL.appendingPathComponent("Photos")
        let report = FolderUsage(
            path: documentsURL.appendingPathComponent("Annual Report.pdf").path,
            size: 20,
            isFile: true
        )
        let trip = FolderUsage(
            path: photosURL.appendingPathComponent("Annual Trip.jpg").path,
            size: 40,
            isFile: true
        )
        let documents = FolderUsage(path: documentsURL.path, size: 20, children: [report])
        let photos = FolderUsage(path: photosURL.path, size: 40, children: [trip])
        let source = [documents, photos]

        let nameMatches = try XCTUnwrap(
            SearchPresentationPreprocessor.matches(
                in: source,
                query: "aNnUaL",
                sortedBy: .sizeDesc
            )
        )
        XCTAssertEqual([trip.path, report.path], nameMatches.map(\.path))

        let pathMatches = try XCTUnwrap(
            SearchPresentationPreprocessor.matches(
                in: source,
                query: "DOCUMENTS",
                sortedBy: .sizeDesc
            )
        )
        XCTAssertEqual([documents.path, report.path], pathMatches.map(\.path))
    }

    func testSearchPresentationPreprocessorLeavesSourceUnchangedAndTreatsWhitespaceAsEmpty() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("search-source")
        let first = FolderUsage(
            path: rootURL.appendingPathComponent("b/report.txt").path,
            size: 10,
            isFile: true
        )
        let second = FolderUsage(
            path: rootURL.appendingPathComponent("a/report.txt").path,
            size: 10,
            isFile: true
        )
        let source = [first, second]
        let original = source

        let matches = try XCTUnwrap(
            SearchPresentationPreprocessor.matches(
                in: source,
                query: "report",
                sortedBy: .sizeDesc
            )
        )

        XCTAssertEqual([second.path, first.path], matches.map(\.path))
        XCTAssertEqual(original, source)
        XCTAssertTrue(
            SearchPresentationPreprocessor.matches(
                in: source,
                query: "  \n\t ",
                sortedBy: .sizeDesc
            )?.isEmpty == true
        )
    }

    func testLargestFilesFindsNestedFilesAndExcludesFolders() throws {
        let rootURL = makeTemporaryFixtureRoot("largest-files-nested")
        let nestedURL = rootURL.appendingPathComponent("nested", isDirectory: true)
        let smaller = FolderUsage(
            path: nestedURL.appendingPathComponent("smaller.dat").path,
            size: 70,
            isFile: true
        )
        let larger = FolderUsage(
            path: rootURL.appendingPathComponent("larger.dat").path,
            size: 90,
            isFile: true
        )
        let nested = FolderUsage(path: nestedURL.path, size: 1_000, children: [smaller])
        let source = [nested, larger]

        let files = try XCTUnwrap(LargestFilesPresentationPreprocessor.largestFiles(in: source))

        XCTAssertEqual(files.map(\.path), [larger.path, smaller.path])
        XCTAssertTrue(files.allSatisfy(\.isFile))
        XCTAssertFalse(files.contains { $0.path == nested.path })
    }

    func testLargestFilesDefaultLimitKeepsTop100() throws {
        let rootURL = makeTemporaryFixtureRoot("largest-files-limit")
        let folderURL = rootURL.appendingPathComponent("scope", isDirectory: true)
        let files = (1...150).map { ordinal in
            FolderUsage(
                path: folderURL.appendingPathComponent("file-\(ordinal).dat").path,
                size: Int64(ordinal),
                isFile: true
            )
        }
        let source = [
            FolderUsage(
                path: folderURL.path,
                size: files.reduce(Int64(0)) { $0 + $1.size },
                children: files
            )
        ]

        let largest = try XCTUnwrap(LargestFilesPresentationPreprocessor.largestFiles(in: source))

        XCTAssertEqual(largest.count, 100)
        XCTAssertEqual(largest.first?.size, 150)
        XCTAssertEqual(largest.last?.size, 51)
        XCTAssertTrue(largest.allSatisfy(\.isFile))
    }

    func testLargestFilesUsesPathTieBreakerForEqualSizes() throws {
        let rootURL = makeTemporaryFixtureRoot("largest-files-tie")
        let b = FolderUsage(
            path: rootURL.appendingPathComponent("b.dat").path,
            size: 50,
            isFile: true
        )
        let a = FolderUsage(
            path: rootURL.appendingPathComponent("a.dat").path,
            size: 50,
            isFile: true
        )

        let largest = try XCTUnwrap(
            LargestFilesPresentationPreprocessor.largestFiles(in: [b, a], limit: 2)
        )

        XCTAssertEqual(largest.map(\.path), [a.path, b.path])
    }

    func testLargestFilesHandlesEdgeLimits() throws {
        let rootURL = makeTemporaryFixtureRoot("largest-files-edge")
        let file = FolderUsage(
            path: rootURL.appendingPathComponent("only.dat").path,
            size: 10,
            isFile: true
        )

        XCTAssertEqual(
            LargestFilesPresentationPreprocessor.largestFiles(in: [file], limit: 0),
            []
        )
        XCTAssertEqual(
            LargestFilesPresentationPreprocessor.largestFiles(in: [file], limit: -1),
            []
        )
        XCTAssertEqual(
            try XCTUnwrap(LargestFilesPresentationPreprocessor.largestFiles(in: [file], limit: 1)),
            [file]
        )
        XCTAssertEqual(
            try XCTUnwrap(LargestFilesPresentationPreprocessor.largestFiles(in: [file], limit: 10)),
            [file]
        )
        XCTAssertEqual(
            LargestFilesPresentationPreprocessor.largestFiles(in: [], limit: 10),
            []
        )
    }

    func testLargestFilesLeavesSourceSnapshotUnchanged() throws {
        let rootURL = makeTemporaryFixtureRoot("largest-files-source")
        let first = FolderUsage(
            path: rootURL.appendingPathComponent("first.dat").path,
            size: 10,
            isFile: true
        )
        let second = FolderUsage(
            path: rootURL.appendingPathComponent("second.dat").path,
            size: 20,
            isFile: true
        )
        let folder = FolderUsage(
            path: rootURL.path,
            size: 30,
            children: [first, second]
        )
        let source = [folder]
        let original = source

        _ = try XCTUnwrap(LargestFilesPresentationPreprocessor.largestFiles(in: source, limit: 1))

        XCTAssertEqual(source, original)
    }

    func testSunburstPresentationPreprocessorBuildsDeterministicDerivedModel() throws {
        let childSmall = FolderUsage(path: "/root/a/small", size: 20, isFile: true)
        let childLarge = FolderUsage(path: "/root/a/large", size: 40, isFile: true)
        let a = FolderUsage(path: "/root/a", size: 60, children: [childSmall, childLarge])
        let b = FolderUsage(path: "/root/b", size: 40)

        let prepared = SunburstPresentationPreprocessor.presentation(
            for: [b, a],
            totalSize: 100,
            levels: 4
        )

        let presentation = try XCTUnwrap(prepared)
        let segments = presentation.segments
        XCTAssertEqual(presentation.totalSize, 100)
        XCTAssertTrue(presentation.aggregates.isEmpty)
        XCTAssertEqual(segments.map(\.item.path), [a.path, childLarge.path, childSmall.path, b.path])
        XCTAssertEqual(segments.map(\.level), [0, 1, 1, 0])
        XCTAssertEqual(segments.map(\.paletteIndex), [0, 0, 0, 1])
        XCTAssertEqual(segments.map(\.canNavigate), [true, false, false, false])
        XCTAssertEqual(segments[0].fractionOfRoot, 0.6, accuracy: 0.0001)
        XCTAssertEqual(segments[1].fractionOfRoot, 0.4, accuracy: 0.0001)
        XCTAssertEqual(segments[2].fractionOfRoot, 0.2, accuracy: 0.0001)
        XCTAssertEqual(segments[3].fractionOfRoot, 0.4, accuracy: 0.0001)
        XCTAssertEqual(segments[0].startAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(segments[0].endAngle, 216, accuracy: 0.0001)
        XCTAssertEqual(segments[1].startAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(segments[1].endAngle, 144, accuracy: 0.0001)
        XCTAssertEqual(segments[2].startAngle, 144, accuracy: 0.0001)
        XCTAssertEqual(segments[2].endAngle, 216, accuracy: 0.0001)
        XCTAssertEqual(segments[3].startAngle, 216, accuracy: 0.0001)
        XCTAssertEqual(segments[3].endAngle, 360, accuracy: 0.0001)
    }

    func testSunburstPresentationPreprocessorUsesPathTieBreaker() {
        let b = FolderUsage(path: "/root/b", size: 50)
        let a = FolderUsage(path: "/root/a", size: 50)

        let prepared = SunburstPresentationPreprocessor.presentation(
            for: [b, a],
            totalSize: 100,
            levels: 1
        )

        XCTAssertEqual(prepared?.segments.map(\.item.path), [a.path, b.path])
        XCTAssertTrue(prepared?.aggregates.isEmpty == true)
    }

    func testSunburstPresentationAggregatesTinyTopLevelSiblingsWithoutChangingTotals() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("sunburst-top-level")
        let large = FolderUsage(path: rootURL.appendingPathComponent("large").path, size: 998)
        let tinyA = FolderUsage(path: rootURL.appendingPathComponent("tiny-a").path, size: 1)
        let tinyB = FolderUsage(path: rootURL.appendingPathComponent("tiny-b").path, size: 1)

        let presentation = try XCTUnwrap(
            SunburstPresentationPreprocessor.presentation(
                for: [tinyB, large, tinyA],
                totalSize: 1_000,
                levels: 1
            )
        )

        XCTAssertEqual(presentation.segments.map(\.item.path), [large.path])
        XCTAssertEqual(presentation.visualSegmentCount, 2)

        let aggregate = try XCTUnwrap(presentation.aggregates.first)
        XCTAssertEqual(aggregate.id, "aggregate-scope-0")
        XCTAssertEqual(aggregate.level, 0)
        XCTAssertEqual(aggregate.size, 2)
        XCTAssertEqual(aggregate.itemCount, 2)
        XCTAssertEqual(aggregate.paletteIndex, 1)
        XCTAssertEqual(aggregate.fractionOfRoot, 0.002, accuracy: 0.0001)
        XCTAssertEqual(aggregate.startAngle, 359.28, accuracy: 0.0001)
        XCTAssertEqual(aggregate.endAngle, 360, accuracy: 0.0001)
    }

    func testSunburstPresentationAggregatesTinyNestedSiblingsWithinParentBranch() throws {
        let parentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sunburst-nested")
            .appendingPathComponent("parent")
        let largeChild = FolderUsage(path: parentURL.appendingPathComponent("large").path, size: 998)
        let tinyA = FolderUsage(path: parentURL.appendingPathComponent("tiny-a").path, size: 1)
        let tinyB = FolderUsage(path: parentURL.appendingPathComponent("tiny-b").path, size: 1)
        let parent = FolderUsage(
            path: parentURL.path,
            size: 1_000,
            children: [tinyB, largeChild, tinyA]
        )

        let presentation = try XCTUnwrap(
            SunburstPresentationPreprocessor.presentation(
                for: [parent],
                totalSize: 1_000,
                levels: 2
            )
        )

        XCTAssertEqual(presentation.segments.map(\.item.path), [parent.path, largeChild.path])
        XCTAssertEqual(presentation.visualSegmentCount, 3)

        let aggregate = try XCTUnwrap(presentation.aggregates.first)
        XCTAssertEqual(aggregate.id, "aggregate-1-\(parent.path)")
        XCTAssertEqual(aggregate.level, 1)
        XCTAssertEqual(aggregate.size, 2)
        XCTAssertEqual(aggregate.itemCount, 2)
        XCTAssertEqual(aggregate.paletteIndex, 0)
        XCTAssertEqual(aggregate.fractionOfRoot, 0.002, accuracy: 0.0001)
        XCTAssertEqual(aggregate.startAngle, 359.28, accuracy: 0.0001)
        XCTAssertEqual(aggregate.endAngle, 360, accuracy: 0.0001)
    }

    func testSunburstPaletteIsRestrainedDepthAwareAndWrapsDeterministically() {
        let lightRoot = SunburstPalette.tone(paletteIndex: 0, level: 0, darkMode: false)
        let lightDeep = SunburstPalette.tone(paletteIndex: 0, level: 3, darkMode: false)
        let darkRoot = SunburstPalette.tone(paletteIndex: 0, level: 0, darkMode: true)

        XCTAssertEqual(SunburstPalette.tone(paletteIndex: SunburstPalette.count, level: 0, darkMode: false), lightRoot)
        XCTAssertEqual(lightRoot.hue, lightDeep.hue, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(lightRoot.saturation, 0.5)
        XCTAssertGreaterThan(lightRoot.saturation, lightDeep.saturation)
        XCTAssertGreaterThan(lightRoot.brightness, lightDeep.brightness)
        XCTAssertGreaterThan(darkRoot.brightness, lightRoot.brightness)
    }

    func testSyntheticPerformanceFixturesHaveExpectedShape() throws {
        let treeFixture = makeTreePerformanceFixture()
        XCTAssertEqual(nodeCount(treeFixture), 4_680)

        let sunburstFixture = makeSunburstPerformanceFixture()
        XCTAssertEqual(nodeCount(sunburstFixture), 8_276)

        let totalSize = sunburstFixture.reduce(Int64(0)) { $0 + $1.size }
        let presentation = try XCTUnwrap(
            SunburstPresentationPreprocessor.presentation(
                for: sunburstFixture,
                totalSize: totalSize,
                levels: 4
            )
        )
        XCTAssertEqual(presentation.segments.count, 84)
        XCTAssertEqual(presentation.aggregates.count, 64)
        XCTAssertEqual(presentation.visualSegmentCount, 148)
        XCTAssertTrue(presentation.aggregates.allSatisfy { $0.itemCount == 128 })

        let allIDs = presentation.segments.map(\.id) + presentation.aggregates.map(\.id)
        XCTAssertEqual(Set(allIDs).count, presentation.visualSegmentCount)
    }

    func testTreePresentationPreprocessorSyntheticPerformance() {
        let source = makeTreePerformanceFixture()
        var prepared: [FolderUsage]?

        measure(metrics: [XCTClockMetric()]) {
            prepared = TreePresentationPreprocessor.sorted(source, by: .sizeDesc)
        }

        XCTAssertEqual(nodeCount(prepared ?? []), 4_680)
    }

    func testSearchPresentationPreprocessorSyntheticPerformance() {
        let source = makeTreePerformanceFixture()
        let targetPath = source[7].children[7].children[7].children[7].path
        var matches: [FolderUsage]?

        measure(metrics: [XCTClockMetric()]) {
            matches = SearchPresentationPreprocessor.matches(
                in: source,
                query: targetPath,
                sortedBy: .sizeDesc
            )
        }

        XCTAssertEqual(1, matches?.count)
    }

    func testLargestFilesPresentationPreprocessorSyntheticPerformance() throws {
        let source = makeLargestFilesPerformanceFixture()
        var largest: [FolderUsage]?

        measure(metrics: [XCTClockMetric()]) {
            largest = LargestFilesPresentationPreprocessor.largestFiles(in: source)
        }

        let result = try XCTUnwrap(largest)
        XCTAssertEqual(result.count, 100)
        XCTAssertTrue(result.allSatisfy(\.isFile))
        XCTAssertTrue(
            zip(result, result.dropFirst()).allSatisfy { lhs, rhs in
                lhs.size > rhs.size || (lhs.size == rhs.size && lhs.path < rhs.path)
            }
        )
    }

    func testSunburstPresentationPreprocessorSyntheticPerformance() {
        let source = makeSunburstPerformanceFixture()
        let totalSize = source.reduce(Int64(0)) { $0 + $1.size }
        var presentation: SunburstPresentation?

        measure(metrics: [XCTClockMetric()]) {
            presentation = SunburstPresentationPreprocessor.presentation(
                for: source,
                totalSize: totalSize,
                levels: 4
            )
        }

        XCTAssertEqual(presentation?.segments.count, 84)
        XCTAssertEqual(presentation?.aggregates.count, 64)
        XCTAssertEqual(presentation?.visualSegmentCount, 148)
    }

    func testFormatBytesUsesNextUnitAtExactBoundary() {
        XCTAssertEqual(formatBytes(1024), "1.0 KB")
    }

    @MainActor
    func testFullDiskAccessSettingsUsesExpectedRouteAndInjectedOpener() throws {
        let url = try XCTUnwrap(FullDiskAccessSettings.url)
        XCTAssertEqual(url.absoluteString, FullDiskAccessSettings.urlString)
        XCTAssertEqual(
            url.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        )

        var openedURL: URL?
        let opened = FullDiskAccessSettings.open(using: { candidate in
            openedURL = candidate
            return true
        })

        XCTAssertTrue(opened)
        XCTAssertEqual(openedURL, url)
        XCTAssertFalse(FullDiskAccessSettings.open(using: { _ in false }))
    }

    private func makeTreePerformanceFixture() -> [FolderUsage] {
        (0..<8).map { rootIndex in
            makeSyntheticNode(
                path: "/fixture/root-\(rootIndex)",
                branchingFactor: 8,
                remainingDepth: 3,
                ordinal: rootIndex + 1
            )
        }
    }

    private func makeSyntheticNode(
        path: String,
        branchingFactor: Int,
        remainingDepth: Int,
        ordinal: Int
    ) -> FolderUsage {
        guard remainingDepth > 0 else {
            return FolderUsage(
                path: path,
                size: Int64((ordinal % 97) + 1),
                isFile: true
            )
        }

        let children = (0..<branchingFactor).map { childIndex in
            makeSyntheticNode(
                path: "\(path)/node-\(childIndex)",
                branchingFactor: branchingFactor,
                remainingDepth: remainingDepth - 1,
                ordinal: ordinal * branchingFactor + childIndex + 1
            )
        }

        return FolderUsage(
            path: path,
            size: children.reduce(Int64(0)) { $0 + $1.size },
            children: children
        )
    }

    private func makeLargestFilesPerformanceFixture() -> [FolderUsage] {
        let rootURL = makeTemporaryFixtureRoot("largest-files-performance")

        return (0..<12).map { folderIndex in
            let folderURL = rootURL.appendingPathComponent("folder-\(folderIndex)", isDirectory: true)
            let files = (0..<1_000).map { fileIndex in
                let ordinal = folderIndex * 1_000 + fileIndex
                return FolderUsage(
                    path: folderURL.appendingPathComponent("file-\(fileIndex).dat").path,
                    size: Int64((ordinal % 997) + 1),
                    isFile: true
                )
            }
            return FolderUsage(
                path: folderURL.path,
                size: files.reduce(Int64(0)) { $0 + $1.size },
                children: files
            )
        }
    }

    private func makeTemporaryFixtureRoot(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeSunburstPerformanceFixture() -> [FolderUsage] {
        (0..<4).map { rootIndex in
            let rootPath = "/sunburst/root-\(rootIndex)"
            let children = (0..<4).map { childIndex in
                let childPath = "\(rootPath)/child-\(childIndex)"
                let grandchildren = (0..<4).map { grandchildIndex in
                    let grandchildPath = "\(childPath)/group-\(grandchildIndex)"
                    let leaves = (0..<128).map { leafIndex in
                        FolderUsage(
                            path: "\(grandchildPath)/leaf-\(leafIndex)",
                            size: 1,
                            isFile: true
                        )
                    }
                    return FolderUsage(path: grandchildPath, size: 128, children: leaves)
                }
                return FolderUsage(path: childPath, size: 512, children: grandchildren)
            }
            return FolderUsage(path: rootPath, size: 2_048, children: children)
        }
    }

    private func nodeCount(_ items: [FolderUsage]) -> Int {
        items.reduce(0) { partialResult, item in
            partialResult + 1 + nodeCount(item.children)
        }
    }
}

private actor R69HeartbeatRecorder {
    private var delays: [Double] = []

    func append(_ delay: Double) {
        delays.append(delay)
    }

    func snapshot() -> [Double] {
        delays
    }
}

private struct R69HeartbeatStats {
    let samples: Int
    let medianMilliseconds: Double
    let p95Milliseconds: Double
    let maxMilliseconds: Double
}

extension FolderUsageTests {
    @MainActor
    func testR69PresentationStateResponsivenessResearch() async throws {
        guard FileManager.default.fileExists(
            atPath: "/tmp/diskusage-r69-research-enabled"
        ) else {
            throw XCTSkip("R6.9 research-only responsiveness harness")
        }

        try await r69RecordIdleHeartbeat(label: "idle-before")

        do {
            let source = r69TreeFixture(rootCount: 220)
            XCTAssertEqual(nodeCount(source), 128_700)

            let state = TreePresentationState()
            var itemEvents = 0
            var preparingEvents = 0
            let itemObserver = state.$items.dropFirst().sink { _ in
                itemEvents += 1
            }
            let preparingObserver = state.$isPreparing.dropFirst().sink { _ in
                preparingEvents += 1
            }

            try await r69MeasureRounds(
                label: "tree",
                rounds: 5,
                start: {
                    state.prepare(source, by: .sizeDesc, preservingCurrent: false)
                },
                isFinished: {
                    !state.isPreparing && !state.items.isEmpty
                },
                validate: {
                    XCTAssertEqual(self.nodeCount(state.items), 128_700)
                },
                observerCounts: {
                    (itemEvents, preparingEvents)
                }
            )

            XCTAssertGreaterThan(itemEvents, 0)
            XCTAssertGreaterThan(preparingEvents, 0)
            withExtendedLifetime((itemObserver, preparingObserver)) {}
            state.cancel()
        }

        do {
            let source = r69TreeFixture(rootCount: 220)
            XCTAssertEqual(nodeCount(source), 128_700)

            let state = SearchPresentationState()
            var itemEvents = 0
            var preparingEvents = 0
            let itemObserver = state.$items.dropFirst().sink { _ in
                itemEvents += 1
            }
            let preparingObserver = state.$isPreparing.dropFirst().sink { _ in
                preparingEvents += 1
            }

            try await r69MeasureRounds(
                label: "search-broad",
                rounds: 5,
                start: {
                    state.prepare(
                        source,
                        query: "node-",
                        by: .sizeDesc,
                        preservingCurrent: false
                    )
                },
                isFinished: {
                    !state.isPreparing && state.items.count == 128_480
                },
                validate: {
                    XCTAssertEqual(state.items.count, 128_480)
                },
                observerCounts: {
                    (itemEvents, preparingEvents)
                }
            )

            XCTAssertGreaterThan(itemEvents, 0)
            XCTAssertGreaterThan(preparingEvents, 0)
            withExtendedLifetime((itemObserver, preparingObserver)) {}
            state.cancel()
        }

        do {
            let source = r69LargestFilesFixture(folderCount: 128)
            XCTAssertEqual(nodeCount(source), 128_128)

            let state = LargestFilesPresentationState()
            var itemEvents = 0
            var preparingEvents = 0
            let itemObserver = state.$items.dropFirst().sink { _ in
                itemEvents += 1
            }
            let preparingObserver = state.$isPreparing.dropFirst().sink { _ in
                preparingEvents += 1
            }

            try await r69MeasureRounds(
                label: "largest-files",
                rounds: 5,
                start: {
                    state.prepare(source)
                },
                isFinished: {
                    !state.isPreparing && state.items.count == 100
                },
                validate: {
                    XCTAssertEqual(state.items.count, 100)
                    XCTAssertTrue(state.items.allSatisfy(\.isFile))
                    XCTAssertTrue(
                        zip(state.items, state.items.dropFirst()).allSatisfy { lhs, rhs in
                            lhs.size > rhs.size
                                || (lhs.size == rhs.size && lhs.path < rhs.path)
                        }
                    )
                },
                observerCounts: {
                    (itemEvents, preparingEvents)
                }
            )

            XCTAssertGreaterThan(itemEvents, 0)
            XCTAssertGreaterThan(preparingEvents, 0)
            withExtendedLifetime((itemObserver, preparingObserver)) {}
            state.cancel()
        }

        do {
            let leafCount = 2_048
            let source = r69SunburstFixture(leafCountPerGroup: leafCount)
            let totalSize = Int64(64 * leafCount)
            XCTAssertEqual(nodeCount(source), 131_156)

            let state = SunburstPresentationState()
            var modelEvents = 0
            var preparingEvents = 0
            let modelObserver = state.$model.dropFirst().sink { _ in
                modelEvents += 1
            }
            let preparingObserver = state.$isPreparing.dropFirst().sink { _ in
                preparingEvents += 1
            }

            try await r69MeasureRounds(
                label: "sunburst",
                rounds: 5,
                start: {
                    state.prepare(items: source, totalSize: totalSize, levels: 4)
                },
                isFinished: {
                    !state.isPreparing && state.model.visualSegmentCount == 148
                },
                validate: {
                    XCTAssertEqual(state.model.totalSize, totalSize)
                    XCTAssertEqual(state.model.segments.count, 84)
                    XCTAssertEqual(state.model.aggregates.count, 64)
                    XCTAssertEqual(state.model.visualSegmentCount, 148)
                    XCTAssertTrue(
                        state.model.aggregates.allSatisfy {
                            $0.itemCount == leafCount
                        }
                    )
                },
                observerCounts: {
                    (modelEvents, preparingEvents)
                }
            )

            XCTAssertGreaterThan(modelEvents, 0)
            XCTAssertGreaterThan(preparingEvents, 0)
            withExtendedLifetime((modelObserver, preparingObserver)) {}
            state.cancel()
        }

        try await r69RecordIdleHeartbeat(label: "idle-after")
    }

    @MainActor
    func testR69PresentationStateSupersessionResearch() async throws {
        guard FileManager.default.fileExists(
            atPath: "/tmp/diskusage-r69-research-enabled"
        ) else {
            throw XCTSkip("R6.9 research-only supersession harness")
        }

        let source = r69TreeFixture(rootCount: 220)
        let replacement = [
            FolderUsage(
                path: "/r69/replacement",
                size: 1,
                isFile: true
            )
        ]
        let state = TreePresentationState()

        state.prepare(source, by: .sizeDesc, preservingCurrent: false)
        state.prepare(replacement, by: .sizeDesc, preservingCurrent: false)

        try await r69WaitUntil(timeoutSeconds: 5) {
            !state.isPreparing && state.items == replacement
        }
        XCTAssertEqual(state.items, replacement)

        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(
            state.items,
            replacement,
            "A cancelled stale generation must not overwrite the newer published result"
        )

        r69Write(
            "R69_SUPERSESSION result=pass final_count=\(state.items.count)"
        )
        state.cancel()
    }

    @MainActor
    private func r69MeasureRounds(
        label: String,
        rounds: Int,
        start: () -> Void,
        isFinished: () -> Bool,
        validate: () -> Void,
        observerCounts: () -> (Int, Int)
    ) async throws {
        let clock = ContinuousClock()

        for round in 1...rounds {
            let outputEventsBefore = observerCounts().0
            let preparingEventsBefore = observerCounts().1
            let recorder = R69HeartbeatRecorder()
            let heartbeat = r69HeartbeatTask(recorder: recorder)

            let started = clock.now
            start()
            XCTAssertFalse(isFinished(), "\(label) round \(round) completed synchronously")

            try await r69WaitUntil(timeoutSeconds: 15, condition: isFinished)
            let completionSeconds = r69Seconds(clock.now - started)

            heartbeat.cancel()
            await heartbeat.value
            let heartbeatValues = await recorder.snapshot()
            let stats = r69HeartbeatStats(heartbeatValues)

            let outputEvents = observerCounts().0 - outputEventsBefore
            let preparingEvents = observerCounts().1 - preparingEventsBefore
            XCTAssertGreaterThan(outputEvents, 0)
            XCTAssertGreaterThan(preparingEvents, 0)
            XCTAssertGreaterThan(stats.samples, 0)

            validate()

            r69Write(
                "R69_STATE label=\(label) round=\(round) "
                    + "completion_s=\(String(format: "%.6f", completionSeconds)) "
                    + "heartbeat_samples=\(stats.samples) "
                    + "heartbeat_median_ms=\(String(format: "%.3f", stats.medianMilliseconds)) "
                    + "heartbeat_p95_ms=\(String(format: "%.3f", stats.p95Milliseconds)) "
                    + "heartbeat_max_ms=\(String(format: "%.3f", stats.maxMilliseconds)) "
                    + "output_events=\(outputEvents) preparing_events=\(preparingEvents)"
            )
        }
    }

    @MainActor
    private func r69RecordIdleHeartbeat(label: String) async throws {
        let recorder = R69HeartbeatRecorder()
        let heartbeat = r69HeartbeatTask(recorder: recorder)

        try await Task.sleep(for: .seconds(1))

        heartbeat.cancel()
        await heartbeat.value
        let stats = r69HeartbeatStats(await recorder.snapshot())
        XCTAssertGreaterThan(stats.samples, 0)

        r69Write(
            "R69_IDLE label=\(label) heartbeat_samples=\(stats.samples) "
                + "heartbeat_median_ms=\(String(format: "%.3f", stats.medianMilliseconds)) "
                + "heartbeat_p95_ms=\(String(format: "%.3f", stats.p95Milliseconds)) "
                + "heartbeat_max_ms=\(String(format: "%.3f", stats.maxMilliseconds))"
        )
    }

    private func r69HeartbeatTask(
        recorder: R69HeartbeatRecorder
    ) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) {
            let clock = ContinuousClock()

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2))
                guard !Task.isCancelled else { break }

                let requested = clock.now
                await MainActor.run {}
                let delay = r69Seconds(clock.now - requested)
                await recorder.append(delay)
            }
        }
    }

    @MainActor
    private func r69WaitUntil(
        timeoutSeconds: Double,
        condition: () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let started = clock.now

        while !condition() {
            if r69Seconds(clock.now - started) >= timeoutSeconds {
                XCTFail("R6.9 research operation timed out")
                return
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    private func r69Write(_ line: String) {
        let path = "/tmp/diskusage-r69-results.log"
        guard let handle = try? FileHandle(
            forWritingTo: URL(fileURLWithPath: path)
        ) else {
            XCTFail("R6.9 research results file is unavailable")
            return
        }

        handle.seekToEndOfFile()
        handle.write(Data((line + "\n").utf8))
        handle.closeFile()
    }

    private func r69TreeFixture(rootCount: Int) -> [FolderUsage] {
        (0..<rootCount).map { rootIndex in
            r69TreeNode(
                path: String(format: "/r69/tree/root-%03d", rootIndex),
                remainingDepth: 3,
                ordinal: rootIndex + 1
            )
        }
    }

    private func r69TreeNode(
        path: String,
        remainingDepth: Int,
        ordinal: Int
    ) -> FolderUsage {
        guard remainingDepth > 0 else {
            return FolderUsage(
                path: path,
                size: Int64((ordinal % 997) + 1),
                isFile: true
            )
        }

        let children = (0..<8).map { childIndex in
            r69TreeNode(
                path: "\(path)/node-\(childIndex)",
                remainingDepth: remainingDepth - 1,
                ordinal: ordinal * 8 + childIndex + 1
            )
        }

        return FolderUsage(
            path: path,
            size: children.reduce(Int64(0)) { $0 + $1.size },
            children: children
        )
    }

    private func r69LargestFilesFixture(folderCount: Int) -> [FolderUsage] {
        (0..<folderCount).map { folderIndex in
            let folderPath = String(
                format: "/r69/largest/folder-%03d",
                folderIndex
            )
            let files = (0..<1_000).map { fileIndex in
                let ordinal = folderIndex * 1_000 + fileIndex
                return FolderUsage(
                    path: String(
                        format: "%@/file-%04d.dat",
                        folderPath,
                        fileIndex
                    ),
                    size: Int64((ordinal % 100_003) + 1),
                    isFile: true
                )
            }

            return FolderUsage(
                path: folderPath,
                size: files.reduce(Int64(0)) { $0 + $1.size },
                children: files
            )
        }
    }

    private func r69SunburstFixture(
        leafCountPerGroup: Int
    ) -> [FolderUsage] {
        (0..<4).map { rootIndex in
            let rootPath = "/r69/sunburst/root-\(rootIndex)"
            let children = (0..<4).map { childIndex in
                let childPath = "\(rootPath)/child-\(childIndex)"
                let groups = (0..<4).map { groupIndex in
                    let groupPath = "\(childPath)/group-\(groupIndex)"
                    let leaves = (0..<leafCountPerGroup).map { leafIndex in
                        FolderUsage(
                            path: "\(groupPath)/leaf-\(leafIndex)",
                            size: 1,
                            isFile: true
                        )
                    }
                    return FolderUsage(
                        path: groupPath,
                        size: Int64(leafCountPerGroup),
                        children: leaves
                    )
                }
                return FolderUsage(
                    path: childPath,
                    size: Int64(4 * leafCountPerGroup),
                    children: groups
                )
            }
            return FolderUsage(
                path: rootPath,
                size: Int64(16 * leafCountPerGroup),
                children: children
            )
        }
    }
}

private extension R69HeartbeatStats {
    init(_ values: [Double]) {
        let milliseconds = values.map { $0 * 1_000 }.sorted()

        guard !milliseconds.isEmpty else {
            self.init(
                samples: 0,
                medianMilliseconds: 0,
                p95Milliseconds: 0,
                maxMilliseconds: 0
            )
            return
        }

        let medianIndex = milliseconds.count / 2
        let p95Index = min(
            milliseconds.count - 1,
            Int(
                ceil(Double(milliseconds.count - 1) * 0.95)
            )
        )

        self.init(
            samples: milliseconds.count,
            medianMilliseconds: milliseconds[medianIndex],
            p95Milliseconds: milliseconds[p95Index],
            maxMilliseconds: milliseconds[milliseconds.count - 1]
        )
    }
}

private func r69Seconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
        + Double(components.attoseconds) / 1_000_000_000_000_000_000
}
