import Foundation

struct FlowObservationResult {
    let signingIdentifier: String?
    let matchedTarget: Bool
    let shouldLogIdentifier: Bool
    let shouldLogMissingIdentifier: Bool
}

final class FlowObservationStore {
    private let queue = DispatchQueue(label: "dev.tavernblink.flow-observations")
    private let identifierCapacity: Int
    private var expectedSigningIdentifier: String?
    private var lastObservedSigningIdentifier: String?
    private var observedTCPFlowCount = 0
    private var matchedTCPFlowCount = 0
    private var missingSigningIdentifierCount = 0
    private var seenSigningIdentifiers: Set<String> = []
    private var identifierLogCapacityReached = false

    init(identifierCapacity: Int) {
        self.identifierCapacity = max(1, identifierCapacity)
    }

    func reset(expectedSigningIdentifier: String?) {
        queue.sync {
            self.expectedSigningIdentifier = normalized(expectedSigningIdentifier)
            lastObservedSigningIdentifier = nil
            observedTCPFlowCount = 0
            matchedTCPFlowCount = 0
            missingSigningIdentifierCount = 0
            seenSigningIdentifiers.removeAll(keepingCapacity: true)
            identifierLogCapacityReached = false
        }
    }

    func observe(signingIdentifier: String?) -> FlowObservationResult {
        queue.sync {
            observedTCPFlowCount += 1
            let signingIdentifier = normalized(signingIdentifier)

            guard let signingIdentifier else {
                missingSigningIdentifierCount += 1
                return FlowObservationResult(
                    signingIdentifier: nil,
                    matchedTarget: false,
                    shouldLogIdentifier: false,
                    shouldLogMissingIdentifier: missingSigningIdentifierCount == 1
                )
            }

            lastObservedSigningIdentifier = signingIdentifier
            let matchedTarget = signingIdentifier == expectedSigningIdentifier
            if matchedTarget {
                matchedTCPFlowCount += 1
            }

            let shouldLogIdentifier: Bool
            if seenSigningIdentifiers.contains(signingIdentifier) {
                shouldLogIdentifier = false
            } else if seenSigningIdentifiers.count < identifierCapacity {
                seenSigningIdentifiers.insert(signingIdentifier)
                shouldLogIdentifier = true
            } else {
                identifierLogCapacityReached = true
                shouldLogIdentifier = false
            }

            return FlowObservationResult(
                signingIdentifier: signingIdentifier,
                matchedTarget: matchedTarget,
                shouldLogIdentifier: shouldLogIdentifier,
                shouldLogMissingIdentifier: false
            )
        }
    }

    func snapshot(
        lifecycleState: ProviderDiagnostics.LifecycleState
    ) -> ProviderDiagnostics {
        queue.sync {
            ProviderDiagnostics(
                lifecycleState: lifecycleState,
                expectedSigningIdentifier: expectedSigningIdentifier,
                lastObservedSigningIdentifier: lastObservedSigningIdentifier,
                observedTCPFlowCount: observedTCPFlowCount,
                matchedTCPFlowCount: matchedTCPFlowCount,
                missingSigningIdentifierCount: missingSigningIdentifierCount,
                identifierLogCapacityReached: identifierLogCapacityReached
            )
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
