# version-check iOS implementation

## Files

- `NoobTestApp.swift` - Version check on launch
- `UpdateRequiredView.swift` - Non-dismissable update modal

## NoobTestApp.swift

Add state variables:
```swift
@State private var requiresUpdate = false
@State private var testflightURL = ""
@State private var versionCheckComplete = false
```

Modify body to check version before showing main UI:
```swift
var body: some Scene {
    WindowGroup {
        if requiresUpdate {
            UpdateRequiredView(testflightURL: testflightURL)
        } else if !versionCheckComplete {
            ProgressView("Checking for updates...")
                .onAppear {
                    checkVersion()
                }
        } else if !isAuthenticated {
            SignInView(...)
        } else {
            ContentView()
        }
    }
}
```

Add version check function:
```swift
func checkVersion() {
    let serverURL = "http://185.96.221.52:8080"
    guard let url = URL(string: "\(serverURL)/api/version") else {
        versionCheckComplete = true
        return
    }

    let appBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0

    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serverBuild = json["latest_build"] as? Int,
               let tfURL = json["testflight_url"] as? String {

                Logger.shared.info("[VERSION] App build: \(appBuild), Server build: \(serverBuild)")

                if appBuild < serverBuild {
                    Logger.shared.info("[VERSION] Update required!")
                    testflightURL = tfURL
                    requiresUpdate = true
                }
            }
            versionCheckComplete = true
        }
    }.resume()
}
```

## UpdateRequiredView.swift

```swift
import SwiftUI

struct UpdateRequiredView: View {
    let testflightURL: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Update Available")
                .font(.title)
                .fontWeight(.bold)

            Text("A new version of microclub is available. Please update to continue.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: openTestFlight) {
                Text("Update Now")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    func openTestFlight() {
        if let url = URL(string: testflightURL) {
            UIApplication.shared.open(url)
        }
    }
}
```

## Key Implementation Details

- Build number from `Bundle.main.infoDictionary["CFBundleVersion"]`
- TestFlight URL opened via `UIApplication.shared.open(url)`
- Modal is non-dismissable by being the root view when `requiresUpdate` is true
- Shows loading spinner while checking version to avoid flash of content
