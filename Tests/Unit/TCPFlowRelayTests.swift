import Foundation
import Network
import NetworkExtension
import XCTest

final class TCPFlowRelayTests: XCTestCase {
    func testSmallMessagesRelayThroughLocalEchoServer() throws {
        try assertEchoed(byteCount: 1)
        try assertEchoed(byteCount: 256)
    }

    func testDelayedUpstreamMaintainsRelay() throws {
        try assertEchoed(byteCount: 4_096, responseDelay: 0.1)
        try assertEchoed(byteCount: 4_096, responseDelay: 0.5)
    }

    func testContinuousTransferRemainsBounded() throws {
        try assertEchoed(
            byteCount: 500 * 1_024 * 1_024,
            timeout: 180
        )
    }

    func testTwentyConcurrentFlows() throws {
        let server = EchoServer()
        let port = try server.start()
        defer { server.stop() }

        let completed = expectation(description: "all relays completed")
        completed.expectedFulfillmentCount = 20
        var relays: [TCPFlowRelay] = []
        var flows: [StreamingRelayFlow] = []

        for index in 0..<20 {
            let byte = UInt8(index + 1)
            let flow = StreamingRelayFlow(
                byteCount: 8_192,
                byte: byte,
                onAllBytesWritten: {}
            )
            let connection = NWRelayConnection(
                to: .hostPort(host: "127.0.0.1", port: port),
                using: .tcp
            )
            let relay = TCPFlowRelay(
                flow: flow,
                connection: connection,
                onClose: { _ in completed.fulfill() }
            )
            flows.append(flow)
            relays.append(relay)
            relay.start()
        }

        wait(for: [completed], timeout: 20)
        XCTAssertTrue(flows.allSatisfy { $0.validationError == nil })
        XCTAssertTrue(flows.allSatisfy { $0.totalBytesWritten == 8_192 })
        XCTAssertTrue(relays.allSatisfy { $0.currentState == .closed(.completed) })
    }

    func testBackpressureAllowsOneOperationPerDirection() {
        let flow = ControlledRelayFlow()
        flow.enqueueRead(Data([1]))
        flow.enqueueRead(Data([2]))
        flow.automaticallyCompletesWrites = false

        let connection = ControlledRelayConnection()
        connection.automaticallyCompletesSends = false
        let relay = TCPFlowRelay(
            flow: flow,
            connection: connection,
            onClose: { _ in }
        )
        relay.start()

        XCTAssertTrue(eventually { connection.sendCallCount == 1 })
        XCTAssertEqual(flow.readCallCount, 1)
        connection.completeNextSend()
        XCTAssertTrue(eventually { connection.sendCallCount == 2 })
        XCTAssertEqual(flow.readCallCount, 2)

        connection.completeNextReceive(data: Data([3]), isComplete: false)
        XCTAssertTrue(eventually { flow.writeCallCount == 1 })
        XCTAssertEqual(connection.receiveCallCount, 1)
        flow.completeNextWrite()
        XCTAssertTrue(eventually { connection.receiveCallCount == 2 })

        relay.close(reason: .userRequested)
        XCTAssertTrue(eventually { relay.currentState == .closed(.userRequested) })
    }

    func testRepeatedUserCloseIsIdempotent() {
        let closed = expectation(description: "relay closed once")
        closed.assertForOverFulfill = true
        let flow = ControlledRelayFlow()
        let connection = ControlledRelayConnection()
        let relay = TCPFlowRelay(
            flow: flow,
            connection: connection,
            onClose: { _ in closed.fulfill() }
        )
        relay.start()

        XCTAssertTrue(eventually { relay.currentState == .relaying })
        relay.close(reason: .userRequested)
        relay.close(reason: .userRequested)
        relay.close(reason: .providerStopped)

        wait(for: [closed], timeout: 2)
        XCTAssertEqual(flow.closeReadCallCount, 1)
        XCTAssertEqual(flow.closeWriteCallCount, 1)
        XCTAssertEqual(connection.cancelCallCount, 1)
        XCTAssertEqual(relay.currentState, .closed(.userRequested))
    }

    func testUserCloseReportsPeerResetAndCompletesAfterClosingBothDirections() {
        let completed = expectation(description: "close completed")
        let flow = ControlledRelayFlow()
        let connection = ControlledRelayConnection()
        let relay = TCPFlowRelay(
            flow: flow,
            connection: connection,
            onClose: { _ in }
        )
        relay.start()

        XCTAssertTrue(eventually { relay.currentState == .relaying })
        relay.close(reason: .userRequested) {
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)

        XCTAssertEqual(flow.closeReadError?.domain, NEAppProxyErrorDomain)
        XCTAssertEqual(
            flow.closeReadError?.code,
            NEAppProxyFlowError.Code.peerReset.rawValue
        )
        XCTAssertEqual(flow.closeWriteError, flow.closeReadError)
        XCTAssertEqual(connection.cancelCallCount, 1)
    }

