import Foundation

struct FolderUsage: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let children: [FolderUsage]
    let isFile: Bool
    
    // Используем path как id — бесплатно, без аллокаций UUID
    var id: String { url.path }

    init(url: URL, size: Int64, children: [FolderUsage] = [], isFile: Bool = false) {
        self.url = url
        self.size = size
        self.children = children
        self.isFile = isFile
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
