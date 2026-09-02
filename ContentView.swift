import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject var viewModel: DiskScannerViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var sortOption: SortOption = .sizeDesc
    @State private var sortedItems: [FolderUsage] = []
    @State private var itemToDelete: FolderUsage?
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 8) {
            header
            controls

            if viewModel.isScanning {
                ProgressPanel(progress: viewModel.progress)
            }

            if viewModel.items.isEmpty && !viewModel.isScanning {
                emptyState
            } else {
                switch settings.viewMode {
                case .tree:
                    TreeView(
                        items: sortedItems,
                        totalSize: viewModel.totalSize,
                        restricted: viewModel.restricted,
                        onShowInFinder: viewModel.showInFinder,
                        onCopyPath: viewModel.copyPath,
                        onDelete: requestDelete
                    )
                case .sunburst:
                    SunburstView(
                        items: viewModel.items,
                        totalSize: viewModel.totalSize,
                        scanProgress: viewModel.isScanning ? viewModel.progress : nil,
                        onShowInFinder: viewModel.showInFinder,
                        onCopyPath: viewModel.copyPath,
                        onDelete: requestDelete
                    )

                    if !viewModel.restricted.isEmpty {
                        restrictedBanner
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: viewModel.items) { _, items in
            refreshSortedItems(items)
        }
        .onChange(of: sortOption) { _, _ in
            refreshSortedItems(viewModel.items)
        }
        .onChange(of: settings.viewMode) { _, _ in
            refreshSortedItems(viewModel.items)
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

    private func refreshSortedItems(_ items: [FolderUsage]) {
        guard settings.viewMode == .tree else {
            sortedItems = []
            return
        }
        sortedItems = sortOption.sorted(items.map { $0.sorted(by: sortOption) })
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

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(String(localized: "header.title", defaultValue: "Disk Usage"))
                    .font(.title)
                    .bold()
                Text(viewModel.targetDescription)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()

                Picker("", selection: $settings.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Image(systemName: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .help(String(localized: "header.viewMode.help", defaultValue: "Switch view mode"))
            }

            if viewModel.diskInfo.totalCapacity > 0 {
                DiskInfoBar(diskInfo: viewModel.diskInfo)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.isScanning {
                Text(viewModel.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if settings.viewMode == .tree {
                    Picker("", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .disabled(viewModel.isScanning)
                }

                Spacer()

                Button {
                    viewModel.scanHome()
                } label: {
                    Label(String(localized: "button.scanHome", defaultValue: "Scan Home"), systemImage: "house")
                }
                .disabled(viewModel.isScanning)

                Button {
                    viewModel.scanRoot()
                } label: {
                    Label(
                        String(localized: "button.scanRoot", defaultValue: "Scan Disk (/)"),
                        systemImage: "internaldrive"
                    )
                }
                .disabled(viewModel.isScanning)

                Button {
                    chooseFolder()
                } label: {
                    Label(
                        String(localized: "button.chooseFolder", defaultValue: "Choose…"),
                        systemImage: "folder"
                    )
                }
                .disabled(viewModel.isScanning)

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
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "empty.message", defaultValue: "No data. Start a scan."))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var restrictedBanner: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text(
                String(
                    format: String(
                        localized: "restricted.count",
                        defaultValue: "%d folders without access"
                    ),
                    viewModel.restricted.count
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
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
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.linear)

            HStack(spacing: 16) {
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
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            if !progress.currentFolder.isEmpty {
                Text(progress.currentFolder)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
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
        case ..<0.7: .blue
        case ..<0.85: .orange
        default: .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geometry.size.width * usedRatio)
                }
            }
            .frame(height: 8)
            .frame(maxWidth: 200)

            HStack(spacing: 4) {
                Text(formatBytes(diskInfo.usedSpace))
                    .fontWeight(.medium)
                Text("/")
                    .foregroundStyle(.secondary)
                Text(formatBytes(diskInfo.totalCapacity))
                    .foregroundStyle(.secondary)
                Text(String(format: "(%.0f%%)", diskInfo.usedPercent))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .monospacedDigit()

            Spacer()

            HStack(spacing: 4) {
                Text(String(localized: "disk.free", defaultValue: "Free:"))
                    .foregroundStyle(.secondary)
                Text(formatBytes(diskInfo.freeSpace))
                    .fontWeight(.medium)
            }
            .font(.caption)
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }
}
