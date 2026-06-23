import UIKit

/// Text input + rewrite apply helpers (extracted from the keyboard controller).
struct KeyboardActionService {
    let proxy: UITextDocumentProxy

    func insertString(_ s: String) {
        proxy.insertText(s)
    }

    func deleteBackward() {
        proxy.deleteBackward()
    }

    func rewriteContext(fallbackText: String? = nil) -> (text: String, snapshot: RewriteSnapshot) {
        let result = readRewriteContextFromProxy()
        if !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return result
        }

        let fallback = fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !fallback.isEmpty else { return result }

        return (
            fallbackText ?? "",
            RewriteSnapshot(
                usesSelection: false,
                utf16Before: KeyboardTextReplacement.utf16Length(fallback),
                utf16After: 0,
                replaceWholeDocumentPreferred: true
            )
        )
    }

    func readRewriteContextFromProxy() -> (text: String, snapshot: RewriteSnapshot) {
        if let input = proxy as? UITextInput,
           let selected = input.selectedTextRange,
           input.offset(from: selected.start, to: selected.end) > 0,
           let selectedText = input.text(in: selected),
           !selectedText.isEmpty
        {
            return (
                selectedText,
                RewriteSnapshot(usesSelection: true, utf16Before: 0, utf16After: 0, replaceWholeDocumentPreferred: false)
            )
        }

        if let sel = proxy.selectedText, !sel.isEmpty {
            return (
                sel,
                RewriteSnapshot(usesSelection: true, utf16Before: 0, utf16After: 0, replaceWholeDocumentPreferred: false)
            )
        }

        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        let split = before + after
        let uBefore = KeyboardTextReplacement.utf16Length(before)
        let uAfter = KeyboardTextReplacement.utf16Length(after)

        if let input = proxy as? UITextInput {
            let start = input.beginningOfDocument
            let end = input.endOfDocument
            if let range = input.textRange(from: start, to: end), let whole = input.text(in: range) {
                let text: String
                let useFullReplace: Bool
                if !whole.isEmpty {
                    text = whole
                    useFullReplace = true
                } else if !split.isEmpty {
                    text = split
                    useFullReplace = false
                } else {
                    text = ""
                    useFullReplace = false
                }
                return (
                    text,
                    RewriteSnapshot(
                        usesSelection: false,
                        utf16Before: uBefore,
                        utf16After: uAfter,
                        replaceWholeDocumentPreferred: useFullReplace
                    )
                )
            }
        }

        return (
            split,
            RewriteSnapshot(usesSelection: false, utf16Before: uBefore, utf16After: uAfter, replaceWholeDocumentPreferred: false)
        )
    }

    /// Best available text at button press — keyboard taps often clear selection before async work runs.
    static func mergeRewriteContexts(
        touchDown: (text: String, snapshot: RewriteSnapshot)?,
        live: (text: String, snapshot: RewriteSnapshot)
    ) -> (text: String, snapshot: RewriteSnapshot) {
        let touchTrim = touchDown?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let liveTrim = live.0.trimmingCharacters(in: .whitespacesAndNewlines)
        if !touchTrim.isEmpty, let td = touchDown {
            if liveTrim.count > touchTrim.count { return live }
            return (td.text, td.snapshot)
        }
        if !liveTrim.isEmpty { return live }
        if let td = touchDown, !touchTrim.isEmpty { return (td.text, td.snapshot) }
        return live
    }

    func applyRewrite(result: String, snapshot: RewriteSnapshot) {
        if snapshot.usesSelection {
            if let input = proxy as? UITextInput,
               let selected = input.selectedTextRange,
               input.offset(from: selected.start, to: selected.end) != 0
            {
                input.replace(selected, withText: result)
                return
            }
        } else if let input = proxy as? UITextInput {
            let start = input.beginningOfDocument
            let end = input.endOfDocument
            if let range = input.textRange(from: start, to: end) {
                input.replace(range, withText: result)
                return
            }
        }

        if snapshot.usesSelection {
            let len = KeyboardTextReplacement.utf16Length(proxy.selectedText ?? "")
            if len > 0 {
                for _ in 0 ..< len { proxy.deleteBackward() }
                proxy.insertText(result)
            } else {
                proxy.insertText(result)
            }
            return
        }

        for _ in 0 ..< snapshot.utf16Before { proxy.deleteBackward() }
        if snapshot.utf16After > 0 {
            proxy.adjustTextPosition(byCharacterOffset: snapshot.utf16After)
            for _ in 0 ..< snapshot.utf16After { proxy.deleteBackward() }
        }
        proxy.insertText(result)
    }
}
