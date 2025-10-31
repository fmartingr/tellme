import Foundation
import CoreUtils

public class LocalizationManager {
    public static let shared = LocalizationManager()

    private var resourceBundle: Bundle
    private var currentLanguage: String

    private init() {
        // Detect system language
        let preferredLanguages = Locale.preferredLanguages
        let systemLanguage = preferredLanguages.first ?? "en"

        if systemLanguage.hasPrefix("es") {
            currentLanguage = "es"
        } else {
            currentLanguage = "en"
        }

        resourceBundle = Bundle.module
        loadResourceBundle()

        Localization.register { [weak self] key in
            guard let self else { return key }
            return self.lookupLocalizedString(key)
        }
    }

    public func localizedString(_ key: String, comment: String = "") -> String {
        let localizedValue = lookupLocalizedString(key)
        return localizedValue != key ? localizedValue : key
    }

    private func loadResourceBundle() {
        let bundle = Bundle.module

        if let languagePath = bundle.path(forResource: currentLanguage, ofType: "lproj"),
           let languageBundle = Bundle(path: languagePath) {
            resourceBundle = languageBundle
        } else {
            resourceBundle = bundle
        }
    }

    private func lookupLocalizedString(_ key: String) -> String {
        resourceBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
