import Foundation

nonisolated private let sizeUnits = ["B", "KB", "MB", "GB", "TB"]
private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return formatter
}()

nonisolated func formatBytes(_ bytes: Int64) -> String {
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024 && unitIndex < sizeUnits.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    return String(format: "%.1f %@", value, sizeUnits[unitIndex])
}

nonisolated func formatPercent(_ part: Int64, of total: Int64) -> String {
    guard total > 0, part > 0 else { return "0.0 %" }
    return String(format: "%.1f %%", Double(part) / Double(total) * 100)
}

func formatNumber(_ number: Int64) -> String {
    numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

nonisolated struct ScanProgress: Equatable, Sendable {
    var filesScanned: Int64 = 0
    var bytesFound: Int64 = 0
    var currentFolder: String = ""
}

nonisolated enum SortOption: String, CaseIterable, Identifiable, Sendable {
    case sizeDesc, sizeAsc, name

    var id: Self { self }

    var title: String {
        switch self {
        case .sizeDesc: String(localized: "sort.sizeDescending", defaultValue: "Size ↓")
        case .sizeAsc: String(localized: "sort.sizeAscending", defaultValue: "Size ↑")
        case .name: String(localized: "sort.name", defaultValue: "Name")
        }
    }

    func sorted(_ items: [FolderUsage]) -> [FolderUsage] {
        items.sorted { lhs, rhs in
            switch self {
            case .sizeDesc:
                return lhs.size != rhs.size ? lhs.size > rhs.size : lhs.path < rhs.path
            case .sizeAsc:
                return lhs.size != rhs.size ? lhs.size < rhs.size : lhs.path < rhs.path
            case .name:
                let comparison = lhs.path.localizedCaseInsensitiveCompare(rhs.path)
                return comparison == .orderedSame
                    ? lhs.path < rhs.path
                    : comparison == .orderedAscending
            }
        }
    }
}

nonisolated enum TreePresentationPreprocessor {
    static func sorted(_ items: [FolderUsage], by option: SortOption) -> [FolderUsage]? {
        guard !isCancelled else { return nil }

        var prepared: [FolderUsage] = []
        prepared.reserveCapacity(items.count)
        for item in items {
            guard let sortedItem = sorted(item, by: option) else { return nil }
            prepared.append(sortedItem)
        }

        guard !isCancelled else { return nil }
        return option.sorted(prepared)
    }

    private static func sorted(_ item: FolderUsage, by option: SortOption) -> FolderUsage? {
        guard !isCancelled else { return nil }

        var children: [FolderUsage] = []
        children.reserveCapacity(item.children.count)
        for child in item.children {
            guard let sortedChild = sorted(child, by: option) else { return nil }
            children.append(sortedChild)
        }

        guard !isCancelled else { return nil }
        return FolderUsage(
            path: item.path,
            size: item.size,
            isFile: item.isFile,
            children: option.sorted(children)
        )
    }

    private static var isCancelled: Bool {
        withUnsafeCurrentTask { task in
            task?.isCancelled ?? false
        }
    }
}

nonisolated struct SunburstPresentation: Equatable, Sendable {
    let totalSize: Int64
    let segments: [SunburstSegment]

    static let empty = SunburstPresentation(totalSize: 0, segments: [])
}

nonisolated struct SunburstSegment: Identifiable, Equatable, Sendable {
    let id: String
    let item: FolderUsage
    let level: Int
    let startAngle: Double
    let endAngle: Double
    let fractionOfRoot: Double
    let hue: Double
    let canNavigate: Bool
}

nonisolated enum SunburstPresentationPreprocessor {
    static func presentation(
        for items: [FolderUsage],
        totalSize: Int64,
        levels: Int = 4
    ) -> SunburstPresentation? {
        guard !isCancelled else { return nil }
        guard totalSize > 0, levels > 0 else {
            return SunburstPresentation(totalSize: totalSize, segments: [])
        }

        let sorted = sortedBySize(items)
        var result: [SunburstSegment] = []
        var angle = 0.0

        for (index, item) in sorted.enumerated() {
            guard !isCancelled else { return nil }

            let span = 360 * Double(item.size) / Double(totalSize)
            let endAngle = angle + span
            defer { angle = endAngle }
            guard span >= 1 else { continue }

            let hue = (Double(index) / Double(max(sorted.count, 1)) + 0.08)
                .truncatingRemainder(dividingBy: 1)
            result.append(
                segment(
                    item: item,
                    level: 0,
                    startAngle: angle,
                    endAngle: endAngle,
                    rootTotalSize: totalSize,
                    hue: hue
                )
            )

            guard build(
                item.children,
                parentTotalSize: item.size,
                rootTotalSize: totalSize,
                level: 1,
                levels: levels,
                start: angle,
                end: endAngle,
                hue: hue,
                result: &result
            ) else { return nil }
        }

        return SunburstPresentation(totalSize: totalSize, segments: result)
    }

    private static func build(
        _ items: [FolderUsage],
        parentTotalSize: Int64,
        rootTotalSize: Int64,
        level: Int,
        levels: Int,
        start: Double,
        end: Double,
        hue: Double,
        result: inout [SunburstSegment]
    ) -> Bool {
        guard !isCancelled else { return false }
        guard level < levels, parentTotalSize > 0, !items.isEmpty else { return true }

        var angle = start
        for item in sortedBySize(items) {
            guard !isCancelled else { return false }

            let span = (end - start) * Double(item.size) / Double(parentTotalSize)
            let endAngle = angle + span
            defer { angle = endAngle }
            guard span >= 1 else { continue }

            result.append(
                segment(
                    item: item,
                    level: level,
                    startAngle: angle,
                    endAngle: endAngle,
                    rootTotalSize: rootTotalSize,
                    hue: hue
                )
            )

            guard build(
                item.children,
                parentTotalSize: item.size,
                rootTotalSize: rootTotalSize,
                level: level + 1,
                levels: levels,
                start: angle,
                end: endAngle,
                hue: hue,
                result: &result
            ) else { return false }
        }

        return true
    }

    private static func segment(
        item: FolderUsage,
        level: Int,
        startAngle: Double,
        endAngle: Double,
        rootTotalSize: Int64,
        hue: Double
    ) -> SunburstSegment {
        SunburstSegment(
            id: "\(item.path)-\(level)",
            item: item,
            level: level,
            startAngle: startAngle,
            endAngle: endAngle,
            fractionOfRoot: Double(item.size) / Double(rootTotalSize),
            hue: hue,
            canNavigate: !item.children.isEmpty
        )
    }

    private static func sortedBySize(_ items: [FolderUsage]) -> [FolderUsage] {
        items.sorted { lhs, rhs in
            lhs.size != rhs.size ? lhs.size > rhs.size : lhs.path < rhs.path
        }
    }

    private static var isCancelled: Bool {
        withUnsafeCurrentTask { task in
            task?.isCancelled ?? false
        }
    }
}
