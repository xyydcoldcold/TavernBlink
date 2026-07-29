import Foundation
import NetworkExtension

final class FlowMatcher {
    private let queue = DispatchQueue(label: "dev.tavernblink.flow-matcher")
    private var targetIdentity: TargetAppIdentity?

    init(targetIdentity: TargetAppIdentity?) {
        self.targetIdentity = targetIdentity
    }

    func updateTargetIdentity(_ identity: TargetAppIdentity?) {
        queue.sync {
            targetIdentity = identity
        }
    }

    func matches(_ metadata: NEFlowMetaData) -> Bool {
        matches(signingIdentifier: metadata.sourceAppSigningIdentifier)
    }

    func matches(signingIdentifier: String?) -> Bool {
        queue.sync {
            Self.matches(
                signingIdentifier: signingIdentifier,
                targetSigningIdentifier: targetIdentity?.signingIdentifier
            )
        }
    }

    static func matches(
        signingIdentifier: String?,
        targetSigningIdentifier: String?
    ) -> Bool {
        guard let signingIdentifier,
              let targetSigningIdentifier,
              !signingIdentifier.isEmpty,
              !targetSigningIdentifier.isEmpty
        else {
            return false
        }
        return signingIdentifier == targetSigningIdentifier
    }
}
