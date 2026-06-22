import UIKit

/// Toolbar zone — hosts `KeyboardAIActionsBar` (AI cluster + trailing chrome controls).
final class KeyboardToolbarView: UIView {
    let aiBar = KeyboardAIActionsBar()
    var actionsRow: UIStackView { aiBar.actionsRow }
    var plusButtonHost: UIStackView { aiBar.trailingHost }

    override init(frame: CGRect) {
        super.init(frame: frame)
        aiBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(aiBar)
        NSLayoutConstraint.activate([
            aiBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            aiBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            aiBar.topAnchor.constraint(equalTo: topAnchor),
            aiBar.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func applyDividerAppearance(isDark: Bool) {
        aiBar.applyDividerAppearance(isDark: isDark)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
