import Foundation
import Network

/// Starting point for the local-only relay harness.
///
/// This file is intentionally not part of a production target. Phase 3 should
/// wrap it in an XCTest or a dedicated development-only executable.
final class EchoServer {
    private let queue = DispatchQueue(label: "dev.tavernblink.echo-server")
    private var listener: NWListener?

    func start() throws -> NWEndpoint.Port {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.echo(connection)
        }
        listener.start(queue: queue)

        guard let port = listener.port else {
            throw HarnessError.portUnavailable
        }
        return port
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func echo(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard case .ready = state, let connection else { return }
            self?.receive(on: connection)
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            if let data, !data.isEmpty {
                connection.send(content: data, completion: .contentProcessed { sendError in
                    if sendError == nil, !isComplete {
                        self.receive(on: connection)
                    } else {
                        connection.cancel()
                    }
                })
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection)
            }
        }
    }
}

private enum HarnessError: Error {
    case portUnavailable
}
