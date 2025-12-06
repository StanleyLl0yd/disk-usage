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

// MARK: - Константы

private let sizeUnits = ["B", "KB", "MB", "GB", "TB"]

// MARK: - Форматирование

func formatBytes(_ bytes: Int64) -> String {
    var value = Double(bytes)
    var i = 0

    while value > 1024.0 && i < sizeUnits.count - 1 {
        value /= 1024.0
        i += 1
    }

    return String(format: "%.1f %@", value, sizeUnits[i])
}

func formatPercent(part: Int64, total: Int64) -> String {
    guard total > 0, part > 0 else {
        return String(localized: "percent.zero", defaultValue: "0.0 %")
    }
    let p = (Double(part) / Double(total)) * 100.0
    return String(format: "%.1f %%", p)
}

func sizeRatio(part: Int64, total: Int64) -> Double {
    guard total > 0, part > 0 else { return 0 }
    return min(Double(part) / Double(total), 1.0)
}

// MARK: - Сортировка

private func compare(_ lhs: FolderUsage, _ rhs: FolderUsage, option: SortOption) -> Bool {
    let nameComparison = { lhs.url.path.localizedCaseInsensitiveCompare(rhs.url.path) == .orderedAscending }
    
    switch option {
    case .sizeDescending:
        return lhs.size != rhs.size ? lhs.size > rhs.size : nameComparison()
    case .sizeAscending:
        return lhs.size != rhs.size ? lhs.size < rhs.size : nameComparison()
    case .name:
        return nameComparison()
    }
}

private func sortTree(_ node: FolderUsage, option: SortOption) -> FolderUsage {
    let sortedChildren = node.children
        .map { sortTree($0, option: option) }
        .sorted { compare($0, $1, option: option) }

    return FolderUsage(
        url: node.url,
        size: node.size,
        children: sortedChildren,
        isFile: node.isFile
    )
}

// MARK: - Size Bar Component

struct SizeBar: View {
    let ratio: Double
    let height: CGFloat = 4
    
    private var barColor: Color {
        switch ratio {
        case 0..<0.25:
            return .green
        case 0.25..<0.5:
            return .yellow
        case 0.5..<0.75:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(barColor)
                    .frame(width: max(geometry.size.width * ratio, ratio > 0 ? 2 : 0))
            }
        }
        .frame(height: height)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject var viewModel: DiskScannerViewModel
    @State private var sortOption: SortOption = .sizeDescending
    @State private var sortedItemsCache: [FolderUsage] = []
    @State private var isRestrictedSectionExpanded: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            headerView
            controlsView
            
            if viewModel.isScanning {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
            }
            
            listView
        }
        .padding()
        .frame(minWidth: 800, minHeight: 500)
        .onChange(of: viewModel.items) { _, newItems in
            updateSortedCache(items: newItems, option: sortOption)
        }
        .onChange(of: sortOption) { _, newOption in
            updateSortedCache(items: viewModel.items, option: newOption)
        }
        .onAppear {
            updateSortedCache(items: viewModel.items, option: sortOption)
        }
    }
    
    private func updateSortedCache(items: [FolderUsage], option: SortOption) {
        sortedItemsCache = items
            .map { sortTree($0, option: option) }
            .sorted { compare($0, $1, option: option) }
    }

    // MARK: - Header

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

    // MARK: - Controls

    private var controlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Статус на отдельной строке — не обрезается
            Text(viewModel.status)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Picker(selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.localizedTitle).tag(option)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(viewModel.isScanning)

                Spacer()

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
        }
        .padding(.top, 4)
    }

    // MARK: - List

    private var listView: some View {
        List {
            if sortedItemsCache.isEmpty && !viewModel.isScanning {
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
                    OutlineGroup(
                        sortedItemsCache,
                        children: \.childrenOptional
                    ) { item in
                        row(for: item)
                    }
                }
            }

            if !viewModel.restrictedTopFolders.isEmpty {
                Section {
                    DisclosureGroup(
                        isExpanded: $isRestrictedSectionExpanded
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
                        .padding(.top, 4)
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                            
                            Text(
                                String(
                                    localized: "section.restricted",
                                    defaultValue: "Folders Without Access"
                                )
                            )
                            
                            Text("(\(viewModel.restrictedTopFolders.count))")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func row(for item: FolderUsage) -> some View {
        HStack(spacing: 8) {
            // Иконка файла или папки
            Image(systemName: item.isFile ? "doc" : "folder")
                .foregroundColor(item.isFile ? .secondary : .accentColor)
                .frame(width: 16)
            
            // Имя и путь
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)

                Text(item.url.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 150, alignment: .leading)

            // Прогресс-бар
            SizeBar(ratio: sizeRatio(part: item.size, total: viewModel.totalSize))
                .frame(minWidth: 60, maxWidth: 120)

            Spacer()

            // Размер и процент
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
            .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Folder Picker

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
