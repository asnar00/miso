import SwiftUI

enum ToolbarExplorer {
    case makePost, search, users
}

struct Toolbar: View {
    @Binding var currentExplorer: ToolbarExplorer

    var body: some View {
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
        .padding(.horizontal, 33)  // 10% more (was 30)
        .padding(.vertical, 14)     // 10% more (was 13)
        .background(
            Color(red: 0.7, green: 0.7, blue: 0.7)
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .frame(maxWidth: 300)       // Limit overall toolbar width
        .padding(.horizontal, 16)
        .offset(y: 12)              // Move up 4pt (was 16)
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
                    isActive ? Color.gray.opacity(0.5) : Color.clear  // 20% darker (was 0.3)
                )
                .cornerRadius(8)
        }
    }
}
