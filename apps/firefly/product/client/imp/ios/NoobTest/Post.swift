import Foundation
import UIKit

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
    let authorName: String?

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
        case authorName = "author_name"
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

    func createPost(title: String, summary: String, body: String, image: UIImage?, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/posts/create") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        // Get user email
        let loginState = Storage.shared.getLoginState()
        guard let email = loginState.email, loginState.isLoggedIn else {
            Logger.shared.error("[PostsAPI] User not logged in")
            completion(.failure(NSError(domain: "Not authenticated", code: 401)))
            return
        }

        Logger.shared.info("[PostsAPI] Creating new post: \(title) for user: \(email)")

        // Get current timezone
        let timezone = TimeZone.current.identifier

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var requestBody = Data()

        // Add text fields (including email and timezone)
        let fields = [
            "email": email,
            "title": title,
            "summary": summary,
            "body": body,
            "timezone": timezone
        ]

        for (key, value) in fields {
            requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            requestBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            requestBody.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add image if present
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            requestBody.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            requestBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            requestBody.append(imageData)
            requestBody.append("\r\n".data(using: .utf8)!)
        }

        requestBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = requestBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error creating post: \(error.localizedDescription)")
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
                Logger.shared.info("[PostsAPI] Successfully created post")
                completion(.success(postResponse.post))
            } catch {
                Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.shared.error("[PostsAPI] Response: \(responseString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
}
