import Foundation

class UIAutomationRegistry {
    static let shared = UIAutomationRegistry()

    private var elements: [String: () -> Void] = [:]
    private let queue = DispatchQueue(label: "com.miso.ui-automation", attributes: .concurrent)

    private init() {}

    func register(id: String, action: @escaping () -> Void) {
        queue.async(flags: .barrier) {
            self.elements[id] = action
        }
    }

    func trigger(id: String) -> Bool {
        var action: (() -> Void)?

        queue.sync {
            action = elements[id]
        }

        guard let action = action else {
            return false
        }

        // Execute on main thread
        DispatchQueue.main.async {
            action()
        }

        return true
    }

    func listElements() -> [String] {
        var keys: [String] = []
        queue.sync {
            keys = Array(elements.keys)
        }
        return keys.sorted()
    }
}
