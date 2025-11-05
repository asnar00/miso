import Foundation
import UIKit

// Post model matching server schema
struct Post: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let parentId: Int?
    var title: String
    var summary: String
    var body: String
    var imageUrl: String?
    let createdAt: String
    let timezone: String
    let locationTag: String?
    let aiGenerated: Bool
    let authorName: String?
    let authorEmail: String?
    let childCount: Int?
    let titlePlaceholder: String?
    let summaryPlaceholder: String?
    let bodyPlaceholder: String?

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
        case authorEmail = "author_email"
        case childCount = "child_count"
        case titlePlaceholder = "title_placeholder"
        case summaryPlaceholder = "summary_placeholder"
        case bodyPlaceholder = "body_placeholder"
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

struct ChildrenResponse: Codable {
    let status: String
    let postId: Int
    let children: [Post]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case status
        case postId = "post_id"
        case children
        case count
    }
}

struct ProfileResponse: Codable {
    let status: String
    let profile: Post?
}

struct ProfileCreateResponse: Codable {
    let status: String
    let profile: Post
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

    func createPost(title: String, summary: String, body: String, image: UIImage?, parentId: Int? = nil, completion: @escaping (Result<Post, Error>) -> Void) {
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

        Logger.shared.info("[PostsAPI] Creating new post: \(title) for user: \(email), parent: \(parentId?.description ?? "none")")

        // Get current timezone
        let timezone = TimeZone.current.identifier

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var requestBody = Data()

        // Add text fields (including email, timezone, and optional parent_id)
        var fields = [
            "email": email,
            "title": title,
            "summary": summary,
            "body": body,
            "timezone": timezone
        ]

        if let parentId = parentId {
            fields["parent_id"] = String(parentId)
        }

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

    // Fetch user's profile post
    func fetchUserProfile(userId: String, completion: @escaping (Result<Post?, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/users/\(userId)/profile") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        Logger.shared.info("[PostsAPI] Fetching profile for user \(userId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error fetching profile: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                Logger.shared.error("[PostsAPI] No data received")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                let profileResponse = try JSONDecoder().decode(ProfileResponse.self, from: data)
                Logger.shared.info("[PostsAPI] Successfully fetched profile")
                completion(.success(profileResponse.profile))
            } catch {
                Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    // Create a new profile post
    func createProfile(title: String, summary: String, body: String, image: UIImage?, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/users/profile/create") else {
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

        Logger.shared.info("[PostsAPI] Creating profile for user: \(email)")

        // Get current timezone
        let timezone = TimeZone.current.identifier

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var requestBody = Data()

        // Add text fields
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
            requestBody.append("Content-Disposition: form-data; name=\"image\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            requestBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            requestBody.append(imageData)
            requestBody.append("\r\n".data(using: .utf8)!)
        }

        requestBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = requestBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error creating profile: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                Logger.shared.error("[PostsAPI] No data received")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                let profileResponse = try JSONDecoder().decode(ProfileCreateResponse.self, from: data)
                Logger.shared.info("[PostsAPI] Successfully created profile")
                completion(.success(profileResponse.profile))
            } catch {
                Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.shared.error("[PostsAPI] Response: \(responseString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    // Update an existing post
    func updatePost(postId: Int, title: String, summary: String, body: String, image: UIImage?, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/posts/update") else {
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

        Logger.shared.info("[PostsAPI] Updating post \(postId) for user: \(email)")

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var requestBody = Data()

        // Add text fields
        let fields = [
            "post_id": String(postId),
            "email": email,
            "title": title,
            "summary": summary,
            "body": body
        ]

        for (key, value) in fields {
            requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            requestBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            requestBody.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add image if present
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            requestBody.append("Content-Disposition: form-data; name=\"image\"; filename=\"post.jpg\"\r\n".data(using: .utf8)!)
            requestBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            requestBody.append(imageData)
            requestBody.append("\r\n".data(using: .utf8)!)
        }

        requestBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = requestBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error updating post: \(error.localizedDescription)")
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
                Logger.shared.info("[PostsAPI] Successfully updated post")
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

    // Update an existing profile post
    func updateProfile(postId: Int, title: String, summary: String, body: String, image: UIImage?, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/users/profile/update") else {
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

        Logger.shared.info("[PostsAPI] Updating profile \(postId) for user: \(email)")

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var requestBody = Data()

        // Add text fields
        let fields = [
            "post_id": String(postId),
            "email": email,
            "title": title,
            "summary": summary,
            "body": body
        ]

        for (key, value) in fields {
            requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            requestBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            requestBody.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add image if present
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            requestBody.append("Content-Disposition: form-data; name=\"image\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
            requestBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            requestBody.append(imageData)
            requestBody.append("\r\n".data(using: .utf8)!)
        }

        requestBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = requestBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostsAPI] Error updating profile: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                Logger.shared.error("[PostsAPI] No data received")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                let profileResponse = try JSONDecoder().decode(ProfileCreateResponse.self, from: data)
                Logger.shared.info("[PostsAPI] Successfully updated profile")
                completion(.success(profileResponse.profile))
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
