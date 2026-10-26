import SwiftUI

/// The language the person picked in settings.
nonisolated enum LanguagePreference: String, CaseIterable, Identifiable {
    case system, chinese, english

    var id: Self { self }

    /// Each option is named in its own language, so it can be found whatever the current one is.
    func title(in language: Language) -> String {
        switch self {
        case .system: language.pick("跟随系统", "System")
        case .chinese: "中文"
        case .english: "English"
        }
    }
}

/// The language the interface is shown in. The app switches language in place, without a
/// restart, so it picks strings itself instead of going through the bundle's localizations.
nonisolated enum Language: Sendable {
    case chinese, english

    init(_ preference: LanguagePreference) {
        switch preference {
        case .chinese: self = .chinese
        case .english: self = .english
        case .system: self = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
        }
    }

    /// For text built outside a view, such as error messages.
    static var current: Language {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.language) ?? ""
        return Language(LanguagePreference(rawValue: raw) ?? .system)
    }

    func pick(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}

extension EnvironmentValues {
    @Entry var language: Language = .current
}