    func testConnectionTimeoutAndClientOpenFailureCloseCleanly() {
        let timeoutFlow = ControlledRelayFlow()
        let timeoutConnection = ControlledRelayConnection()
        timeoutConnection.automaticallyBecomesReady = false
        let timeoutRelay = TCPFlowRelay(
            flow: timeoutFlow,
            connection: timeoutConnection,
            connectionTimeout: 0.01,
            onClose: { _ in }
        )
        timeoutRelay.start()

        XCTAssertTrue(eventually {
            timeoutRelay.currentState == .closed(.upstreamFailed)
        })
        XCTAssertEqual(timeoutConnection.cancelCallCount, 1)
        XCTAssertEqual(timeoutFlow.closeReadCallCount, 1)
        XCTAssertEqual(timeoutFlow.closeWriteCallCount, 1)

        let failedOpenFlow = ControlledRelayFlow()
        failedOpenFlow.openError = RelayTestError.clientOpenFailed
        let failedOpenConnection = ControlledRelayConnection()
        let failedOpenRelay = TCPFlowRelay(
            flow: failedOpenFlow,
            connection: failedOpenConnection,
            onClose: { _ in }
        )
        failedOpenRelay.start()

        XCTAssertTrue(eventually {
            failedOpenRelay.currentState == .closed(.clientFailed)
        })
        XCTAssertEqual(failedOpenConnection.cancelCallCount, 1)
        XCTAssertEqual(failedOpenFlow.closeReadCallCount, 1)
        XCTAssertEqual(failedOpenFlow.closeWriteCallCount, 1)
    }

    func testClientAndUpstreamEOFCompleteIndependently() {
        let clientEOFFlow = ControlledRelayFlow()
        clientEOFFlow.enqueueRead(Data())
        let clientEOFConnection = ControlledRelayConnection()
        let clientEOFRelay = TCPFlowRelay(
            flow: clientEOFFlow,
            connection: clientEOFConnection,
            onClose: { _ in }
        )
        clientEOFRelay.start()

        XCTAssertTrue(eventually { clientEOFConnection.sendCallCount == 1 })
        XCTAssertEqual(clientEOFFlow.closeReadCallCount, 1)
        XCTAssertEqual(clientEOFRelay.currentState, .relaying)
        clientEOFConnection.completeNextReceive(
            data: Data([0x42]),
            isComplete: true
        )
        XCTAssertTrue(eventually {
            clientEOFRelay.currentState == .closed(.completed)
        })
        XCTAssertEqual(clientEOFFlow.writeCallCount, 1)
        XCTAssertEqual(clientEOFFlow.closeWriteCallCount, 1)

        let upstreamEOFFlow = ControlledRelayFlow()
        let upstreamEOFConnection = ControlledRelayConnection()
        let upstreamEOFRelay = TCPFlowRelay(
            flow: upstreamEOFFlow,
            connection: upstreamEOFConnection,
            onClose: { _ in }
        )
        upstreamEOFRelay.start()

        XCTAssertTrue(eventually { upstreamEOFConnection.receiveCallCount == 1 })
        upstreamEOFConnection.completeNextReceive(data: nil, isComplete: true)
        XCTAssertTrue(eventually { upstreamEOFFlow.closeWriteCallCount == 1 })
        XCTAssertEqual(upstreamEOFRelay.currentState, .relaying)
        upstreamEOFFlow.completeNextRead(Data())
        XCTAssertTrue(eventually {
            upstreamEOFRelay.currentState == .closed(.completed)
        })
        XCTAssertEqual(upstreamEOFFlow.closeReadCallCount, 1)
    }

    func testUserCloseDuringTransferStopsRelay() throws {
        let server = EchoServer(responseDelay: 0.002)
        let port = try server.start()
        defer { server.stop() }

        let closed = expectation(description: "relay closed")
        let byteCount = 64 * 1_024 * 1_024
        let flow = StreamingRelayFlow(
            byteCount: byteCount,
            byte: 0x5A,
            onAllBytesWritten: {}
        )
        let relay = TCPFlowRelay(
            flow: flow,
            connection: NWRelayConnection(
                to: .hostPort(host: "127.0.0.1", port: port),
                using: .tcp
            ),
            onClose: { _ in closed.fulfill() }
        )
        relay.start()

        XCTAssertTrue(eventually(timeout: 10) { flow.totalBytesWritten > 0 })
        relay.close(reason: .userRequested)
        wait(for: [closed], timeout: 5)

        XCTAssertGreaterThan(flow.totalBytesWritten, 0)
        XCTAssertLessThan(flow.totalBytesWritten, byteCount)
        XCTAssertEqual(relay.currentState, .closed(.userRequested))
    }

