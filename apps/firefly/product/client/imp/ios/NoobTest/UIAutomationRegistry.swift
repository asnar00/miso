import Foundation
import SwiftUI

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

// SwiftUI view modifier to make any view UI-automatable
struct UIAutomationModifier: ViewModifier {
    let id: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onAppear {
            UIAutomationRegistry.shared.register(id: id, action: action)
        }
    }
}

extension View {
    func uiAutomationId(_ id: String, action: @escaping () -> Void) -> some View {
        self.modifier(UIAutomationModifier(id: id, action: action))
    }
}
