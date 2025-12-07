import SwiftUI

struct SunburstView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    var scanProgress: ScanProgress? = nil
    let onSelect: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void
    
    @State private var path: [FolderUsage] = []
    
    private let levels = 4, center: CGFloat = 70, ring: CGFloat = 45
    
    private var current: (items: [FolderUsage], total: Int64) {
        (path.last?.children ?? items, path.last?.size ?? totalSize)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            breadcrumb
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    ForEach(segments(c), id: \.0) { id, item, lvl, s, e, color in
                        Arc(c: c, r1: center + CGFloat(lvl) * ring, r2: center + CGFloat(lvl + 1) * ring - 1, a1: s, a2: e)
                            .fill(color)
                            .overlay(Arc(c: c, r1: center + CGFloat(lvl) * ring, r2: center + CGFloat(lvl + 1) * ring - 1, a1: s, a2: e).stroke(.white.opacity(0.3), lineWidth: 0.5))
                            .onTapGesture { if !item.children.isEmpty { withAnimation(.easeInOut(duration: 0.3)) { path.append(item) } } }
                            .folderContextMenu(item, showHeader: true) { onDelete(item) }
                    }
                    Circle().fill(Color(NSColor.controlBackgroundColor)).frame(width: center * 2, height: center * 2).position(c)
                    VStack(spacing: 4) {
                        Text(formatBytes(scanProgress?.bytesFound ?? current.total)).font(.system(size: 18, weight: .bold))
                        Text(scanProgress != nil ? String(localized: "sunburst.scanning", defaultValue: "scanning…") : String(localized: "sunburst.scanned", defaultValue: "scanned")).font(.system(size: 11)).foregroundStyle(.secondary)
                    }.frame(width: center * 1.8).position(c)
                }
            }
        }.frame(minWidth: 400, minHeight: 400)
    }
    
    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button { withAnimation(.easeInOut(duration: 0.3)) { _ = path.popLast() } } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
            }.buttonStyle(.bordered).disabled(path.isEmpty)
            
            HStack(spacing: 4) {
                Button("/") { withAnimation(.easeInOut(duration: 0.3)) { path.removeAll() } }
                    .buttonStyle(.plain).foregroundStyle(path.isEmpty ? .primary : .secondary)
                ForEach(Array(path.enumerated()), id: \.element.path) { i, item in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    Button(item.name) { withAnimation(.easeInOut(duration: 0.3)) { path = Array(path.prefix(i + 1)) } }
                        .buttonStyle(.plain).foregroundStyle(i == path.count - 1 ? .primary : .secondary).lineLimit(1)
                }
            }.font(.system(size: 13))
            Spacer()
        }.padding(.horizontal)
    }
    
    private func segments(_ c: CGPoint) -> [(String, FolderUsage, Int, Double, Double, Color)] {
        var result: [(String, FolderUsage, Int, Double, Double, Color)] = []
        let sorted = current.items.sorted { $0.size > $1.size }
        let count = sorted.count
        
        func build(_ items: [FolderUsage], _ total: Int64, _ lvl: Int, _ start: Double, _ end: Double, _ hue: Double) {
            guard lvl < levels, total > 0 else { return }
            var angle = start
            for item in items.sorted(by: { $0.size > $1.size }) {
                let span = (end - start) * Double(item.size) / Double(total)
                guard span >= 1 else { continue }
                let endAngle = angle + span
                let brightness = 0.9 - Double(lvl) * 0.12
                let saturation = 0.7 - Double(lvl) * 0.08
                result.append(("\(item.path)-\(lvl)", item, lvl, angle, endAngle, Color(hue: hue, saturation: saturation, brightness: brightness)))
                if !item.children.isEmpty { build(item.children, item.size, lvl + 1, angle, endAngle, hue) }
                angle = endAngle
            }
        }
        
        // Каждая корневая папка получает свой hue (начинаем с оранжевого, красный в конце)
        var angle = 0.0
        for (i, item) in sorted.enumerated() {
            let span = 360.0 * Double(item.size) / Double(current.total)
            guard span >= 1 else { continue }
            let hue = (Double(i) / Double(max(count, 1)) + 0.08).truncatingRemainder(dividingBy: 1.0)
            let brightness = 0.9
            let saturation = 0.7
            result.append(("\(item.path)-0", item, 0, angle, angle + span, Color(hue: hue, saturation: saturation, brightness: brightness)))
            if !item.children.isEmpty { build(item.children, item.size, 1, angle, angle + span, hue) }
            angle += span
        }
        return result
    }
}

struct Arc: Shape {
    let c: CGPoint, r1: CGFloat, r2: CGFloat, a1: Double, a2: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r2, startAngle: .degrees(a1 - 90), endAngle: .degrees(a2 - 90), clockwise: false)
        p.addArc(center: c, radius: r1, startAngle: .degrees(a2 - 90), endAngle: .degrees(a1 - 90), clockwise: true)
        p.closeSubpath()
        return p
    }
}
