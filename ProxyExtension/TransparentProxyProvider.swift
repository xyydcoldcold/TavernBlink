import Foundation
import NetworkExtension
import OSLog

final class TransparentProxyProvider: NETransparentProxyProvider {
    private let logger = Logger(
        subsystem: "dev.tavernblink.TavernBlink.ProxyExtension",
        category: "provider"
    )
    private let registry = FlowRegistry()
    private let responseCache = ProviderResponseCache(capacity: 128)
    private lazy var sharedConfiguration = SharedConfiguration()
    private lazy var matcher = FlowMatcher(targetIdentity: sharedConfiguration.targetIdentity)
    private var isReady = false

    override func startProxy(
        options: [String: Any]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
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
            self.isReady = true
            self.logger.notice("Transparent proxy started in fail-open scaffold mode")
            completionHandler(nil)
        }
    }

    override func stopProxy(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        isReady = false
        let closed = registry.disconnectAll(reason: .providerStopped)
        logger.notice("Transparent proxy stopped; closed \(closed) registered relays")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard isReady, flow is NEAppProxyTCPFlow else {
            return false
        }

        guard matcher.matches(flow.metaData) else {
            return false
        }

        // Phase 0 safety boundary: an incomplete relay must never claim a flow.
        // Enable this path only after TCPFlowRelay passes the bounded-buffer echo
        // harness and its close paths are integrated with FlowRegistry.
        logger.debug("Observed target signing identifier; leaving flow to the system")
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
            let fallback = ProviderCommand(action: .status)
            return .status(
                for: fallback,
                result: .invalidCommand,
                activeFlowCount: registry.activeCount,
                errorCode: "invalidCommand",
                errorSummary: error.localizedDescription
            )
        }

        if let cached = responseCache.response(for: command.requestID) {
            return cached
        }

        let response: ProviderResponse
        guard command.protocolVersion == ProviderCommand.currentProtocolVersion else {
            response = .status(
                for: command,
                result: .unsupportedProtocol,
                activeFlowCount: registry.activeCount,
                errorCode: "unsupportedProtocol",
                errorSummary: "Unsupported provider protocol version \(command.protocolVersion)"
            )
            responseCache.insert(response)
            return response
        }

        switch command.action {
        case .status, .exportDiagnostics:
            response = .status(for: command, activeFlowCount: registry.activeCount)

        case .updateTargetIdentity:
            guard let identity = command.targetIdentity else {
                response = .status(
                    for: command,
                    result: .invalidCommand,
                    activeFlowCount: registry.activeCount,
                    errorCode: "missingIdentity",
                    errorSummary: "updateTargetIdentity requires a verified identity"
                )
                break
            }
            sharedConfiguration.targetIdentity = identity
            matcher.updateTargetIdentity(identity)
            response = .status(for: command, activeFlowCount: registry.activeCount)

        case .disconnectNow:
            let start = ContinuousClock.now
            let closedCount = registry.disconnectAll(reason: .userRequested)
            let duration = start.duration(to: .now)
            let milliseconds = Int(duration.components.seconds * 1_000)
                + Int(duration.components.attoseconds / 1_000_000_000_000_000)
            response = .status(
                for: command,
                activeFlowCount: registry.activeCount,
                closedFlowCount: closedCount,
                durationMilliseconds: milliseconds
            )
        }

        responseCache.insert(response)
        return response
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
