import SwiftUI

enum ToolbarTab {
    case home, post, search, profile
}

struct Toolbar: View {
    @Binding var navigationPath: [Int]
    @Binding var activeTab: ToolbarTab
    let onPostButtonTap: () -> Void
    let onSearchButtonTap: () -> Void
    let onProfileButtonTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Home button
                ToolbarButton(icon: "house", isActive: activeTab == .home) {
                    activeTab = .home
                    navigationPath = []
                }

                Spacer()

                // Post button
                ToolbarButton(icon: "plus", isActive: activeTab == .post) {
                    activeTab = .post
                    onPostButtonTap()
                }

                Spacer()

                // Search button
                ToolbarButton(icon: "magnifyingglass", isActive: activeTab == .search) {
                    activeTab = .search
                    onSearchButtonTap()
                }

                Spacer()

                // Profile button
                ToolbarButton(icon: "person", isActive: activeTab == .profile) {
                    activeTab = .profile
                    onProfileButtonTap()
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 15)  // Move buttons down 15pt
            .frame(height: 50)  // Toolbar height

            // Spacer to extend background to bottom
            Spacer()
                .frame(height: 0)
        }
        .background(
            Color.white.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(radius: 2)
        .onAppear {
            // Register toolbar buttons with UI automation
            UIAutomationRegistry.shared.register(id: "toolbar-home") {
                activeTab = .home
                navigationPath = []
            }

            UIAutomationRegistry.shared.register(id: "toolbar-plus") {
                activeTab = .post
                onPostButtonTap()
            }

            UIAutomationRegistry.shared.register(id: "toolbar-search") {
                activeTab = .search
                onSearchButtonTap()
            }

            UIAutomationRegistry.shared.register(id: "toolbar-profile") {
                activeTab = .profile
                onProfileButtonTap()
            }
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(
                    isActive ? Color.gray.opacity(0.3) : Color.clear
                )
                .cornerRadius(8)
        }
    }
}
