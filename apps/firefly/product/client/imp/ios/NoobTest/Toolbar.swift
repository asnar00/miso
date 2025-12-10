import SwiftUI

enum ToolbarExplorer {
    case makePost, search, users
}

struct Toolbar: View {
    @Binding var currentExplorer: ToolbarExplorer
    @ObservedObject var tunables = TunableConstants.shared
    let onResetMakePost: () -> Void
    let onResetSearch: () -> Void
    let onResetUsers: () -> Void
    var showPostsBadge: Bool = false
    var showSearchBadge: Bool = false
    var showUsersBadge: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Make Post button
            ToolbarButton(icon: "bubble.left", isActive: currentExplorer == .makePost, showBadge: showPostsBadge) {
                if currentExplorer == .makePost {
                    onResetMakePost()
                } else {
                    currentExplorer = .makePost
                    onResetMakePost()  // Also clear badge when switching to posts tab
                }
            }

            Spacer()

            // Search button
            ToolbarButton(icon: "magnifyingglass", isActive: currentExplorer == .search, showBadge: showSearchBadge) {
                if currentExplorer == .search {
                    onResetSearch()
                } else {
                    currentExplorer = .search
                }
            }

            Spacer()

            // Users button
            ToolbarButton(icon: "person.2", isActive: currentExplorer == .users, showBadge: showUsersBadge) {
                if currentExplorer == .users {
                    onResetUsers()
                } else {
                    currentExplorer = .users
                    onResetUsers()  // Also clear badge when switching to users tab
                }
            }
        }
        .padding(.horizontal, 66)  // Increased to move outer buttons inward
        .padding(.vertical, 12)     // Match add post button height
        .background(
            tunables.buttonColor()
                .cornerRadius(12 * tunables.getDouble("corner-roundness", default: 1.0))
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 8 * tunables.getDouble("spacing", default: 1.0))  // Match posts padding
        .offset(y: 34)  // Push down to align bottom edge with screen bottom
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
    var showBadge: Bool = false
    let action: () -> Void
    @ObservedObject var tunables = TunableConstants.shared

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 35, height: 35)
                .background(
                    isActive ? tunables.buttonHighlightColor() : Color.clear
                )
                .cornerRadius(6)
                .overlay(alignment: .topTrailing) {
                    if showBadge {
                        Circle()
                            .fill(Color.red)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
        }
    }
}
