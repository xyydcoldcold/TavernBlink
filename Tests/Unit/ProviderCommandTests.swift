import XCTest

final class ProviderCommandTests: XCTestCase {
    func testCommandRoundTripsWithIdentity() throws {
        let identity = TargetAppIdentity(
            displayName: "Hearthstone",
            signingIdentifier: "com.example.hearthstone",
            teamIdentifier: "ABCDE12345",
            verificationMode: .completeBundle
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
        let diagnostics = ProviderDiagnostics(
            lifecycleState: .readyRelaying,
            expectedSigningIdentifier: "com.blizzard.hearthstone",
            lastObservedSigningIdentifier: "com.blizzard.hearthstone",
            observedTCPFlowCount: 8,
            matchedTCPFlowCount: 3,
            missingSigningIdentifierCount: 0,
            identifierLogCapacityReached: false
        )
        let response = ProviderResponse.status(
            for: command,
            activeFlowCount: 3,
            disconnectibleFlowCount: 2,
            diagnostics: diagnostics
        )

        XCTAssertEqual(response.requestID, command.requestID)
        XCTAssertEqual(response.activeFlowCount, 3)
        XCTAssertEqual(response.disconnectibleFlowCount, 2)
        XCTAssertEqual(response.result, .ok)
        XCTAssertEqual(response.diagnostics, diagnostics)
    }

    func testResponseDecodesLegacyPayloadWithoutDisconnectibleCount() throws {
        let requestID = UUID()
        let payload = """
        {
          "protocolVersion": 1,
          "requestID": "\(requestID.uuidString)",
          "result": "ok",
          "activeFlowCount": 3,
          "closedFlowCount": 0,
          "durationMilliseconds": 0
        }
        """

        let response = try JSONDecoder().decode(
            ProviderResponse.self,
            from: Data(payload.utf8)
        )

        XCTAssertEqual(response.requestID, requestID)
        XCTAssertNil(response.disconnectibleFlowCount)
    }

    func testPrepareToDisableCommandRoundTrips() throws {
        let command = ProviderCommand(action: .prepareToDisable)

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(ProviderCommand.self, from: data)

        XCTAssertEqual(decoded, command)
    }
}
