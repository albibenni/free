import Foundation
import Network
import Testing

@testable import FreeLogic

private enum LocalServerTestError: Error, Equatable {
    case listenerInitFailed
}

private final class FakeLocalServerConnection: LocalServerConnection {
    var didStart = false
    var didCancel = false
    var sentPayloads: [Data?] = []
    var receiveConfig: (data: Data?, isComplete: Bool, error: NWError?) = (nil, false, nil)
    var receiveParameters: (minimum: Int, maximum: Int)?

    func start(queue: DispatchQueue) {
        didStart = true
    }

    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (_ data: Data?, _ isComplete: Bool, _ error: NWError?) -> Void
    ) {
        receiveParameters = (minimumIncompleteLength, maximumLength)
        completion(receiveConfig.data, receiveConfig.isComplete, receiveConfig.error)
    }

    func send(content: Data?, completion: @escaping (NWError?) -> Void) {
        sentPayloads.append(content)
        completion(nil)
    }

    func cancel() {
        didCancel = true
    }
}

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
        var capturedError: Error?
        server.onFailure = { error in
            capturedError = error
        }
        server.listenerFactory = { _, _ in
            throw LocalServerTestError.listenerInitFailed
        }

        server.start(on: 12345)

        #expect(server.listener == nil)
        #expect(server.port == nil)
        #expect((capturedError as? LocalServerTestError) == .listenerInitFailed)
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

    @Test("LocalServer returns correct HTML response")
    func serverResponse() async throws {
        let server = LocalServer()
        let testPort: NWEndpoint.Port = 10001

        server.start(on: testPort)
        try await Task.sleep(nanoseconds: 500_000_000)

        let url = URL(string: "http://localhost:10001")!

        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as? HTTPURLResponse

        #expect(httpResponse?.statusCode == 200)
        #expect(httpResponse?.allHeaderFields["Content-Type"] as? String == "text/html")

        let html = String(data: data, encoding: .utf8)
        #expect(html?.contains("Focus Mode Active") == true)
        #expect(html?.contains("🛡️") == true)

        server.stop()
    }

    @Test("LocalServer handles port collisions")
    func portCollision() async throws {
        let server1 = LocalServer()
        let server2 = LocalServer()
        let port: NWEndpoint.Port = 10005

        server1.start(on: port)

        try await Task.sleep(nanoseconds: 200_000_000)

        var failureOccurred = false
        server2.onFailure = { _ in
            failureOccurred = true
        }

        server2.start(on: port)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(failureOccurred == true)

        server1.stop()
        server2.stop()
    }
}
