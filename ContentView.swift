import SwiftUI
import AppKit
import Combine

@MainActor
final class TreePresentationState: ObservableObject {
    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isPreparing = false

    private var task: Task<Void, Never>?
    private var generation = 0

    func prepare(
        _ source: [FolderUsage],
        by option: SortOption,
        preservingCurrent: Bool
    ) {
        generation &+= 1
        let generation = generation
        task?.cancel()

        guard !source.isEmpty else {
            task = nil
            items = []
            isPreparing = false
            return
        }

        if !preservingCurrent {
            items = []
        }
        isPreparing = true

        task = Task.detached(priority: .userInitiated) { [source, option] in
            guard let prepared = TreePresentationPreprocessor.sorted(source, by: option) else { return }

            await MainActor.run { [weak self] in
                guard let self, self.generation == generation else { return }
                self.items = prepared
                self.isPreparing = false
                self.task = nil
            }
        }
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        isPreparing = false
    }
}

struct ContentView: View {
    @StateObject var viewModel: DiskScannerViewModel
    @EnvironmentObject var settings: AppSettings
    @StateObject private var treePresentation = TreePresentationState()
    @State private var sortOption: SortOption = .sizeDesc
    @State private var itemToDelete: FolderUsage?
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: ZenDesign.Spacing.small) {
            workspaceHeader

            if viewModel.lifecycle == .scanning {
                ProgressPanel(progress: viewModel.progress)
            }

            if viewModel.lifecycle == .completed,
               settings.viewMode == .tree,
               !viewModel.items.isEmpty {
                treeControls
            }

            content

            if viewModel.lifecycle == .completed,
               !viewModel.restricted.isEmpty,
               viewModel.items.isEmpty || settings.viewMode == .sunburst {
                restrictedBanner
            }
        }
        .padding(ZenDesign.Spacing.large)
        .background(ZenDesign.Colors.primaryBackground)
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem {
                Picker(
                    String(localized: "settings.viewMode", defaultValue: "Default View"),
                    selection: $settings.viewMode
                ) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon)
                            .labelStyle(.iconOnly)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 88)
                .help(String(localized: "header.viewMode.help", defaultValue: "Switch view mode"))
            }

            ToolbarItem(placement: .primaryAction) {
                if viewModel.isScanning {
                    Button(role: .cancel) {
                        viewModel.cancel()
                    } label: {
                        Label(
                            String(localized: "button.cancel", defaultValue: "Cancel"),
                            systemImage: "xmark.circle"
                        )
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Menu {
                        Button {
                            viewModel.scanHome()
                        } label: {
                            Label(
                                String(localized: "button.scanHome", defaultValue: "Scan Home"),
                                systemImage: "house"
                            )
                        }

                        Button {
                            viewModel.scanRoot()
                        } label: {
                            Label(
                                String(localized: "button.scanRoot", defaultValue: "Scan Disk (/)"),
                                systemImage: "internaldrive"
                            )
                        }

                        Divider()

                        Button {
                            chooseFolder()
                        } label: {
                            Label(
                                String(localized: "button.chooseFolder", defaultValue: "Choose…"),
                                systemImage: "folder"
                            )
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .help(String(localized: "status.initial", defaultValue: "Choose a folder or start a scan."))
                    .accessibilityLabel(
                        Text(String(localized: "status.initial", defaultValue: "Choose a folder or start a scan."))
                    )
                }
            }
        }
        .onReceive(viewModel.$items) { items in
            treePresentation.prepare(items, by: sortOption, preservingCurrent: false)
        }
        .onChange(of: sortOption) { _, option in
            treePresentation.prepare(viewModel.items, by: option, preservingCurrent: true)
        }
        .onDisappear {
            treePresentation.cancel()
        }
        .alert(
            String(localized: "alert.delete.title", defaultValue: "Move to Trash?"),
            isPresented: $showDeleteAlert,
            presenting: itemToDelete
        ) { item in
            Button(String(localized: "alert.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "alert.delete", defaultValue: "Move to Trash"), role: .destructive) {
                deleteItem(item)
            }
        } message: { item in
            Text(
                String(
                    format: String(
                        localized: "alert.delete.message",
                        defaultValue: "Move \"%@\" to Trash?\n\nSize: %@."
                    ),
                    item.name,
                    formatBytes(item.size)
                )
            )
        }
        .alert(
            String(localized: "alert.error.title", defaultValue: "Error"),
            isPresented: $showErrorAlert
        ) {
            Button(String(localized: "alert.ok", defaultValue: "OK")) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.lifecycle {
        case .initial:
            initialState
        case .scanning:
            scanningState
        case .cancelled:
            cancelledState
        case .completed:
            if viewModel.items.isEmpty {
                completedEmptyState
            } else {
                switch settings.viewMode {
                case .tree:
                    if treePresentation.items.isEmpty {
                        preparingState
                    } else {
                        TreeView(
                            items: treePresentation.items,
                            totalSize: viewModel.totalSize,
                            restricted: viewModel.restricted,
                            onShowInFinder: viewModel.showInFinder,
                            onCopyPath: viewModel.copyPath,
                            onDelete: requestDelete
                        )
                        .overlay(alignment: .topTrailing) {
                            if treePresentation.isPreparing {
                                presentationIndicator
                                    .padding(ZenDesign.Spacing.small)
                            }
                        }
                    }
                case .sunburst:
                    SunburstView(
                        items: viewModel.items,
                        totalSize: viewModel.totalSize,
                        snapshotRevision: viewModel.snapshotRevision,
                        onShowInFinder: viewModel.showInFinder,
                        onCopyPath: viewModel.copyPath,
                        onDelete: requestDelete
                    )
                }
            }
        }
    }

    private func requestDelete(_ item: FolderUsage) {
        if settings.confirmDelete {
            itemToDelete = item
            showDeleteAlert = true
        } else {
            deleteItem(item)
        }
    }

    private func deleteItem(_ item: FolderUsage) {
        if case .error(let message) = viewModel.moveToTrash(item) {
            errorMessage = message
            showErrorAlert = true
        }
    }

    private var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: ZenDesign.Spacing.small) {
            HStack(spacing: ZenDesign.Spacing.large) {
                Text(viewModel.targetDescription)
                    .font(ZenDesign.Typography.section)
                    .foregroundStyle(ZenDesign.Colors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.diskInfo.totalCapacity > 0 {
                    DiskInfoBar(diskInfo: viewModel.diskInfo)
                        .frame(maxWidth: 520)
                }
            }

            if viewModel.lifecycle == .completed || viewModel.lifecycle == .cancelled {
                Text(viewModel.status)
                    .font(ZenDesign.Typography.detail)
                    .foregroundStyle(ZenDesign.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, ZenDesign.Spacing.medium)
        .padding(.vertical, ZenDesign.Spacing.small)
        .background(ZenDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: ZenDesign.Radius.medium, style: .continuous))
    }

    private var treeControls: some View {
        HStack {
            Picker("", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer()
        }
        .padding(.horizontal, ZenDesign.Spacing.medium)
    }

    private var initialState: some View {
        VStack(spacing: ZenDesign.Spacing.large) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(ZenDesign.Colors.mutedText)
            Text(String(localized: "status.initial", defaultValue: "Choose a folder or start a scan."))
                .font(.title3)
                .foregroundStyle(ZenDesign.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: ZenDesign.Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "status.scanning", defaultValue: "Scanning…"))
                .font(.title3)
                .foregroundStyle(ZenDesign.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cancelledState: some View {
        VStack(spacing: ZenDesign.Spacing.large) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(ZenDesign.Colors.mutedText)
            Text(String(localized: "status.cancelled", defaultValue: "Cancelled."))
                .font(.title3)
                .foregroundStyle(ZenDesign.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completedEmptyState: some View {
        VStack(spacing: ZenDesign.Spacing.large) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(ZenDesign.Colors.mutedText)
            Text(
                String(
                    localized: "status.finished.empty",
                    defaultValue: "No allocated-size items in this scan."
                )
            )
            .font(.title3)
            .foregroundStyle(ZenDesign.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var preparingState: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var presentationIndicator: some View {
        ProgressView()
            .controlSize(.small)
            .padding(ZenDesign.Spacing.small)
            .background(ZenDesign.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: ZenDesign.Radius.small, style: .continuous))
    }

    private var restrictedBanner: some View {
        VStack(alignment: .leading, spacing: ZenDesign.Spacing.compact) {
            HStack(spacing: ZenDesign.Spacing.small) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                Text(
                    String(
                        format: String(
                            localized: "restricted.count",
                            defaultValue: "%d folders without access"
                        ),
                        viewModel.restricted.count
                    )
                )
                .font(ZenDesign.Typography.detail)
                .foregroundStyle(ZenDesign.Colors.secondaryText)
                Spacer()
            }

            Text(
                String(
                    localized: "restricted.hint",
                    defaultValue: "Grant Full Disk Access in System Settings for complete analysis."
                )
            )
            .font(ZenDesign.Typography.micro)
            .foregroundStyle(ZenDesign.Colors.mutedText)
        }
        .padding(.horizontal, ZenDesign.Spacing.medium)
        .padding(.vertical, ZenDesign.Spacing.small)
        .background(ZenDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: ZenDesign.Radius.medium, style: .continuous))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scan(url)
        }
    }
}

struct ProgressPanel: View {
    let progress: ScanProgress

    var body: some View {
        VStack(spacing: ZenDesign.Spacing.small) {
            ProgressView()
                .progressViewStyle(.linear)

            HStack(spacing: ZenDesign.Spacing.large) {
                Label(
                    String(
                        format: String(localized: "progress.files", defaultValue: "%@ files"),
                        formatNumber(progress.filesScanned)
                    ),
                    systemImage: "doc"
                )
                Label(formatBytes(progress.bytesFound), systemImage: "internaldrive")
                Spacer()
            }
            .font(ZenDesign.Typography.detail)
            .foregroundStyle(ZenDesign.Colors.secondaryText)
            .monospacedDigit()

            if !progress.currentFolder.isEmpty {
                Text(progress.currentFolder)
                    .font(ZenDesign.Typography.micro)
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, ZenDesign.Spacing.medium)
    }
}

struct DiskInfoBar: View {
    let diskInfo: DiskInfo

    private var usedRatio: Double {
        guard diskInfo.totalCapacity > 0 else { return 0 }
        return Double(diskInfo.usedSpace) / Double(diskInfo.totalCapacity)
    }

    private var barColor: Color {
        switch usedRatio {
        case ..<0.7: ZenDesign.Colors.accent
        case ..<0.85: ZenDesign.Colors.warning
        default: ZenDesign.Colors.destructive
        }
    }

    var body: some View {
        HStack(spacing: ZenDesign.Spacing.medium) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 14))
                .foregroundStyle(ZenDesign.Colors.secondaryText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(ZenDesign.Colors.separator.opacity(0.65))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geometry.size.width * usedRatio)
                }
            }
            .frame(height: 8)
            .frame(maxWidth: 180)

            HStack(spacing: ZenDesign.Spacing.compact) {
                Text(formatBytes(diskInfo.usedSpace))
                    .fontWeight(.medium)
                Text("/")
                    .foregroundStyle(ZenDesign.Colors.secondaryText)
                Text(formatBytes(diskInfo.totalCapacity))
                    .foregroundStyle(ZenDesign.Colors.secondaryText)
                Text(String(format: "(%.0f%%)", diskInfo.usedPercent))
                    .foregroundStyle(ZenDesign.Colors.secondaryText)
            }
            .font(ZenDesign.Typography.detail)
            .monospacedDigit()

            HStack(spacing: ZenDesign.Spacing.compact) {
                Text(String(localized: "disk.free", defaultValue: "Free:"))
                    .foregroundStyle(ZenDesign.Colors.secondaryText)
                Text(formatBytes(diskInfo.freeSpace))
                    .fontWeight(.medium)
            }
            .font(ZenDesign.Typography.detail)
            .monospacedDigit()
        }
    }
}
