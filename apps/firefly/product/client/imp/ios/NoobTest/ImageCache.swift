import UIKit

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func get(_ url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }

    func set(_ url: String, image: UIImage) {
        cache.setObject(image, forKey: url as NSString)
    }

    func preload(urls: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }

            // Skip if already cached
            if get(urlString) != nil {
                continue
            }

            group.enter()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                defer { group.leave() }

                guard let data = data,
                      let image = UIImage(data: data) else {
                    return
                }

                self?.set(urlString, image: image)
            }.resume()
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}
