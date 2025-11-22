import Foundation
import Combine

/// Global singleton that broadcasts post deletion events to all views
class PostDeletionNotifier: ObservableObject {
    static let shared = PostDeletionNotifier()

    /// Published property that emits the ID of deleted posts
    @Published var deletedPostId: Int? = nil

    private init() {}

    /// Call this when a post is deleted to notify all observers
    func notifyPostDeleted(_ postId: Int) {
        Logger.shared.info("[PostDeletionNotifier] Broadcasting deletion of post \(postId)")
        DispatchQueue.main.async {
            self.deletedPostId = postId
        }
    }
}
