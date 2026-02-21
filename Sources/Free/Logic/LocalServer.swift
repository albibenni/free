import Foundation
import Network

protocol LocalServerConnection {
    func start(queue: DispatchQueue)
    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (_ data: Data?, _ isComplete: Bool, _ error: NWError?) -> Void
    )
    func send(content: Data?, completion: @escaping (NWError?) -> Void)
    func cancel()
}

private final class LocalServerNWConnectionAdapter: LocalServerConnection {
    private let base: NWConnection

    init(base: NWConnection) {
        self.base = base
    }

    func start(queue: DispatchQueue) {
        base.start(queue: queue)
    }

    func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @escaping (_ data: Data?, _ isComplete: Bool, _ error: NWError?) -> Void
    ) {
        base.receive(
            minimumIncompleteLength: minimumIncompleteLength,
            maximumLength: maximumLength
        ) { data, _, isComplete, error in
            completion(data, isComplete, error)
        }
    }

    func send(content: Data?, completion: @escaping (NWError?) -> Void) {
        base.send(content: content, completion: .contentProcessed(completion))
    }

    func cancel() {
        base.cancel()
    }
}

class LocalServer {
    var listener: NWListener?
    private(set) var port: NWEndpoint.Port?
    var onFailure: ((Error) -> Void)?
    var processNameProvider: () -> String = { ProcessInfo.processInfo.processName }
    var listenerFactory:
        (_ parameters: NWParameters, _ port: NWEndpoint.Port) throws -> NWListener = {
            parameters, port in
            try NWListener(using: parameters, on: port)
        }

    func start(on requestedPort: NWEndpoint.Port = 10000) {
        let isGeneralTesting = processNameProvider().contains("Test") && requestedPort == 10000

        if isGeneralTesting {
            return
        }

        do {
            let parameters = NWParameters.tcp
            let listener = try listenerFactory(parameters, requestedPort)
            self.port = requestedPort

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let actualPort = listener.port {
                        print("Local server listening on port \(actualPort)")
                    }
                case .failed(let error):
                    print("Server failed with error: \(error)")
                    self.onFailure?(error)
                default:
                    break
                }
            }

            listener.newConnectionHandler = { connection in
                self.handleConnection(LocalServerNWConnectionAdapter(base: connection))
            }

            listener.start(queue: .global())
            self.listener = listener
        } catch {
            print("Failed to start server: \(error)")
            self.onFailure?(error)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = nil
    }

    func handleConnection(_ connection: LocalServerConnection) {
        connection.start(queue: .global())

        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                        background-color: #f2f2f7;
                        display: flex;
                        flex-direction: column;
                        align-items: center;
                        justify-content: center;
                        height: 100vh;
                        margin: 0;
                        color: #1c1c1e;
                    }
                    .container {
                        text-align: center;
                        background: white;
                        padding: 40px;
                        border-radius: 20px;
                        box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                    }
                    h1 { font-size: 32px; margin-bottom: 10px; color: #ff3b30; }
                    p { font-size: 18px; color: #8e8e93; }
                    .logo { font-size: 60px; margin-bottom: 20px; }
                    @media (prefers-color-scheme: dark) {
                        body { background-color: #1c1c1e; color: #f2f2f7; }
                        .container { background: #2c2c2e; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
                        p { color: #aeaeb2; }
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="logo">🛡️</div>
                    <h1>Focus Mode Active</h1>
                    <p>This site is blocked by Free.</p>
                    <p>Get back to work!</p>
                </div>
            </body>
            </html>
            """

        let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html\r
            Content-Length: \(html.utf8.count)\r
            Connection: close\r
            \r
            \(html)
            """

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, isComplete, _ in
            if isComplete {
                connection.cancel()
            } else {
                connection.send(content: response.data(using: .utf8)) { _ in
                    connection.cancel()
                }
            }
        }
    }
}
