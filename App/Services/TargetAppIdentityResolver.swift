import Foundation
import Security

final class TargetAppIdentityResolver {
    static let expectedSigningIdentifier = "unity.Blizzard Entertainment.Hearthstone"
    static let expectedTeamIdentifier = "G847MC6JZ5"

    enum IdentityError: LocalizedError {
        case notAnApplication
        case staticCode(OSStatus)
        case requirement(OSStatus)
        case invalidSignature(OSStatus)
        case missingTeamIdentifier
        case missingSigningIdentifier
        case unexpectedIdentity(signingIdentifier: String, teamIdentifier: String)

        var errorDescription: String? {
            switch self {
            case .notAnApplication:
                return "Choose a macOS application bundle."
            case let .staticCode(status):
                return "Unable to inspect the app signature (OSStatus \(status))."
            case let .requirement(status):
                return "Unable to create the Hearthstone signing requirement (OSStatus \(status))."
            case let .invalidSignature(status):
                return "The selected app does not have an acceptable code signature (OSStatus \(status))."
            case .missingTeamIdentifier:
                return "The selected app signature has no Team ID."
            case .missingSigningIdentifier:
                return "The selected app signature has no signing identifier."
            case let .unexpectedIdentity(signingIdentifier, teamIdentifier):
                return """
                The selected app is not the supported Blizzard Hearthstone build \
                (signing ID: \(signingIdentifier), Team ID: \(teamIdentifier)).
                """
            }
        }
    }

    func resolveApplication(at url: URL) throws -> TargetAppIdentity {
        guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
            throw IdentityError.notAnApplication
        }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            throw IdentityError.staticCode(createStatus)
        }

        let requirement = try makeHearthstoneRequirement()
        let completeFlags = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures
                | kSecCSCheckNestedCode
                | kSecCSStrictValidate
        )
        let completeStatus = SecStaticCodeCheckValidity(
            staticCode,
            completeFlags,
            requirement
        )

        let verificationMode: TargetAppIdentity.VerificationMode
        if completeStatus == errSecSuccess {
            verificationMode = .completeBundle
        } else {
            guard Self.isResourceSealError(completeStatus) else {
                throw IdentityError.invalidSignature(completeStatus)
            }

            let fallbackFlags = SecCSFlags(
                rawValue: completeFlags.rawValue | kSecCSDoNotValidateResources
            )
            let fallbackStatus = SecStaticCodeCheckValidity(
                staticCode,
                fallbackFlags,
                requirement
            )
            guard fallbackStatus == errSecSuccess else {
                throw IdentityError.invalidSignature(fallbackStatus)
            }
            verificationMode = .codeSignatureOnly
        }

        var information: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        )
        guard infoStatus == errSecSuccess,
              let dictionary = information as? [CFString: Any],
              let signingIdentifier = dictionary[kSecCodeInfoIdentifier] as? String,
              !signingIdentifier.isEmpty
        else {
            throw IdentityError.missingSigningIdentifier
        }
        guard let teamIdentifier = dictionary[kSecCodeInfoTeamIdentifier] as? String,
              !teamIdentifier.isEmpty
        else {
            throw IdentityError.missingTeamIdentifier
        }
        guard Self.isExpectedHearthstoneIdentity(
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier
        ) else {
            throw IdentityError.unexpectedIdentity(
                signingIdentifier: signingIdentifier,
                teamIdentifier: teamIdentifier
            )
        }

        let displayName = (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return TargetAppIdentity(
            displayName: displayName,
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            verificationMode: verificationMode
        )
    }

    static func isExpectedHearthstoneIdentity(
        signingIdentifier: String,
        teamIdentifier: String
    ) -> Bool {
        signingIdentifier == expectedSigningIdentifier
            && teamIdentifier == expectedTeamIdentifier
    }

    static func isResourceSealError(_ status: OSStatus) -> Bool {
        [
            errSecCSBadResource,
            errSecCSResourcesInvalid,
            errSecCSResourcesNotFound,
            errSecCSResourcesNotSealed
        ].contains(status)
    }

    private func makeHearthstoneRequirement() throws -> SecRequirement {
        let requirementText = """
        identifier "\(Self.expectedSigningIdentifier)" and anchor apple generic \
        and certificate leaf[subject.OU] = "\(Self.expectedTeamIdentifier)"
        """
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(
            requirementText as CFString,
            [],
            &requirement
        )
        guard status == errSecSuccess, let requirement else {
            throw IdentityError.requirement(status)
        }
        return requirement
    }
}
