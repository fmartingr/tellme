import Foundation

public enum Localization {
    private static var provider: (String) -> String = { key in key }

    public static func register(provider: @escaping (String) -> String) {
        self.provider = provider
    }

    public static func localized(_ key: String) -> String {
        provider(key)
    }
}

public func L(_ key: String) -> String {
    Localization.localized(key)
}

