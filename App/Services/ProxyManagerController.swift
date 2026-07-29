import Foundation
import NetworkExtension
import OSLog

final class ProxyManagerController {
    static let providerServerAddress = "127.0.0.1"

    enum State: Equatable {
        case missing
        case disabled
        case disconnected
        case connecting
        case connected
        case reasserting
        case disconnecting
        case invalid
    }

    enum ControllerError: LocalizedError {
        case noManager
        case invalidSession
        case startTimedOut
        case duplicateConfigurations(Int)

        var errorDescription: String? {
            switch self {
            case .noManager:
                return "The TavernBlink transparent proxy configuration is missing."
            case .invalidSession:
                return "The transparent proxy provider session is unavailable."
            case .startTimedOut:
                return "The transparent proxy did not reach the connected state in time."
            case let .duplicateConfigurations(count):
                return "Found \(count) TavernBlink proxy configurations. Remove duplicates before continuing."
            }
        }
    }

    var onStateChange: ((State) -> Void)?

    private let logger = Logger(
        subsystem: "dev.tavernblink.TavernBlink",
        category: "manager"
    )
    private(set) var manager: NETransparentProxyManager?
    private let messenger = ProviderMessenger()
    private var statusObserver: NSObjectProtocol?
    private var startCompletion: ((Result<Void, Error>) -> Void)?
    private var startAttemptID: UUID?

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    func load(completion: @escaping (Result<NETransparentProxyManager?, Error>) -> Void) {
        NETransparentProxyManager.loadAllFromPreferences { [weak self] managers, error in
            if let error {
                completion(.failure(error))
                return
            }

            let matchingManagers = managers?.filter {
                $0.localizedDescription == AppConstants.managerDescription
            } ?? []

            guard matchingManagers.count <= 1 else {
                let error = ControllerError.duplicateConfigurations(matchingManagers.count)
                self?.logger.error("\(error.localizedDescription, privacy: .public)")
                completion(.failure(error))
                return
            }

            let manager = matchingManagers.first
            self?.manager = manager
            if let manager {
                self?.observe(manager)
            } else {
                self?.stopObservingStatus()
                self?.onStateChange?(.missing)
            }
            completion(.success(manager))
        }
    }

    func configureAndStart(completion: @escaping (Result<Void, Error>) -> Void) {
        load { [weak self] result in
            guard let self else { return }
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(existing):
                let manager = existing ?? NETransparentProxyManager()
                let providerProtocol = Self.makeProviderProtocol(
                    providerBundleIdentifier: AppConstants.proxyExtensionBundleIdentifier
                )

                manager.localizedDescription = AppConstants.managerDescription
                manager.protocolConfiguration = providerProtocol
                manager.isEnabled = true
                self.manager = manager
                self.logger.info("Saving transparent proxy configuration")

                manager.saveToPreferences { error in
                    if let error {
                        self.logger.error("Saving proxy configuration failed: \(error.localizedDescription, privacy: .public)")
                        completion(.failure(error))
                        return
                    }
                    manager.loadFromPreferences { error in
                        if let error {
                            self.logger.error("Reloading proxy configuration failed: \(error.localizedDescription, privacy: .public)")
                            completion(.failure(error))
                            return
                        }
                        self.observe(manager)
                        do {
                            try manager.connection.startVPNTunnel()
                            self.logger.notice("Requested transparent proxy start")
                            self.waitForConnection(of: manager, completion: completion)
                        } catch {
                            self.logger.error("Starting transparent proxy failed: \(error.localizedDescription, privacy: .public)")
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    static func makeProviderProtocol(
        providerBundleIdentifier: String
    ) -> NETunnelProviderProtocol {
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = providerBundleIdentifier
        // NetworkExtension requires this field even though a transparent proxy
        // does not connect to a traditional VPN server.
        providerProtocol.serverAddress = providerServerAddress
        providerProtocol.providerConfiguration = [
            "protocolVersion": ProviderCommand.currentProtocolVersion
        ]
        return providerProtocol
    }

    private func waitForConnection(
        of manager: NETransparentProxyManager,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if startCompletion != nil {
            finishStart(.failure(ControllerError.startTimedOut))
        }
        startCompletion = completion
        let attemptID = UUID()
        startAttemptID = attemptID

        if manager.connection.status == .connected {
            finishStart(.success(()))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self,
                  self.startCompletion != nil,
                  self.startAttemptID == attemptID
            else {
                return
            }
            self.logger.error("Transparent proxy start timed out")
            self.finishStart(.failure(ControllerError.startTimedOut))
        }
    }

    private func finishStart(_ result: Result<Void, Error>) {
        let completion = startCompletion
        startCompletion = nil
        startAttemptID = nil
        completion?(result)
    }

    private func observe(_ manager: NETransparentProxyManager) {
        stopObservingStatus()
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self, weak manager] _ in
            guard let self, let manager else { return }
            self.publishStatus(of: manager)
        }
        publishStatus(of: manager)
    }

    private func stopObservingStatus() {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
            self.statusObserver = nil
        }
    }

    private func publishStatus(of manager: NETransparentProxyManager) {
        let state: State
        if !manager.isEnabled {
            state = .disabled
        } else {
            switch manager.connection.status {
            case .invalid:
                state = .invalid
            case .disconnected:
                state = .disconnected
            case .connecting:
                state = .connecting
            case .connected:
                state = .connected
            case .reasserting:
                state = .reasserting
            case .disconnecting:
                state = .disconnecting
            @unknown default:
                state = .invalid
            }
        }

        logger.info("Transparent proxy state changed to \(String(describing: state), privacy: .public)")
        onStateChange?(state)
        if state == .connected, startCompletion != nil {
            finishStart(.success(()))
        }
    }

    func send(
        _ command: ProviderCommand,
        completion: @escaping (Result<ProviderResponse, Error>) -> Void
    ) {
        guard let session = manager?.connection as? NETunnelProviderSession else {
            completion(.failure(ControllerError.invalidSession))
            return
        }
        messenger.send(command, through: session, completion: completion)
    }

    func disable(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let manager else {
            completion(.failure(ControllerError.noManager))
            return
        }

        if startCompletion != nil {
            finishStart(.failure(ControllerError.noManager))
        }
        manager.connection.stopVPNTunnel()
        manager.isEnabled = false
        manager.saveToPreferences { error in
            if let error {
                self.logger.error("Disabling transparent proxy failed: \(error.localizedDescription, privacy: .public)")
                completion(.failure(error))
            } else {
                self.logger.notice("Transparent proxy configuration disabled")
                self.publishStatus(of: manager)
                completion(.success(()))
            }
        }
    }
}
