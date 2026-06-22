import UIKit

/// Letter key with Apple-style cap rendering (replaces flat `LetterKeyControl`).
final class AppleLetterKeyControl: UIControl {
    let baseLetter: Character

    private let capView = KeyCapBackgroundView()
    private let titleLabel = UILabel()
    private var normalFill: UIColor = .white
    private var pressedFill: UIColor = .lightGray
    private var textColor: UIColor = .black
    private var cornerRadius: CGFloat = 5
    private var shadowOpacity: Float = 0.35
    private(set) var displaysUppercase = false

    init(letter: Character, metrics: AppleKeyboardMetrics.Resolved) {
        self.baseLetter = Character(String(letter).lowercased())
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityIdentifier = "kb_\(baseLetter)"
        accessibilityTraits = .button
        applyMetrics(metrics)

        capView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capView)

        titleLabel.font = .systemFont(ofSize: metrics.letterFontSize, weight: .regular)
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            capView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capView.trailingAnchor.constraint(equalTo: trailingAnchor),
            capView.topAnchor.constraint(equalTo: topAnchor),
            capView.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        updateTitle()
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyMetrics(_ metrics: AppleKeyboardMetrics.Resolved) {
        cornerRadius = metrics.cornerRadius
        shadowOpacity = metrics.keyShadowOpacity
        titleLabel.font = .systemFont(ofSize: metrics.letterFontSize, weight: .regular)
        refreshCapStyle()
    }

    func applyCaps(uppercase: Bool) {
        displaysUppercase = uppercase
        updateTitle()
    }

    func applyColors(normal: UIColor, pressed: UIColor, text: UIColor) {
        normalFill = normal
        pressedFill = pressed
        textColor = text
        titleLabel.textColor = text
        refreshCapStyle()
    }

    private func refreshCapStyle() {
        capView.capStyle = KeyCapRenderer.Style(
            fill: normalFill,
            pressedFill: pressedFill,
            cornerRadius: cornerRadius,
            shadowOpacity: shadowOpacity
        )
        capView.isPressed = isHighlighted
        capView.setNeedsDisplay()
    }

    @objc private func touchDown() {
        isHighlighted = true
        capView.isPressed = true
    }

    @objc private func touchUp() {
        isHighlighted = false
        capView.isPressed = false
    }

    private func updateTitle() {
        let letter = String(baseLetter)
        titleLabel.text = displaysUppercase ? letter.uppercased() : letter
        accessibilityLabel = titleLabel.text
    }
}
