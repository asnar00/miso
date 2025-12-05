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
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background color
            Color(red: 255/255, green: 178/255, blue: 127/255)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Logo
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: 40))
                    .foregroundColor(.black)
                    .padding(.top, 30)  // Move down by ~75% of height
                    .padding(.bottom, 40)

                // Title
                Text("welcome to microclub.")
                    .font(.title)
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
            Text("please enter your email address:")
                .foregroundColor(.black)

            TextField("", text: $email, prompt: Text("email@example.com").foregroundStyle(Color(red: 180/255, green: 140/255, blue: 110/255)))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .tint(.white)  // White cursor
                .disabled(isLoading)
                .onAppear {
                    UIAutomationRegistry.shared.registerTextField(id: "signin-email") { text in
                        self.email = text
                    }
                }

            Button(action: sendCode) {
                Text("log in")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .disabled(isLoading || email.isEmpty)
            .onAppear {
                UIAutomationRegistry.shared.register(id: "signin-login") {
                    self.sendCode()
                }
            }
        }
        .padding()
    }

    // Code entry view
    var codeEntryView: some View {
        VStack(spacing: 20) {
            Text("enter the 4-digit code")
                .foregroundColor(.black)

            Text("sent to \(email)")
                .foregroundColor(.black.opacity(0.7))

            // Four separate digit boxes with hidden text field
            ZStack {
                // Hidden text field that receives input
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .focused($isCodeFieldFocused)
                    .opacity(0.001)
                    .onChange(of: code) { newValue in
                        // Limit to 4 digits only
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 4 {
                            code = String(filtered.prefix(4))
                        } else if filtered != newValue {
                            code = filtered
                        }
                    }
                    .onAppear {
                        UIAutomationRegistry.shared.registerTextField(id: "signin-code") { text in
                            self.code = String(text.prefix(4).filter { $0.isNumber })
                        }
                    }

                // Visual digit boxes
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        let digit = index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
                        Text(digit)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 50, height: 60)
                            .background(Color(red: 240/255, green: 160/255, blue: 110/255))  // Darker peach
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isCodeFieldFocused && index == code.count ? Color.black : Color.black.opacity(0.3), lineWidth: isCodeFieldFocused && index == code.count ? 2 : 1)
                            )
                    }
                }
            }
            .onTapGesture {
                isCodeFieldFocused = true
            }
            .onAppear {
                // Auto-focus when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCodeFieldFocused = true
                }
            }

            Button(action: verifyCode) {
                Text("verify")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .disabled(isLoading || code.count != 4)
            .onAppear {
                UIAutomationRegistry.shared.register(id: "signin-verify") {
                    self.verifyCode()
                }
            }

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
                    let userId = json["user_id"] as? Int ?? 0
                    let userName = json["name"] as? String ?? ""

                    // Save login state including name
                    Storage.shared.saveLoginState(email: email, userId: userId, name: userName, isLoggedIn: true)
                    Logger.shared.info("[SignIn] User authenticated: \(email) (ID: \(userId), name: \(userName), new_user: \(newUser))")

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
