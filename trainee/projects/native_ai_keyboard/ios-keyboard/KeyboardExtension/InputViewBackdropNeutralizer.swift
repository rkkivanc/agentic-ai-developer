import UIKit

/// Adapts `UIInputView` chrome for solid tray (iOS ≤25) vs liquid-glass host card (iOS 26+).
enum InputViewBackdropNeutralizer {
    static func neutralize(in inputView: UIView, fillColor: UIColor, content: UIView) {
        if KeyboardHostChromePolicy.usesLiquidGlassHostCard {
            adaptForLiquidGlassHost(in: inputView, content: content)
        } else {
            adaptOpaqueTray(in: inputView, fillColor: fillColor, content: content)
        }
    }

    // MARK: - iOS 26+ (UIInputSetHostView rounded card)

    private static func adaptForLiquidGlassHost(in inputView: UIView, content: UIView) {
        inputView.isOpaque = false
        inputView.backgroundColor = .clear
        (inputView as? UIInputView)?.backgroundColor = .clear

        // Keep system backdrop siblings — they carry the host card material.
        inputView.bringSubviewToFront(content)

        content.isOpaque = false
        content.backgroundColor = .clear
    }

    // MARK: - iOS ≤25

    private static func adaptOpaqueTray(in inputView: UIView, fillColor: UIColor, content: UIView) {
        guard let inputView = inputView as? UIInputView else {
            paintOpaque(inputView, fillColor: fillColor)
            inputView.bringSubviewToFront(content)
            return
        }

        inputView.backgroundColor = fillColor
        paintOpaque(inputView, fillColor: fillColor)

        for subview in inputView.subviews where subview !== content {
            suppressSystemBackdropSubview(subview, fillColor: fillColor)
        }

        inputView.bringSubviewToFront(content)
        content.isOpaque = true
        content.backgroundColor = fillColor
    }

    private static func paintOpaque(_ view: UIView, fillColor: UIColor) {
        view.isOpaque = true
        view.backgroundColor = fillColor
    }

    private static func suppressSystemBackdropSubview(_ view: UIView, fillColor: UIColor) {
        let typeName = String(describing: type(of: view))
        let isBackdrop = view is UIVisualEffectView
            || typeName.localizedCaseInsensitiveContains("backdrop")

        guard isBackdrop else { return }

        view.isHidden = true
        view.alpha = 0
        view.isOpaque = true
        view.backgroundColor = fillColor
    }
}
