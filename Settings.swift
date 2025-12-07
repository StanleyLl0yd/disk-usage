import SwiftUI
import Combine

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Identifiable {
    case tree
    case sunburst
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .tree:     String(localized: "viewMode.tree", defaultValue: "Tree")
        case .sunburst: String(localized: "viewMode.sunburst", defaultValue: "Sunburst")
        }
    }
    
    var icon: String {
        switch self {
        case .tree:     "list.bullet.indent"
        case .sunburst: "circle.circle"
        }
    }
}

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ru
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .system: String(localized: "language.system", defaultValue: "System")
        case .en:     "English"
        case .ru:     "Русский"
        }
    }
    
    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .en:     "en"
        case .ru:     "ru"
        }
    }
}

// MARK: - App Settings

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
        self.viewMode = ViewMode(rawValue: defaults.string(forKey: "viewMode") ?? "") ?? .tree
        self.language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        self.confirmDelete = defaults.object(forKey: "confirmDelete") as? Bool ?? true
        self.showHiddenFiles = defaults.object(forKey: "showHiddenFiles") as? Bool ?? false
    }
    
    /// Применяет выбранный язык
    func applyLanguage() {
        if let identifier = language.localeIdentifier {
            defaults.set([identifier], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
