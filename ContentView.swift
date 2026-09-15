import SwiftUI
import AppKit
import Combine

nonisolated enum LargestFilesPresentationPreprocessor {
    static let defaultLimit = 100

    static func largestFiles(
        in source: [FolderUsage],
        limit: Int = defaultLimit
    ) -> [FolderUsage]? {
        guard limit > 0 else { return [] }
        guard !isCancelled else { return nil }

        var heap: [FolderUsage] = []
        heap.reserveCapacity(limit)

        for item in source {
            guard collectFiles(in: item, limit: limit, heap: &heap) else { return nil }
        }

        guard !isCancelled else { return nil }
        return heap.sorted { isBetter($0, than: $1) }
    }

    private static func collectFiles(
        in item: FolderUsage,
        limit: Int,
        heap: inout [FolderUsage]
    ) -> Bool {
        guard !isCancelled else { return false }

        if item.isFile {
            retain(item, limit: limit, heap: &heap)
            return true
        }

        for child in item.children {
            guard collectFiles(in: child, limit: limit, heap: &heap) else { return false }
        }
        return true
    }

    private static func retain(
        _ candidate: FolderUsage,
        limit: Int,
        heap: inout [FolderUsage]
    ) {
        if heap.count < limit {
            heap.append(candidate)
            siftUp(&heap, from: heap.count - 1)
            return
        }

        guard let worst = heap.first, isBetter(candidate, than: worst) else { return }
        heap[0] = candidate
        siftDown(&heap, from: 0)
    }

    private static func siftUp(_ heap: inout [FolderUsage], from startIndex: Int) {
        var index = startIndex
        while index > 0 {
            let parent = (index - 1) / 2
            guard isWorse(heap[index], than: heap[parent]) else { return }
            heap.swapAt(index, parent)
            index = parent
        }
    }

    private static func siftDown(_ heap: inout [FolderUsage], from startIndex: Int) {
        var index = startIndex
        while true {
            let left = index * 2 + 1
            guard left < heap.count else { return }

            let right = left + 1
            var worseChild = left
            if right < heap.count, isWorse(heap[right], than: heap[left]) {
                worseChild = right
            }

            guard isWorse(heap[worseChild], than: heap[index]) else { return }
            heap.swapAt(index, worseChild)
            index = worseChild
        }
    }

    private static func isBetter(_ lhs: FolderUsage, than rhs: FolderUsage) -> Bool {
        if lhs.size != rhs.size {
            return lhs.size > rhs.size
        }
        return lhs.path < rhs.path
    }

    private static func isWorse(_ lhs: FolderUsage, than rhs: FolderUsage) -> Bool {
        if lhs.size != rhs.size {
            return lhs.size < rhs.size
        }
        return lhs.path > rhs.path
    }

    private static var isCancelled: Bool {
        withUnsafeCurrentTask { task in
            task?.isCancelled ?? false
        }
    }
}

nonisolated enum SearchPresentationPreprocessor {
    static func matches(
        in source: [FolderUsage],
        query: String,
        sortedBy option: SortOption
    ) -> [FolderUsage]? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        guard !isCancelled else { return nil }

        var matches: [FolderUsage] = []
        for item in source {
            guard collectMatches(in: item, query: query, into: &matches) else { return nil }
        }

        guard !isCancelled else { return nil }
        return option.sorted(matches)
    }

    private static func collectMatches(
        in item: FolderUsage,
        query: String,
        into matches: inout [FolderUsage]
    ) -> Bool {
        guard !isCancelled else { return false }

        if item.name.localizedCaseInsensitiveContains(query)
            || item.path.localizedCaseInsensitiveContains(query) {
            matches.append(item)
        }

        for child in item.children {
            guard collectMatches(in: child, query: query, into: &matches) else { return false }
        }
        return true
    }

    private static var isCancelled: Bool {
        withUnsafeCurrentTask { task in
            task?.isCancelled ?? false
        }
    }
}

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

@MainActor
final class SearchPresentationState: ObservableObject {
    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isPreparing = false

    private var task: Task<Void, Never>?
    private var generation = 0

