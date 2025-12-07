import SwiftUI

// MARK: - Folder Context Menu

struct FolderContextMenu: ViewModifier {
    let item: FolderUsage
    let showHeader: Bool
    let onDelete: () -> Void
    
    func body(content: Content) -> some View {
        content.contextMenu {
            if showHeader {
                Text("\(item.name) — \(formatBytes(item.size))")
                Divider()
            }
            
            Button {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Label(String(localized: "context.showInFinder", defaultValue: "Show in Finder"), systemImage: "folder")
            }
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            } label: {
                Label(String(localized: "context.copyPath", defaultValue: "Copy Path"), systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "context.moveToTrash", defaultValue: "Move to Trash"), systemImage: "trash")
            }
        }
    }
}

extension View {
    func folderContextMenu(_ item: FolderUsage, showHeader: Bool = false, onDelete: @escaping () -> Void) -> some View {
        modifier(FolderContextMenu(item: item, showHeader: showHeader, onDelete: onDelete))
    }
}
