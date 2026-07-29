import AppKit
import Foundation
import NetworkExtension

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var status: AppStatus = .needsInstall
    @Published private(set) var targetIdentity: TargetAppIdentity?
    @Published private(set) var lastError: String?

    private let systemExtensionController = SystemExtensionController()
    private let proxyManagerController = ProxyManagerController()
    private let identityResolver = TargetAppIdentityResolver()
    private lazy var sharedConfiguration = SharedConfiguration()

    init() {
        systemExtensionController.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleActivationState(state)
            }
        }
    }

    var canConfigureProxy: Bool {
        targetIdentity != nil && status != .starting && status != .disconnecting
    }

    var canDisconnect: Bool {
        if case .readyWithFlow = status {
            return true
        }
        return false
    }

    func refresh() {
        lastError = nil
        targetIdentity = sharedConfiguration.targetIdentity

        systemExtensionController.refresh()
        proxyManagerController.load { [weak self] result in
            Task { @MainActor in
                self?.handleManagerLoad(result)
            }
        }
    }

    func installSystemExtension() {
        lastError = nil
        status = .starting
        systemExtensionController.activate()
    }

    func chooseTargetApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose Hearthstone"
        panel.prompt = "Verify App"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let identity = try identityResolver.resolveApplication(at: url)
            sharedConfiguration.targetIdentity = identity
            targetIdentity = identity
            lastError = nil
        } catch {
            status = .error
            lastError = error.localizedDescription
        }
    }

    func configureAndStartProxy() {
        guard let targetIdentity else {
            lastError = "Choose and verify Hearthstone first."
            return
        }

        status = .starting
        lastError = nil
        proxyManagerController.configureAndStart { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.sendIdentity(targetIdentity)
                case let .failure(error):
                    self.status = .error
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func disconnectNow() {
        status = .disconnecting
        lastError = nil
        proxyManagerController.send(ProviderCommand(action: .disconnectNow)) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(response):
                    if response.closedFlowCount == 0 {
                        self.status = .readyNoFlow
                    } else {
                        self.status = .success(response.closedFlowCount)
                    }
                case let .failure(error):
                    self.status = .error
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func disableProxy() {
        proxyManagerController.disable { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.status = .configurationMissing
                case let .failure(error):
                    self.status = .error
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func sendIdentity(_ identity: TargetAppIdentity) {
        let command = ProviderCommand(action: .updateTargetIdentity, targetIdentity: identity)
        proxyManagerController.send(command) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(response):
                    self.apply(response)
                case let .failure(error):
                    self.status = .error
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func requestProviderStatus() {
        proxyManagerController.send(ProviderCommand(action: .status)) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(response):
                    self.apply(response)
                case let .failure(error):
                    self.status = .error
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func apply(_ response: ProviderResponse) {
        guard response.result == .ok else {
            status = .error
            lastError = response.errorSummary ?? response.result.rawValue
            return
        }
        status = response.activeFlowCount > 0
            ? .readyWithFlow(response.activeFlowCount)
            : .readyNoFlow
    }

    private func handleActivationState(_ state: SystemExtensionController.State) {
        switch state {
        case .idle:
            break
        case .needsApproval:
            status = .needsApproval
        case .activated:
            status = .configurationMissing
        case .rebootRequired:
            status = .needsApproval
            lastError = "A restart is required to finish activating the extension."
        case let .failed(error):
            status = .error
            lastError = error.localizedDescription
        }
    }

    private func handleManagerLoad(_ result: Result<NETransparentProxyManager?, Error>) {
        switch result {
        case let .success(manager):
            guard let manager else {
                if status != .needsApproval {
                    status = .configurationMissing
                }
                return
            }
            switch manager.connection.status {
            case .connected:
                requestProviderStatus()
            case .connecting, .reasserting:
                status = .starting
            default:
                status = .configurationMissing
            }
        case let .failure(error):
            status = .error
            lastError = error.localizedDescription
        }
    }
}