    func prepare(
        _ source: [FolderUsage],
        query: String,
        by option: SortOption,
        preservingCurrent: Bool
    ) {
        generation &+= 1
        let generation = generation
        task?.cancel()

        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !source.isEmpty else {
            task = nil
            items = []
            isPreparing = false
            return
        }

        if !preservingCurrent {
            items = []
        }
        isPreparing = true

        task = Task.detached(priority: .userInitiated) { [source, query, option] in
            guard let prepared = SearchPresentationPreprocessor.matches(
                in: source,
                query: query,
                sortedBy: option
            ) else { return }

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

@MainActor
final class LargestFilesPresentationState: ObservableObject {
    @Published private(set) var items: [FolderUsage] = []
    @Published private(set) var isPreparing = false

    private var task: Task<Void, Never>?
    private var generation = 0

    func prepare(_ source: [FolderUsage]) {
        generation &+= 1
        let generation = generation
        task?.cancel()

        guard !source.isEmpty else {
            task = nil
            items = []
            isPreparing = false
            return
        }

        items = []
        isPreparing = true

        task = Task.detached(priority: .userInitiated) { [source] in
            guard let prepared = LargestFilesPresentationPreprocessor.largestFiles(in: source) else { return }

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
        items = []
        isPreparing = false
    }
}

@MainActor
final class ItemSelectionState: ObservableObject {
    @Published var selectedPath: String?

    func selectedItem(in items: [FolderUsage]) -> FolderUsage? {
        guard let selectedPath else { return nil }
        return find(path: selectedPath, in: items)
    }

    func reconcile(with items: [FolderUsage]) {
        guard selectedPath != nil else { return }
        if selectedItem(in: items) == nil {
            selectedPath = nil
        }
    }

    private func find(path: String, in items: [FolderUsage]) -> FolderUsage? {
        for item in items {
            if item.path == path {
                return item
            }
            if let match = find(path: path, in: item.children) {
                return match
            }
        }
        return nil
    }
}

struct ContentView: View {
    @StateObject var viewModel: DiskScannerViewModel
    @EnvironmentObject var settings: AppSettings
    @StateObject private var treePresentation = TreePresentationState()
    @StateObject private var searchPresentation = SearchPresentationState()
    @StateObject private var largestFilesPresentation = LargestFilesPresentationState()
    @StateObject private var selection = ItemSelectionState()
    @State private var sortOption: SortOption = .sizeDesc
    @State private var searchQuery = ""
    @State private var isLargestFilesMode = false
    @State private var itemToDelete: FolderUsage?
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

            if viewModel.lifecycle == .completed,
               let selectedItem = selection.selectedItem(in: viewModel.items) {
                SelectedItemDetail(
                    item: selectedItem,
                    totalSize: viewModel.totalSize,
                    onShowInFinder: viewModel.showInFinder,
                    onCopyPath: viewModel.copyPath,
                    onDelete: requestDelete
                )
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
            selection.reconcile(with: items)
            treePresentation.prepare(items, by: sortOption, preservingCurrent: false)
            searchPresentation.prepare(
                items,
                query: searchQuery,
                by: sortOption,
                preservingCurrent: false
            )
            if isLargestFilesMode {
                largestFilesPresentation.prepare(items)
            }
        }
        .onChange(of: sortOption) { _, option in
            treePresentation.prepare(viewModel.items, by: option, preservingCurrent: true)
            searchPresentation.prepare(
                viewModel.items,
                query: searchQuery,
                by: option,
                preservingCurrent: true
            )
        }
        .onChange(of: searchQuery) { _, query in
            selection.selectedPath = nil
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isLargestFilesMode = false
            }
            searchPresentation.prepare(
                viewModel.items,
                query: query,
                by: sortOption,
                preservingCurrent: false
            )
        }
        .onChange(of: isLargestFilesMode) { _, isEnabled in
            selection.selectedPath = nil
            if isEnabled {
                searchQuery = ""
                largestFilesPresentation.prepare(viewModel.items)
            } else {
                largestFilesPresentation.cancel()
            }
        }
        .onDisappear {
            treePresentation.cancel()
            searchPresentation.cancel()
            largestFilesPresentation.cancel()
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
                    if isSearchActive {
                        treeView(
                            items: searchPresentation.items,
                            searchMode: true,
                            isPreparing: searchPresentation.isPreparing
                        )
                    } else if isLargestFilesMode {
                        if largestFilesPresentation.isPreparing {
                            preparingState
                        } else if largestFilesPresentation.items.isEmpty {
                            largestFilesEmptyState
                        } else {
                            treeView(
                                items: largestFilesPresentation.items,
                                searchMode: false,
                                isPreparing: false
                            )
                        }
                    } else if treePresentation.items.isEmpty {
                        preparingState
                    } else {
                        treeView(
                            items: treePresentation.items,
                            searchMode: false,
                            isPreparing: treePresentation.isPreparing
                        )
                    }
                case .sunburst:
                    SunburstView(
                        items: viewModel.items,
                        totalSize: viewModel.totalSize,
                        snapshotRevision: viewModel.snapshotRevision,
                        selectedPath: $selection.selectedPath,
                        onShowInFinder: viewModel.showInFinder,
                        onCopyPath: viewModel.copyPath,
                        onDelete: requestDelete
                    )
                }
            }
        }
    }

