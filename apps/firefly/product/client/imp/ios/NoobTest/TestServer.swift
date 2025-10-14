import Foundation
import Network

// Test result structure
struct TestResult {
    let success: Bool
    let error: String?

    init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}

// Registry for test functions
class TestRegistry {
    static let shared = TestRegistry()
    private var tests: [String: () -> TestResult] = [:]

    private init() {}

    func register(feature: String, test: @escaping () -> TestResult) {
        tests[feature] = test
    }

    func run(feature: String) -> TestResult {
        Logger.shared.info("[TEST] Request to run test for feature: '\(feature)'")
        guard let test = tests[feature] else {
            Logger.shared.error("[TEST] No test found for feature '\(feature)'")
            return TestResult(success: false, error: "No test found for feature '\(feature)'")
        }
        Logger.shared.info("[TEST] Running test for '\(feature)'...")
        let result = test()
        if result.success {
            Logger.shared.info("[TEST] ✓ Test '\(feature)' succeeded")
        } else {
            Logger.shared.error("[TEST] ✗ Test '\(feature)' failed: \(result.error ?? "unknown error")")
        }
        return result
    }
}

// Simple HTTP test server
class TestServer {
    static let shared = TestServer()
    private var listener: NWListener?

    private init() {}

    func start(port: UInt16 = 8081) {
        Logger.shared.info("[TESTSERVER] start() called with port \(port)")

        // Register tests
        Logger.shared.info("[TESTSERVER] About to register tests")
        registerTests()
        Logger.shared.info("[TESTSERVER] Tests registered")

        Logger.shared.info("[TESTSERVER] Attempting to start on port \(port)")
        do {
            Logger.shared.info("[TESTSERVER] Creating TCP parameters")
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            Logger.shared.info("[TESTSERVER] TCP parameters created")

            Logger.shared.info("[TESTSERVER] Creating NWListener")
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            Logger.shared.info("[TESTSERVER] NWListener created successfully")

            // Semaphore to wait for listener to be ready
            let readySemaphore = DispatchSemaphore(value: 0)

            listener?.stateUpdateHandler = { state in
                Logger.shared.info("[TESTSERVER] State changed to \(String(describing: state))")
                if case .ready = state {
                    readySemaphore.signal()
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Logger.shared.info("[TESTSERVER] New connection received")
                self?.handleConnection(connection)
            }

            Logger.shared.info("[TESTSERVER] About to start listener")
            listener?.start(queue: .global(qos: .userInitiated))
            Logger.shared.info("[TESTSERVER] Listener.start() called, waiting for ready state...")

            // Wait up to 1 second for listener to become ready
            let timeout = readySemaphore.wait(timeout: .now() + 1.0)
            if timeout == .timedOut {
                Logger.shared.error("[TESTSERVER] Listener failed to become ready within 1 second")
            } else {
                Logger.shared.info("[TESTSERVER] Listener is ready and accepting connections")
            }
        } catch {
            Logger.shared.error("[TESTSERVER] Failed to start - \(error.localizedDescription)")
        }
    }

    private func registerTests() {
        // Register storage test
        TestRegistry.shared.register(feature: "storage") {
            return testStorage()
        }

        Logger.shared.info("TestServer: Registered tests: storage")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let response = self?.handleRequest(request) ?? "Internal error"
            self?.sendResponse(connection, response)
        }
    }

    private func handleRequest(_ request: String) -> String {
        // Parse HTTP request line (e.g., "GET /test/ping HTTP/1.1")
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            Logger.shared.error("[TESTSERVER] Bad request - no first line")
            return httpResponse("Bad request", status: "400 Bad Request")
        }

        Logger.shared.info("[TESTSERVER] Request: \(firstLine)")

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            Logger.shared.error("[TESTSERVER] Method not allowed: \(parts[0])")
            return httpResponse("Method not allowed", status: "405 Method Not Allowed")
        }

        let path = parts[1]
        guard path.hasPrefix("/test/") else {
            Logger.shared.error("[TESTSERVER] Path not found: \(path)")
            return httpResponse("Not found", status: "404 Not Found")
        }

        let feature = String(path.dropFirst("/test/".count))
        Logger.shared.info("[TESTSERVER] Dispatching test for feature: \(feature)")
        let result = TestRegistry.shared.run(feature: feature)

        let message = result.success ? "succeeded" : "failed because \(result.error ?? "unknown error")"
        Logger.shared.info("[TESTSERVER] Sending response: \(message)")
        return httpResponse(message, status: "200 OK")
    }

    private func httpResponse(_ body: String, status: String) -> String {
        return """
        HTTP/1.1 \(status)
        Content-Type: text/plain
        Content-Length: \(body.utf8.count)
        Connection: close

        \(body)
        """
    }

    private func sendResponse(_ connection: NWConnection, _ response: String) {
        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
