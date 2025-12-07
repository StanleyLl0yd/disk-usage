import Foundation

struct FolderUsage: Identifiable, Hashable {
    let path: String
    let size: Int64
    let isFile: Bool
    let children: [FolderUsage]
    
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent }
    var childrenOptional: [FolderUsage]? { children.isEmpty ? nil : children }
    
    init(path: String, size: Int64, isFile: Bool = false, children: [FolderUsage] = []) {
        self.path = path
        self.size = size
        self.isFile = isFile
        self.children = children
    }
    
    func sorted(by option: SortOption) -> FolderUsage {
        let sortedChildren = children.map { $0.sorted(by: option) }.sorted { a, b in
            switch option {
            case .sizeDesc: a.size != b.size ? a.size > b.size : a.path < b.path
            case .sizeAsc:  a.size != b.size ? a.size < b.size : a.path < b.path
            case .name:     a.path.localizedCaseInsensitiveCompare(b.path) == .orderedAscending
            }
        }
        return FolderUsage(path: path, size: size, isFile: isFile, children: sortedChildren)
    }
    
    /// Удаляет элемент из дерева по пути и пересчитывает размеры
    func removing(path targetPath: String) -> FolderUsage? {
        if self.path == targetPath { return nil }
        
        var newChildren: [FolderUsage] = []
        var removedSize: Int64 = 0
        
        for child in children {
            if child.path == targetPath {
                removedSize = child.size
            } else if let updated = child.removing(path: targetPath) {
                removedSize = child.size - updated.size
                newChildren.append(updated)
            } else {
                newChildren.append(child)
            }
        }
        
        return FolderUsage(
            path: path,
            size: size - removedSize,
            isFile: isFile,
            children: newChildren
        )
    }
}
