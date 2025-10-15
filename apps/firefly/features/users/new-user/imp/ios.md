# new-user iOS implementation
*welcome screen for first-time users*

## File Structure

Create new file: `apps/firefly/product/client/imp/ios/NoobTest/NewUserView.swift`

## NewUserView.swift

Complete implementation:

```swift
import SwiftUI

struct NewUserView: View {
    let email: String
    @Binding var hasSeenWelcome: Bool

    var body: some View {
        ZStack {
            // Background color
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: 100))
                    .foregroundColor(.black)

                // Welcome text
                Text("welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                // User email
                Text(email)
                    .font(.title3)
                    .foregroundColor(.black.opacity(0.8))

                Spacer()

                // Get Started button
                Button(action: {
                    hasSeenWelcome = true
                    Logger.shared.info("[NewUser] User tapped Get Started")
                }) {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}
```

## Integration

This view is shown after sign-in when `isNewUser` is true and `hasSeenWelcome` is false.

See `sign-in/imp/ios.md` for the complete NoobTestApp.swift implementation showing the three-state navigation:
1. Not authenticated → SignInView
2. Authenticated + new user + hasn't seen welcome → NewUserView
3. Authenticated (or has seen welcome) → ContentView

## Adding to Xcode Project

Add NewUserView.swift to the Xcode project by editing `NoobTest.xcodeproj/project.pbxproj`:

1. Find an existing Swift file entry (like ContentView.swift)
2. Copy the pattern and add new entries for NewUserView.swift
3. Update file references and build phases

Or use the existing pattern from `miso/platforms/ios/project-editing.md`.

## Testing

### Manual test:
1. Clear login state: `curl http://localhost:8081/test/clear-login` (requires USB forwarding)
2. Restart app
3. Sign in with a new email address (one not in the database)
4. After entering the verification code, should see welcome screen
5. Tap "Get Started"
6. Should transition to main ContentView
7. If you sign out and sign in again with the same account, you won't see the welcome screen (device already registered)

## UI Design Notes

- Background: Turquoise (#40E0D0) matching existing app
- Logo: ᕦ(ツ)ᕤ larger than sign-in (size 100)
- Welcome text: Large title, bold, black
- Email: Smaller, slightly transparent black
- Button: Black background with white text, full width with padding
- Centered layout with generous spacing
