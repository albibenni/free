import Foundation
import Network

class LocalServer {
    var listener: NWListener? 
    let port: NWEndpoint.Port = 10000

    func start() {
        // Skip starting the server if we are running in a unit test environment
        let isTesting = ProcessInfo.processInfo.environment["IS_TESTING"] == "1" || 
                        ProcessInfo.processInfo.processName.contains("Test")
        
        if isTesting {
            return
        }

        do {
            let parameters = NWParameters.tcp
            let listener = try NWListener(using: parameters, on: port)
            
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("Local server listening on port \(self.port)")
                case .failed(let error):
                    print("Server failed with error: \(error)")
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { connection in
                self.handleConnection(connection)
            }
            
            listener.start(queue: .global())
            self.listener = listener
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
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

        // Read the request (we don't strictly need to parse it, just consume it)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, isComplete, _ in
            if isComplete {
                connection.cancel()
            } else {
                // Send response immediately
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }
}
