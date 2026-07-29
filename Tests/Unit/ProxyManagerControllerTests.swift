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
}
