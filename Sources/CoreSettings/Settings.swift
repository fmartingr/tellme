import Foundation
import CoreUtils

public enum HotkeyMode: String, CaseIterable, Codable {
    case pushToTalk = "push_to_talk"
    case toggle = "toggle"

    public var displayName: String {
        switch self {
        case .pushToTalk:
            return NSLocalizedString("preferences.general.mode.push_to_talk", comment: "Push to talk mode")
        case .toggle:
            return NSLocalizedString("preferences.general.mode.toggle", comment: "Toggle mode")
        }
    }
}

public struct HotkeyConfig: Codable {
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Default to ⌘⇧V
    public static let `default` = HotkeyConfig(keyCode: 9, modifiers: 768) // V key with Cmd+Shift
}

public enum InsertionMethod: String, CaseIterable, Codable {
    case paste = "paste"
    case typing = "typing"

    public var displayName: String {
        switch self {
        case .paste:
            return NSLocalizedString("preferences.insertion.method.paste", comment: "Paste method")
        case .typing:
            return NSLocalizedString("preferences.insertion.method.type", comment: "Type method")
        }
    }
}

public class Settings: ObservableObject {
    private let logger = Logger(category: "Settings")
    private let userDefaults = UserDefaults.standard

    // General Settings
    @Published public var hotkey: HotkeyConfig {
        didSet { saveHotkey() }
    }

    @Published public var hotkeyMode: HotkeyMode {
        didSet { saveHotkeyMode() }
    }

    @Published public var playSounds: Bool {
        didSet { userDefaults.set(playSounds, forKey: "playSounds") }
    }

    @Published public var dictationTimeLimit: TimeInterval {
        didSet { userDefaults.set(dictationTimeLimit, forKey: "dictationTimeLimit") }
    }

    // HUD Settings
    @Published public var hudOpacity: Double {
        didSet { userDefaults.set(hudOpacity, forKey: "hudOpacity") }
    }

    @Published public var hudSize: Double {
        didSet { userDefaults.set(hudSize, forKey: "hudSize") }
    }

    // Model Settings
    @Published public var activeModelName: String? {
        didSet { userDefaults.set(activeModelName, forKey: "activeModelName") }
    }

    @Published public var forcedLanguage: String? {
        didSet { userDefaults.set(forcedLanguage, forKey: "forcedLanguage") }
    }

    // Insertion Settings
    @Published public var insertionMethod: InsertionMethod {
        didSet { userDefaults.set(insertionMethod.rawValue, forKey: "insertionMethod") }
    }

    @Published public var showPreview: Bool {
        didSet { userDefaults.set(showPreview, forKey: "showPreview") }
    }

    // Advanced Settings
    @Published public var enableLogging: Bool {
        didSet { userDefaults.set(enableLogging, forKey: "enableLogging") }
    }

    @Published public var processingThreads: Int {
        didSet { userDefaults.set(processingThreads, forKey: "processingThreads") }
    }

    public init() {
        // Load settings from UserDefaults
        self.hotkey = Settings.loadHotkey()
        self.hotkeyMode = HotkeyMode(rawValue: userDefaults.string(forKey: "hotkeyMode") ?? "") ?? .pushToTalk
        self.playSounds = userDefaults.object(forKey: "playSounds") as? Bool ?? false
        self.dictationTimeLimit = userDefaults.object(forKey: "dictationTimeLimit") as? TimeInterval ?? 600 // 10 minutes

        // HUD Settings
        self.hudOpacity = userDefaults.object(forKey: "hudOpacity") as? Double ?? 0.9
        self.hudSize = userDefaults.object(forKey: "hudSize") as? Double ?? 1.0

        // Model Settings
        self.activeModelName = userDefaults.string(forKey: "activeModelName")
        self.forcedLanguage = userDefaults.string(forKey: "forcedLanguage")

        // Insertion Settings
        let insertionMethodString = userDefaults.string(forKey: "insertionMethod") ?? "paste"
        self.insertionMethod = InsertionMethod(rawValue: insertionMethodString) ?? .paste
        self.showPreview = userDefaults.object(forKey: "showPreview") as? Bool ?? false

        // Advanced Settings
        self.enableLogging = userDefaults.object(forKey: "enableLogging") as? Bool ?? false
        self.processingThreads = userDefaults.object(forKey: "processingThreads") as? Int ?? 4

        logger.info("Settings initialized")
    }

    public func exportSettings() throws -> Data {
        let settingsDict: [String: Any] = [
            "hotkeyKeyCode": hotkey.keyCode,
            "hotkeyModifiers": hotkey.modifiers,
            "hotkeyMode": hotkeyMode.rawValue,
            "playSounds": playSounds,
            "dictationTimeLimit": dictationTimeLimit,
            "hudOpacity": hudOpacity,
            "hudSize": hudSize,
            "activeModelName": activeModelName as Any,
            "forcedLanguage": forcedLanguage as Any,
            "insertionMethod": insertionMethod.rawValue,
            "showPreview": showPreview,
            "enableLogging": enableLogging,
            "processingThreads": processingThreads
        ]

        return try JSONSerialization.data(withJSONObject: settingsDict, options: .prettyPrinted)
    }

    public func importSettings(from data: Data) throws {
        let settingsDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        if let keyCode = settingsDict["hotkeyKeyCode"] as? UInt32,
           let modifiers = settingsDict["hotkeyModifiers"] as? UInt32 {
            hotkey = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        }

        if let modeString = settingsDict["hotkeyMode"] as? String,
           let mode = HotkeyMode(rawValue: modeString) {
            hotkeyMode = mode
        }

        if let sounds = settingsDict["playSounds"] as? Bool {
            playSounds = sounds
        }

        if let timeLimit = settingsDict["dictationTimeLimit"] as? TimeInterval {
            dictationTimeLimit = timeLimit
        }

        if let opacity = settingsDict["hudOpacity"] as? Double {
            hudOpacity = opacity
        }

        if let size = settingsDict["hudSize"] as? Double {
            hudSize = size
        }

        activeModelName = settingsDict["activeModelName"] as? String
        forcedLanguage = settingsDict["forcedLanguage"] as? String

        if let methodString = settingsDict["insertionMethod"] as? String,
           let method = InsertionMethod(rawValue: methodString) {
            insertionMethod = method
        }

        if let preview = settingsDict["showPreview"] as? Bool {
            showPreview = preview
        }

        if let logging = settingsDict["enableLogging"] as? Bool {
            enableLogging = logging
        }

        if let threads = settingsDict["processingThreads"] as? Int {
            processingThreads = threads
        }

        logger.info("Settings imported successfully")
    }

    private static func loadHotkey() -> HotkeyConfig {
        let keyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? UInt32 ?? HotkeyConfig.default.keyCode
        let modifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt32 ?? HotkeyConfig.default.modifiers
        return HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
    }

    private func saveHotkey() {
        userDefaults.set(hotkey.keyCode, forKey: "hotkeyKeyCode")
        userDefaults.set(hotkey.modifiers, forKey: "hotkeyModifiers")
    }

    private func saveHotkeyMode() {
        userDefaults.set(hotkeyMode.rawValue, forKey: "hotkeyMode")
    }
}