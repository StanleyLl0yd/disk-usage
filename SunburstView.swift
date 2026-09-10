import SwiftUI
import Combine

@MainActor
final class SunburstPresentationState: ObservableObject {
    @Published private(set) var segments: [SunburstSegment] = []

    private var task: Task<Void, Never>?
    private var generation = 0

    func prepare(items: [FolderUsage], totalSize: Int64, levels: Int) {
        generation &+= 1
        let generation = generation
        task?.cancel()
        segments = []

        guard !items.isEmpty, totalSize > 0 else {
            task = nil
            return
        }

        task = Task.detached(priority: .userInitiated) { [items, totalSize, levels] in
            guard let prepared = SunburstPresentationPreprocessor.segments(
                for: items,
                totalSize: totalSize,
                levels: levels
            ) else { return }

            await MainActor.run { [weak self] in
                guard let self, self.generation == generation else { return }
                self.segments = prepared
                self.task = nil
            }
        }
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        segments = []
    }
}

struct SunburstView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    let snapshotRevision: UInt64
    var scanProgress: ScanProgress? = nil
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    @StateObject private var presentation = SunburstPresentationState()
    @State private var navigation: [String] = []

    private let levels = 4, center: CGFloat = 70, ring: CGFloat = 45

    private var resolvedPath: [FolderUsage] {
        var candidates = items
        var result: [FolderUsage] = []
        for path in navigation {
            guard let item = candidates.first(where: { $0.path == path }) else { break }
            result.append(item)
            candidates = item.children
        }
        return result
    }

    private var current: (items: [FolderUsage], total: Int64) {
        (resolvedPath.last?.children ?? items, resolvedPath.last?.size ?? totalSize)
    }

    var body: some View {
        VStack(spacing: 12) {
            breadcrumb
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    ForEach(presentation.segments) { segment in
                        let arc = Arc(
                            c: c,
                            r1: center + CGFloat(segment.level) * ring,
                            r2: center + CGFloat(segment.level + 1) * ring - 1,
                            a1: segment.startAngle,
                            a2: segment.endAngle
                        )
                        let color = Color(
                            hue: segment.hue,
                            saturation: 0.7 - Double(segment.level) * 0.08,
                            brightness: 0.9 - Double(segment.level) * 0.12
                        )

                        arc.fill(color)
                            .overlay(arc.stroke(.white.opacity(0.3), lineWidth: 0.5))
                            .onTapGesture {
                                if !segment.item.children.isEmpty {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        navigation.append(segment.item.path)
                                    }
                                }
                            }
                            .folderContextMenu(
                                segment.item,
                                showHeader: true,
                                onShowInFinder: onShowInFinder,
                                onCopyPath: onCopyPath,
                                onDelete: onDelete
                            )
                    }

                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: center * 2, height: center * 2)
                        .position(c)

                    VStack(spacing: 4) {
                        Text(formatBytes(scanProgress?.bytesFound ?? current.total))
                            .font(.system(size: 18, weight: .bold))
                        Text(scanProgress != nil
                             ? String(localized: "sunburst.scanning", defaultValue: "scanning…")
                             : String(localized: "sunburst.scanned", defaultValue: "scanned"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: center * 1.8)
                    .position(c)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .onAppear {
            preparePresentation()
        }
        .onChange(of: navigation) { _, _ in
            preparePresentation()
        }
        .onChange(of: snapshotRevision) { _, _ in
            reconcileNavigationAndPrepare()
        }
        .onDisappear {
            presentation.cancel()
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { _ = navigation.popLast() }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(resolvedPath.isEmpty)

            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { navigation.removeAll() }
                } label: {
                    Text(verbatim: "/")
                }
                .buttonStyle(.plain)
                .foregroundStyle(resolvedPath.isEmpty ? .primary : .secondary)

                ForEach(Array(resolvedPath.enumerated()), id: \.element.path) { index, item in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    Button(item.name) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navigation = Array(navigation.prefix(index + 1))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == resolvedPath.count - 1 ? .primary : .secondary)
                    .lineLimit(1)
                }
            }
            .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal)
    }

    private func preparePresentation() {
        let snapshot = current
        presentation.prepare(items: snapshot.items, totalSize: snapshot.total, levels: levels)
    }

    private func reconcileNavigationAndPrepare() {
        let validNavigation = resolvedPath.map(\.path)
        if validNavigation == navigation {
            preparePresentation()
        } else {
            navigation = validNavigation
        }
    }
}

struct Arc: Shape {
    let c: CGPoint, r1: CGFloat, r2: CGFloat, a1: Double, a2: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: c, radius: r2, startAngle: .degrees(a1 - 90), endAngle: .degrees(a2 - 90), clockwise: false)
        path.addArc(center: c, radius: r1, startAngle: .degrees(a2 - 90), endAngle: .degrees(a1 - 90), clockwise: true)
        path.closeSubpath()
        return path
    }
}
