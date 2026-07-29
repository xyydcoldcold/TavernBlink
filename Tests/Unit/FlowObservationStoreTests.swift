import XCTest

final class FlowObservationStoreTests: XCTestCase {
    func testResetForNewTargetClearsPriorObservations() {
        let store = FlowObservationStore(identifierCapacity: 2)
        store.reset(expectedSigningIdentifier: "com.example.old")
        _ = store.observe(signingIdentifier: "com.example.old")
        _ = store.observe(signingIdentifier: nil)

        store.reset(expectedSigningIdentifier: "com.example.new")

        let diagnostics = store.snapshot(lifecycleState: .readyFailOpen)
        XCTAssertEqual(diagnostics.expectedSigningIdentifier, "com.example.new")
        XCTAssertNil(diagnostics.lastObservedSigningIdentifier)
        XCTAssertEqual(diagnostics.observedTCPFlowCount, 0)
        XCTAssertEqual(diagnostics.matchedTCPFlowCount, 0)
        XCTAssertEqual(diagnostics.missingSigningIdentifierCount, 0)
        XCTAssertFalse(diagnostics.identifierLogCapacityReached)
    }

    func testObservationsTrackMatchesMissingIdentifiersAndLogCapacity() {
        let store = FlowObservationStore(identifierCapacity: 1)
        store.reset(expectedSigningIdentifier: "com.example.target")

        let first = store.observe(signingIdentifier: "com.example.target")
        let duplicate = store.observe(signingIdentifier: "com.example.target")
        let overflow = store.observe(signingIdentifier: "com.example.other")
        let missing = store.observe(signingIdentifier: "")

        XCTAssertTrue(first.matchedTarget)
        XCTAssertTrue(first.shouldLogIdentifier)
        XCTAssertFalse(duplicate.shouldLogIdentifier)
        XCTAssertFalse(overflow.matchedTarget)
        XCTAssertFalse(overflow.shouldLogIdentifier)
        XCTAssertTrue(missing.shouldLogMissingIdentifier)

        let diagnostics = store.snapshot(lifecycleState: .readyFailOpen)
        XCTAssertEqual(diagnostics.lastObservedSigningIdentifier, "com.example.other")
        XCTAssertEqual(diagnostics.observedTCPFlowCount, 4)
        XCTAssertEqual(diagnostics.matchedTCPFlowCount, 2)
        XCTAssertEqual(diagnostics.missingSigningIdentifierCount, 1)
        XCTAssertTrue(diagnostics.identifierLogCapacityReached)
    }
}
