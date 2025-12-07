import SwiftUI

struct TreeView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    let restricted: [String]
    let onDelete: (FolderUsage) -> Void
    
    @State private var showRestricted = false
    
    var body: some View {
        List {
            if items.isEmpty {
                Text(String(localized: "empty.message", defaultValue: "No data. Start a scan."))
                    .foregroundStyle(.secondary).padding(.vertical, 20)
            } else {
                Section(String(localized: "section.items", defaultValue: "Items")) {
                    OutlineGroup(items, children: \.childrenOptional) { item in
                        ItemRow(item: item, totalSize: totalSize)
                            .folderContextMenu(item) { onDelete(item) }
                    }
                }
            }
            
            if !restricted.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showRestricted) {
                        ForEach(restricted, id: \.self) {
                            Text($0).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(String(localized: "restricted.hint", defaultValue: "Grant Full Disk Access in System Settings for complete analysis."))
                            .font(.footnote).foregroundStyle(.secondary)
                    } label: {
                        Label(
                            "\(String(localized: "section.restricted", defaultValue: "No Access")) (\(restricted.count))",
                            systemImage: "lock.fill"
                        )
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let item: FolderUsage
    let totalSize: Int64
    
    private var ratio: Double { totalSize > 0 ? min(Double(item.size) / Double(totalSize), 1) : 0 }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.isFile ? "doc" : "folder")
                .foregroundStyle(item.isFile ? .secondary : Color.accentColor)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(minWidth: 150, alignment: .leading)
            
            SizeBar(ratio: ratio).frame(minWidth: 60, maxWidth: 120)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(item.size)).monospacedDigit()
                Text(formatPercent(item.size, of: totalSize)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Size Bar

struct SizeBar: View {
    let ratio: Double
    
    private var color: Color {
        switch ratio {
        case ..<0.25: .green
        case ..<0.5:  .yellow
        case ..<0.75: .orange
        default:      .red
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(color).frame(width: max(geo.size.width * ratio, ratio > 0 ? 2 : 0))
            }
        }
        .frame(height: 4)
    }
}
