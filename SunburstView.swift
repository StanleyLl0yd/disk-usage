import SwiftUI
import Combine

nonisolated struct SunburstBreadcrumb: Identifiable, Equatable, Sendable {
    let path: String
    let name: String

    var id: String { path }
}

nonisolated struct SunburstSegment: Identifiable, Equatable, Sendable {
    let path: String
    let size: Int64
    let isFile: Bool
    let hasChildren: Bool
    let level: Int
    let startAngle: Double
    let endAngle: Double
    let hue: Double

    var id: String { "\(path)-\(level)" }

    var item: FolderUsage {
        FolderUsage(path: path, size: size, isFile: isFile)
    }
}

nonisolated struct SunburstPresentation: Equatable, Sendable {
    let navigation: [SunburstBreadcrumb]
    let total: Int64
    let segments: [SunburstSegment]

    static let empty = SunburstPresentation(navigation: [], total: 0, segments: [])
}

nonisolated enum SunburstPresentationPreprocessor {
    static func prepare(
        items: [FolderUsage],
        totalSize: Int64,
        navigation: [String],
        levels: Int = 4,
        minimumSpan: Double = 1
    ) -> SunburstPresentation? {
        guard !isCancelled else { return nil }

        var candidates = items
        var resolvedNavigation: [SunburstBreadcrumb] = []
        var currentItem: FolderUsage?

        for path in navigation {
            guard !isCancelled else { return nil }
            guard let item = candidates.first(where: { $0.path == path }) else { break }
            resolvedNavigation.append(SunburstBreadcrumb(path: item.path, name: item.name))
            currentItem = item
            candidates = item.children
        }

        let currentItems = currentItem?.children ?? items
        let currentTotal = currentItem?.size ?? totalSize
        var segments: [SunburstSegment] = []

        guard levels > 0, currentTotal > 0 else {
            return SunburstPresentation(
                navigation: resolvedNavigation,
                total: currentTotal,
                segments: segments
            )
        }

        let sorted = SortOption.sizeDesc.sorted(currentItems)
        segments.reserveCapacity(sorted.count)

        func build(
            _ children: [FolderUsage],
            total: Int64,
            level: Int,
            start: Double,
            end: Double,
            hue: Double
        ) -> Bool {
            guard !isCancelled else { return false }
            guard level < levels, total > 0 else { return true }

            var angle = start
            for item in SortOption.sizeDesc.sorted(children) {
                guard !isCancelled else { return false }

                let span = (end - start) * Double(item.size) / Double(total)
                let endAngle = angle + span
                defer { angle = endAngle }
                guard span >= minimumSpan else { continue }

                segments.append(
                    SunburstSegment(
                        path: item.path,
                        size: item.size,
                        isFile: item.isFile,
                        hasChildren: !item.children.isEmpty,
                        level: level,
                        startAngle: angle,
                        endAngle: endAngle,
                        hue: hue
                    )
                )

                if !item.children.isEmpty,
                   !build(
                       item.children,
                       total: item.size,
                       level: level + 1,
                       start: angle,
                       end: endAngle,
                       hue: hue
                   ) {
                    return false
                }
            }

            return true
        }

        var angle = 0.0
        for (index, item) in sorted.enumerated() {
            guard !isCancelled else { return nil }

            let span = 360 * Double(item.size) / Double(currentTotal)
            let endAngle = angle + span
            defer { angle = endAngle }
            guard span >= minimumSpan else { continue }

            let hue = (Double(index) / Double(max(sorted.count, 1)) + 0.08)
                .truncatingRemainder(dividingBy: 1)
            segments.append(
                SunburstSegment(
                    path: item.path,
                    size: item.size,
                    isFile: item.isFile,
                    hasChildren: !item.children.isEmpty,
                    level: 0,
                    startAngle: angle,
                    endAngle: endAngle,
                    hue: hue
                )
            )

            if !item.children.isEmpty,
               !build(
                   item.children,
                   total: item.size,
                   level: 1,
                   start: angle,
                   end: endAngle,
                   hue: hue
               ) {
                return nil
            }
        }

        guard !isCancelled else { return nil }
        return SunburstPresentation(
            navigation: resolvedNavigation,
            total: currentTotal,
            segments: segments
        )
    }

    private static var isCancelled: Bool {
        withUnsafeCurrentTask { task in
            task?.isCancelled ?? false
        }
    }
}

@MainActor
final class SunburstPresentationState: ObservableObject {
    @Published private(set) var presentation: SunburstPresentation = .empty

    private var source: [FolderUsage] = []
    private var totalSize: Int64 = 0
    private var navigation: [String] = []
    private var task: Task<Void, Never>?
    private var generation = 0

    func updateSource(_ source: [FolderUsage], totalSize: Int64) {
        self.source = source
        self.totalSize = totalSize
        prepare()
    }

    func drillDown(_ path: String) {
        navigation.append(path)
        prepare()
    }

    func navigateBack() {
        guard !navigation.isEmpty else { return }
        navigation.removeLast()
        prepare()
    }

    func navigateToRoot() {
        guard !navigation.isEmpty else { return }
        navigation.removeAll()
        prepare()
    }

    func navigate(toDepth depth: Int) {
        let depth = min(max(depth, 0), navigation.count)
        guard depth != navigation.count else { return }
        navigation = Array(navigation.prefix(depth))
        prepare()
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
    }

    private func prepare() {
        generation &+= 1
        let generation = generation
        task?.cancel()

        guard !source.isEmpty else {
            task = nil
            navigation.removeAll()
            presentation = .empty
            return
        }

        let source = source
        let totalSize = totalSize
        let navigation = navigation

        task = Task.detached(priority: .userInitiated) { [source, totalSize, navigation] in
            guard let prepared = SunburstPresentationPreprocessor.prepare(
                items: source,
                totalSize: totalSize,
                navigation: navigation
            ) else { return }

            await MainActor.run { [weak self] in
                guard let self, self.generation == generation else { return }
                self.navigation = prepared.navigation.map(\.path)
                self.presentation = prepared
                self.task = nil
            }
        }
    }
}

struct SunburstView: View {
    @ObservedObject var state: SunburstPresentationState
    var scanProgress: ScanProgress? = nil
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    private let center: CGFloat = 70
    private let ring: CGFloat = 45

    var body: some View {
        VStack(spacing: 12) {
            breadcrumb
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    ForEach(state.presentation.segments) { segment in
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
                                if segment.hasChildren {
                                    state.drillDown(segment.path)
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
                        Text(formatBytes(scanProgress?.bytesFound ?? state.presentation.total))
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
                .animation(
                    .easeInOut(duration: 0.3),
                    value: state.presentation.navigation.map(\.path)
                )
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button {
                state.navigateBack()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(state.presentation.navigation.isEmpty)

            HStack(spacing: 4) {
                Button {
                    state.navigateToRoot()
                } label: {
                    Text(verbatim: "/")
                }
                .buttonStyle(.plain)
                .foregroundStyle(state.presentation.navigation.isEmpty ? .primary : .secondary)

                ForEach(Array(state.presentation.navigation.enumerated()), id: \.element.path) { index, item in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    Button(item.name) {
                        state.navigate(toDepth: index + 1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        index == state.presentation.navigation.count - 1 ? .primary : .secondary
                    )
                    .lineLimit(1)
                }
            }
            .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal)
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
