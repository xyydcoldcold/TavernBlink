import Foundation
import Network
import NetworkExtension
import OSLog

final class TCPFlowRelay: RelayControlling {
    enum State: Equatable {
        case created
        case connectingUpstream
        case openingClientFlow
        case relaying
        case closing(RelayCloseReason)
        case closed(RelayCloseReason)
    }

    static let maximumChunkSize = 65_536

    let id = UUID()

    var currentState: State {
        queue.sync {
            state
        }
    }

    private let flow: RelayFlowIO
    private let connection: RelayConnectionIO
    private let queue: DispatchQueue
    private let connectionTimeout: TimeInterval
    private var state: State = .created
    private var timeoutWorkItem: DispatchWorkItem?
    private var onClose: ((UUID) -> Void)?
    private var closeCompletions: [() -> Void] = []
    private var clientReadFinished = false
    private var upstreamReadFinished = false
    private var didCloseFlowRead = false
    private var didCloseFlowWrite = false
    private let logger = Logger(
        subsystem: "dev.tavernblink.TavernBlink.ProxyExtension",
        category: "relay"
    )

    convenience init(
        flow: NEAppProxyTCPFlow,
        connectionTimeout: TimeInterval = 30,
        onClose: @escaping (UUID) -> Void
    ) throws {
        let flowIO = try AppProxyTCPFlowIO(flow: flow)
        let parameters = NWParameters.tcp
        flowIO.applyMetadata(to: parameters)
        let connection = NWRelayConnection(
            to: flowIO.remoteEndpoint,
            using: parameters
        )
        self.init(
            flow: flowIO,
            connection: connection,
            connectionTimeout: connectionTimeout,
            onClose: onClose
        )
    }

    init(
        flow: RelayFlowIO,
        connection: RelayConnectionIO,
        connectionTimeout: TimeInterval = 30,
        queue: DispatchQueue? = nil,
        onClose: @escaping (UUID) -> Void
    ) {
        self.flow = flow
        self.connection = connection
        self.connectionTimeout = connectionTimeout
        self.queue = queue ?? DispatchQueue(
            label: "dev.tavernblink.tcp-flow-relay.\(id.uuidString)"
        )
        self.onClose = onClose
    }

    func start() {
        queue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    func close(reason: RelayCloseReason, completion: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self else {
                completion()
                return
            }
            if self.isClosingOrClosed {
                completion()
                return
            }
            self.closeCompletions.append(completion)
            self.finishClose(reason: reason)
        }
    }

    private func startOnQueue() {
        guard state == .created else {
            return
        }

        state = .connectingUpstream
        connection.stateUpdateHandler = { [weak self] state in
            self?.queue.async {
                self?.handleConnectionState(state)
            }
        }
        scheduleConnectionTimeout()
        connection.start(on: queue)
    }

