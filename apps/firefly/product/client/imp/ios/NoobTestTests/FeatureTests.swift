//
//  FeatureTests.swift
//  NoobTestTests
//
//  Generated feature tests for Firefly iOS client
//  Auto-generated from feature test specifications
//

import XCTest

class FeatureTests: XCTestCase {

    // ========================================================================
    // MARK: - Feature: ping
    // ========================================================================

    // Test 1: Server Responds to Ping
    func test_ping_serverResponds() {
        let serverURL = "http://192.168.1.76:8080"
        let expectation = XCTestExpectation(description: "Server responds to ping")

        guard let url = URL(string: "\(serverURL)/api/ping") else {
            XCTFail("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            // Verify no error
            XCTAssertNil(error, "Request should not error")

            // Verify HTTP 200
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200, "Should return 200 OK")
            } else {
                XCTFail("Response should be HTTP response")
            }

            // Verify JSON contains "status": "ok"
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        XCTAssertEqual(json["status"] as? String, "ok", "Status should be 'ok'")
                    }
                } catch {
                    XCTFail("Failed to parse JSON: \(error)")
                }
            }

            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // Test 2: Client Detects Server Running
    func test_ping_detectsServerRunning() {
        let serverURL = "http://192.168.1.76:8080"
        let expectation = XCTestExpectation(description: "Detects server running")

        guard let url = URL(string: "\(serverURL)/api/ping") else {
            XCTFail("Invalid URL")
            return
        }

        var connectionSuccess = false

        URLSession.shared.dataTask(with: url) { data, response, error in
            if error == nil,
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                connectionSuccess = true
            }

            XCTAssertTrue(connectionSuccess, "Should detect server is running")
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // Test 3: Client Detects Server Down
    func test_ping_detectsServerDown() {
        // Use invalid port to simulate server down
        let invalidURL = "http://192.168.1.76:9999"
        let expectation = XCTestExpectation(description: "Detects server down")

        guard let url = URL(string: "\(invalidURL)/api/ping") else {
            XCTFail("Invalid URL")
            return
        }

        var connectionFailed = false

        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                connectionFailed = true
            } else if let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode != 200 {
                connectionFailed = true
            }

            XCTAssertTrue(connectionFailed, "Should detect server is down")
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // ========================================================================
    // MARK: - Test Runner
    // ========================================================================

    func test_all() {
        print("\n" + String(repeating: "=", count: 60))
        print("Running all feature tests...")
        print(String(repeating: "=", count: 60))

        print("\n[Feature: ping]")
        test_ping_serverResponds()
        test_ping_detectsServerRunning()
        test_ping_detectsServerDown()

        print("\n" + String(repeating: "=", count: 60))
        print("All tests completed!")
        print(String(repeating: "=", count: 60))
    }
}