    func testFlowRegistrySnapshotsAndClosesOnce() {
        let registry = FlowRegistry()
        let removed = StubRelay()
        let retained = StubRelay()
        registry.insert(removed)
        registry.insert(retained)
        registry.remove(id: removed.id)

        XCTAssertEqual(registry.activeCount, 1)
        let first = expectation(description: "first disconnect")
        registry.disconnectAll(reason: .providerStopped) { count in
            XCTAssertEqual(count, 1)
            XCTAssertEqual(registry.activeCount, 0)
            first.fulfill()
        }
        wait(for: [first], timeout: 2)

        let second = expectation(description: "second disconnect")
        registry.disconnectAll(reason: .providerStopped) { count in
            XCTAssertEqual(count, 0)
            second.fulfill()
        }
        wait(for: [second], timeout: 2)
        XCTAssertTrue(removed.closeReasons.isEmpty)
        XCTAssertEqual(retained.closeReasons, [.providerStopped])
    }

    private func assertEchoed(
        byteCount: Int,
        responseDelay: TimeInterval = 0,
        timeout: TimeInterval = 10
    ) throws {
        let server = EchoServer(responseDelay: responseDelay)
        let port = try server.start()
        defer { server.stop() }

        let bytesWritten = expectation(description: "all bytes echoed")
        let closed = expectation(description: "relay completed")
        let flow = StreamingRelayFlow(
            byteCount: byteCount,
            byte: 0xA5,
            onAllBytesWritten: { bytesWritten.fulfill() }
        )
        let connection = NWRelayConnection(
            to: .hostPort(host: "127.0.0.1", port: port),
            using: .tcp
        )
        let relay = TCPFlowRelay(
            flow: flow,
            connection: connection,
            onClose: { _ in closed.fulfill() }
        )

        relay.start()
        wait(for: [bytesWritten, closed], timeout: timeout)

        XCTAssertNil(flow.validationError)
        XCTAssertNil(flow.closeErrorDescription)
        XCTAssertEqual(flow.totalBytesWritten, byteCount)
        XCTAssertLessThanOrEqual(flow.maximumOutstandingReads, 1)
        XCTAssertLessThanOrEqual(flow.maximumOutstandingWrites, 1)
        XCTAssertEqual(relay.currentState, .closed(.completed))
    }

    private func eventually(
        timeout: TimeInterval = 2,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
        return condition()
    }
}

private final class StreamingRelayFlow: RelayFlowIO {
    private let lock = NSLock()
    private let expectedByte: UInt8
    private let totalByteCount: Int
    private let onAllBytesWritten: () -> Void
    private var remainingBytes: Int
    private var didNotifyAllBytesWritten = false
    private var outstandingReads = 0
    private var outstandingWrites = 0
    private(set) var maximumOutstandingReads = 0
    private(set) var maximumOutstandingWrites = 0
    private(set) var totalBytesWritten = 0
    private(set) var validationError: String?
    private(set) var closeErrorDescription: String?

    init(
        byteCount: Int,
        byte: UInt8,
        onAllBytesWritten: @escaping () -> Void
    ) {
        totalByteCount = byteCount
        remainingBytes = byteCount
        expectedByte = byte
        self.onAllBytesWritten = onAllBytesWritten
    }

    func open(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func readData(completion: @escaping (Data?, Error?) -> Void) {
        let data: Data
        lock.lock()
        outstandingReads += 1
        maximumOutstandingReads = max(maximumOutstandingReads, outstandingReads)
        if remainingBytes > 0 {
            let count = min(TCPFlowRelay.maximumChunkSize, remainingBytes)
            remainingBytes -= count
            data = Data(repeating: expectedByte, count: count)
        } else {
            data = Data()
        }
        lock.unlock()

        DispatchQueue.global().async { [weak self] in
            guard let self else {
                return
            }
            self.lock.lock()
            self.outstandingReads -= 1
            self.lock.unlock()
            completion(data, nil)
        }
    }

    func writeData(_ data: Data, completion: @escaping (Error?) -> Void) {
        var shouldNotify = false
        lock.lock()
        outstandingWrites += 1
        maximumOutstandingWrites = max(maximumOutstandingWrites, outstandingWrites)
        if validationError == nil,
           data.contains(where: { $0 != expectedByte }) {
            validationError = "Echoed data did not match the input byte pattern."
        }
        totalBytesWritten += data.count
        if totalBytesWritten > totalByteCount, validationError == nil {
            validationError = "Relay wrote more bytes than were sent."
        }
        if totalBytesWritten == totalByteCount, !didNotifyAllBytesWritten {
            didNotifyAllBytesWritten = true
            shouldNotify = true
        }
        outstandingWrites -= 1
        lock.unlock()

        if shouldNotify {
            onAllBytesWritten()
        }
        completion(nil)
    }

    func closeRead(error: Error?) {
        recordCloseError(error)
    }

    func closeWrite(error: Error?) {
        recordCloseError(error)
    }

    private func recordCloseError(_ error: Error?) {
        guard let error else {
            return
        }
        let nsError = error as NSError
        lock.lock()
        closeErrorDescription = [
            nsError.domain,
            String(nsError.code),
            nsError.localizedDescription,
        ].joined(separator: ":")
        lock.unlock()
    }
}

private final class ControlledRelayFlow: RelayFlowIO {
    var automaticallyCompletesWrites = true
    var openError: Error?

