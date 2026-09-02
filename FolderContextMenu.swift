import SwiftUI

struct FolderContextMenu: ViewModifier {
    let item: FolderUsage
    let showHeader: Bool
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            if showHeader {
                Text(verbatim: "\(item.name) — \(formatBytes(item.size))")
                Divider()
            }

            Button {
                onShowInFinder(item)
            } label: {
                Label(
                    String(localized: "context.showInFinder", defaultValue: "Show in Finder"),
                    systemImage: "folder"
                )
            }

            Button {
                onCopyPath(item)
            } label: {
                Label(
                    String(localized: "context.copyPath", defaultValue: "Copy Path"),
                    systemImage: "doc.on.doc"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label(
                    String(localized: "context.moveToTrash", defaultValue: "Move to Trash"),
                    systemImage: "trash"
                )
            }
        }
    }
}

extension View {
    func folderContextMenu(
        _ item: FolderUsage,
        showHeader: Bool = false,
        onShowInFinder: @escaping (FolderUsage) -> Void,
        onCopyPath: @escaping (FolderUsage) -> Void,
        onDelete: @escaping (FolderUsage) -> Void
    ) -> some View {
        modifier(
            FolderContextMenu(
                item: item,
                showHeader: showHeader,
                onShowInFinder: onShowInFinder,
                onCopyPath: onCopyPath,
                onDelete: onDelete
            )
        )
    }
}
