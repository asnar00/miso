import SwiftUI

struct FloatingSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    @State private var isExpanded = false
    let onSearch: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        Group {
            if isExpanded {
                // Expanded search bar
                HStack(spacing: 12) {
                    // Search icon
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.white.opacity(0.6))
                        .font(.system(size: 18))

                    // Text field
                    TextField("Search posts...", text: $searchText, prompt: Text("Search posts...").foregroundColor(Color.white.opacity(0.6)))
                        .focused($isFocused)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .tint(.white)
                        .accessibilityIdentifier("search-field")
                        .onAppear {
                            UIAutomationRegistry.shared.registerTextField(id: "search-field") { text in
                                self.searchText = text
                            }
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            if !newValue.isEmpty {
                                // Debounce search
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if searchText == newValue {
                                        onSearch(newValue)
                                    }
                                }
                            } else {
                                onClear()
                            }
                        }

                    // Clear button
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            onClear()
                            isFocused = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 18))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(white: 0.05))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                )
                .frame(maxWidth: 600)
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                // Collapsed search button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
                    }
                    // Auto-focus the text field after expansion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color(white: 0.05))
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        )
                }
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .onChange(of: isFocused) { oldValue, newValue in
            // Collapse when unfocused and search is empty
            if !newValue && searchText.isEmpty {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
    }
}
