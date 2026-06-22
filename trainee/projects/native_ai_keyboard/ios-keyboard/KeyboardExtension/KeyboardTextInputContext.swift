import UIKit

/// Maps `UITextDocumentProxy` traits to keyboard UI decisions (Apple: Configuring a Custom Keyboard Interface).
enum KeyboardTextInputContext {
    struct Snapshot: Equatable {
        let keyboardType: UIKeyboardType
        let returnKeyType: UIReturnKeyType
        let autocapitalizationType: UITextAutocapitalizationType
        let isSecure: Bool
    }

    static func snapshot(from proxy: UITextDocumentProxy) -> Snapshot {
        Snapshot(
            keyboardType: proxy.keyboardType ?? .default,
            returnKeyType: proxy.returnKeyType ?? .default,
            autocapitalizationType: proxy.autocapitalizationType ?? .sentences,
            isSecure: proxy.isSecureTextEntry ?? false
        )
    }

    /// Whether the return key label should reflect the current field (email search, etc.).
    static func prefersEmailLayout(_ snapshot: Snapshot) -> Bool {
        snapshot.keyboardType == .emailAddress
    }

    static func prefersURLLayout(_ snapshot: Snapshot) -> Bool {
        snapshot.keyboardType == .URL
    }
}
