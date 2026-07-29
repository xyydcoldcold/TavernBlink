import Foundation
import SystemExtensions

final class SystemExtensionController: NSObject, OSSystemExtensionRequestDelegate {
    enum State {
        case idle
        case needsApproval
        case activated
        case rebootRequired
        case failed(Error)
    }

    var onStateChange: ((State) -> Void)?

    private let queue = DispatchQueue(label: "dev.tavernblink.system-extension")
    private var requests: [OSSystemExtensionRequest] = []

    func activate() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: AppConstants.proxyExtensionBundleIdentifier,
            queue: queue
        )
        submit(request)
    }

    func deactivate() {
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: AppConstants.proxyExtensionBundleIdentifier,
            queue: queue
        )
        submit(request)
    }

    func refresh() {
        let request = OSSystemExtensionRequest.propertiesRequest(
            forExtensionWithIdentifier: AppConstants.proxyExtensionBundleIdentifier,
            queue: queue
        )
        submit(request)
    }

    private func submit(_ request: OSSystemExtensionRequest) {
        request.delegate = self
        requests.append(request)
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    private func finish(_ request: OSSystemExtensionRequest) {
        requests.removeAll { $0 === request }
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        onStateChange?(.needsApproval)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        onStateChange?(result == .completed ? .activated : .rebootRequired)
        finish(request)
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        onStateChange?(.failed(error))
        finish(request)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        foundProperties properties: [OSSystemExtensionProperties]
    ) {
        if let property = properties.first {
            if property.isAwaitingUserApproval {
                onStateChange?(.needsApproval)
            } else if property.isEnabled {
                onStateChange?(.activated)
            } else {
                onStateChange?(.idle)
            }
        } else {
            onStateChange?(.idle)
        }
        finish(request)
    }
}