    private func scheduleConnectionTimeout() {
        guard connectionTimeout > 0 else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.state == .connectingUpstream else {
                return
            }
            self.finishClose(
                reason: .upstreamFailed,
                error: RelayRuntimeError.connectionTimedOut
            )
        }
        timeoutWorkItem = workItem
        queue.asyncAfter(deadline: .now() + connectionTimeout, execute: workItem)
    }

    private func handleConnectionState(_ connectionState: RelayConnectionState) {
        switch connectionState {
        case .setup, .preparing, .waiting:
            break
        case .ready:
            guard state == .connectingUpstream else {
                return
            }
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            state = .openingClientFlow
            flow.open { [weak self] error in
                self?.queue.async {
                    self?.handleFlowOpened(error: error)
                }
            }
        case let .failed(error):
            if state == .connectingUpstream || state == .openingClientFlow {
                finishClose(reason: .upstreamFailed, error: error)
            }
        case .cancelled:
            if state == .connectingUpstream || state == .openingClientFlow {
                finishClose(reason: .upstreamFailed)
            }
        }
    }

    private func handleFlowOpened(error: Error?) {
        guard state == .openingClientFlow else {
            return
        }
        if let error {
            finishClose(reason: .clientFailed, error: error)
            return
        }

        state = .relaying
        logger.notice("Relay \(self.id.uuidString, privacy: .public) entered relaying state")
        readFromClient()
        readFromUpstream()
    }

    private func readFromClient() {
        guard state == .relaying, !clientReadFinished else {
            return
        }

        flow.readData { [weak self] data, error in
            self?.queue.async {
                self?.handleClientRead(data: data, error: error)
            }
        }
    }

    private func handleClientRead(data: Data?, error: Error?) {
        guard state == .relaying, !clientReadFinished else {
            return
        }
        if let error {
            finishClose(reason: .clientFailed, error: error)
            return
        }
        guard let data, !data.isEmpty else {
            finishClientRead()
            return
        }

        connection.send(data, isFinal: false) { [weak self] error in
            self?.queue.async {
                guard let self, self.state == .relaying else {
                    return
                }
                if let error {
                    self.finishClose(reason: .upstreamFailed, error: error)
                } else {
                    self.readFromClient()
                }
            }
        }
    }

    private func finishClientRead() {
        guard !clientReadFinished else {
            return
        }
        clientReadFinished = true
        closeFlowReadOnce(error: nil)
        connection.send(nil, isFinal: true) { [weak self] error in
            self?.queue.async {
                guard let self, !self.isClosingOrClosed else {
                    return
                }
                if let error {
                    self.finishClose(reason: .upstreamFailed, error: error)
                } else {
                    self.finishIfBothDirectionsCompleted()
                }
            }
        }
    }

    private func readFromUpstream() {
        guard state == .relaying, !upstreamReadFinished else {
            return
        }

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: Self.maximumChunkSize
        ) { [weak self] data, isComplete, error in
            self?.queue.async {
                self?.handleUpstreamRead(
                    data: data,
                    isComplete: isComplete,
                    error: error
                )
            }
        }
    }

    private func handleUpstreamRead(
        data: Data?,
        isComplete: Bool,
        error: Error?
    ) {
        guard state == .relaying, !upstreamReadFinished else {
            return
        }

        if let data, !data.isEmpty {
            flow.writeData(data) { [weak self] writeError in
                self?.queue.async {
                    guard let self, self.state == .relaying else {
                        return
                    }
                    if let writeError {
                        self.finishClose(reason: .clientFailed, error: writeError)
                    } else if let error {
                        self.finishClose(reason: .upstreamFailed, error: error)
                    } else if isComplete {
                        self.finishUpstreamRead()
                    } else {
                        self.readFromUpstream()
                    }
                }
            }
            return
        }

        if let error {
            finishClose(reason: .upstreamFailed, error: error)
        } else if isComplete {
            finishUpstreamRead()
        } else {
            readFromUpstream()
        }
    }

    private func finishUpstreamRead() {
        guard !upstreamReadFinished else {
            return
        }
        upstreamReadFinished = true
        closeFlowWriteOnce(error: nil)
        finishIfBothDirectionsCompleted()
    }

    private func finishIfBothDirectionsCompleted() {
        if clientReadFinished && upstreamReadFinished {
            finishClose(reason: .completed)
        }
    }

    private var isClosingOrClosed: Bool {
        switch state {
        case .closing, .closed:
            return true
        default:
            return false
        }
    }

    private func finishClose(reason: RelayCloseReason, error: Error? = nil) {
        guard !isClosingOrClosed else {
            return
        }

        state = .closing(reason)
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        connection.stateUpdateHandler = nil

        let flowError = reason == .completed
            ? nil
            : error ?? Self.flowError(for: reason)
        closeFlowReadOnce(error: flowError)
        closeFlowWriteOnce(error: flowError)
        connection.cancel()

        state = .closed(reason)
        if let error {
            logger.error(
                "Relay \(self.id.uuidString, privacy: .public) closed with \(reason.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        } else {
            logger.notice(
                "Relay \(self.id.uuidString, privacy: .public) closed with \(reason.rawValue, privacy: .public)"
            )
        }
        let callback = onClose
        onClose = nil
        callback?(id)

        let completions = closeCompletions
        closeCompletions.removeAll()
        completions.forEach { $0() }
    }

    private func closeFlowReadOnce(error: Error?) {
        guard !didCloseFlowRead else {
            return
        }
        didCloseFlowRead = true
        flow.closeRead(error: error)
    }

    private func closeFlowWriteOnce(error: Error?) {
        guard !didCloseFlowWrite else {
            return
        }
        didCloseFlowWrite = true
        flow.closeWrite(error: error)
    }

    private static func flowError(for reason: RelayCloseReason) -> NSError {
        let code: Int
        switch reason {
        case .userRequested, .providerStopped:
            code = reason == .userRequested
                ? NEAppProxyFlowError.Code.peerReset.rawValue
                : NEAppProxyFlowError.Code.aborted.rawValue
        case .upstreamFailed:
            code = NEAppProxyFlowError.Code.hostUnreachable.rawValue
        case .clientFailed, .completed:
            code = NEAppProxyFlowError.Code.internal.rawValue
        }
        return NSError(
            domain: NEAppProxyErrorDomain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: reason.rawValue]
        )
    }
}

private enum RelayRuntimeError: LocalizedError {
    case connectionTimedOut

    var errorDescription: String? {
        "The upstream TCP connection timed out."
    }
}
