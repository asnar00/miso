import SwiftUI

enum ToolbarExplorer {
    case makePost, search, users
}

struct Toolbar: View {
    @Binding var currentExplorer: ToolbarExplorer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Make Post button
                ToolbarButton(icon: "bubble.left", isActive: currentExplorer == .makePost) {
                    currentExplorer = .makePost
                }

                Spacer()

                // Search button
                ToolbarButton(icon: "magnifyingglass", isActive: currentExplorer == .search) {
                    currentExplorer = .search
                }

                Spacer()

                // Users button
                ToolbarButton(icon: "person.2", isActive: currentExplorer == .users) {
                    currentExplorer = .users
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
            UIAutomationRegistry.shared.register(id: "toolbar-makepost") {
                currentExplorer = .makePost
            }

            UIAutomationRegistry.shared.register(id: "toolbar-search") {
                currentExplorer = .search
            }

            UIAutomationRegistry.shared.register(id: "toolbar-users") {
                currentExplorer = .users
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
