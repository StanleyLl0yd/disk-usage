import SwiftUI
import AppKit

enum SortOption: String, CaseIterable, Identifiable {
    case sizeDescending
    case sizeAscending
    case name

    var id: Self { self }

    var localizedTitle: String {
        switch self {
        case .sizeDescending:
            return String(localized: "sort.sizeDescending", defaultValue: "Size ↓")
        case .sizeAscending:
            return String(localized: "sort.sizeAscending", defaultValue: "Size ↑")
        case .name:
            return String(localized: "sort.name", defaultValue: "Name")
        }
    }
}

// УЛУЧШЕНИЕ 8: Использовать ByteCountFormatter для локализации
private let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter
}()

func formatBytes(_ bytes: Int64) -> String {
    byteFormatter.string(fromByteCount: bytes)
}

func formatPercent(part: Int64, total: Int64) -> String {
    guard total > 0, part > 0 else {
        return String(localized: "percent.zero", defaultValue: "0.0 %")
    }
    let p = (Double(part) / Double(total)) * 100.0
    return String(format: "%.1f %%", p)
}

private func compare(_ lhs: FolderUsage, _ rhs: FolderUsage, option: SortOption) -> Bool {
    switch option {
    case .sizeDescending:
        if lhs.size == rhs.size {
            return lhs.url.path.localizedCaseInsensitiveCompare(rhs.url.path) == .orderedAscending
        }
        return lhs.size > rhs.size
    case .sizeAscending:
        if lhs.size == rhs.size {
            return lhs.url.path.localizedCaseInsensitiveCompare(rhs.url.path) == .orderedAscending
        }
        return lhs.size < rhs.size
    case .name:
        return lhs.url.path.localizedCaseInsensitiveCompare(rhs.url.path) == .orderedAscending
    }
}

private func sortTree(_ node: FolderUsage, option: SortOption) -> FolderUsage {
    let sortedChildren = node.children.map { child in
        sortTree(child, option: option)
    }.sorted { a, b in
        compare(a, b, option: option)
    }

    return FolderUsage(
        id: node.id,
        url: node.url,
        size: node.size,
        children: sortedChildren
    )
}

struct ContentView: View {
    @StateObject var viewModel: DiskScannerViewModel
    @State private var sortOption: SortOption = .sizeDescending
    // УЛУЧШЕНИЕ 3: Кэш для сортировки
    @State private var sortCache: [SortOption: [FolderUsage]] = [:]
    // УЛУЧШЕНИЕ 14: Debouncing для сортировки
    @State private var sortDebounceTask: DispatchWorkItem?
    // Текущие отсортированные элементы
    @State private var currentSortedItems: [FolderUsage] = []

    private var sortedItems: [FolderUsage] {
        currentSortedItems
    }
    
    // Вычисление сортировки
    private func computeSortedItems() {
        // Проверяем кэш
        if let cached = sortCache[sortOption] {
            currentSortedItems = cached
            return
        }
        
        // Вычисляем и кэшируем
        let sorted = viewModel.items.map { sortTree($0, option: sortOption) }
            .sorted { a, b in
                compare(a, b, option: sortOption)
            }
        
        sortCache[sortOption] = sorted
        currentSortedItems = sorted
    }

