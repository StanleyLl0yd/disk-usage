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

func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var i = 0

    while value > 1024.0 && i < units.count - 1 {
        value /= 1024.0
        i += 1
    }

    return String(format: "%.1f %@", value, units[i])
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

    // Упрощённая сортировка без кэша
    private var sortedItems: [FolderUsage] {
        viewModel.items.map { sortTree($0, option: sortOption) }
            .sorted { a, b in
                compare(a, b, option: sortOption)
            }
    }

    var body: some View {
        VStack(spacing: 8) {
            headerView
            controlsView
            
            // Простой прогресс без счётчика файлов
            if viewModel.isScanning {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
            }
            
            listView
        }
        .padding()
        .frame(minWidth: 800, minHeight: 500)
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
            
            // Кнопка отмены
            if viewModel.isScanning {
                Button {
                    viewModel.cancelScan()
                } label: {
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
                    // Простой OutlineGroup без DisclosureGroup
                    OutlineGroup(
                        sortedItems,
                        children: \.childrenOptional
                    ) { item in
                        row(for: item)
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

    private func row(for item: FolderUsage) -> some View {
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
