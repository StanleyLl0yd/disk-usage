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
