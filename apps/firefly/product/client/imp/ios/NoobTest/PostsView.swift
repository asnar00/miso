import SwiftUI

struct PostsView: View {
    let onPostCreated: () -> Void

    @State private var posts: [Post]
    @State private var expandedPostId: Int? = nil
    @State private var showNewPostEditor = false

    let serverURL = "http://185.96.221.52:8080"

    init(posts: [Post], onPostCreated: @escaping () -> Void) {
        _posts = State(initialValue: posts)
        self.onPostCreated = onPostCreated
    }

    var body: some View {
        NavigationStack {
            postsContent
        }
        .navigationBarHidden(true)
    }

    var postsContent: some View {
        ZStack {
            Color(red: 128/255, green: 128/255, blue: 128/255)
                .ignoresSafeArea()

            VStack {
                if posts.isEmpty {
                    Text("No posts yet")
                        .foregroundColor(.black)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                // New post button at the top
                                NewPostButton {
                                    showNewPostEditor = true
                                }

                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: expandedPostId == post.id,
                                        onTap: {
                                            if expandedPostId == post.id {
                                                // Collapse currently expanded post
                                                expandedPostId = nil
                                            } else {
                                                // Expand new post and scroll to it
                                                expandedPostId = post.id
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo(post.id, anchor: .top)
                                                }
                                            }
                                        },
                                        onPostCreated: onPostCreated
                                    )
                                    .id(post.id)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: onPostCreated, parentId: nil)
        }
    }
}

#Preview {
    PostsView(posts: [], onPostCreated: {})
}
