import Foundation

struct ProviderDiagnostics: Codable, Equatable {
    enum LifecycleState: String, Codable {
        case starting
        case readyFailOpen
        case readyRelaying
        case stopping
        case stopped
    }

    let lifecycleState: LifecycleState
    let expectedSigningIdentifier: String?
    let lastObservedSigningIdentifier: String?
    let observedTCPFlowCount: Int
    let matchedTCPFlowCount: Int
    let missingSigningIdentifierCount: Int
    let identifierLogCapacityReached: Bool
}

struct ProviderResponse: Codable, Equatable {
    enum Result: String, Codable {
        case ok
        case unsupportedProtocol
        case invalidCommand
        case notReady
        case failed
    }

    let protocolVersion: Int
    let requestID: UUID
    let result: Result
    let activeFlowCount: Int
    let disconnectibleFlowCount: Int?
    let closedFlowCount: Int
    let durationMilliseconds: Int
    let errorCode: String?
    let errorSummary: String?
    let diagnostics: ProviderDiagnostics?

    static func status(
        for command: ProviderCommand,
        result: Result = .ok,
        activeFlowCount: Int,
        disconnectibleFlowCount: Int? = nil,
        closedFlowCount: Int = 0,
        durationMilliseconds: Int = 0,
        errorCode: String? = nil,
        errorSummary: String? = nil,
        diagnostics: ProviderDiagnostics? = nil
    ) -> ProviderResponse {
        ProviderResponse(
            protocolVersion: ProviderCommand.currentProtocolVersion,
            requestID: command.requestID,
            result: result,
            activeFlowCount: activeFlowCount,
            disconnectibleFlowCount: disconnectibleFlowCount,
            closedFlowCount: closedFlowCount,
            durationMilliseconds: durationMilliseconds,
            errorCode: errorCode,
            errorSummary: errorSummary,
            diagnostics: diagnostics
        )
    }
}
