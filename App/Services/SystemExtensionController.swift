import Foundation
import OSLog
import SystemExtensions

final class SystemExtensionController: NSObject, OSSystemExtensionRequestDelegate {
    enum State {
        case notInstalled
        case disabled
        case needsApproval
        case activated
        case rebootRequired
        case failed(Error)
    }

    var onStateChange: ((State) -> Void)?

    private enum RequestKind {
        case activation
        case deactivation
        case properties
    }

    private let logger = Logger(
        subsystem: "dev.tavernblink.TavernBlink",
        category: "activation"
    )
    private let queue = DispatchQueue(label: "dev.tavernblink.system-extension")
    private var requests: [
        ObjectIdentifier: (request: OSSystemExtensionRequest, kind: RequestKind)
    ] = [:]

    func activate() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: AppConstants.proxyExtensionBundleIdentifier,
            queue: queue
        )
        submit(request, kind: .activation)
    }

    func deactivate() {
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: AppConstants.proxyExtensionBundleIdentifier,
            queue: queue
        )
        submit(request, kind: .deactivation)
    }

    func refresh() {
        let request = OSSystemExtensionRequest.propertiesRequest(
            forExtensionWithIdentifier: AppConstants.proxyExtensionBundleIdentifier,
            queue: queue
        )
        submit(request, kind: .properties)
    }

    private func submit(_ request: OSSystemExtensionRequest, kind: RequestKind) {
        queue.async { [self] in
            request.delegate = self
            requests[ObjectIdentifier(request)] = (request, kind)
            logger.info("Submitting system extension request for \(request.identifier, privacy: .public)")
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }

    @discardableResult
    private func finish(_ request: OSSystemExtensionRequest) -> RequestKind? {
        requests.removeValue(forKey: ObjectIdentifier(request))?.kind
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        logger.notice(
            "Replacing system extension \(existing.bundleShortVersion, privacy: .public) (\(existing.bundleVersion, privacy: .public)) with \(ext.bundleShortVersion, privacy: .public) (\(ext.bundleVersion, privacy: .public))"
        )
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.notice("System extension requires user approval")
        onStateChange?(.needsApproval)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        guard let kind = finish(request) else {
            return
        }

        logger.notice("System extension request completed with result \(String(describing: result), privacy: .public)")
        if result == .willCompleteAfterReboot {
            onStateChange?(.rebootRequired)
            return
        }

        switch kind {
        case .activation:
            onStateChange?(.activated)
        case .deactivation:
            onStateChange?(.notInstalled)
        case .properties:
            onStateChange?(.notInstalled)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        finish(request)
        logger.error("System extension request failed: \(error.localizedDescription, privacy: .public)")
        onStateChange?(.failed(error))
    }

    func request(
        _ request: OSSystemExtensionRequest,
        foundProperties properties: [OSSystemExtensionProperties]
    ) {
        guard finish(request) != nil else {
            return
        }

        if let property = properties.first(where: { $0.isAwaitingUserApproval }) {
            logger.notice(
                "System extension \(property.bundleShortVersion, privacy: .public) awaits approval"
            )
            onStateChange?(.needsApproval)
        } else if let property = properties.first(where: { $0.isEnabled }) {
            logger.info(
                "System extension \(property.bundleShortVersion, privacy: .public) is enabled"
            )
            onStateChange?(.activated)
        } else if properties.isEmpty {
            logger.info("System extension is not installed")
            onStateChange?(.notInstalled)
        } else {
            logger.info("System extension exists but is disabled")
            onStateChange?(.disabled)
        }
    }
}
