import SwiftUI

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
