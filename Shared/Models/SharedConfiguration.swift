import Foundation

final class SharedConfiguration {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(appGroupIdentifier: String = AppConstants.appGroupIdentifier) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            preconditionFailure("Unable to open App Group defaults: \(appGroupIdentifier)")
        }
        self.defaults = defaults
    }

    var targetIdentity: TargetAppIdentity? {
        get {
            guard let data = defaults.data(forKey: AppConstants.targetIdentityDefaultsKey) else {
                return nil
            }
            return try? decoder.decode(TargetAppIdentity.self, from: data)
        }
        set {
            if let newValue, let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: AppConstants.targetIdentityDefaultsKey)
            } else {
                defaults.removeObject(forKey: AppConstants.targetIdentityDefaultsKey)
            }
        }
    }
}
