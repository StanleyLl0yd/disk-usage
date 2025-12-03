import Foundation

struct FolderUsage: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let size: Int64
    let children: [FolderUsage]

    init(id: UUID = UUID(), url: URL, size: Int64, children: [FolderUsage] = []) {
        self.id = id
        self.url = url
        self.size = size
        self.children = children
    }

    // Для OutlineGroup, которому нужен Optional
    var childrenOptional: [FolderUsage]? {
        children.isEmpty ? nil : children
    }

    var name: String {
        let last = url.lastPathComponent
        return last.isEmpty ? url.path : last
    }
}
