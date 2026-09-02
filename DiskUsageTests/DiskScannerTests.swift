import Foundation
import XCTest
@testable import DiskUsage

final class DiskScannerTests: XCTestCase {
    func testHiddenFilesSettingControlsEnumeration() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
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

    private func flatten(_ item: FolderUsage) -> [FolderUsage] {
        [item] + item.children.flatMap(flatten)
    }
}
