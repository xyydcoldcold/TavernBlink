import Foundation

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
    let closedFlowCount: Int
    let durationMilliseconds: Int
    let errorCode: String?
    let errorSummary: String?

    static func status(
        for command: ProviderCommand,
        result: Result = .ok,
        activeFlowCount: Int,
        closedFlowCount: Int = 0,
        durationMilliseconds: Int = 0,
        errorCode: String? = nil,
        errorSummary: String? = nil
    ) -> ProviderResponse {
        ProviderResponse(
            protocolVersion: ProviderCommand.currentProtocolVersion,
            requestID: command.requestID,
            result: result,
            activeFlowCount: activeFlowCount,
            closedFlowCount: closedFlowCount,
            durationMilliseconds: durationMilliseconds,
            errorCode: errorCode,
            errorSummary: errorSummary
        )
    }
}
