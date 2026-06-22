import UIKit

/// Responsive keyboard height for `UIInputView` (see Apple: Configuring a Custom Keyboard Interface).
enum KeyboardPresentationLayout {
    private static weak var heightConstraint: NSLayoutConstraint?

    /// Design height scaled to current width and orientation.
    static func targetContentHeight(for width: CGFloat, isLandscape: Bool = false) -> CGFloat {
        let w = max(320, width > 1 ? width : 390)
        return AppleKeyboardMetrics.totalDesignHeight(for: w, isLandscape: isLandscape)
    }

    static func installHeightConstraint(on inputView: UIView, isLandscape: Bool = false) {
        guard heightConstraint == nil else {
            refreshHeightIfNeeded(for: inputView, isLandscape: isLandscape)
            return
        }
        let target = targetContentHeight(for: inputView.bounds.width, isLandscape: isLandscape)
        let c = inputView.heightAnchor.constraint(equalToConstant: target)
        c.priority = UILayoutPriority(999)
        c.isActive = true
        heightConstraint = c
    }

    static func refreshHeightIfNeeded(for inputView: UIView, isLandscape: Bool = false) {
        guard let hc = heightConstraint else { return }
        let target = targetContentHeight(for: inputView.bounds.width, isLandscape: isLandscape)
        guard abs(hc.constant - target) > 0.5 else { return }
        hc.constant = target
    }
}
