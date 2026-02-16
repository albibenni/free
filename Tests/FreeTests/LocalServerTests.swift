import Testing
import Foundation
import Network
@testable import FreeLogic

struct LocalServerTests {

    @Test("LocalServer returns correct HTML response")
    func serverResponse() async throws {
        let server = LocalServer()
        // Use a high port unlikely to be used
        let testPort: NWEndpoint.Port = 10001

        server.start(on: testPort)

        // Give it a moment to start
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
        
        // Wait for server1 to be ready
        try await Task.sleep(nanoseconds: 200_000_000) 
        
        var failureOccurred = false
        server2.onFailure = { _ in
            failureOccurred = true
        }
        
        server2.start(on: port)
        
        // Give NWListener a moment to fail
        try await Task.sleep(nanoseconds: 500_000_000)
        
        #expect(failureOccurred == true)
        
        server1.stop()
        server2.stop()
    }
}
