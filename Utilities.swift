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

nonisolated func formatScannedFileCount(_ count: Int64, locale: Locale = .current) -> String {
    let resource = LocalizedStringResource(
        "progress.files",
        defaultValue: "\(count) files",
        locale: locale
    )
    return String(localized: resource)
}

nonisolated func formatRestrictedFolderCount(_ count: Int, locale: Locale = .current) -> String {
    let resource = LocalizedStringResource(
        "restricted.count",
        defaultValue: "\(count) folders without access",
        locale: locale
    )
    return String(localized: resource)
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
    struct AggregateSegment: Identifiable, Equatable, Sendable {
        let id: String
        let level: Int
        let startAngle: Double
        let endAngle: Double
        let size: Int64
        let itemCount: Int
        let fractionOfRoot: Double
        let paletteIndex: Int
    }

    let totalSize: Int64
    let segments: [SunburstSegment]
    let aggregates: [AggregateSegment]

    init(
        totalSize: Int64,
        segments: [SunburstSegment],
        aggregates: [AggregateSegment] = []
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

nonisolated enum SunburstPresentationPreprocessor {
    private struct PositionedItem: Sendable {
        let item: FolderUsage
        let startAngle: Double
        let endAngle: Double
        let paletteIndex: Int
    }

    private struct AggregateDraft: Sendable {
        let startAngle: Double
        let endAngle: Double
        let size: Int64
        let itemCount: Int
        let paletteIndex: Int
    }

    private struct SiblingLayout: Sendable {
        let visible: [PositionedItem]
        let aggregate: AggregateDraft?
    }

    private enum PaletteAssignment: Sendable {
        case topLevel
        case fixed(Int)

        func index(for position: Int) -> Int {
            switch self {
            case .topLevel:
                position % SunburstPalette.count
            case let .fixed(index):
                index
            }
        }
    }

    private struct BuildContext: Sendable {
        let parentID: String
        let parentTotalSize: Int64
        let rootTotalSize: Int64
        let level: Int
        let levels: Int
        let startAngle: Double
        let endAngle: Double
        let paletteIndex: Int
    }

    private struct BuildOutput: Sendable {
        var segments: [SunburstSegment] = []
        var aggregates: [SunburstPresentation.AggregateSegment] = []
    }

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
        guard let layout = siblingLayout(
            items,
            parentTotalSize: totalSize,
            startAngle: 0,
            endAngle: 360,
            paletteAssignment: .topLevel
        ) else { return nil }

        var output = BuildOutput()
        for positioned in layout.visible {
            output.segments.append(segment(positioned, level: 0, rootTotalSize: totalSize))

            let context = BuildContext(
                parentID: positioned.item.path,
                parentTotalSize: positioned.item.size,
                rootTotalSize: totalSize,
                level: 1,
                levels: levels,
                startAngle: positioned.startAngle,
                endAngle: positioned.endAngle,
                paletteIndex: positioned.paletteIndex
            )
            guard build(positioned.item.children, context: context, output: &output) else { return nil }
        }

        if let aggregate = layout.aggregate {
            output.aggregates.append(
                aggregateSegment(
                    id: "aggregate-scope-0",
                    draft: aggregate,
                    level: 0,
                    rootTotalSize: totalSize
                )
            )
        }

        return SunburstPresentation(
            totalSize: totalSize,
            segments: output.segments,
            aggregates: output.aggregates
        )
    }

    private static func build(
        _ items: [FolderUsage],
        context: BuildContext,
        output: inout BuildOutput
    ) -> Bool {
        guard !isCancelled else { return false }
        guard context.level < context.levels,
              context.parentTotalSize > 0,
              !items.isEmpty else { return true }
        guard let layout = siblingLayout(
            items,
            parentTotalSize: context.parentTotalSize,
            startAngle: context.startAngle,
            endAngle: context.endAngle,
            paletteAssignment: .fixed(context.paletteIndex)
        ) else { return false }

        for positioned in layout.visible {
            output.segments.append(
                segment(
                    positioned,
                    level: context.level,
                    rootTotalSize: context.rootTotalSize
                )
            )

            let childContext = BuildContext(
                parentID: positioned.item.path,
                parentTotalSize: positioned.item.size,
                rootTotalSize: context.rootTotalSize,
                level: context.level + 1,
                levels: context.levels,
                startAngle: positioned.startAngle,
                endAngle: positioned.endAngle,
                paletteIndex: context.paletteIndex
            )
            guard build(positioned.item.children, context: childContext, output: &output) else { return false }
        }

        if let aggregate = layout.aggregate {
            output.aggregates.append(
                aggregateSegment(
                    id: "aggregate-\(context.level)-\(context.parentID)",
                    draft: aggregate,
                    level: context.level,
                    rootTotalSize: context.rootTotalSize
                )
            )
        }

        return true
    }

    private static func siblingLayout(
        _ items: [FolderUsage],
        parentTotalSize: Int64,
        startAngle: Double,
        endAngle: Double,
        paletteAssignment: PaletteAssignment
    ) -> SiblingLayout? {
        var visible: [PositionedItem] = []
        var angle = startAngle
        var aggregateStart: Double?
        var aggregateSize: Int64 = 0
        var aggregateCount = 0
        var aggregatePaletteIndex: Int?

        for (position, item) in sortedBySize(items).enumerated() {
            guard !isCancelled else { return nil }

            let span = (endAngle - startAngle) * Double(item.size) / Double(parentTotalSize)
            let itemEndAngle = angle + span
            defer { angle = itemEndAngle }
            guard span > 0 else { continue }

            let paletteIndex = paletteAssignment.index(for: position)
            if span >= minimumIndividualSpan {
                visible.append(
                    PositionedItem(
                        item: item,
                        startAngle: angle,
                        endAngle: itemEndAngle,
                        paletteIndex: paletteIndex
                    )
                )
                continue
            }

            if aggregateStart == nil {
                aggregateStart = angle
                aggregatePaletteIndex = paletteIndex
            }
            aggregateSize += item.size
            aggregateCount += 1
        }

        let aggregate = aggregateDraft(
            startAngle: aggregateStart,
            endAngle: angle,
            size: aggregateSize,
            itemCount: aggregateCount,
            paletteIndex: aggregatePaletteIndex
        )
        return SiblingLayout(visible: visible, aggregate: aggregate)
    }

    private static func aggregateDraft(
        startAngle: Double?,
        endAngle: Double,
        size: Int64,
        itemCount: Int,
        paletteIndex: Int?
    ) -> AggregateDraft? {
        guard let startAngle, let paletteIndex, size > 0, itemCount > 0 else { return nil }
        return AggregateDraft(
            startAngle: startAngle,
            endAngle: endAngle,
            size: size,
            itemCount: itemCount,
            paletteIndex: paletteIndex
        )
    }

    private static func segment(
        _ positioned: PositionedItem,
        level: Int,
        rootTotalSize: Int64
    ) -> SunburstSegment {
        SunburstSegment(
            id: "\(positioned.item.path)-\(level)",
            item: positioned.item,
            level: level,
            startAngle: positioned.startAngle,
            endAngle: positioned.endAngle,
            fractionOfRoot: Double(positioned.item.size) / Double(rootTotalSize),
            paletteIndex: positioned.paletteIndex,
            canNavigate: !positioned.item.children.isEmpty
        )
    }

    private static func aggregateSegment(
        id: String,
        draft: AggregateDraft,
        level: Int,
        rootTotalSize: Int64
    ) -> SunburstPresentation.AggregateSegment {
        SunburstPresentation.AggregateSegment(
            id: id,
            level: level,
            startAngle: draft.startAngle,
            endAngle: draft.endAngle,
            size: draft.size,
            itemCount: draft.itemCount,
            fractionOfRoot: Double(draft.size) / Double(rootTotalSize),
            paletteIndex: draft.paletteIndex
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
