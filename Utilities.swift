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
    let aggregates: [SunburstAggregateSegment]

    init(
        totalSize: Int64,
        segments: [SunburstSegment],
        aggregates: [SunburstAggregateSegment] = []
    ) {
        self.totalSize = totalSize
        self.segments = segments
        self.aggregates = aggregates
    }

    var visualSegmentCount: Int { segments.count + aggregates.count }

    static let empty = SunburstPresentation(totalSize: 0, segments: [])
}

nonisolated struct SunburstTone: Equatable, Sendable {
    let hue: Double
    let saturation: Double
    let brightness: Double
}

nonisolated enum SunburstPalette {
    static let count = 8

    static func tone(paletteIndex: Int, level: Int, darkMode: Bool) -> SunburstTone {
        let normalizedIndex = ((paletteIndex % count) + count) % count
        let depth = Double(min(max(level, 0), 3))

        return SunburstTone(
            hue: hue(at: normalizedIndex),
            saturation: max(0.26, 0.46 - depth * 0.045),
            brightness: darkMode
                ? max(0.70, 0.84 - depth * 0.035)
                : max(0.62, 0.80 - depth * 0.05)
        )
    }

    private static func hue(at index: Int) -> Double {
        switch index {
        case 0: 0.58
        case 1: 0.49
        case 2: 0.38
        case 3: 0.11
        case 4: 0.04
        case 5: 0.81
        case 6: 0.72
        default: 0.64
        }
    }
}

nonisolated struct SunburstSegment: Identifiable, Equatable, Sendable {
    let id: String
    let item: FolderUsage
    let level: Int
    let startAngle: Double
    let endAngle: Double
    let fractionOfRoot: Double
    let paletteIndex: Int
    let canNavigate: Bool
}

nonisolated struct SunburstAggregateSegment: Identifiable, Equatable, Sendable {
    let id: String
    let level: Int
    let startAngle: Double
    let endAngle: Double
    let size: Int64
    let itemCount: Int
    let fractionOfRoot: Double
    let paletteIndex: Int
}

nonisolated enum SunburstPresentationPreprocessor {
    private static let minimumIndividualSpan = 1.0

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
        var aggregates: [SunburstAggregateSegment] = []
        var angle = 0.0
        var aggregateStart: Double?
        var aggregateSize: Int64 = 0
        var aggregateCount = 0
        var aggregatePaletteIndex: Int?

        for (index, item) in sorted.enumerated() {
            guard !isCancelled else { return nil }

            let span = 360 * Double(item.size) / Double(totalSize)
            let endAngle = angle + span
            defer { angle = endAngle }
            guard span > 0 else { continue }

            let paletteIndex = index % SunburstPalette.count
            guard span >= minimumIndividualSpan else {
                if aggregateStart == nil {
                    aggregateStart = angle
                    aggregatePaletteIndex = paletteIndex
                }
                aggregateSize += item.size
                aggregateCount += 1
                continue
            }

            result.append(
                segment(
                    item: item,
                    level: 0,
                    startAngle: angle,
                    endAngle: endAngle,
                    rootTotalSize: totalSize,
                    paletteIndex: paletteIndex
                )
            )

            guard build(
                item.children,
                parentID: item.path,
                parentTotalSize: item.size,
                rootTotalSize: totalSize,
                level: 1,
                levels: levels,
                start: angle,
                end: endAngle,
                paletteIndex: paletteIndex,
                result: &result,
                aggregates: &aggregates
            ) else { return nil }
        }

        if let aggregateStart,
           let aggregatePaletteIndex,
           aggregateSize > 0,
           aggregateCount > 0 {
            aggregates.append(
                aggregateSegment(
                    id: "other:scope:0",
                    level: 0,
                    startAngle: aggregateStart,
                    endAngle: 360,
                    size: aggregateSize,
                    itemCount: aggregateCount,
                    rootTotalSize: totalSize,
                    paletteIndex: aggregatePaletteIndex
                )
            )
        }

        return SunburstPresentation(
            totalSize: totalSize,
            segments: result,
            aggregates: aggregates
        )
    }

    private static func build(
        _ items: [FolderUsage],
        parentID: String,
        parentTotalSize: Int64,
        rootTotalSize: Int64,
        level: Int,
        levels: Int,
        start: Double,
        end: Double,
        paletteIndex: Int,
        result: inout [SunburstSegment],
        aggregates: inout [SunburstAggregateSegment]
    ) -> Bool {
        guard !isCancelled else { return false }
        guard level < levels, parentTotalSize > 0, !items.isEmpty else { return true }

        var angle = start
        var aggregateStart: Double?
        var aggregateSize: Int64 = 0
        var aggregateCount = 0

        for item in sortedBySize(items) {
            guard !isCancelled else { return false }

            let span = (end - start) * Double(item.size) / Double(parentTotalSize)
            let endAngle = angle + span
            defer { angle = endAngle }
            guard span > 0 else { continue }

            guard span >= minimumIndividualSpan else {
                if aggregateStart == nil {
                    aggregateStart = angle
                }
                aggregateSize += item.size
                aggregateCount += 1
                continue
            }

            result.append(
                segment(
                    item: item,
                    level: level,
                    startAngle: angle,
                    endAngle: endAngle,
                    rootTotalSize: rootTotalSize,
                    paletteIndex: paletteIndex
                )
            )

            guard build(
                item.children,
                parentID: item.path,
                parentTotalSize: item.size,
                rootTotalSize: rootTotalSize,
                level: level + 1,
                levels: levels,
                start: angle,
                end: endAngle,
                paletteIndex: paletteIndex,
                result: &result,
                aggregates: &aggregates
            ) else { return false }
        }

        if let aggregateStart, aggregateSize > 0, aggregateCount > 0 {
            aggregates.append(
                aggregateSegment(
                    id: "other:\(parentID):\(level)",
                    level: level,
                    startAngle: aggregateStart,
                    endAngle: end,
                    size: aggregateSize,
                    itemCount: aggregateCount,
                    rootTotalSize: rootTotalSize,
                    paletteIndex: paletteIndex
                )
            )
        }

        return true
    }

    private static func segment(
        item: FolderUsage,
        level: Int,
        startAngle: Double,
        endAngle: Double,
        rootTotalSize: Int64,
        paletteIndex: Int
    ) -> SunburstSegment {
        SunburstSegment(
            id: "\(item.path)-\(level)",
            item: item,
            level: level,
            startAngle: startAngle,
            endAngle: endAngle,
            fractionOfRoot: Double(item.size) / Double(rootTotalSize),
            paletteIndex: paletteIndex,
            canNavigate: !item.children.isEmpty
        )
    }

    private static func aggregateSegment(
        id: String,
        level: Int,
        startAngle: Double,
        endAngle: Double,
        size: Int64,
        itemCount: Int,
        rootTotalSize: Int64,
        paletteIndex: Int
    ) -> SunburstAggregateSegment {
        SunburstAggregateSegment(
            id: id,
            level: level,
            startAngle: startAngle,
            endAngle: endAngle,
            size: size,
            itemCount: itemCount,
            fractionOfRoot: Double(size) / Double(rootTotalSize),
            paletteIndex: paletteIndex
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
