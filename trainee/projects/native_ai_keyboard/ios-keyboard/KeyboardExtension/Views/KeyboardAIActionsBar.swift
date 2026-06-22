import UIKit

/// AI action strip mounted above the Apple-style keyplane (Improve / Shorten / Expand + settings).
final class KeyboardAIActionsBar: UIView {
    let actionsRow = UIStackView()
    let trailingHost = UIStackView()
    private let bottomHairline = UIView()

    private let contentGuide = UILayoutGuide()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addLayoutGuide(contentGuide)
        NSLayoutConstraint.activate([
            contentGuide.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            contentGuide.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            contentGuide.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            contentGuide.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.distribution = .fill
        topRow.spacing = 0
        topRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topRow)

        actionsRow.axis = .horizontal
        actionsRow.spacing = 0
        actionsRow.alignment = .center
        actionsRow.distribution = .fillEqually

        trailingHost.axis = .horizontal
        trailingHost.alignment = .center
        trailingHost.distribution = .fill
        trailingHost.spacing = 4
        trailingHost.setContentHuggingPriority(.required, for: .horizontal)
        trailingHost.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        topRow.addArrangedSubview(actionsRow)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(trailingHost)

        bottomHairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomHairline)

        NSLayoutConstraint.activate([
            topRow.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            topRow.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            topRow.bottomAnchor.constraint(equalTo: bottomHairline.topAnchor, constant: -2),
            bottomHairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomHairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomHairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomHairline.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    func applyDividerAppearance(isDark: Bool) {
        bottomHairline.backgroundColor = isDark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.06)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
