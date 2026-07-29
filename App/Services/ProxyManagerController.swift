import Foundation
import NetworkExtension

final class ProxyManagerController {
    enum ControllerError: LocalizedError {
        case noManager
        case invalidSession
        case startTimedOut

        var errorDescription: String? {
            switch self {
            case .noManager:
                return "The TavernBlink transparent proxy configuration is missing."
            case .invalidSession:
                return "The transparent proxy provider session is unavailable."
            case .startTimedOut:
                return "The transparent proxy did not reach the connected state in time."
            }
        }
    }

    private(set) var manager: NETransparentProxyManager?
    private let messenger = ProviderMessenger()
    private var statusObserver: NSObjectProtocol?
    private var startCompletion: ((Result<Void, Error>) -> Void)?

    func load(completion: @escaping (Result<NETransparentProxyManager?, Error>) -> Void) {
        NETransparentProxyManager.loadAllFromPreferences { [weak self] managers, error in
            if let error {
                completion(.failure(error))
                return
            }

            let manager = managers?.first {
                $0.localizedDescription == AppConstants.managerDescription
            }
            self?.manager = manager
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
                let providerProtocol = NETunnelProviderProtocol()
                providerProtocol.providerBundleIdentifier = AppConstants.proxyExtensionBundleIdentifier
                providerProtocol.providerConfiguration = [
                    "protocolVersion": ProviderCommand.currentProtocolVersion
                ]

                manager.localizedDescription = AppConstants.managerDescription
                manager.protocolConfiguration = providerProtocol
                manager.isEnabled = true
                self.manager = manager

                manager.saveToPreferences { error in
                    if let error {
                        completion(.failure(error))
                        return
                    }
                    manager.loadFromPreferences { error in
                        if let error {
                            completion(.failure(error))
                            return
                        }
                        do {
                            try manager.connection.startVPNTunnel()
                            self.waitForConnection(of: manager, completion: completion)
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    private func waitForConnection(
        of manager: NETransparentProxyManager,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        clearStartObserver()
        startCompletion = completion

        if manager.connection.status == .connected {
            finishStart(.success(()))
            return
        }

        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self, weak manager] _ in
            guard let self, let manager else { return }
            if manager.connection.status == .connected {
                self.finishStart(.success(()))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.startCompletion != nil else { return }
            self.finishStart(.failure(ControllerError.startTimedOut))
        }
    }

    private func finishStart(_ result: Result<Void, Error>) {
        let completion = startCompletion
        startCompletion = nil
        clearStartObserver()
        completion?(result)
    }

    private func clearStartObserver() {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
            self.statusObserver = nil
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

        manager.connection.stopVPNTunnel()
        manager.isEnabled = false
        manager.saveToPreferences { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
