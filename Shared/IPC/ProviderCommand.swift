import Foundation

struct ProviderCommand: Codable, Equatable {
    static let currentProtocolVersion = 1

    enum Action: String, Codable {
        case status
        case disconnectNow
        case prepareToDisable
        case updateTargetIdentity
        case exportDiagnostics
    }

    let protocolVersion: Int
    let requestID: UUID
    let action: Action
    let targetIdentity: TargetAppIdentity?

    init(
        action: Action,
        requestID: UUID = UUID(),
        targetIdentity: TargetAppIdentity? = nil,
        protocolVersion: Int = Self.currentProtocolVersion
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.action = action
        self.targetIdentity = targetIdentity
    }
}
