import SwiftUI

struct TreeView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    let restricted: [String]
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    @State private var showRestricted = false

    var body: some View {
        List {
            if items.isEmpty {
                Text(String(localized: "empty.message", defaultValue: "No data. Start a scan."))
                    .foregroundStyle(ZenDesign.Colors.secondaryText)
                    .padding(.vertical, 20)
            } else {
                Section(String(localized: "section.items", defaultValue: "Items")) {
                    OutlineGroup(items, children: \.childrenOptional) { item in
                        ItemRow(item: item, totalSize: totalSize)
                            .folderContextMenu(
                                item,
                                onShowInFinder: onShowInFinder,
                                onCopyPath: onCopyPath,
                                onDelete: onDelete
                            )
                    }
                }
            }

            if !restricted.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showRestricted) {
                        ForEach(restricted, id: \.self) {
                            Text($0)
                                .font(ZenDesign.Typography.detail)
                                .foregroundStyle(ZenDesign.Colors.secondaryText)
                        }
                        Text(
                            String(
                                localized: "restricted.hint",
                                defaultValue: "Grant Full Disk Access in System Settings for complete analysis."
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(ZenDesign.Colors.secondaryText)
                    } label: {
                        Label {
                            Text(
                                verbatim: "\(String(localized: "section.restricted", defaultValue: "No Access")) (\(restricted.count))"
                            )
                        } icon: {
                            Image(systemName: "lock.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(ZenDesign.Colors.secondaryText)
                    }
                }
            }
        }
    }
}

struct ItemRow: View {
    let item: FolderUsage
    let totalSize: Int64

    private var ratio: Double {
        totalSize > 0 ? min(Double(item.size) / Double(totalSize), 1) : 0
    }

    var body: some View {
        HStack(spacing: ZenDesign.Spacing.small) {
            Image(systemName: item.isFile ? "doc" : "folder")
                .foregroundStyle(item.isFile ? ZenDesign.Colors.secondaryText : ZenDesign.Colors.accent)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                Text(item.path)
                    .font(ZenDesign.Typography.micro)
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                    .lineLimit(1)
            }
            .frame(minWidth: 150, alignment: .leading)

            SizeBar(ratio: ratio)
                .frame(minWidth: 60, maxWidth: 120)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(item.size)).monospacedDigit()
                Text(formatPercent(item.size, of: totalSize))
                    .font(ZenDesign.Typography.micro)
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                    .monospacedDigit()
            }
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

struct SizeBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(ZenDesign.Colors.separator.opacity(0.65))
                Capsule()
                    .fill(ZenDesign.Colors.accent.opacity(0.78))
                    .frame(width: max(geometry.size.width * ratio, ratio > 0 ? 2 : 0))
            }
        }
        .frame(height: 4)
    }
}
