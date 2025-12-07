import Foundation

// MARK: - Formatting

private let sizeUnits = ["B", "KB", "MB", "GB", "TB"]
private let numberFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = " "
    return f
}()

func formatBytes(_ bytes: Int64) -> String {
    var value = Double(bytes)
    var i = 0
    while value > 1024 && i < sizeUnits.count - 1 {
        value /= 1024
        i += 1
    }
    return String(format: "%.1f %@", value, sizeUnits[i])
}

func formatPercent(_ part: Int64, of total: Int64) -> String {
    guard total > 0, part > 0 else { return "0.0 %" }
    return String(format: "%.1f %%", Double(part) / Double(total) * 100)
}

func formatNumber(_ number: Int64) -> String {
    numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// MARK: - Progress

struct ScanProgress: Equatable {
    var filesScanned: Int64 = 0
    var bytesFound: Int64 = 0
    var currentFolder: String = ""
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Identifiable {
    case sizeDesc, sizeAsc, name
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .sizeDesc: String(localized: "sort.sizeDescending", defaultValue: "Size ↓")
        case .sizeAsc:  String(localized: "sort.sizeAscending", defaultValue: "Size ↑")
        case .name:     String(localized: "sort.name", defaultValue: "Name")
        }
    }
}
