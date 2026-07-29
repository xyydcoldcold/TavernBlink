import Foundation
import Network
import NetworkExtension

protocol RelayFlowIO: AnyObject {
    func open(completion: @escaping (Error?) -> Void)
    func readData(completion: @escaping (Data?, Error?) -> Void)
    func writeData(_ data: Data, completion: @escaping (Error?) -> Void)
    func closeRead(error: Error?)
    func closeWrite(error: Error?)
}

enum RelayConnectionState {
    case setup
    case waiting(Error)
    case preparing
    case ready
    case failed(Error)
    case cancelled
}

protocol RelayConnectionIO: AnyObject {
    var stateUpdateHandler: ((RelayConnectionState) -> Void)? { get set }

    func start(on queue: DispatchQueue)
    func send(_ data: Data?, isFinal: Bool, completion: @escaping (Error?) -> Void)
    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (Data?, Bool, Error?) -> Void
    )
    func cancel()
}

enum RelayAdapterError: LocalizedError {
    case unsupportedRemoteEndpoint

    var errorDescription: String? {
        switch self {
        case .unsupportedRemoteEndpoint:
            return "The target TCP flow has an unsupported remote endpoint."
        }
    }
}

final class AppProxyTCPFlowIO: RelayFlowIO {
    let remoteEndpoint: Network.NWEndpoint

    private let flow: NEAppProxyTCPFlow

    init(flow: NEAppProxyTCPFlow) throws {
        self.flow = flow

        if #available(macOS 15.0, *) {
            remoteEndpoint = flow.remoteFlowEndpoint
        } else {
            guard let hostEndpoint = flow.remoteEndpoint as? NWHostEndpoint,
                  let port = Network.NWEndpoint.Port(hostEndpoint.port)
            else {
                throw RelayAdapterError.unsupportedRemoteEndpoint
            }
            remoteEndpoint = .hostPort(
                host: .init(hostEndpoint.hostname),
                port: port
            )
        }
    }

    func applyMetadata(to parameters: NWParameters) {
        if #available(macOS 15.0, *) {
            flow.setMetadata(on: parameters)
        }
    }

    func open(completion: @escaping (Error?) -> Void) {
        if #available(macOS 15.0, *) {
            flow.open(withLocalFlowEndpoint: nil, completionHandler: completion)
        } else {
            flow.open(withLocalEndpoint: nil, completionHandler: completion)
        }
    }

    func readData(completion: @escaping (Data?, Error?) -> Void) {
        flow.readData(completionHandler: completion)
    }

    func writeData(_ data: Data, completion: @escaping (Error?) -> Void) {
        flow.write(data, withCompletionHandler: completion)
    }

    func closeRead(error: Error?) {
        flow.closeReadWithError(error as NSError?)
    }

    func closeWrite(error: Error?) {
        flow.closeWriteWithError(error as NSError?)
    }
}

final class NWRelayConnection: RelayConnectionIO {
    var stateUpdateHandler: ((RelayConnectionState) -> Void)?

    private let connection: NWConnection

    init(to endpoint: Network.NWEndpoint, using parameters: NWParameters) {
        connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            self?.publish(state)
        }
    }

    func start(on queue: DispatchQueue) {
        connection.start(queue: queue)
    }

    func send(_ data: Data?, isFinal: Bool, completion: @escaping (Error?) -> Void) {
        connection.send(
            content: data,
            contentContext: isFinal ? .finalMessage : .defaultMessage,
            isComplete: true,
            completion: .contentProcessed(completion)
        )
    }

    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (Data?, Bool, Error?) -> Void
    ) {
        connection.receive(
            minimumIncompleteLength: minimumIncompleteLength,
            maximumLength: maximumLength
        ) { data, _, isComplete, error in
            completion(data, isComplete, error)
        }
    }

    func cancel() {
        connection.cancel()
    }

    private func publish(_ state: NWConnection.State) {
        let relayState: RelayConnectionState
        switch state {
        case .setup:
            relayState = .setup
        case let .waiting(error):
            relayState = .waiting(error)
        case .preparing:
            relayState = .preparing
        case .ready:
            relayState = .ready
        case let .failed(error):
            relayState = .failed(error)
        case .cancelled:
            relayState = .cancelled
        @unknown default:
            relayState = .failed(RelayAdapterError.unsupportedRemoteEndpoint)
        }
        stateUpdateHandler?(relayState)
    }
}
