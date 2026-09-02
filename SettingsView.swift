import SwiftUI
import Combine

enum ViewMode: String, CaseIterable, Identifiable {
    case tree
    case sunburst

    var id: Self { self }

    var title: String {
        switch self {
        case .tree: String(localized: "viewMode.tree", defaultValue: "Tree")
        case .sunburst: String(localized: "viewMode.sunburst", defaultValue: "Sunburst")
        }
    }

    var icon: String {
        switch self {
        case .tree: "list.bullet.indent"
        case .sunburst: "circle.circle"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ru

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "language.system", defaultValue: "System")
        case .en: "English"
        case .ru: "Русский"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .en: "en"
        case .ru: "ru"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var viewMode: ViewMode {
        didSet { defaults.set(viewMode.rawValue, forKey: "viewMode") }
    }

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }

    @Published var confirmDelete: Bool {
        didSet { defaults.set(confirmDelete, forKey: "confirmDelete") }
    }

    @Published var showHiddenFiles: Bool {
        didSet { defaults.set(showHiddenFiles, forKey: "showHiddenFiles") }
    }

    private init() {
        viewMode = ViewMode(rawValue: defaults.string(forKey: "viewMode") ?? "") ?? .tree
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        confirmDelete = defaults.object(forKey: "confirmDelete") as? Bool ?? true
        showHiddenFiles = defaults.object(forKey: "showHiddenFiles") as? Bool ?? false
    }

    func applyLanguage() {
        if let identifier = language.localeIdentifier {
            defaults.set([identifier], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            Section {
                Picker(
                    String(localized: "settings.viewMode", defaultValue: "Default View"),
                    selection: $settings.viewMode
                ) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text(String(localized: "settings.section.appearance", defaultValue: "Appearance"))
            }

            Section {
                Picker(
                    String(localized: "settings.language", defaultValue: "Language"),
                    selection: $settings.language
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .onChange(of: settings.language) { oldValue, newValue in
                    guard oldValue != newValue else { return }
                    settings.applyLanguage()
                    showRestartAlert = true
                }
            } header: {
                Text(String(localized: "settings.section.language", defaultValue: "Language"))
            } footer: {
                Text(
                    String(
                        localized: "settings.language.hint",
                        defaultValue: "Restart the app to apply language changes."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle(
                    String(localized: "settings.confirmDelete", defaultValue: "Confirm before deleting"),
                    isOn: $settings.confirmDelete
                )
                Toggle(
                    String(localized: "settings.showHidden", defaultValue: "Show hidden files"),
                    isOn: $settings.showHiddenFiles
                )
            } header: {
                Text(String(localized: "settings.section.behavior", defaultValue: "Behavior"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
        .alert(
            String(localized: "settings.restart.title", defaultValue: "Restart Required"),
            isPresented: $showRestartAlert
        ) {
            Button(String(localized: "settings.restart.later", defaultValue: "Later")) {}
            Button(String(localized: "settings.restart.now", defaultValue: "Restart Now")) {
                restartApp()
            }
        } message: {
            Text(
                String(
                    localized: "settings.restart.message",
                    defaultValue: "The app needs to restart to apply the new language."
                )
            )
        }
    }

    private func restartApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [Bundle.main.bundleURL.path]
        guard (try? process.run()) != nil else { return }
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    SettingsView()
}
