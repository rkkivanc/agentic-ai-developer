import UIKit

/// Draws Apple-style key caps with a subtle bottom shadow (CoreGraphics — original implementation).
enum KeyCapRenderer {
    struct Style {
        var fill: UIColor
        var pressedFill: UIColor
        var cornerRadius: CGFloat
        var shadowOpacity: Float
    }

    static func applyShadow(to layer: CALayer, opacity: Float) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.masksToBounds = false
    }

    static func draw(
        in context: CGContext,
        bounds: CGRect,
        style: Style,
        pressed: Bool
    ) {
        let inset = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - 1
        )
        let path = UIBezierPath(
            roundedRect: inset,
            cornerRadius: style.cornerRadius
        )

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 1),
            blur: 0,
            color: UIColor.black.withAlphaComponent(CGFloat(style.shadowOpacity)).cgColor
        )
        (pressed ? style.pressedFill : style.fill).setFill()
        path.fill()
        context.restoreGState()
    }
}

/// Background layer that paints a key cap; sits behind labels / symbols.
final class KeyCapBackgroundView: UIView {
    var capStyle = KeyCapRenderer.Style(
        fill: .white,
        pressedFill: .lightGray,
        cornerRadius: 5,
        shadowOpacity: 0.35
    )
    var isPressed = false {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        KeyCapRenderer.draw(in: ctx, bounds: rect, style: capStyle, pressed: isPressed)
    }
}
