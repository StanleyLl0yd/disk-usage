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

    func testSunburstPresentationPreprocessorBuildsDeterministicGeometry() {
        let childSmall = FolderUsage(path: "/root/a/small", size: 20, isFile: true)
        let childLarge = FolderUsage(path: "/root/a/large", size: 40, isFile: true)
        let a = FolderUsage(path: "/root/a", size: 60, children: [childSmall, childLarge])
        let b = FolderUsage(path: "/root/b", size: 40)

        let prepared = SunburstPresentationPreprocessor.segments(
            for: [b, a],
            totalSize: 100,
            levels: 4
        )

        let segments = try! XCTUnwrap(prepared)
        XCTAssertEqual(segments.map(\.item.path), [a.path, childLarge.path, childSmall.path, b.path])
        XCTAssertEqual(segments.map(\.level), [0, 1, 1, 0])
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

        let prepared = SunburstPresentationPreprocessor.segments(
            for: [b, a],
            totalSize: 100,
            levels: 1
        )

        XCTAssertEqual(prepared?.map(\.item.path), [a.path, b.path])
    }

    func testSyntheticPerformanceFixturesHaveExpectedShape() throws {
        let treeFixture = makeTreePerformanceFixture()
        XCTAssertEqual(nodeCount(treeFixture), 4_680)

        let sunburstFixture = makeSunburstPerformanceFixture()
        XCTAssertEqual(nodeCount(sunburstFixture), 8_276)

        let totalSize = sunburstFixture.reduce(Int64(0)) { $0 + $1.size }
        let segments = try XCTUnwrap(
            SunburstPresentationPreprocessor.segments(
                for: sunburstFixture,
                totalSize: totalSize,
                levels: 4
            )
        )
        XCTAssertEqual(segments.count, 84)
        XCTAssertEqual(Set(segments.map(\.id)).count, segments.count)
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
        var segments: [SunburstSegment]?

        measure(metrics: [XCTClockMetric()]) {
            segments = SunburstPresentationPreprocessor.segments(
                for: source,
                totalSize: totalSize,
                levels: 4
            )
        }

        XCTAssertEqual(segments?.count, 84)
    }

    func testFormatBytesUsesNextUnitAtExactBoundary() {
        XCTAssertEqual(formatBytes(1024), "1.0 KB")
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
