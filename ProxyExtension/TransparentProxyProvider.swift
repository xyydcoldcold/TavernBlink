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
        registry.resumeAcceptingFlows()
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
            self.setLifecycleState(.readyRelaying)
            self.logger.notice("Transparent proxy started with bounded TCP relay enabled")
            completionHandler(nil)
        }
    }

    override func stopProxy(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        setLifecycleState(.stopping)
        registry.disconnectAll(reason: .providerStopped) { [self] closed in
            self.logger.notice("Transparent proxy stopped; closed \(closed) registered relays")
            self.setLifecycleState(.stopped)
            completionHandler()
        }
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard currentLifecycleState == .readyRelaying,
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

        do {
            let relay = try TCPFlowRelay(
                flow: tcpFlow,
                onRelaying: { [weak self] relayID in
                    self?.registry.markRelaying(id: relayID)
                },
                onClose: { [weak self] relayID in
                    self?.registry.remove(id: relayID)
                }
            )
            guard registry.insertIfAccepting(
                relay,
                remotePort: relay.remotePort,
                isRelaying: false
            ) else {
                matchingLogger.info(
                    "Left target TCP flow to the system while disable preparation was in progress"
                )
                return false
            }
            relay.start()
            if let remotePort = relay.remotePort {
                matchingLogger.notice(
                    "Claimed target TCP flow \(relay.id.uuidString, privacy: .public), remote port \(remotePort)"
                )
            } else {
                matchingLogger.notice(
                    "Claimed target TCP flow \(relay.id.uuidString, privacy: .public), remote port unavailable"
                )
            }
            return true
        } catch {
            matchingLogger.error(
                "Unable to create target TCP relay; leaving flow to the system: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        makeResponse(for: messageData) { response in
            completionHandler?(try? JSONEncoder().encode(response))
        }
    }

    private func makeResponse(
        for data: Data,
        completion: @escaping (ProviderResponse) -> Void
    ) {
        let command: ProviderCommand
        do {
            command = try JSONDecoder().decode(ProviderCommand.self, from: data)
        } catch {
            messagingLogger.error(
                "Rejected invalid provider message: \(error.localizedDescription, privacy: .public)"
            )
            let fallback = ProviderCommand(action: .status)
            completion(providerResponse(
                for: fallback,
                result: .invalidCommand,
                errorCode: "invalidCommand",
                errorSummary: error.localizedDescription
            ))
            return
        }

        switch responseCache.register(
            requestID: command.requestID,
            completion: completion
        ) {
        case let .cached(cached):
            messagingLogger.info(
                "Returning cached response for request \(command.requestID.uuidString, privacy: .public)"
            )
            completion(cached)
            return
        case .waiting:
            messagingLogger.info(
                "Waiting for in-flight response for request \(command.requestID.uuidString, privacy: .public)"
            )
            return
        case .new:
            break
        }

        messagingLogger.info(
            "Received provider action \(command.action.rawValue, privacy: .public), request \(command.requestID.uuidString, privacy: .public)"
        )

        guard command.protocolVersion == ProviderCommand.currentProtocolVersion else {
            let response = providerResponse(
                for: command,
                result: .unsupportedProtocol,
                errorCode: "unsupportedProtocol",
                errorSummary: "Unsupported provider protocol version \(command.protocolVersion)"
            )
            finishResponse(response)
            return
        }

        switch command.action {
        case .status, .exportDiagnostics:
            finishResponse(providerResponse(for: command))

        case .prepareToDisable:
            let registeredFlowCount = registry.prepareForDisable()
            guard registeredFlowCount == 0 else {
                messagingLogger.notice(
                    "Rejected disable preparation while \(registeredFlowCount) target relay(s) remain registered"
                )
                finishResponse(providerResponse(
                    for: command,
                    result: .notReady,
                    activeFlowCount: registeredFlowCount,
                    errorCode: "activeFlowsPreventDisable",
                    errorSummary: "Target flows are still active; the proxy was left running."
                ))
                return
            }
            messagingLogger.notice(
                "Disable preparation succeeded; new target flow admission is paused"
            )
            finishResponse(providerResponse(for: command))

        case .updateTargetIdentity:
            guard let identity = command.targetIdentity else {
                finishResponse(providerResponse(
                    for: command,
                    result: .invalidCommand,
                    errorCode: "missingIdentity",
                    errorSummary: "updateTargetIdentity requires a verified identity"
                ))
                return
            }
            sharedConfiguration.targetIdentity = identity
            matcher.updateTargetIdentity(identity)
            registry.resumeAcceptingFlows()
            observations.reset(expectedSigningIdentifier: identity.signingIdentifier)
            matchingLogger.notice(
                "Updated expected signing identifier to \(identity.signingIdentifier, privacy: .public) and reset flow observations"
            )
            finishResponse(providerResponse(for: command))

        case .disconnectNow:
            let start = ContinuousClock.now
            registry.disconnectPreferred(reason: .userRequested) { [self] result in
                let duration = start.duration(to: .now)
                let milliseconds = Int(duration.components.seconds * 1_000)
                    + Int(duration.components.attoseconds / 1_000_000_000_000_000)
                if let remotePort = result.remotePort {
                    self.disconnectLogger.notice(
                        "Disconnect request completed \(result.closedCount) flow close(s) in \(milliseconds) ms; selected remote port \(remotePort)"
                    )
                } else {
                    self.disconnectLogger.notice(
                        "Disconnect request completed \(result.closedCount) flow close(s) in \(milliseconds) ms; selected remote port unavailable"
                    )
                }
                self.finishResponse(
                    self.providerResponse(
                        for: command,
                        closedFlowCount: result.closedCount,
                        durationMilliseconds: milliseconds
                    )
                )
            }
        }
    }

    private func finishResponse(_ response: ProviderResponse) {
        responseCache.resolve(response)
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
        activeFlowCount: Int? = nil,
        closedFlowCount: Int = 0,
        durationMilliseconds: Int = 0,
        errorCode: String? = nil,
        errorSummary: String? = nil
    ) -> ProviderResponse {
        .status(
            for: command,
            result: result,
            activeFlowCount: activeFlowCount ?? registry.activeCount,
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
    enum Registration {
        case cached(ProviderResponse)
        case waiting
        case new
    }

    typealias Completion = (ProviderResponse) -> Void

    private let queue = DispatchQueue(label: "dev.tavernblink.provider-response-cache")
    private let capacity: Int
    private var order: [UUID] = []
    private var responses: [UUID: ProviderResponse] = [:]
    private var waiters: [UUID: [Completion]] = [:]

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func register(
        requestID: UUID,
        completion: @escaping Completion
    ) -> Registration {
        queue.sync {
            if let response = responses[requestID] {
                return .cached(response)
            }
            if waiters[requestID] != nil {
                waiters[requestID, default: []].append(completion)
                return .waiting
            }
            waiters[requestID] = [completion]
            return .new
        }
    }

    func resolve(_ response: ProviderResponse) {
        let completions: [Completion] = queue.sync {
            let requestID = response.requestID
            if responses[requestID] == nil {
                order.append(requestID)
            }
            responses[requestID] = response

            while order.count > capacity {
                responses.removeValue(forKey: order.removeFirst())
            }
            return waiters.removeValue(forKey: requestID) ?? []
        }
        completions.forEach { $0(response) }
    }
}
