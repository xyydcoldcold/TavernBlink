import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case simplifiedChinese

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

@MainActor
final class AppLanguageSettings: ObservableObject {
    static let defaultsKey = "TavernBlinkAppLanguage"

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Self.defaultsKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = defaults.string(forKey: Self.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .english
    }
}
