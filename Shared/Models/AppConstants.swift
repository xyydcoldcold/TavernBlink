import Foundation

enum AppConstants {
    static let managerDescription = "TavernBlink Transparent Proxy"
    static let targetIdentityDefaultsKey = "targetAppIdentity"
    static let targetApplicationPathDefaultsKey = "targetApplicationPath"

    static var proxyExtensionBundleIdentifier: String {
        value(forInfoKey: "ProxyExtensionBundleIdentifier")
    }

    static var appGroupIdentifier: String {
        value(forInfoKey: "SharedAppGroupIdentifier")
    }

    private static func value(forInfoKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("$(")
        else {
            preconditionFailure("Missing build setting for \(key)")
        }
        return value
    }
}
