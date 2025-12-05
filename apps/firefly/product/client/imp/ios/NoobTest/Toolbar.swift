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
    var showSearchBadge: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Make Post button
            ToolbarButton(icon: "bubble.left", isActive: currentExplorer == .makePost, showBadge: false) {
                if currentExplorer == .makePost {
                    onResetMakePost()
                } else {
                    currentExplorer = .makePost
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
            ToolbarButton(icon: "person.2", isActive: currentExplorer == .users, showBadge: false) {
                if currentExplorer == .users {
                    onResetUsers()
                } else {
                    currentExplorer = .users
                }
            }
        }
        .padding(.horizontal, 33)
        .padding(.vertical, 10)     // Reduced from 14 (75% height)
        .background(
            tunables.buttonColor()
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .frame(maxWidth: 300)       // Limit overall toolbar width
        .padding(.horizontal, 16)
        .offset(y: 16)              // Move up another 4pt
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
