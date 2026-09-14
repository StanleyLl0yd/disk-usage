import SwiftUI
import Combine

@MainActor
final class SunburstPresentationState: ObservableObject {
    @Published private(set) var model = SunburstPresentation.empty
    @Published private(set) var isPreparing = false

    private var task: Task<Void, Never>?
    private var generation = 0

    func prepare(items: [FolderUsage], totalSize: Int64, levels: Int) {
        generation &+= 1
        let generation = generation
        task?.cancel()
        model = SunburstPresentation(totalSize: totalSize, segments: [])

        guard !items.isEmpty, totalSize > 0 else {
            task = nil
            isPreparing = false
            return
        }

        isPreparing = true
        task = Task.detached(priority: .userInitiated) { [items, totalSize, levels] in
            guard let prepared = SunburstPresentationPreprocessor.presentation(
                for: items,
                totalSize: totalSize,
                levels: levels
            ) else { return }

            await MainActor.run { [weak self] in
                guard let self, self.generation == generation else { return }
                self.model = prepared
                self.isPreparing = false
                self.task = nil
            }
        }
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        model = .empty
        isPreparing = false
    }
}

struct SunburstView: View {
    let items: [FolderUsage]
    let totalSize: Int64
    let snapshotRevision: UInt64
    @Binding var selectedPath: String?
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
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
        VStack(spacing: ZenDesign.Spacing.medium) {
            breadcrumb
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    RoundedRectangle(cornerRadius: ZenDesign.Radius.medium, style: .continuous)
                        .fill(ZenDesign.Colors.surface.opacity(colorScheme == .dark ? 0.28 : 0.52))

                    ForEach(presentation.model.segments) { segment in
                        let arc = Arc(
                            c: c,
                            r1: center + CGFloat(segment.level) * ring,
                            r2: center + CGFloat(segment.level + 1) * ring - 1,
                            a1: segment.startAngle,
                            a2: segment.endAngle
                        )
                        let tone = SunburstPalette.tone(
                            paletteIndex: segment.paletteIndex,
                            level: segment.level,
                            darkMode: colorScheme == .dark
                        )
                        let color = Color(
                            hue: tone.hue,
                            saturation: tone.saturation,
                            brightness: tone.brightness
                        )
                        let isSelected = selectedPath == segment.item.path

                        arc.fill(color.opacity(isSelected ? 1 : 0.92))
                            .overlay(
                                arc.stroke(
                                    isSelected
                                        ? ZenDesign.Colors.accent.opacity(0.9)
                                        : ZenDesign.Colors.surface.opacity(colorScheme == .dark ? 0.70 : 0.92),
                                    lineWidth: isSelected ? 2 : 0.8
                                )
                            )
                            .onTapGesture {
                                selectedPath = segment.item.path
                                if segment.canNavigate {
                                    updateNavigation {
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
                        .fill(ZenDesign.Colors.surface)
                        .overlay {
                            Circle()
                                .strokeBorder(ZenDesign.Colors.separator.opacity(0.45), lineWidth: 1)
                        }
                        .frame(width: center * 2, height: center * 2)
                        .position(c)

                    VStack(spacing: 4) {
                        Text(formatBytes(current.total))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ZenDesign.Colors.primaryText)
                        Text(String(localized: "sunburst.scanned", defaultValue: "scanned"))
                            .font(.system(size: 11))
                            .foregroundStyle(ZenDesign.Colors.secondaryText)
                    }
                    .frame(width: center * 1.8)
                    .position(c)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .overlay(alignment: .topTrailing) {
            if presentation.isPreparing {
                ProgressView()
                    .controlSize(.small)
                    .padding(ZenDesign.Spacing.small)
                    .background(ZenDesign.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: ZenDesign.Radius.small, style: .continuous))
                    .padding(ZenDesign.Spacing.small)
            }
        }
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
        HStack(spacing: ZenDesign.Spacing.small) {
            Button {
                updateNavigation { _ = navigation.popLast() }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(resolvedPath.isEmpty)

            HStack(spacing: ZenDesign.Spacing.compact) {
                Button {
                    updateNavigation { navigation.removeAll() }
                } label: {
                    Text(verbatim: "/")
                }
                .buttonStyle(.plain)
                .foregroundStyle(resolvedPath.isEmpty ? ZenDesign.Colors.primaryText : ZenDesign.Colors.secondaryText)

                ForEach(Array(resolvedPath.enumerated()), id: \.element.path) { index, item in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(ZenDesign.Colors.mutedText)
                    Button(item.name) {
                        updateNavigation {
                            navigation = Array(navigation.prefix(index + 1))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == resolvedPath.count - 1 ? ZenDesign.Colors.primaryText : ZenDesign.Colors.secondaryText)
                    .lineLimit(1)
                }
            }
            .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal)
    }

    private func updateNavigation(_ changes: () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                changes()
            }
        }
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
