import Foundation
import XCTest
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
