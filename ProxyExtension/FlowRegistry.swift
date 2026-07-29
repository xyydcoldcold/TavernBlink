import Foundation

protocol RelayControlling: AnyObject {
    var id: UUID { get }
    func close(reason: RelayCloseReason)
}

enum RelayCloseReason: String {
    case userRequested
    case providerStopped
    case upstreamFailed
    case clientFailed
    case completed
}

final class FlowRegistry {
    private let queue = DispatchQueue(label: "dev.tavernblink.flow-registry")
    private var relays: [UUID: RelayControlling] = [:]

    var activeCount: Int {
        queue.sync {
            relays.count
        }
    }

    func insert(_ relay: RelayControlling) {
        queue.sync {
            relays[relay.id] = relay
        }
    }

    func remove(id: UUID) {
        _ = queue.sync {
            relays.removeValue(forKey: id)
        }
    }

    @discardableResult
    func disconnectAll(reason: RelayCloseReason) -> Int {
        let snapshot: [RelayControlling] = queue.sync {
            let snapshot = Array(relays.values)
            relays.removeAll()
            return snapshot
        }
        snapshot.forEach { $0.close(reason: reason) }
        return snapshot.count
    }
}
