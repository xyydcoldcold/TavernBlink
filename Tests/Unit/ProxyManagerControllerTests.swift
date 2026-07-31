import XCTest

final class ProxyManagerControllerTests: XCTestCase {
    func testProviderProtocolContainsRequiredConfiguration() {
        let bundleIdentifier = "com.example.TavernBlink.ProxyExtension"
        let providerProtocol = ProxyManagerController.makeProviderProtocol(
            providerBundleIdentifier: bundleIdentifier
        )

        XCTAssertEqual(providerProtocol.providerBundleIdentifier, bundleIdentifier)
        XCTAssertEqual(
            providerProtocol.serverAddress,
            ProxyManagerController.providerServerAddress
        )
        XCTAssertFalse(providerProtocol.serverAddress?.isEmpty ?? true)
        XCTAssertEqual(
            providerProtocol.providerConfiguration?["protocolVersion"] as? Int,
            ProviderCommand.currentProtocolVersion
        )
    }

    func testDisablePreflightProceedsOnlyForOKResponse() {
        let command = ProviderCommand(action: .prepareToDisable)
        let response = ProviderResponse.status(
            for: command,
            activeFlowCount: 0
        )

        XCTAssertEqual(
            ProxyManagerController.disablePreflightDecision(for: response),
            .proceed
        )
    }

    func testDisablePreflightBlocksForActiveFlows() {
        let command = ProviderCommand(action: .prepareToDisable)
        let response = ProviderResponse.status(
            for: command,
            result: .notReady,
            activeFlowCount: 3,
            errorCode: "activeFlowsPreventDisable",
            errorSummary: "Target flows are still active."
        )

        XCTAssertEqual(
            ProxyManagerController.disablePreflightDecision(for: response),
            .activeFlows(3)
        )
    }

    func testDisablePreflightRejectsUnexpectedProviderFailure() {
        let command = ProviderCommand(action: .prepareToDisable)
        let response = ProviderResponse.status(
            for: command,
            result: .failed,
            activeFlowCount: 0,
            errorCode: "unexpected",
            errorSummary: "Unexpected provider failure."
        )

        XCTAssertEqual(
            ProxyManagerController.disablePreflightDecision(for: response),
            .rejected("Unexpected provider failure.")
        )
    }
}
