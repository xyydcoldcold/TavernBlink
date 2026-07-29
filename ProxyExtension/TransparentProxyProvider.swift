import Foundation
import NetworkExtension
import OSLog

final class TransparentProxyProvider: NETransparentProxyProvider {
    private let logger = Logger(
        subsystem: "dev.tavernblink.TavernBlink.ProxyExtension",
        category: "provider"
    )
    private let matchingLogger = Logger(
        subsystem: "dev.tavernblink.TavernBlink.ProxyExtension",
        category: "matching"
    )
    private let disconnectLogger = Logger(
        subsystem: "dev.tavernblink.TavernBlink.ProxyExtension",
        category: "disconnect"
    )
    private let messagingLogger = Logger(
        subsystem: "dev.tavernblink.TavernBlink.ProxyExtension",
        category: "messaging"
    )
    private let registry = FlowRegistry()
    private let responseCache = ProviderResponseCache(capacity: 128)
    private let observations = FlowObservationStore(identifierCapacity: 128)
    private let lifecycleQueue = DispatchQueue(label: "dev.tavernblink.provider-lifecycle")
    private lazy var sharedConfiguration = SharedConfiguration()
    private lazy var matcher = FlowMatcher(targetIdentity: sharedConfiguration.targetIdentity)
    private var lifecycleState: ProviderDiagnostics.LifecycleState = .starting

