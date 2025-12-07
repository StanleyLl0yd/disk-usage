import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject var viewModel: DiskScannerViewModel
    @State private var sortOption: SortOption = .sizeDesc
    @State private var sortedItems: [FolderUsage] = []
    @State private var showRestricted = false
    
    // Для диалога удаления
    @State private var itemToDelete: FolderUsage?
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 8) {
            header
            controls
            if viewModel.isScanning { ProgressPanel(progress: viewModel.progress) }
            itemList
        }
        .padding()
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: viewModel.items) { _, items in updateSort(items) }
        .onChange(of: sortOption) { _, _ in updateSort(viewModel.items) }
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
            Text(String(format: String(localized: "alert.delete.message", defaultValue: "Are you sure you want to move \"%@\" to Trash?\n\nThis will free up %@."), item.name, formatBytes(item.size)))
        }
        .alert(
            String(localized: "alert.error.title", defaultValue: "Error"),
            isPresented: $showErrorAlert
        ) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func updateSort(_ items: [FolderUsage]) {
        sortedItems = items.map { $0.sorted(by: sortOption) }.sorted {
            switch sortOption {
            case .sizeDesc: $0.size > $1.size
            case .sizeAsc:  $0.size < $1.size
            case .name:     $0.path < $1.path
            }
        }
    }
    
    private func deleteItem(_ item: FolderUsage) {
        let result = viewModel.moveToTrash(item)
        if case .error(let message) = result {
            errorMessage = message
            showErrorAlert = true
        } else {
            // Обновляем отсортированный список
            updateSort(viewModel.items)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Text(String(localized: "header.title", defaultValue: "Disk Usage"))
                .font(.title).bold()
            Text(viewModel.targetDescription)
                .font(.headline).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
        }
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.isScanning {
                Text(viewModel.status).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Picker("", selection: $sortOption) {
                    ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(viewModel.isScanning)
                
                Spacer()
                
                Button { viewModel.scanHome() } label: {
                    Label(String(localized: "button.scanHome", defaultValue: "Scan Home"), systemImage: "house")
                }.disabled(viewModel.isScanning)
                
                Button { viewModel.scanRoot() } label: {
                    Label(String(localized: "button.scanRoot", defaultValue: "Scan Disk (/)"), systemImage: "internaldrive")
                }.disabled(viewModel.isScanning)
                
                Button { chooseFolder() } label: {
                    Label(String(localized: "button.chooseFolder", defaultValue: "Choose…"), systemImage: "folder")
                }.disabled(viewModel.isScanning)
                
                if viewModel.isScanning {
                    Button(role: .cancel) { viewModel.cancel() } label: {
                        Label(String(localized: "button.cancel", defaultValue: "Cancel"), systemImage: "xmark.circle")
                    }.keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
    }
    
    // MARK: - List
    
    private var itemList: some View {
        List {
            if sortedItems.isEmpty && !viewModel.isScanning {
                Text(String(localized: "empty.message", defaultValue: "No data. Start a scan."))
                    .foregroundStyle(.secondary).padding(.vertical, 20)
            } else {
                Section(String(localized: "section.items", defaultValue: "Items")) {
                    OutlineGroup(sortedItems, children: \.childrenOptional) { item in
                        ItemRow(item: item, totalSize: viewModel.totalSize)
                            .contextMenu { contextMenu(for: item) }
                    }
                }
            }
            
            if !viewModel.restricted.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showRestricted) {
                        ForEach(viewModel.restricted, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        Text(String(localized: "restricted.hint", defaultValue: "Grant Full Disk Access in System Settings for complete analysis."))
                            .font(.footnote).foregroundStyle(.secondary)
                    } label: {
                        Label("\(String(localized: "section.restricted", defaultValue: "No Access")) (\(viewModel.restricted.count))", systemImage: "lock.fill")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenu(for item: FolderUsage) -> some View {
        Button {
            viewModel.showInFinder(item)
        } label: {
            Label(String(localized: "context.showInFinder", defaultValue: "Show in Finder"), systemImage: "folder")
        }
        
        Button {
            viewModel.copyPath(item)
        } label: {
            Label(String(localized: "context.copyPath", defaultValue: "Copy Path"), systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            itemToDelete = item
            showDeleteAlert = true
        } label: {
            Label(String(localized: "context.moveToTrash", defaultValue: "Move to Trash"), systemImage: "trash")
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

// MARK: - Item Row

struct ItemRow: View {
    let item: FolderUsage
    let totalSize: Int64
    
    private var ratio: Double { totalSize > 0 ? min(Double(item.size) / Double(totalSize), 1) : 0 }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.isFile ? "doc" : "folder")
                .foregroundStyle(item.isFile ? .secondary : Color.accentColor)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(minWidth: 150, alignment: .leading)
            
            SizeBar(ratio: ratio).frame(minWidth: 60, maxWidth: 120)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(item.size)).monospacedDigit()
                Text(formatPercent(item.size, of: totalSize)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Size Bar

struct SizeBar: View {
    let ratio: Double
    
    private var color: Color {
        switch ratio {
        case ..<0.25: .green
        case ..<0.5:  .yellow
        case ..<0.75: .orange
        default:      .red
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(color).frame(width: max(geo.size.width * ratio, ratio > 0 ? 2 : 0))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Progress Panel

struct ProgressPanel: View {
    let progress: ScanProgress
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView().progressViewStyle(.linear)
            HStack(spacing: 16) {
                Label(String(format: String(localized: "progress.files", defaultValue: "%@ files"), formatNumber(progress.filesScanned)), systemImage: "doc")
                Label(formatBytes(progress.bytesFound), systemImage: "internaldrive")
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            
            if !progress.currentFolder.isEmpty {
                Text(progress.currentFolder)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}
