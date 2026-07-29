import Foundation

struct TargetAppIdentity: Codable, Equatable {
    enum VerificationMode: String, Codable {
        case completeBundle
        case codeSignatureOnly
    }

    let displayName: String
    let signingIdentifier: String
    let teamIdentifier: String
    let verificationMode: VerificationMode

    init(
        displayName: String,
        signingIdentifier: String,
        teamIdentifier: String,
        verificationMode: VerificationMode
    ) {
        self.displayName = displayName
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.verificationMode = verificationMode
    }
}
