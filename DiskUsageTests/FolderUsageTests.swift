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

    func testSunburstPresentationPreprocessorIsDeterministicAndDoesNotMutateSource() {
        let zChild = FolderUsage(path: "/root/a/z", size: 25, isFile: true)
        let aChild = FolderUsage(path: "/root/a/a", size: 25, isFile: true)
        let folderB = FolderUsage(path: "/root/b", size: 50)
        let folderA = FolderUsage(path: "/root/a", size: 50, children: [zChild, aChild])
        let source = [folderB, folderA]

        let prepared = SunburstPresentationPreprocessor.prepare(
            items: source,
            totalSize: 100,
            navigation: []
        )

        let topLevel = prepared?.segments.filter { $0.level == 0 }
        let nested = prepared?.segments.filter { $0.level == 1 }

        XCTAssertEqual(topLevel?.map(\.path), [folderA.path, folderB.path])
        XCTAssertEqual(nested?.map(\.path), [aChild.path, zChild.path])
        XCTAssertEqual(topLevel?.map(\.startAngle), [0, 180])
        XCTAssertEqual(topLevel?.map(\.endAngle), [180, 360])
        XCTAssertEqual(source.map(\.path), [folderB.path, folderA.path])
        XCTAssertEqual(source[1].children.map(\.path), [zChild.path, aChild.path])
    }

    func testSunburstPresentationPreprocessorResolvesNavigation() {
        let leaf = FolderUsage(path: "/root/folder/leaf", size: 100, isFile: true)
        let folder = FolderUsage(path: "/root/folder", size: 100, children: [leaf])

        let prepared = SunburstPresentationPreprocessor.prepare(
            items: [folder],
            totalSize: 100,
            navigation: [folder.path]
        )

        XCTAssertEqual(prepared?.navigation.map(\.path), [folder.path])
        XCTAssertEqual(prepared?.total, folder.size)
        XCTAssertEqual(prepared?.segments.map(\.path), [leaf.path])
        XCTAssertEqual(prepared?.segments.map(\.level), [0])
    }

    func testSunburstPresentationPreprocessorPreservesDepthCapAndMinimumSpan() {
        let deepest = FolderUsage(path: "/root/a/b/c/d", size: 100, isFile: true)
        let levelThree = FolderUsage(path: "/root/a/b/c", size: 100, children: [deepest])
        let levelTwo = FolderUsage(path: "/root/a/b", size: 100, children: [levelThree])
        let levelOne = FolderUsage(path: "/root/a", size: 100, children: [levelTwo])
        let tiny = FolderUsage(path: "/root/tiny", size: 1, isFile: true)
        let large = FolderUsage(path: "/root/large", size: 999, isFile: true)

        let depthPrepared = SunburstPresentationPreprocessor.prepare(
            items: [levelOne],
            totalSize: 100,
            navigation: []
        )
        let filteredPrepared = SunburstPresentationPreprocessor.prepare(
            items: [tiny, large],
            totalSize: 1_000,
            navigation: []
        )

        XCTAssertEqual(depthPrepared?.segments.map(\.level), [0, 1, 2, 3])
        XCTAssertFalse(depthPrepared?.segments.contains(where: { $0.path == deepest.path }) == true)
        XCTAssertEqual(filteredPrepared?.segments.map(\.path), [large.path])
    }

    func testFormatBytesUsesNextUnitAtExactBoundary() {
        XCTAssertEqual(formatBytes(1024), "1.0 KB")
    }
}
