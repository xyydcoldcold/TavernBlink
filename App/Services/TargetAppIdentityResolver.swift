import Foundation
import Security

final class TargetAppIdentityResolver {
    enum IdentityError: LocalizedError {
        case notAnApplication
        case staticCode(OSStatus)
        case invalidSignature(OSStatus)
        case missingSigningIdentifier

        var errorDescription: String? {
            switch self {
            case .notAnApplication:
                return "Choose a macOS application bundle."
            case let .staticCode(status):
                return "Unable to inspect the app signature (OSStatus \(status))."
            case let .invalidSignature(status):
                return "The selected app does not have a valid signature (OSStatus \(status))."
            case .missingSigningIdentifier:
                return "The selected app signature has no signing identifier."
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

        let validityStatus = SecStaticCodeCheckValidity(staticCode, [], nil)
        guard validityStatus == errSecSuccess else {
            throw IdentityError.invalidSignature(validityStatus)
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

        let displayName = (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return TargetAppIdentity(
            displayName: displayName,
            signingIdentifier: signingIdentifier
        )
    }
}