    var body: some View {
        VStack(spacing: 8) {
            headerView
            controlsView
            
            // УЛУЧШЕНИЕ 1: Прогресс-бар при сканировании
            if viewModel.isScanning {
                VStack(spacing: 4) {
                    HStack {
                        Text(String(
                            localized: "progress.scanning",
                            defaultValue: "Scanning…"
                        ))
                        Spacer()
                        Text("\(viewModel.filesScanned) files")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    ProgressView()
                        .progressViewStyle(.linear)
                }
                .padding(.horizontal)
            }
            
            listView
        }
        .padding()
        .frame(minWidth: 800, minHeight: 500)
        // УЛУЧШЕНИЕ 3: Очищаем кэш и пересчитываем при изменении данных
        .onChange(of: viewModel.items) {
            sortCache.removeAll()
            computeSortedItems()
        }
        // УЛУЧШЕНИЕ 14: Debouncing при изменении сортировки
        .onChange(of: sortOption) {
            sortDebounceTask?.cancel()
            let task = DispatchWorkItem { [self] in
                self.computeSortedItems()
            }
            sortDebounceTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: task)
        }
        .onAppear {
            computeSortedItems()
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Text(
                String(
                    localized: "header.title",
                    defaultValue: "Disk Usage"
                )
            )
            .font(.title)
            .bold()

            Text(viewModel.currentTargetDescription)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var controlsView: some View {
        HStack(spacing: 12) {
            Text(viewModel.status)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Picker(
                String(localized: "picker.sort", defaultValue: "Sort"),
                selection: $sortOption
            ) {
                ForEach(SortOption.allCases) { option in
                    Text(option.localizedTitle).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .disabled(viewModel.isScanning)
            
            // УЛУЧШЕНИЕ 9: Toggle для параллельного сканирования
            Toggle(isOn: $viewModel.useParallelScanning) {
                Label(
                    String(localized: "toggle.parallelScan", defaultValue: "Parallel"),
                    systemImage: "bolt.fill"
                )
            }
            .toggleStyle(.button)
            .disabled(viewModel.isScanning)
            .help(String(
                localized: "toggle.parallelScan.help",
                defaultValue: "Use parallel scanning for faster results (experimental)"
            ))

            Button {
                viewModel.scanHome()
            } label: {
                Label(
                    String(localized: "button.scanHome", defaultValue: "Scan Home"),
                    systemImage: "house"
                )
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
                    String(localized: "button.chooseFolder", defaultValue: "Choose Folder…"),
                    systemImage: "folder"
                )
            }
            .disabled(viewModel.isScanning)
            
            // УЛУЧШЕНИЕ 2: Кнопка отмены
            if viewModel.isScanning {
                Button(action: {
                    viewModel.cancelScan()
                }) {
                    Label(
                        String(localized: "button.cancel", defaultValue: "Cancel"),
                        systemImage: "xmark.circle"
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    private var listView: some View {
        List {
            if sortedItems.isEmpty && !viewModel.isScanning {
                Section {
                    Text(
                        String(
                            localized: "empty.message",
                            defaultValue: "No data to display. Choose a folder or start a scan."
                        )
                    )
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                }
            } else {
                Section(
                    String(
                        localized: "section.largestItems",
                        defaultValue: "Largest Items"
                    )
                ) {
                    // УЛУЧШЕНИЕ 7: Lazy loading для больших списков
                    ForEach(sortedItems) { item in
                        DisclosureGroup {
                            OutlineGroup(
                                item.children,
                                children: \.childrenOptional
                            ) { child in
                                row(for: child)
                            }
                        } label: {
                            row(for: item)
                        }
                    }
                }
            }

            if !viewModel.restrictedTopFolders.isEmpty {
                Section(
                    String(
                        localized: "section.restricted",
                        defaultValue: "Folders Without Access"
                    )
                ) {
                    ForEach(viewModel.restrictedTopFolders, id: \.self) { path in
                        Text(path)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    Text(
                        String(
                            localized: "restricted.hint",
                            defaultValue: "For a more complete analysis, you can grant the app Full Disk Access in System Settings → Privacy & Security. Do this only if you trust the app."
                        )
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // УЛУЧШЕНИЕ 4 & 10: Визуализация размера + контекстное меню
    private func row(for item: FolderUsage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)

                    Text(item.url.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(item.size))
                        .monospacedDigit()
                        .font(.body)

                    Text(
                        formatPercent(
                            part: item.size,
                            total: viewModel.totalSize
                        )
                    )
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            
            // Визуальный индикатор размера - выносим отдельно
            if viewModel.totalSize > 0 {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(
                            width: max(2, CGFloat(item.size) / CGFloat(viewModel.totalSize) * 600),
                            height: 6
                        )
                }
                .cornerRadius(3)
                .padding(.top, 6)
            }
        }
        .padding(.vertical, 4)
        // УЛУЧШЕНИЕ 10: Контекстное меню
        .contextMenu {
            Button(action: {
                NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
            }) {
                Label(
                    String(localized: "context.showInFinder", defaultValue: "Show in Finder"),
                    systemImage: "folder"
                )
            }
            
            Button(action: {
                NSWorkspace.shared.open(item.url)
            }) {
                Label(
                    String(localized: "context.open", defaultValue: "Open"),
                    systemImage: "arrow.right.square"
                )
            }
            
            Divider()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(item.url.path, forType: .string)
            }) {
                Label(
                    String(localized: "context.copyPath", defaultValue: "Copy Path"),
                    systemImage: "doc.on.doc"
                )
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                confirmDelete(item)
            }) {
                Label(
                    String(localized: "context.moveToTrash", defaultValue: "Move to Trash"),
                    systemImage: "trash"
                )
            }
        }
    }
    
    // УЛУЧШЕНИЕ 10: Подтверждение удаления
    private func confirmDelete(_ item: FolderUsage) {
        let alert = NSAlert()
        alert.messageText = String(
            localized: "alert.deleteTitle",
            defaultValue: "Move to Trash?"
        )
        alert.informativeText = String(
            format: String(
                localized: "alert.deleteMessage",
                defaultValue: "Are you sure you want to move \"%@\" to Trash? This will free up %@."
            ),
            item.name,
            formatBytes(item.size)
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(
            localized: "alert.moveToTrash",
            defaultValue: "Move to Trash"
        ))
        alert.addButton(withTitle: String(
            localized: "alert.cancel",
            defaultValue: "Cancel"
        ))
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                // Пересканировать после удаления
                if let parent = item.url.deletingLastPathComponent().path.isEmpty ? nil : item.url.deletingLastPathComponent() {
                    viewModel.scanFolder(at: parent)
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = String(
                    localized: "alert.errorTitle",
                    defaultValue: "Could not move to Trash"
                )
                errorAlert.informativeText = error.localizedDescription
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(
            localized: "panel.choose",
            defaultValue: "Choose"
        )
        panel.message = String(
            localized: "panel.message",
            defaultValue: "Choose a folder to analyze disk usage."
        )

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanFolder(at: url)
        }
    }
}
