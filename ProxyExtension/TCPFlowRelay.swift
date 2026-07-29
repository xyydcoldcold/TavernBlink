import Foundation
import Network
import NetworkExtension

/// Boundary for the Phase 3 bounded, bidirectional TCP relay.
///
/// The provider does not instantiate this type yet. Keeping the state model in
/// the skeleton makes ownership and close semantics explicit while avoiding the
/// dangerous behavior of claiming flows with an incomplete implementation.
final class TCPFlowRelay: RelayControlling {
    enum State: Equatable {
        case created
        case connectingUpstream
        case openingClientFlow
        case relaying
        case closing(RelayCloseReason)
        case closed(RelayCloseReason)
    }

    let id = UUID()

    private let flow: NEAppProxyTCPFlow
    private let queue = DispatchQueue(label: "dev.tavernblink.tcp-flow-relay")
    private var state: State = .created
    private var upstreamConnection: NWConnection?
    private var onClose: ((UUID) -> Void)?

    init(flow: NEAppProxyTCPFlow, onClose: @escaping (UUID) -> Void) {
        self.flow = flow
        self.onClose = onClose
    }

    func start() {
        // Phase 3: connect to flow.remoteEndpoint, then open the client flow and
        // begin one-in-flight-block reads in each direction.
        preconditionFailure("TCPFlowRelay.start() is intentionally disabled until the relay harness passes")
    }

    func close(reason: RelayCloseReason) {
        queue.sync {
            guard case .closed = state else {
                state = .closing(reason)
                let error = NSError(
                    domain: "dev.tavernblink.relay",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: reason.rawValue]
                )
                flow.closeReadWithError(error)
                flow.closeWriteWithError(error)
                upstreamConnection?.cancel()
                upstreamConnection = nil
                state = .closed(reason)
                let callback = onClose
                onClose = nil
                callback?(id)
                return
            }
        }
    }
}
