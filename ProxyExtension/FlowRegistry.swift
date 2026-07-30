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
    struct DisconnectResult: Equatable {
        let closedCount: Int
        let remotePort: UInt16?
    }

    private struct Entry {
        let relay: RelayControlling
        let remotePort: UInt16?
        let insertionOrder: UInt64
        var isRelaying: Bool
    }

    private static let preferredGameplayPort: UInt16 = 3724

    private let queue = DispatchQueue(label: "dev.tavernblink.flow-registry")
    private var relays: [UUID: Entry] = [:]
    private var nextInsertionOrder: UInt64 = 0

    var activeCount: Int {
        queue.sync {
            relays.values.filter(\.isRelaying).count
        }
    }

    func insert(
        _ relay: RelayControlling,
        remotePort: UInt16? = nil,
        isRelaying: Bool = true
    ) {
        queue.sync {
            relays[relay.id] = Entry(
                relay: relay,
                remotePort: remotePort,
                insertionOrder: nextInsertionOrder,
                isRelaying: isRelaying
            )
            nextInsertionOrder &+= 1
        }
    }

    func markRelaying(id: UUID) {
        queue.sync {
            relays[id]?.isRelaying = true
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
            let snapshot = relays.values.map(\.relay)
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

    func disconnectPreferred(
        reason: RelayCloseReason,
        completion: @escaping (DisconnectResult) -> Void
    ) {
        let selected: Entry? = queue.sync {
            guard let candidate = relays.values
                .filter(\.isRelaying)
                .min(by: Self.isPreferredBefore)
            else {
                return nil
            }
            relays.removeValue(forKey: candidate.relay.id)
            return candidate
        }

        guard let selected else {
            completion(DisconnectResult(closedCount: 0, remotePort: nil))
            return
        }

        selected.relay.close(reason: reason) {
            completion(
                DisconnectResult(
                    closedCount: 1,
                    remotePort: selected.remotePort
                )
            )
        }
    }

    private static func isPreferredBefore(_ lhs: Entry, _ rhs: Entry) -> Bool {
        let lhsIsPreferred = lhs.remotePort == preferredGameplayPort
        let rhsIsPreferred = rhs.remotePort == preferredGameplayPort
        if lhsIsPreferred != rhsIsPreferred {
            return lhsIsPreferred
        }
        return lhs.insertionOrder < rhs.insertionOrder
    }
}
