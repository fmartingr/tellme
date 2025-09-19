import Foundation

public class LocalizationManager {
    public static let shared = LocalizationManager()

    private var currentLanguage: String
    private var strings: [String: String] = [:]

    private init() {
        // Detect system language
        let preferredLanguages = Locale.preferredLanguages
        let systemLanguage = preferredLanguages.first ?? "en"

        if systemLanguage.hasPrefix("es") {
            currentLanguage = "es"
        } else {
            currentLanguage = "en"
        }

        loadStrings()
    }

    public func localizedString(_ key: String, comment: String = "") -> String {
        return strings[key] ?? key
    }

    private func loadStrings() {
        // Load strings for current language
        if let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "Localizations/\(currentLanguage).lproj"),
           let data = FileManager.default.contents(atPath: path),
           let content = String(data: data, encoding: .utf8) {
            parseStringsFile(content)
        } else {
            // Fallback to embedded strings
            loadEmbeddedStrings()
        }
    }

    private func parseStringsFile(_ content: String) {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("\"") && trimmed.contains("\" = \"") && trimmed.hasSuffix("\";") {
                // Parse: "key" = "value";
                let parts = trimmed.dropFirst().dropLast() // Remove leading " and trailing ";
                if let equalIndex = parts.firstIndex(of: "=") {
                    let keyPart = String(parts[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let valuePart = String(parts[parts.index(after: equalIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

                    if keyPart.hasPrefix("\"") && keyPart.hasSuffix("\"") &&
                       valuePart.hasPrefix("\"") && valuePart.hasSuffix("\"") {
                        let key = String(keyPart.dropFirst().dropLast())
                        let value = String(valuePart.dropFirst().dropLast())
                        strings[key] = value
                    }
                }
            }
        }
    }

    private func loadEmbeddedStrings() {
        // Fallback embedded strings for key functionality
        if currentLanguage == "es" {
            strings = [
                "app.name": "Tell me",
                "preferences.title": "Preferencias de Tell me",
                "preferences.general": "General",
                "preferences.models": "Modelos",
                "preferences.insertion": "Inserción de Texto",
                "preferences.interface": "Interfaz",
                "preferences.advanced": "Avanzado",
                "preferences.permissions": "Permisos",
                "preferences.general.title": "Configuración General",
                "preferences.models.title": "Modelos de Reconocimiento de Voz",
                "preferences.insertion.title": "Inserción de Texto",
                "preferences.hud.title": "Configuración de Interfaz",
                "preferences.advanced.title": "Configuración Avanzada",
                "general.cancel": "Cancelar",
                "general.ok": "Aceptar",
                "preferences.models.download": "Descargar",
                "preferences.models.delete": "Eliminar",
                "preferences.models.downloading": "Descargando...",
                "status.loaded": "Cargado",
                "status.loading": "Cargando...",
                "alert.delete_model": "Eliminar Modelo"
            ]
        } else {
            strings = [
                "app.name": "Tell me",
                "preferences.title": "Tell me Preferences",
                "preferences.general": "General",
                "preferences.models": "Models",
                "preferences.insertion": "Text Insertion",
                "preferences.interface": "Interface",
                "preferences.advanced": "Advanced",
                "preferences.permissions": "Permissions",
                "preferences.general.title": "General Settings",
                "preferences.models.title": "Speech Recognition Models",
                "preferences.insertion.title": "Text Insertion",
                "preferences.hud.title": "Interface Settings",
                "preferences.advanced.title": "Advanced Settings",
                "general.cancel": "Cancel",
                "general.ok": "OK",
                "preferences.models.download": "Download",
                "preferences.models.delete": "Delete",
                "preferences.models.downloading": "Downloading...",
                "status.loaded": "Loaded",
                "status.loading": "Loading...",
                "alert.delete_model": "Delete Model"
            ]
        }
    }
}

// Global convenience function that doesn't conflict with system NSLocalizedString
public func L(_ key: String) -> String {
    return LocalizationManager.shared.localizedString(key)
}