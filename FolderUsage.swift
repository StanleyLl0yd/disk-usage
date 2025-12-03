import Foundation

struct FolderUsage: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
}
