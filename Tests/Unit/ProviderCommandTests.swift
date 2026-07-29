import XCTest

final class ProviderCommandTests: XCTestCase {
    func testCommandRoundTripsWithIdentity() throws {
        let identity = TargetAppIdentity(
            displayName: "Hearthstone",
            signingIdentifier: "com.example.hearthstone"
        )
        let command = ProviderCommand(
            action: .updateTargetIdentity,
            requestID: UUID(uuidString: "2B0A1685-B038-4AB7-89B6-96346775FA55")!,
            targetIdentity: identity
        )

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(ProviderCommand.self, from: data)

        XCTAssertEqual(decoded, command)
    }

    func testResponseCarriesRequestID() {
        let command = ProviderCommand(action: .status)
        let response = ProviderResponse.status(for: command, activeFlowCount: 3)

        XCTAssertEqual(response.requestID, command.requestID)
        XCTAssertEqual(response.activeFlowCount, 3)
        XCTAssertEqual(response.result, .ok)
    }
}
