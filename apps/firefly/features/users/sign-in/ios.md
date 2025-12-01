# sign-in iOS implementation
*client-side authentication UI for Firefly iOS app*

## File Structure

Create new file: `apps/firefly/product/client/imp/ios/NoobTest/SignInView.swift`

Modify existing: `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift`

## SignInView.swift

Complete implementation:

```swift
import SwiftUI

struct SignInView: View {
    // Server configuration
    let serverURL = "http://185.96.221.52:8080"

    // State management
    enum SignInState {
        case enterEmail
        case enterCode
    }

    @State private var currentState: SignInState = .enterEmail
    @State private var email: String = ""
    @State private var code: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @Binding var isAuthenticated: Bool
    @Binding var isNewUser: Bool

    var body: some View {
        ZStack {
            // Background color
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Logo
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: 80))
                    .foregroundColor(.black)
                    .padding(.bottom, 40)

                // Title
                Text("Welcome to Firefly")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                // Content based on state
                if currentState == .enterEmail {
                    emailEntryView
                } else {
                    codeEntryView
                }

                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding()

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
    }

    // Email entry view
    var emailEntryView: some View {
        VStack(spacing: 20) {
            Text("Enter your email address")
                .foregroundColor(.black)

            TextField("email@example.com", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(isLoading)

            Button(action: sendCode) {
                Text("Send Code")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .disabled(isLoading || email.isEmpty)
        }
        .padding()
    }

    // Code entry view
    var codeEntryView: some View {
        VStack(spacing: 20) {
            Text("Enter the 4-digit code")
                .foregroundColor(.black)

            Text("sent to \(email)")
                .font(.caption)
                .foregroundColor(.black.opacity(0.7))

            TextField("0000", text: $code)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .bold))
                .disabled(isLoading)
                .onChange(of: code) { newValue in
                    // Limit to 4 digits
                    if newValue.count > 4 {
                        code = String(newValue.prefix(4))
                    }
                }

            Button(action: verifyCode) {
                Text("Verify Code")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .disabled(isLoading || code.count != 4)

            Button(action: {
                currentState = .enterEmail
                code = ""
                errorMessage = ""
            }) {
                Text("Use different email")
                    .foregroundColor(.black)
            }
            .disabled(isLoading)
        }
        .padding()
    }

    // Send verification code
    func sendCode() {
        errorMessage = ""
        isLoading = true

        guard let url = URL(string: "\(serverURL)/api/auth/send-code") else {
            errorMessage = "Invalid server URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email.lowercased().trimmingCharacters(in: .whitespaces)]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Connection error: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? String else {
                    errorMessage = "Invalid response from server"
                    return
                }

                if status == "success" {
                    currentState = .enterCode
                    Logger.shared.info("[SignIn] Code sent to \(email)")
                } else {
                    errorMessage = json["message"] as? String ?? "Failed to send code"
                    Logger.shared.error("[SignIn] Failed to send code: \(errorMessage)")
                }
            }
        }.resume()
    }

    // Verify code
    func verifyCode() {
        errorMessage = ""
        isLoading = true

        guard let url = URL(string: "\(serverURL)/api/auth/verify-code") else {
            errorMessage = "Invalid server URL"
            isLoading = false
            return
        }

        let deviceID = Storage.shared.getDeviceID()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email.lowercased().trimmingCharacters(in: .whitespaces),
            "code": code,
            "device_id": deviceID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Connection error: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? String else {
                    errorMessage = "Invalid response from server"
                    return
                }

                if status == "success" {
                    // Check if this is a new user
                    let newUser = json["is_new_user"] as? Bool ?? false

                    // Save login state
                    Storage.shared.saveLoginState(email: email, isLoggedIn: true)
                    Logger.shared.info("[SignIn] User authenticated: \(email) (new_user: \(newUser))")

                    // Trigger authentication and set new user flag
                    isNewUser = newUser
                    isAuthenticated = true
                } else {
                    errorMessage = json["message"] as? String ?? "Verification failed"
                    Logger.shared.error("[SignIn] Verification failed: \(errorMessage)")
                }
            }
        }.resume()
    }
}
```

## NoobTestApp.swift

Modify to check authentication state and show appropriate view (three-state navigation):

```swift
import SwiftUI

@main
struct NoobTestApp: App {
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false

    init() {
        Logger.shared.info("[APP] NoobTestApp init() called")

        // Check login state on startup
        let (email, isLoggedIn) = Storage.shared.getLoginState()
        _isAuthenticated = State(initialValue: isLoggedIn && email != nil)

        if isLoggedIn && email != nil {
            Logger.shared.info("[APP] User already logged in: \(email!)")
            // Existing users have already seen welcome
            _hasSeenWelcome = State(initialValue: true)
        } else {
            Logger.shared.info("[APP] No user logged in, showing sign-in")
        }

        // Start test server
        Logger.shared.info("[APP] About to start TestServer")
        TestServer.shared.start()
        Logger.shared.info("[APP] TestServer.start() returned")
    }

    var body: some Scene {
        WindowGroup {
            if !isAuthenticated {
                SignInView(isAuthenticated: $isAuthenticated, isNewUser: $isNewUser)
            } else if isNewUser && !hasSeenWelcome {
                // Get email from storage for welcome screen
                let (email, _) = Storage.shared.getLoginState()
                NewUserView(email: email ?? "unknown", hasSeenWelcome: $hasSeenWelcome)
            } else {
                ContentView()
            }
        }
    }
}
```

## Adding to Xcode Project

Add SignInView.swift to the Xcode project by editing `NoobTest.xcodeproj/project.pbxproj`:

1. Find an existing Swift file entry (like ContentView.swift)
2. Copy the pattern and add new entries for SignInView.swift
3. Update file references and build phases

Or use the existing pattern from `miso/platforms/ios/project-editing.md`.

## Testing

### Test manually:
1. Build and deploy to device
2. Clear app data first: `Storage.shared.clearLoginState()`
3. Restart app - should show sign-in screen
4. Enter email address
5. Check email for code
6. Enter code
7. Should transition to main ContentView

### Add test:
```swift
// In TestServer.swift, register sign-in test
TestRegistry.shared.register(feature: "sign-in") {
    return testSignIn()
}

func testSignIn() -> TestResult {
    Logger.shared.info("[TEST:sign-in] Testing sign-in flow")

    // Test that Storage methods work
    Storage.shared.clearLoginState()
    let (email1, isLoggedIn1) = Storage.shared.getLoginState()
    guard email1 == nil && !isLoggedIn1 else {
        return TestResult(success: false, error: "Failed to clear login state")
    }

    Storage.shared.saveLoginState(email: "test@example.com", isLoggedIn: true)
    let (email2, isLoggedIn2) = Storage.shared.getLoginState()
    guard email2 == "test@example.com" && isLoggedIn2 else {
        return TestResult(success: false, error: "Failed to save login state")
    }

    Storage.shared.clearLoginState()
    Logger.shared.info("[TEST:sign-in] Login state management works")
    return TestResult(success: true)
}
```

## UI Design Notes

- Background: Turquoise (#40E0D0) matching existing app
- Logo: ᕦ(ツ)ᕤ at top
- Text fields: White background with rounded corners
- Buttons: Black background with white text
- Loading: Full-screen overlay with spinner
- Errors: Red text on white semi-transparent background