    private func treeView(
        items: [FolderUsage],
        searchMode: Bool,
        isPreparing: Bool
    ) -> some View {
        TreeView(
            items: items,
            totalSize: viewModel.totalSize,
            restricted: viewModel.restricted,
            canRescan: viewModel.canRescan,
            isSearchMode: searchMode,
            isSearchPreparing: searchMode && isPreparing,
            searchQuery: $searchQuery,
            selectedPath: $selection.selectedPath,
            onShowInFinder: viewModel.showInFinder,
            onCopyPath: viewModel.copyPath,
            onDelete: requestDelete,
            onOpenFullDiskAccess: openFullDiskAccessSettings,
            onRescan: viewModel.rescan
        )
        .overlay(alignment: .topTrailing) {
            if isPreparing && !items.isEmpty {
                presentationIndicator
                    .padding(ZenDesign.Spacing.small)
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
        switch viewModel.moveToTrash(item) {
        case .success:
            selection.reconcile(with: viewModel.items)
        case .error(let message):
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
            if !isLargestFilesMode {
                Picker("", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Spacer()

            Toggle(isOn: $isLargestFilesMode) {
                Label(
                    String(localized: "largestFiles.top100", defaultValue: "Top 100 Files"),
                    systemImage: "list.number"
                )
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help(
                String(
                    localized: "largestFiles.help",
                    defaultValue: "Show up to the 100 largest files in this scan"
                )
            )
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

    private var largestFilesEmptyState: some View {
        VStack(spacing: ZenDesign.Spacing.large) {
            Image(systemName: "doc")
                .font(.system(size: 48))
                .foregroundStyle(ZenDesign.Colors.mutedText)
            Text(
                String(
                    localized: "largestFiles.empty",
                    defaultValue: "No files in this scan."
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
                    defaultValue: "Some locations could not be read. Full Disk Access is controlled by macOS System Settings. Enable it for DiskUsage, then rescan."
                )
            )
            .font(ZenDesign.Typography.micro)
            .foregroundStyle(ZenDesign.Colors.mutedText)

            RestrictedAccessActions(
                canRescan: viewModel.canRescan,
                onOpenFullDiskAccess: openFullDiskAccessSettings,
                onRescan: viewModel.rescan
            )
            .padding(.top, ZenDesign.Spacing.compact)
        }
        .padding(.horizontal, ZenDesign.Spacing.medium)
        .padding(.vertical, ZenDesign.Spacing.small)
        .background(ZenDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: ZenDesign.Radius.medium, style: .continuous))
    }

    private func openFullDiskAccessSettings() {
        guard FullDiskAccessSettings.open() else {
            errorMessage = String(
                localized: "restricted.settingsOpenError",
                defaultValue: "Could not open Full Disk Access settings. Open System Settings > Privacy & Security > Full Disk Access manually."
            )
            showErrorAlert = true
            return
        }
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

struct SelectedItemDetail: View {
    let item: FolderUsage
    let totalSize: Int64
    let onShowInFinder: (FolderUsage) -> Void
    let onCopyPath: (FolderUsage) -> Void
    let onDelete: (FolderUsage) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: ZenDesign.Spacing.large) {
            HStack(alignment: .top, spacing: ZenDesign.Spacing.small) {
                Image(systemName: item.isFile ? "doc" : "folder")
                    .foregroundStyle(item.isFile ? ZenDesign.Colors.secondaryText : ZenDesign.Colors.accent)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: ZenDesign.Spacing.compact) {
                    Text(item.name)
                        .font(ZenDesign.Typography.section)
                        .foregroundStyle(ZenDesign.Colors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.path)
                        .font(ZenDesign.Typography.micro)
                        .foregroundStyle(ZenDesign.Colors.mutedText)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: ZenDesign.Spacing.compact) {
                Text(formatBytes(item.size))
                    .font(ZenDesign.Typography.detail)
                    .fontWeight(.medium)
                    .foregroundStyle(ZenDesign.Colors.primaryText)
                    .monospacedDigit()

                Text(formatPercent(item.size, of: totalSize))
                    .font(ZenDesign.Typography.micro)
                    .foregroundStyle(ZenDesign.Colors.mutedText)
                    .monospacedDigit()
            }
            .frame(minWidth: 76, alignment: .trailing)

            HStack(spacing: ZenDesign.Spacing.compact) {
                Button {
                    onShowInFinder(item)
                } label: {
                    Label(
                        String(localized: "context.showInFinder", defaultValue: "Show in Finder"),
                        systemImage: "folder"
                    )
                }

                Button {
                    onCopyPath(item)
                } label: {
                    Label(
                        String(localized: "context.copyPath", defaultValue: "Copy Path"),
                        systemImage: "doc.on.doc"
                    )
                }

                Button(role: .destructive) {
                    onDelete(item)
                } label: {
                    Label(
                        String(localized: "context.moveToTrash", defaultValue: "Move to Trash"),
                        systemImage: "trash"
                    )
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, ZenDesign.Spacing.medium)
        .padding(.vertical, ZenDesign.Spacing.small)
        .background(ZenDesign.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: ZenDesign.Radius.medium, style: .continuous))
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
