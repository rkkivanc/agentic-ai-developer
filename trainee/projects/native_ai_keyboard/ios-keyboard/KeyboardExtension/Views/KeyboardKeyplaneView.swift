import UIKit

/// Keyplane zone — Apple-style QWERTY / numbers rows (populated by `KeyboardLayoutView`).
final class KeyboardKeyplaneView: UIStackView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        axis = .vertical
        alignment = .fill
        distribution = .fillEqually
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = UIEdgeInsets(top: 10, left: 3, bottom: 3, right: 3)
        spacing = 6
    }

    func applyMetrics(_ metrics: AppleKeyboardMetrics.Resolved) {
        layoutMargins = UIEdgeInsets(
            top: metrics.topMargin,
            left: metrics.horizontalMargin,
            bottom: metrics.bottomMargin,
            right: metrics.horizontalMargin
        )
        spacing = metrics.rowGap
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
