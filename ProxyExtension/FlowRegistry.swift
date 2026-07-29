import Foundation

protocol RelayControlling: AnyObject {
    var id: UUID { get }
    func close(reason: RelayCloseReason, completion: @escaping () -> Void)
}

extension RelayControlling {
    func close(reason: RelayCloseReason) {
        close(reason: reason, completion: {})
    }
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

    func disconnectAll(
        reason: RelayCloseReason,
        completion: @escaping (Int) -> Void
    ) {
        let snapshot: [RelayControlling] = queue.sync {
            let snapshot = Array(relays.values)
            relays.removeAll()
            return snapshot
        }

        guard !snapshot.isEmpty else {
            completion(0)
            return
        }

        let group = DispatchGroup()
        snapshot.forEach { relay in
            group.enter()
            relay.close(reason: reason) {
                group.leave()
            }
        }
        group.notify(queue: .global(qos: .userInitiated)) {
            completion(snapshot.count)
        }
    }
}
