import Foundation

struct FolderUsage: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let children: [FolderUsage]

    // Используем path как id — бесплатно, без аллокаций UUID
    var id: String { url.path }

    init(url: URL, size: Int64, children: [FolderUsage] = []) {
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
