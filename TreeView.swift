import SwiftUI

struct TreeView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    let restricted: [String]
    let canRescan: Bool
    let isSearchMode: Bool
    let isSearchPreparing: Bool
    @Binding var searchQuery: String
    @Binding var selectedPath: String?
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void
    let onOpenFullDiskAccess: () -> Void
    let onRescan: () -> Void

    @State private var showRestricted = false
    @FocusState private var isTreeFocused: Bool

    var body: some View {
        List(selection: $selectedPath) {
            Section(String(localized: "section.items", defaultValue: "Items")) {
                if isSearchMode {
                    if isSearchPreparing && items.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    } else if items.isEmpty {
                        ContentUnavailableView.search(text: searchQuery)
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                } else {
                    OutlineGroup(items, children: \.childrenOptional) { item in
                        itemRow(item)
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
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help($0)
                        }
                        Text(
                            String(
                                localized: "restricted.hint",
                                defaultValue: "Some locations could not be read. Full Disk Access is controlled by macOS System Settings. Enable it for DiskUsage, then rescan."
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(ZenDesign.Colors.secondaryText)

                        RestrictedAccessActions(
                            canRescan: canRescan,
                            onOpenFullDiskAccess: onOpenFullDiskAccess,
                            onRescan: onRescan
                        )
                        .padding(.top, ZenDesign.Spacing.compact)
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
        .searchable(text: $searchQuery)
        .focused($isTreeFocused)
        .onAppear {
            isTreeFocused = true
        }
    }

    @ViewBuilder
    private func itemRow(_ item: FolderUsage) -> some View {
        ItemRow(
            item: item,
            totalSize: totalSize,
            isSelected: selectedPath == item.path,
            isTreeFocused: isTreeFocused
        )
        .tag(item.path)
        .folderContextMenu(
            item,
            onShowInFinder: onShowInFinder,
            onCopyPath: onCopyPath,
            onDelete: onDelete
        )
    }
}

struct RestrictedAccessActions: View {
    let canRescan: Bool
    let onOpenFullDiskAccess: () -> Void
    let onRescan: () -> Void

    var body: some View {
        HStack(spacing: ZenDesign.Spacing.compact) {
            Button(action: onOpenFullDiskAccess) {
                Label(
                    String(localized: "restricted.openSettings", defaultValue: "Open Full Disk Access"),
                    systemImage: "gearshape"
                )
            }

            Button(action: onRescan) {
                Label(
                    String(localized: "button.rescan", defaultValue: "Rescan"),
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(!canRescan)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct ItemRow: View {
    let item: FolderUsage
    let totalSize: Int64
    let isSelected: Bool
    let isTreeFocused: Bool

    @State private var isHovered = false

    private var ratio: Double {
        guard totalSize > 0 else { return 0 }
        return min(max(Double(item.size) / Double(totalSize), 0), 1)
    }

    private var rowBackground: Color {
        if isSelected {
            return ZenDesign.Colors.accent.opacity(isTreeFocused ? 0.12 : 0.07)
        }
        return isHovered ? ZenDesign.Colors.elevatedSurface.opacity(0.85) : .clear
    }

    private var rowStroke: Color {
        isSelected && isTreeFocused ? ZenDesign.Colors.accent.opacity(0.35) : .clear
    }

    var body: some View {
        HStack(spacing: ZenDesign.Spacing.small) {
            Image(systemName: item.isFile ? "doc.text" : "folder.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.isFile ? ZenDesign.Colors.secondaryText : ZenDesign.Colors.accent)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(ZenDesign.Typography.detail)
                    .fontWeight(item.isFile ? .regular : .medium)
                    .foregroundStyle(ZenDesign.Colors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.path)
                    .font(ZenDesign.Typography.micro)
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(item.path)

            SizeBar(ratio: ratio, isEmphasized: isSelected)
                .frame(width: 96)

            VStack(alignment: .trailing, spacing: 1) {
                Text(formatBytes(item.size))
                    .font(ZenDesign.Typography.detail)
                    .fontWeight(.medium)
                    .foregroundStyle(ZenDesign.Colors.primaryText)
                    .monospacedDigit()

                Text(formatPercent(item.size, of: totalSize))
                    .font(ZenDesign.Typography.micro)
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                    .monospacedDigit()
            }
            .frame(width: 76, alignment: .trailing)
        }
        .padding(.horizontal, ZenDesign.Spacing.compact)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: ZenDesign.Radius.small, style: .continuous)
                .fill(rowBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ZenDesign.Radius.small, style: .continuous)
                .strokeBorder(rowStroke, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

struct SizeBar: View {
    let ratio: Double
    let isEmphasized: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ZenDesign.Colors.separator.opacity(0.45))

                Capsule()
                    .fill(ZenDesign.Colors.accent.opacity(isEmphasized ? 0.9 : 0.68))
                    .frame(width: max(geometry.size.width * ratio, ratio > 0 ? 2 : 0))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
