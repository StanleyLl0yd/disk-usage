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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func flatten(_ item: FolderUsage) -> [FolderUsage] {
        [item] + item.children.flatMap(flatten)
    }
}