    private let lock = NSLock()
    private var reads: [Data?] = []
    private var pendingReadCompletions: [(Data?, Error?) -> Void] = []
    private var pendingWriteCompletions: [(Error?) -> Void] = []
    private(set) var readCallCount = 0
    private(set) var writeCallCount = 0
    private(set) var closeReadCallCount = 0
    private(set) var closeWriteCallCount = 0
    private(set) var closeReadError: NSError?
    private(set) var closeWriteError: NSError?

    func enqueueRead(_ data: Data?) {
        lock.lock()
        reads.append(data)
        lock.unlock()
    }

    func open(completion: @escaping (Error?) -> Void) {
        completion(openError)
    }

    func readData(completion: @escaping (Data?, Error?) -> Void) {
        lock.lock()
        readCallCount += 1
        let hasRead = !reads.isEmpty
        let data = hasRead ? reads.removeFirst() : nil
        if hasRead {
            lock.unlock()
            completion(data, nil)
        } else {
            pendingReadCompletions.append(completion)
            lock.unlock()
        }
    }

    func completeNextRead(_ data: Data?) {
        lock.lock()
        let completion = pendingReadCompletions.removeFirst()
        lock.unlock()
        completion(data, nil)
    }

    func writeData(_ data: Data, completion: @escaping (Error?) -> Void) {
        _ = data
        lock.lock()
        writeCallCount += 1
        if automaticallyCompletesWrites {
            lock.unlock()
            completion(nil)
        } else {
            pendingWriteCompletions.append(completion)
            lock.unlock()
        }
    }

    func completeNextWrite() {
        lock.lock()
        let completion = pendingWriteCompletions.removeFirst()
        lock.unlock()
        completion(nil)
    }

    func closeRead(error: Error?) {
        lock.lock()
        closeReadCallCount += 1
        closeReadError = error as NSError?
        lock.unlock()
    }

    func closeWrite(error: Error?) {
        lock.lock()
        closeWriteCallCount += 1
        closeWriteError = error as NSError?
        lock.unlock()
    }
}

private final class ControlledRelayConnection: RelayConnectionIO {
    var stateUpdateHandler: ((RelayConnectionState) -> Void)?
    var automaticallyCompletesSends = true
    var automaticallyBecomesReady = true

    private let lock = NSLock()
    private var pendingSendCompletions: [(Error?) -> Void] = []
    private var pendingReceiveCompletions: [
        (Data?, Bool, Error?) -> Void
    ] = []
    private(set) var sendCallCount = 0
    private(set) var receiveCallCount = 0
    private(set) var cancelCallCount = 0

    func start(on queue: DispatchQueue) {
        guard automaticallyBecomesReady else {
            return
        }
        queue.async { [weak self] in
            self?.stateUpdateHandler?(.ready)
        }
    }

    func send(_ data: Data?, isFinal: Bool, completion: @escaping (Error?) -> Void) {
        _ = data
        _ = isFinal
        lock.lock()
        sendCallCount += 1
        if automaticallyCompletesSends {
            lock.unlock()
            completion(nil)
        } else {
            pendingSendCompletions.append(completion)
            lock.unlock()
        }
    }

    func completeNextSend() {
        lock.lock()
        let completion = pendingSendCompletions.removeFirst()
        lock.unlock()
        completion(nil)
    }

    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (Data?, Bool, Error?) -> Void
    ) {
        _ = minimumIncompleteLength
        _ = maximumLength
        lock.lock()
        receiveCallCount += 1
        pendingReceiveCompletions.append(completion)
        lock.unlock()
    }

    func completeNextReceive(data: Data?, isComplete: Bool) {
        lock.lock()
        let completion = pendingReceiveCompletions.removeFirst()
        lock.unlock()
        completion(data, isComplete, nil)
    }

    func cancel() {
        lock.lock()
        cancelCallCount += 1
        lock.unlock()
    }
}

private enum RelayTestError: Error {
    case clientOpenFailed
}

private final class StubRelay: RelayControlling {
    let id = UUID()
    private(set) var closeReasons: [RelayCloseReason] = []

    func close(reason: RelayCloseReason, completion: @escaping () -> Void) {
        closeReasons.append(reason)
        completion()
    }
}
