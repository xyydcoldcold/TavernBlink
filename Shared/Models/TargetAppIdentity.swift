import Foundation

struct TargetAppIdentity: Codable, Equatable {
    let displayName: String
    let signingIdentifier: String

    init(displayName: String, signingIdentifier: String) {
        self.displayName = displayName
        self.signingIdentifier = signingIdentifier
    }
}
