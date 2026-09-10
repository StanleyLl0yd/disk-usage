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
                lhs.size != rhs.size ? lhs.size > rhs.size : lhs.path < rhs.path
            case .sizeAsc:
                lhs.size != rhs.size ? lhs.size < rhs.size : lhs.path < rhs.path
            case .name:
                lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
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
