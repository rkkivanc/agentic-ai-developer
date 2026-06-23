import UIKit

/// Tracks compose text when `UITextDocumentProxy` cannot read the field (common in Messages).
final class KeyboardComposeTracker {
    private var draft = ""

    var fallbackText: String { draft }

    func reset() {
        draft = ""
    }

    func setText(_ text: String) {
        draft = text
    }

    func noteInsertion(_ text: String) {
        guard !text.isEmpty else { return }
        draft.append(contentsOf: text)
    }

    func noteDeleteBackward() {
        guard !draft.isEmpty else { return }
        draft.removeLast()
    }

    func reconcile(proxyText: String) {
        guard !proxyText.isEmpty else { return }
        if proxyText.count >= draft.count || draft.isEmpty || proxyText.hasSuffix(draft) || draft.hasSuffix(proxyText) {
            draft = proxyText
        }
    }

    func noteProxyBecameExplicitlyEmpty(_ proxy: UITextDocumentProxy) {
        let before = proxy.documentContextBeforeInput
        let after = proxy.documentContextAfterInput
        let selected = proxy.selectedText ?? ""
        guard before != nil || after != nil else { return }
        if before == "", after == "", selected.isEmpty {
            draft = ""
        }
    }

    func fallbackSnapshot(for text: String) -> RewriteSnapshot {
        RewriteSnapshot(
            usesSelection: false,
            utf16Before: KeyboardTextReplacement.utf16Length(text),
            utf16After: 0,
            replaceWholeDocumentPreferred: true
        )
    }
}
