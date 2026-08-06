import AppKit
import Foundation
import NetworkExtension

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var status: AppStatus = .needsInstall
    @Published private(set) var targetIdentity: TargetAppIdentity?
    @Published private(set) var providerDiagnostics: ProviderDiagnostics?
    @Published private(set) var activeFlowCount = 0
    @Published private(set) var lastError: String?

    private let languageSettings: AppLanguageSettings
    private let systemExtensionController = SystemExtensionController()
    private let proxyManagerController = ProxyManagerController()
    private let identityResolver = TargetAppIdentityResolver()
    private let targetApplicationPanelPresenter = TargetApplicationPanelPresenter()
    private lazy var sharedConfiguration = SharedConfiguration()
    private var extensionState: SystemExtensionController.State = .notInstalled
    private var managerState: ProxyManagerController.State = .missing
    private var statusRequestInFlight = false
    private var providerStatusTimer: Timer?

    private static let providerStatusPollInterval: TimeInterval = 1

    init(languageSettings: AppLanguageSettings) {
        self.languageSettings = languageSettings
        systemExtensionController.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleActivationState(state)
            }
        }
        proxyManagerController.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleManagerState(state)
            }
        }
    }

    var canConfigureProxy: Bool {
        guard case .activated = extensionState else {
            return false
        }
        return targetIdentity != nil && status != .starting && status != .disconnecting
    }

    var canDisconnect: Bool {
        activeFlowCount > 0 && managerState == .connected
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
        targetApplicationPanelPresenter.present(
            language: languageSettings.language
        ) { [weak self] url in
            guard let self, let url else {
                return
            }
            self.verifyTargetApplication(at: url)
        }
    }

    private func verifyTargetApplication(at url: URL) {
        do {
            let selectedURL = url.standardizedFileURL.resolvingSymlinksInPath()
            let identity = try identityResolver.resolveApplication(at: selectedURL)
            sharedConfiguration.targetIdentity = identity
            sharedConfiguration.targetApplicationPath = selectedURL.path
            targetIdentity = identity
            lastError = nil
        } catch {
            status = .error
            lastError = AppStrings(languageSettings.language).errorMessage(error)
        }
    }

    func configureAndStartProxy() {
        let strings = AppStrings(languageSettings.language)
        guard targetIdentity != nil else {
            lastError = strings.chooseAndVerifyFirst
            return
        }

        guard let targetApplicationPath = sharedConfiguration.targetApplicationPath else {
            status = .error
            lastError = strings.chooseAgainToReverify
            return
        }

        let targetIdentity: TargetAppIdentity
        do {
            targetIdentity = try identityResolver.resolveApplication(
                at: URL(fileURLWithPath: targetApplicationPath)
            )
            sharedConfiguration.targetIdentity = targetIdentity
            self.targetIdentity = targetIdentity
        } catch {
            status = .error
            lastError = strings.revalidationFailed(strings.errorMessage(error))
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
                    self.lastError = AppStrings(
                        self.languageSettings.language
                    ).errorMessage(error)
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
                    self.activeFlowCount = response.activeFlowCount
                    if response.closedFlowCount == 0 {
                        self.status = .readyNoFlow
                    } else {
                        self.status = .success(response.closedFlowCount)
                    }
                case let .failure(error):
                    self.status = .error
                    self.lastError = AppStrings(
                        self.languageSettings.language
                    ).errorMessage(error)
                }
            }
        }
    }

    func prepareForTermination(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastError = nil
        proxyManagerController.disableIfConfigured { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }
                switch result {
                case .success:
                    self.activeFlowCount = 0
                    self.status = .configurationMissing
                    completion(.success(()))
                case let .failure(error):
                    if let controllerError = error as? ProxyManagerController.ControllerError,
                       case let .activeFlowsPreventDisable(count) = controllerError {
                        self.activeFlowCount = count
                        self.status = count > 0
                            ? .readyWithFlow(count)
                            : .readyNoFlow
                        self.lastError = AppStrings(
                            self.languageSettings.language
                        ).errorMessage(controllerError)
                    } else {
                        self.status = .error
                        self.lastError = AppStrings(
                            self.languageSettings.language
                        ).errorMessage(error)
                    }
                    completion(.failure(error))
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
                    self.lastError = AppStrings(
                        self.languageSettings.language
                    ).errorMessage(error)
                }
            }
        }
    }

    private func requestProviderStatus(reportErrors: Bool = true) {
        guard !statusRequestInFlight else {
            return
        }
        statusRequestInFlight = true
        proxyManagerController.send(ProviderCommand(action: .status)) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.statusRequestInFlight = false
                switch result {
                case let .success(response):
                    self.apply(response)
                case let .failure(error):
                    if reportErrors {
                        self.status = .error
                        self.lastError = AppStrings(
                            self.languageSettings.language
                        ).errorMessage(error)
                    }
                }
            }
        }
    }

    private func startProviderStatusPolling() {
        guard providerStatusTimer == nil else {
            return
        }

        let timer = Timer(
            timeInterval: Self.providerStatusPollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.managerState == .connected else {
                    return
                }
                self.requestProviderStatus(reportErrors: false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        providerStatusTimer = timer
    }

    private func stopProviderStatusPolling() {
        providerStatusTimer?.invalidate()
        providerStatusTimer = nil
    }

    private func apply(_ response: ProviderResponse) {
        activeFlowCount = response.activeFlowCount
        providerDiagnostics = response.diagnostics
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
        extensionState = state
        switch state {
        case .notInstalled, .disabled, .needsApproval, .activated:
            reconcileStatus()
        case .rebootRequired:
            lastError = AppStrings(languageSettings.language).restartRequired
            reconcileStatus()
        case let .failed(error):
            status = .error
            lastError = AppStrings(languageSettings.language).errorMessage(error)
        }
    }

    private func handleManagerLoad(_ result: Result<NETransparentProxyManager?, Error>) {
        switch result {
        case let .success(manager):
            if manager?.connection.status == .connected {
                requestProviderStatus()
            } else {
                reconcileStatus()
            }
        case let .failure(error):
            status = .error
            lastError = AppStrings(languageSettings.language).errorMessage(error)
        }
    }

    private func handleManagerState(_ state: ProxyManagerController.State) {
        let previousState = managerState
        managerState = state
        if state == .connected {
            startProviderStatusPolling()
        } else {
            stopProviderStatusPolling()
            activeFlowCount = 0
        }
        reconcileStatus()
        if state == .connected, previousState != .connected {
            requestProviderStatus()
        }
    }

    private func reconcileStatus() {
        switch extensionState {
        case .notInstalled, .disabled:
            status = .needsInstall
        case .needsApproval, .rebootRequired:
            status = .needsApproval
        case .failed:
            status = .error
        case .activated:
            switch managerState {
            case .missing, .disabled, .disconnected, .invalid:
                status = .configurationMissing
            case .connecting, .reasserting, .disconnecting:
                status = .starting
            case .connected:
                status = activeFlowCount > 0
                    ? .readyWithFlow(activeFlowCount)
                    : .readyNoFlow
            }
        }
    }
}
