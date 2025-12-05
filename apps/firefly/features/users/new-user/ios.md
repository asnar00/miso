# new-user iOS implementation
*welcome screen for first-time users*

## File: NewUserView.swift

Path: `apps/firefly/product/client/imp/ios/NoobTest/NewUserView.swift`

```swift
import SwiftUI

struct NewUserView: View {
    let name: String
    let email: String
    @Binding var hasSeenWelcome: Bool
    @Binding var shouldEditProfile: Bool

    var body: some View {
        ZStack {
            // Background color - orange/peach
            Color(red: 255/255, green: 178/255, blue: 127/255)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo - smaller than sign-in screen
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: 50))
                    .foregroundColor(.black)
                    .padding(.top, 38)

                // Welcome text with name
                VStack(spacing: 8) {
                    Text("welcome")
                        .font(.largeTitle)
                        .foregroundColor(.black)
                    Text("\(name)!")
                        .font(.largeTitle)
                        .foregroundColor(.black)
                }

                Spacer()

                // Get Started button
                Button(action: {
                    getStarted()
                }) {
                    Text("get started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .onAppear {
                    UIAutomationRegistry.shared.register(id: "newuser-getstarted") {
                        self.getStarted()
                    }
                }
            }
        }
    }

    func getStarted() {
        shouldEditProfile = true
        hasSeenWelcome = true
    }
}
```

## Integration in NoobTestApp.swift

The app-level navigation shows NewUserView between sign-in and main content:

```swift
// In NoobTestApp.swift body
if !isAuthenticated {
    SignInView(...)
} else if isNewUser && !hasSeenWelcome {
    NewUserView(
        name: userName,
        email: userEmail,
        hasSeenWelcome: $hasSeenWelcome,
        shouldEditProfile: $shouldEditProfile
    )
} else {
    ContentView(shouldEditProfile: $shouldEditProfile)
}
```

## ContentView Profile Editing Trigger

ContentView receives `shouldEditProfile` and triggers the profile editor:

```swift
// In ContentView
@Binding var shouldEditProfile: Bool
@State private var editingNewUserProfile = false

.onAppear {
    if shouldEditProfile {
        currentExplorer = .users
        editingNewUserProfile = true
        shouldEditProfile = false
    }
    // ... fetch data
}

// Users PostsView receives the binding
PostsView(..., editCurrentUserProfile: $editingNewUserProfile)
```

## PostsListView Profile Edit Handling

PostsListView must check `editCurrentUserProfile` in **both** onAppear and onChange:

```swift
// In PostsListView
@Binding var editCurrentUserProfile: Bool

.onAppear {
    // ... setup code ...

    if !initialPosts.isEmpty {
        posts = initialPosts
        isLoading = false

        // Check on initial load (value may already be true)
        if editCurrentUserProfile {
            triggerEditCurrentUserProfile()
        }
    }
}

.onChange(of: editCurrentUserProfile) { oldValue, newValue in
    // Check on value change (for later triggers)
    if newValue && !posts.isEmpty {
        triggerEditCurrentUserProfile()
    }
}

func triggerEditCurrentUserProfile() {
    let loginState = Storage.shared.getLoginState()
    guard let userEmail = loginState.email else {
        editCurrentUserProfile = false
        return
    }

    // Find current user's profile post
    if let profilePost = posts.first(where: {
        $0.authorEmail?.lowercased() == userEmail.lowercased() &&
        $0.template == "profile"
    }) {
        viewModel.expandedPostId = profilePost.id
        editingPostId = profilePost.id
        isAnyPostEditing = true
    }

    editCurrentUserProfile = false
}
```

## Why Both Checks Are Needed

The timing issue:
1. NewUserView sets `shouldEditProfile = true`
2. ContentView.onAppear runs, sets `editingNewUserProfile = true`
3. ContentView starts fetching users data (async)
4. While loading, PostsListView doesn't exist yet
5. When data loads, PostsListView is created with `editCurrentUserProfile` already `true`
6. `onChange` never fires because the value didn't change after the view appeared
7. Therefore `onAppear` must also check and call `triggerEditCurrentUserProfile()`

## Testing

Use the `reproduce.sh` script to test the full flow:
1. Clears Henry's profile content
2. Resets Henry's device IDs
3. Logs out and restarts app
4. Runs through sign-in with automation
5. Taps "get started"
6. Verifies profile editor opens automatically