    override func startProxy(
        options: [String: Any]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        setLifecycleState(.starting)
        let targetIdentity = sharedConfiguration.targetIdentity
        matcher.updateTargetIdentity(targetIdentity)
        observations.reset(expectedSigningIdentifier: targetIdentity?.signingIdentifier)

        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.includedNetworkRules = [
            NENetworkRule(
                remoteNetwork: nil,
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .TCP,
                direction: .outbound
            )
        ]

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else {
                completionHandler(ProviderError.deallocated)
                return
            }
            if let error {
                self.logger.error("Failed to apply transparent proxy settings: \(error.localizedDescription, privacy: .public)")
                completionHandler(error)
                return
            }
            self.setLifecycleState(.readyFailOpen)
            self.logger.notice("Transparent proxy started in fail-open scaffold mode")
            completionHandler(nil)
        }
    }

    override func stopProxy(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        setLifecycleState(.stopping)
        let closed = registry.disconnectAll(reason: .providerStopped)
        logger.notice("Transparent proxy stopped; closed \(closed) registered relays")
        setLifecycleState(.stopped)
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard currentLifecycleState == .readyFailOpen,
              let tcpFlow = flow as? NEAppProxyTCPFlow
        else {
            return false
        }

        let signingIdentifier = tcpFlow.metaData.sourceAppSigningIdentifier
        let observation = observations.observe(signingIdentifier: signingIdentifier)
        let endpointKind = tcpFlow.remoteHostname == nil ? "address" : "hostname"

        if observation.shouldLogMissingIdentifier {
            matchingLogger.notice(
                "Observed TCP flow without a source signing identifier; endpoint kind \(endpointKind, privacy: .public)"
            )
        } else if observation.shouldLogIdentifier, let identifier = observation.signingIdentifier {
            matchingLogger.notice(
                "Observed source signing identifier \(identifier, privacy: .public); matched target: \(observation.matchedTarget); endpoint kind: \(endpointKind, privacy: .public)"
            )
        }

        guard matcher.matches(signingIdentifier: signingIdentifier) else {
            return false
        }

        // Phase 0 safety boundary: an incomplete relay must never claim a flow.
        // Enable this path only after TCPFlowRelay passes the bounded-buffer echo
        // harness and its close paths are integrated with FlowRegistry.
        matchingLogger.debug("Observed target TCP flow; leaving it to the system")
        return false
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        let response = makeResponse(for: messageData)
        completionHandler?(try? JSONEncoder().encode(response))
    }

    private func makeResponse(for data: Data) -> ProviderResponse {
        let command: ProviderCommand
        do {
            command = try JSONDecoder().decode(ProviderCommand.self, from: data)
        } catch {
            messagingLogger.error(
                "Rejected invalid provider message: \(error.localizedDescription, privacy: .public)"
            )
            let fallback = ProviderCommand(action: .status)
            return providerResponse(
                for: fallback,
                result: .invalidCommand,
                errorCode: "invalidCommand",
                errorSummary: error.localizedDescription
            )
        }

        if let cached = responseCache.response(for: command.requestID) {
            messagingLogger.info(
                "Returning cached response for request \(command.requestID.uuidString, privacy: .public)"
            )
            return cached
        }

        messagingLogger.info(
            "Received provider action \(command.action.rawValue, privacy: .public), request \(command.requestID.uuidString, privacy: .public)"
        )

        let response: ProviderResponse
        guard command.protocolVersion == ProviderCommand.currentProtocolVersion else {
            response = providerResponse(
                for: command,
                result: .unsupportedProtocol,
                errorCode: "unsupportedProtocol",
                errorSummary: "Unsupported provider protocol version \(command.protocolVersion)"
            )
            responseCache.insert(response)
            return response
        }

        switch command.action {
        case .status, .exportDiagnostics:
            response = providerResponse(for: command)

        case .updateTargetIdentity:
            guard let identity = command.targetIdentity else {
                response = providerResponse(
                    for: command,
                    result: .invalidCommand,
                    errorCode: "missingIdentity",
                    errorSummary: "updateTargetIdentity requires a verified identity"
                )
                break
            }
            sharedConfiguration.targetIdentity = identity
            matcher.updateTargetIdentity(identity)
            observations.reset(expectedSigningIdentifier: identity.signingIdentifier)
            matchingLogger.notice(
                "Updated expected signing identifier to \(identity.signingIdentifier, privacy: .public) and reset flow observations"
            )
            response = providerResponse(for: command)

        case .disconnectNow:
            let start = ContinuousClock.now
            let closedCount = registry.disconnectAll(reason: .userRequested)
            let duration = start.duration(to: .now)
            let milliseconds = Int(duration.components.seconds * 1_000)
                + Int(duration.components.attoseconds / 1_000_000_000_000_000)
            disconnectLogger.notice(
                "Disconnect request closed \(closedCount) flow(s) in \(milliseconds) ms"
            )
            response = providerResponse(
                for: command,
                closedFlowCount: closedCount,
                durationMilliseconds: milliseconds
            )
        }

        responseCache.insert(response)
        return response
    }

    private var currentLifecycleState: ProviderDiagnostics.LifecycleState {
        lifecycleQueue.sync {
            lifecycleState
        }
    }

    private func setLifecycleState(_ state: ProviderDiagnostics.LifecycleState) {
        lifecycleQueue.sync {
            lifecycleState = state
        }
    }

    private func providerResponse(
        for command: ProviderCommand,
        result: ProviderResponse.Result = .ok,
        closedFlowCount: Int = 0,
        durationMilliseconds: Int = 0,
        errorCode: String? = nil,
        errorSummary: String? = nil
    ) -> ProviderResponse {
        .status(
            for: command,
            result: result,
            activeFlowCount: registry.activeCount,
            closedFlowCount: closedFlowCount,
            durationMilliseconds: durationMilliseconds,
            errorCode: errorCode,
            errorSummary: errorSummary,
            diagnostics: observations.snapshot(lifecycleState: currentLifecycleState)
        )
    }
}

private enum ProviderError: LocalizedError {
    case deallocated

    var errorDescription: String? {
        "The transparent proxy provider was released while starting."
    }
}

private final class ProviderResponseCache {
    private let queue = DispatchQueue(label: "dev.tavernblink.provider-response-cache")
    private let capacity: Int
    private var order: [UUID] = []
    private var responses: [UUID: ProviderResponse] = [:]

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func response(for requestID: UUID) -> ProviderResponse? {
        queue.sync {
            responses[requestID]
        }
    }

    func insert(_ response: ProviderResponse) {
        queue.sync {
            let requestID = response.requestID
            if responses[requestID] == nil {
                order.append(requestID)
            }
            responses[requestID] = response

            while order.count > capacity {
                responses.removeValue(forKey: order.removeFirst())
            }
        }
    }
}
