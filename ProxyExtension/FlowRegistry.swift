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
    enum DisconnectRejection: Error, Equatable {
        case noStableGameplayFlow
        case cooldown
    }

    struct DisconnectResult: Equatable {
        let closedCount: Int
        let remotePort: UInt16?
        let rejection: DisconnectRejection?

        init(
            closedCount: Int,
            remotePort: UInt16?,
            rejection: DisconnectRejection? = nil
        ) {
            self.closedCount = closedCount
            self.remotePort = remotePort
            self.rejection = rejection
        }
    }

    private struct Entry {
        let relay: RelayControlling
        let remotePort: UInt16?
        let isHostnameEndpoint: Bool
        let insertionOrder: UInt64
        var isRelaying: Bool
        var relayingSince: TimeInterval?
    }

    private static let legacyGameplayPort: UInt16 = 3724
    private static let currentGameplayPort: UInt16 = 1119

    private let queue = DispatchQueue(label: "dev.tavernblink.flow-registry")
    private let minimumGameplayRelayAge: TimeInterval
    private let disconnectCooldown: TimeInterval
    private let uptime: () -> TimeInterval
    private var relays: [UUID: Entry] = [:]
    private var nextInsertionOrder: UInt64 = 0
    private var isAcceptingNewFlows = true
    private var nextDisconnectAllowedAt: TimeInterval = 0

    init(
        minimumGameplayRelayAge: TimeInterval = 1,
        disconnectCooldown: TimeInterval = 2,
        uptime: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.minimumGameplayRelayAge = minimumGameplayRelayAge
        self.disconnectCooldown = disconnectCooldown
        self.uptime = uptime
    }

    var activeCount: Int {
        queue.sync {
            relays.values.filter(\.isRelaying).count
        }
    }

    var disconnectibleGameplayCount: Int {
        queue.sync {
            let now = uptime()
            return relays.values.filter {
                isStableGameplayFlow($0, now: now)
            }.count
        }
    }

    @discardableResult
    func insertIfAccepting(
        _ relay: RelayControlling,
        remotePort: UInt16? = nil,
        isHostnameEndpoint: Bool = false,
        isRelaying: Bool = true
    ) -> Bool {
        queue.sync {
            guard isAcceptingNewFlows else {
                return false
            }
            insertLocked(
                relay,
                remotePort: remotePort,
                isHostnameEndpoint: isHostnameEndpoint,
                isRelaying: isRelaying
            )
            return true
        }
    }

    func insert(
        _ relay: RelayControlling,
        remotePort: UInt16? = nil,
        isHostnameEndpoint: Bool = false,
        isRelaying: Bool = true
    ) {
        queue.sync {
            insertLocked(
                relay,
                remotePort: remotePort,
                isHostnameEndpoint: isHostnameEndpoint,
                isRelaying: isRelaying
            )
        }
    }

    /// Atomically blocks future admissions only when no relay is registered.
    ///
    /// Returning a nonzero count leaves admission enabled, so a rejected
    /// disable attempt does not change the running game session.
    func prepareForDisable() -> Int {
        queue.sync {
            guard relays.isEmpty else {
                return relays.count
            }
            isAcceptingNewFlows = false
            return 0
        }
    }

    func resumeAcceptingFlows() {
        queue.sync {
            isAcceptingNewFlows = true
        }
    }

    func markRelaying(id: UUID) {
        queue.sync {
            relays[id]?.isRelaying = true
            relays[id]?.relayingSince = uptime()
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
        let selection: Result<Entry, DisconnectRejection> = queue.sync {
            let now = uptime()
            guard now >= nextDisconnectAllowedAt else {
                return .failure(.cooldown)
            }
            guard let candidate = relays.values
                .filter({ isStableGameplayFlow($0, now: now) })
                .min(by: Self.isPreferredBefore)
            else {
                return .failure(.noStableGameplayFlow)
            }
            relays.removeValue(forKey: candidate.relay.id)
            nextDisconnectAllowedAt = now + disconnectCooldown
            return .success(candidate)
        }

        guard case let .success(selected) = selection else {
            let rejection: DisconnectRejection
            switch selection {
            case let .failure(reason):
                rejection = reason
            case .success:
                preconditionFailure("Handled above")
            }
            completion(DisconnectResult(
                closedCount: 0,
                remotePort: nil,
                rejection: rejection
            ))
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
        let lhsPriority = gameplayPriority(lhs)
        let rhsPriority = gameplayPriority(rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return lhs.insertionOrder < rhs.insertionOrder
    }

    private static func gameplayPriority(_ entry: Entry) -> Int {
        switch entry.remotePort {
        case legacyGameplayPort:
            return 0
        case currentGameplayPort where !entry.isHostnameEndpoint:
            return 1
        case currentGameplayPort:
            return 2
        default:
            return Int.max
        }
    }

    private func isStableGameplayFlow(
        _ entry: Entry,
        now: TimeInterval
    ) -> Bool {
        guard entry.isRelaying,
              Self.gameplayPriority(entry) != Int.max,
              let relayingSince = entry.relayingSince
        else {
            return false
        }
        return now - relayingSince >= minimumGameplayRelayAge
    }

    private func insertLocked(
        _ relay: RelayControlling,
        remotePort: UInt16?,
        isHostnameEndpoint: Bool,
        isRelaying: Bool
    ) {
        let now = uptime()
        relays[relay.id] = Entry(
            relay: relay,
            remotePort: remotePort,
            isHostnameEndpoint: isHostnameEndpoint,
            insertionOrder: nextInsertionOrder,
            isRelaying: isRelaying,
            relayingSince: isRelaying ? now : nil
        )
        nextInsertionOrder &+= 1
    }
}
