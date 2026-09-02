import SwiftUI

struct SunburstView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    var scanProgress: ScanProgress? = nil
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    @State private var path: [FolderUsage] = []

    private let levels = 4
    private let center: CGFloat = 70
    private let ring: CGFloat = 45

    private var current: (items: [FolderUsage], total: Int64) {
        (path.last?.children ?? items, path.last?.size ?? totalSize)
    }

    var body: some View {
        VStack(spacing: 12) {
            breadcrumb
            GeometryReader { geometry in
                let centerPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                ZStack {
                    ForEach(segments(centerPoint), id: \.0) { _, item, level, start, end, color in
                        Arc(
                            c: centerPoint,
                            r1: center + CGFloat(level) * ring,
                            r2: center + CGFloat(level + 1) * ring - 1,
                            a1: start,
                            a2: end
                        )
                        .fill(color)
                        .overlay(
                            Arc(
                                c: centerPoint,
                                r1: center + CGFloat(level) * ring,
                                r2: center + CGFloat(level + 1) * ring - 1,
                                a1: start,
                                a2: end
                            )
                            .stroke(.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            if !item.children.isEmpty {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    path.append(item)
                                }
                            }
                        }
                        .folderContextMenu(
                            item,
                            showHeader: true,
                            onShowInFinder: onShowInFinder,
                            onCopyPath: onCopyPath,
                            onDelete: onDelete
                        )
                    }

                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: center * 2, height: center * 2)
                        .position(centerPoint)

                    VStack(spacing: 4) {
                        Text(formatBytes(scanProgress?.bytesFound ?? current.total))
                            .font(.system(size: 18, weight: .bold))
                        Text(
                            scanProgress != nil
                                ? String(localized: "sunburst.scanning", defaultValue: "scanning…")
                                : String(localized: "sunburst.scanned", defaultValue: "scanned")
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .frame(width: center * 1.8)
                    .position(centerPoint)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .onChange(of: scanProgress) { _, newValue in
            if newValue != nil {
                path.removeAll()
            }
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    _ = path.popLast()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(path.isEmpty)

            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        path.removeAll()
                    }
                } label: {
                    Text(verbatim: "/")
                }
                .buttonStyle(.plain)
                .foregroundStyle(path.isEmpty ? .primary : .secondary)

                ForEach(Array(path.enumerated()), id: \.element.path) { index, item in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button(item.name) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            path = Array(path.prefix(index + 1))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == path.count - 1 ? .primary : .secondary)
                    .lineLimit(1)
                }
            }
            .font(.system(size: 13))

            Spacer()
        }
        .padding(.horizontal)
    }

    private func segments(_ centerPoint: CGPoint) -> [(String, FolderUsage, Int, Double, Double, Color)] {
        var result: [(String, FolderUsage, Int, Double, Double, Color)] = []
        let sorted = current.items.sorted { $0.size > $1.size }
        let count = sorted.count

        func build(
            _ items: [FolderUsage],
            _ total: Int64,
            _ level: Int,
            _ start: Double,
            _ end: Double,
            _ hue: Double
        ) {
            guard level < levels, total > 0 else { return }
            var angle = start

            for item in items.sorted(by: { $0.size > $1.size }) {
                let span = (end - start) * Double(item.size) / Double(total)
                let endAngle = angle + span
                defer { angle = endAngle }
                guard span >= 1 else { continue }

                let brightness = 0.9 - Double(level) * 0.12
                let saturation = 0.7 - Double(level) * 0.08
                result.append((
                    "\(item.path)-\(level)",
                    item,
                    level,
                    angle,
                    endAngle,
                    Color(hue: hue, saturation: saturation, brightness: brightness)
                ))

                if !item.children.isEmpty {
                    build(item.children, item.size, level + 1, angle, endAngle, hue)
                }
            }
        }

        guard current.total > 0 else { return result }
        var angle = 0.0

        for (index, item) in sorted.enumerated() {
            let span = 360.0 * Double(item.size) / Double(current.total)
            let endAngle = angle + span
            defer { angle = endAngle }
            guard span >= 1 else { continue }

            let hue = (Double(index) / Double(max(count, 1)) + 0.08).truncatingRemainder(dividingBy: 1.0)
            let color = Color(hue: hue, saturation: 0.7, brightness: 0.9)
            result.append(("\(item.path)-0", item, 0, angle, endAngle, color))

            if !item.children.isEmpty {
                build(item.children, item.size, 1, angle, endAngle, hue)
            }
        }

        return result
    }
}

struct Arc: Shape {
    let c: CGPoint
    let r1: CGFloat
    let r2: CGFloat
    let a1: Double
    let a2: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: c,
            radius: r2,
            startAngle: .degrees(a1 - 90),
            endAngle: .degrees(a2 - 90),
            clockwise: false
        )
        path.addArc(
            center: c,
            radius: r1,
            startAngle: .degrees(a2 - 90),
            endAngle: .degrees(a1 - 90),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
