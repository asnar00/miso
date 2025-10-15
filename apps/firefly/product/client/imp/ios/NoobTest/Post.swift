import Foundation

// Post model matching server schema
struct Post: Codable, Identifiable {
    let id: Int
    let userId: Int
    let parentId: Int?
    let title: String
    let summary: String
    let body: String
    let imageUrl: String?
    let createdAt: String
    let timezone: String
    let locationTag: String?
    let aiGenerated: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case parentId = "parent_id"
        case title
        case summary
        case body
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case timezone
        case locationTag = "location_tag"
        case aiGenerated = "ai_generated"
    }
}

// API response structures
struct PostsResponse: Codable {
    let status: String
    let posts: [Post]
}

struct SinglePostResponse: Codable {
    let status: String
    let post: Post
}

// API client for posts
class PostsAPI {
    static let shared = PostsAPI()
    let serverURL = "http://185.96.221.52:8080"

    func fetchRecentPosts(limit: Int = 50, completion: @escaping (Result<[Post], Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/posts/recent?limit=\(limit)") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        Logger.shared.info("[PostsAPI] Fetching recent posts (limit: \(limit))")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error fetching posts: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                Logger.shared.error("[PostsAPI] No data received")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                let postsResponse = try JSONDecoder().decode(PostsResponse.self, from: data)
                Logger.shared.info("[PostsAPI] Successfully fetched \(postsResponse.posts.count) posts")
                completion(.success(postsResponse.posts))
            } catch {
                Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchPost(id: Int, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/posts/\(id)") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        Logger.shared.info("[PostsAPI] Fetching post \(id)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error fetching post: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                Logger.shared.error("[PostsAPI] No data received")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                Logger.shared.info("[PostsAPI] Successfully fetched post \(id)")
                completion(.success(postResponse.post))
            } catch {
                Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
}
