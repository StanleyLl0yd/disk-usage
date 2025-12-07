import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showRestartAlert = false
    @State private var previousLanguage: AppLanguage = .system
    
    var body: some View {
        Form {
            // MARK: - Appearance
            Section {
                Picker(String(localized: "settings.viewMode", defaultValue: "Default View"), selection: $settings.viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text(String(localized: "settings.section.appearance", defaultValue: "Appearance"))
            }
            
            // MARK: - Language
            Section {
                Picker(String(localized: "settings.language", defaultValue: "Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.title).tag(lang)
                    }
                }
                .onChange(of: settings.language) { old, new in
                    if old != new {
                        previousLanguage = old
                        settings.applyLanguage()
                        showRestartAlert = true
                    }
                }
            } header: {
                Text(String(localized: "settings.section.language", defaultValue: "Language"))
            } footer: {
                Text(String(localized: "settings.language.hint", defaultValue: "Restart the app to apply language changes."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // MARK: - Behavior
            Section {
                Toggle(String(localized: "settings.confirmDelete", defaultValue: "Confirm before deleting"), isOn: $settings.confirmDelete)
                
                Toggle(String(localized: "settings.showHidden", defaultValue: "Show hidden files"), isOn: $settings.showHiddenFiles)
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
            Text(String(localized: "settings.restart.message", defaultValue: "The app needs to restart to apply the new language."))
        }
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    SettingsView()
}
