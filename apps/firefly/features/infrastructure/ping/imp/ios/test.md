# ping test (iOS)
*Swift implementation of ping connectivity test*

## Test function

```swift
func testPing() -> TestResult {
    let serverURL = "http://185.96.221.52:8080"
    guard let url = URL(string: "\(serverURL)/api/ping") else {
        return TestResult(success: false, error: "Invalid server URL")
    }

    var result = TestResult(success: false, error: "Timeout")
    let semaphore = DispatchSemaphore(value: 0)

    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            result = TestResult(success: false, error: "Connection failed: \(error.localizedDescription)")
            semaphore.signal()
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                result = TestResult(success: true)
            } else {
                result = TestResult(success: false, error: "Server returned status \(httpResponse.statusCode)")
            }
        }
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + 2.0)
    return result
}
```

## Registration

In ContentView init or app startup:
```swift
TestRegistry.shared.register(feature: "ping") {
    return testPing()
}
```
