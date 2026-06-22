import UIKit

/// Functional / return / space key with Apple-style cap rendering.
final class AppleKeyButton: UIControl {
    enum Kind {
        case letter
        case functional
        case returnKey
    }

    let kind: Kind
    var titleText: String? {
        didSet {
            titleLabel.text = titleText
            titleLabel.isHidden = titleText == nil
            refreshTitleFont()
        }
    }
    var symbolName: String? {
        didSet { updateSymbol() }
    }
    var symbolPointSize: CGFloat = 16 {
        didSet { updateSymbol() }
    }
    var outputValue: String?
    var titleFontSizeOverride: CGFloat?

    private let capView = KeyCapBackgroundView()
    private let titleLabel = UILabel()
    private let symbolView = UIImageView()
    private var normalFill: UIColor = .white
    private var pressedFill: UIColor = .lightGray
    private var textColor: UIColor = .black
    private var cornerRadius: CGFloat = 5
    private var shadowOpacity: Float = 0.35

    init(kind: Kind, metrics: AppleKeyboardMetrics.Resolved) {
        self.kind = kind
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        applyMetrics(metrics)

        capView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capView)

        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = textColor
        symbolView.isUserInteractionEnabled = false
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolView)

        NSLayoutConstraint.activate([
            capView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capView.trailingAnchor.constraint(equalTo: trailingAnchor),
            capView.topAnchor.constraint(equalTo: topAnchor),
            capView.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -0.5),
            symbolView.widthAnchor.constraint(equalToConstant: 24),
            symbolView.heightAnchor.constraint(equalToConstant: 18),
        ])

        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)

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
        symbolPointSize = metrics.symbolPointSize
        let fontSize = titleFontSizeOverride ?? (kind == .letter ? metrics.letterFontSize : metrics.functionalFontSize)
        let weight: UIFont.Weight = kind == .returnKey ? .medium : .regular
        titleLabel.font = .systemFont(ofSize: fontSize, weight: weight)
        refreshCapStyle()
        updateSymbol()
    }

    private func refreshTitleFont() {
        let metrics = AppleKeyboardMetrics.resolve(width: bounds.width > 1 ? bounds.width : 390)
        let fontSize = titleFontSizeOverride ?? (kind == .letter ? metrics.letterFontSize : metrics.functionalFontSize)
        let weight: UIFont.Weight = kind == .returnKey ? .medium : .regular
        titleLabel.font = .systemFont(ofSize: fontSize, weight: weight)
    }

    func applyColors(normal: UIColor, pressed: UIColor, text: UIColor) {
        normalFill = normal
        pressedFill = pressed
        textColor = text
        titleLabel.textColor = text
        symbolView.tintColor = text
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

    private func updateSymbol() {
        guard let symbolName else {
            symbolView.image = nil
            symbolView.isHidden = true
            return
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        symbolView.image = UIImage(systemName: symbolName, withConfiguration: cfg)?
            .withRenderingMode(.alwaysTemplate)
        symbolView.isHidden = false
        titleLabel.isHidden = true
    }

    @objc private func touchDown() {
        isHighlighted = true
        capView.isPressed = true
    }

    @objc private func touchUp() {
        isHighlighted = false
        capView.isPressed = false
    }
}
