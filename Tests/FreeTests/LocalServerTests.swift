import Foundation
import Network
import Testing

@testable import FreeLogic

private enum LocalServerTestError: Error, Equatable {
    case listenerInitFailed
}

private final class FakeLocalServerConnection: LocalServerConnection {
    private let lock = NSLock()
    private var _didStart = false
    private var _didCancel = false
    private var _sentPayloads: [Data?] = []
    private var _receiveConfig: (data: Data?, isComplete: Bool, error: NWError?) = (nil, false, nil)
    private var _receiveParameters: (minimum: Int, maximum: Int)?

    var didStart: Bool { withLock { _didStart } }
    var didCancel: Bool { withLock { _didCancel } }
    var sentPayloads: [Data?] { withLock { _sentPayloads } }
    var receiveParameters: (minimum: Int, maximum: Int)? { withLock { _receiveParameters } }
    var receiveConfig: (data: Data?, isComplete: Bool, error: NWError?) {
        get { withLock { _receiveConfig } }
        set { withLock { _receiveConfig = newValue } }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func start(queue: DispatchQueue) {
        withLock { _didStart = true }
    }

    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (_ data: Data?, _ isComplete: Bool, _ error: NWError?) -> Void
    ) {
        let config = withLock {
            _receiveParameters = (minimumIncompleteLength, maximumLength)
            return _receiveConfig
        }
        completion(config.data, config.isComplete, config.error)
    }

    func send(content: Data?, completion: @escaping (NWError?) -> Void) {
        withLock { _sentPayloads.append(content) }
        completion(nil)
    }

    func cancel() {
        withLock { _didCancel = true }
    }
}

@Suite(.serialized)
struct LocalServerTests {
    @Test("LocalServer.start skips default test port in test runtime")
    func startSkipsDefaultPortInTests() {
        let server = LocalServer()
        server.processNameProvider = { "UnitTestProcess" }
        server.start()

        #expect(server.port == nil)
        #expect(server.listener == nil)
    }

    @Test("LocalServer.start reports listener factory errors")
    func startReportsFactoryFailure() {
        let server = LocalServer()
        var capturedError: LocalServerTestError?
        server.onFailure = { error in
            capturedError = error as? LocalServerTestError
        }
        server.listenerFactory = { _ in
            throw LocalServerTestError.listenerInitFailed
        }

        server.start(on: 12345)

        #expect(server.listener == nil)
        #expect(server.port == nil)
        #expect(capturedError == .listenerInitFailed)
    }

    @Test("handleConnection closes immediately when receive completes")
    func handleConnectionCompletesWithoutResponse() {
        let server = LocalServer()
        let connection = FakeLocalServerConnection()
        connection.receiveConfig = (nil, true, nil)

        server.handleConnection(connection)

        #expect(connection.didStart == true)
        #expect(connection.didCancel == true)
        #expect(connection.sentPayloads.isEmpty)
        #expect(connection.receiveParameters?.minimum == 1)
        #expect(connection.receiveParameters?.maximum == 65536)
    }

    @Test("handleConnection sends block page for active request")
    func handleConnectionSendsBlockPage() {
        let server = LocalServer()
        let connection = FakeLocalServerConnection()
        connection.receiveConfig = (Data("GET / HTTP/1.1\r\n\r\n".utf8), false, nil)

        server.handleConnection(connection)

        #expect(connection.didStart == true)
        #expect(connection.didCancel == true)
        #expect(connection.sentPayloads.count == 1)
        let payload = connection.sentPayloads.first ?? nil
        let response = payload.flatMap { String(data: $0, encoding: .utf8) }
        #expect(response?.contains("HTTP/1.1 200 OK") == true)
        #expect(response?.contains("Content-Type: text/html") == true)
        #expect(response?.contains("Focus Mode Active") == true)
    }

    @Test("LocalServer response payload includes expected headers and block-page content")
    func serverResponsePayload() {
        let server = LocalServer()
        let connection = FakeLocalServerConnection()
        connection.receiveConfig = (Data("GET / HTTP/1.1\r\n\r\n".utf8), false, nil)

        server.handleConnection(connection)

        let payload = connection.sentPayloads.first ?? nil
        let response = payload.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(response.contains("HTTP/1.1 200 OK"))
        #expect(response.contains("Content-Type: text/html"))
        #expect(response.contains("Focus Mode Active"))
        #expect(response.contains("🛡️"))
        #expect(response.contains("This site is blocked by Free."))
    }
}
