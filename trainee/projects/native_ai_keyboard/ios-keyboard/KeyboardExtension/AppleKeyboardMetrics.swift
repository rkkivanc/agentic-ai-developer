import CoreGraphics
import UIKit

/// Apple keyboard layout metrics derived from public iOS keyboard measurements (not third-party code).
enum AppleKeyboardMetrics {
    struct Resolved: Equatable {
        let horizontalMargin: CGFloat
        let topMargin: CGFloat
        let bottomMargin: CGFloat
        let keyGap: CGFloat
        let rowGap: CGFloat
        let keyHeight: CGFloat
        let cornerRadius: CGFloat
        let shiftDeleteWidth: CGFloat
        let bottomSideKeyWidth: CGFloat
        let staggerInset: CGFloat
        let letterFontSize: CGFloat
        let functionalFontSize: CGFloat
        let symbolPointSize: CGFloat
        let aiToolbarHeight: CGFloat
        let keysAreaHeight: CGFloat
        let keyShadowOpacity: Float
    }

    /// AI action row (Improve / Shorten / Expand) — fixed height, not part of the key area.
    static func aiToolbarHeight(for width: CGFloat, isLandscape: Bool = false) -> CGFloat {
        isLandscape ? 44 : 56
    }

    /// Stock iOS keyboard key area (QWERTY rows only, no custom toolbar).
    static func keysAreaHeight(for width: CGFloat, isLandscape: Bool = false) -> CGFloat {
        if isLandscape { return 210 }
        let w = max(320, width > 1 ? width : 390)
        return clamp(260, 268 + (w - 375) * 12 / (414 - 375), 280)
    }

    /// `UIInputView` height = toolbar + keys (e.g. 56 + 280 = 336 on Plus/Max width).
    static func totalDesignHeight(for width: CGFloat, isLandscape: Bool = false) -> CGFloat {
        aiToolbarHeight(for: width, isLandscape: isLandscape)
            + keysAreaHeight(for: width, isLandscape: isLandscape)
    }

    static func keyplaneDesignHeight(for width: CGFloat, isLandscape: Bool = false) -> CGFloat {
        keysAreaHeight(for: width, isLandscape: isLandscape)
    }

    /// Portrait baseline widths: 320 (SE), 375 (6/7/8), 390 (14/15), 414 (Plus/Max).
    static func resolve(width: CGFloat, isLandscape: Bool = false) -> Resolved {
        let w = max(320, width)

        let keysArea = keysAreaHeight(for: width, isLandscape: isLandscape)
        let toolbarH = aiToolbarHeight(for: width, isLandscape: isLandscape)

        let horizontalMargin: CGFloat = w >= 414 ? 4 : 3
        let topMargin: CGFloat = isLandscape ? 6 : (w >= 414 ? 8 : 10)
        let bottomMargin: CGFloat = w >= 414 ? 4 : 3
        let keyGap: CGFloat = isLandscape ? 5 : 6
        let rowGap: CGFloat = isLandscape ? 5 : 6

        let verticalChrome = topMargin + bottomMargin + rowGap * 3
        let keyHeight = max(36, (keysArea - verticalChrome) / 4)

        let cornerRadius = clamp(4, 5 + (w - 375) * (6 - 5) / (414 - 375), 6)
        let shiftDeleteWidth = clamp(36, w * 42 / 375, 48)
        let bottomSideKeyWidth = clamp(74, w * 87.5 / 375, 100)
        let staggerInset = max(4, w * 0.05)

        return Resolved(
            horizontalMargin: horizontalMargin,
            topMargin: topMargin,
            bottomMargin: bottomMargin,
            keyGap: keyGap,
            rowGap: rowGap,
            keyHeight: keyHeight,
            cornerRadius: cornerRadius,
            shiftDeleteWidth: shiftDeleteWidth,
            bottomSideKeyWidth: bottomSideKeyWidth,
            staggerInset: staggerInset,
            letterFontSize: isLandscape ? 18 : 22,
            functionalFontSize: isLandscape ? 14 : 16,
            symbolPointSize: isLandscape ? 13 : 16,
            aiToolbarHeight: toolbarH,
            keysAreaHeight: keysArea,
            keyShadowOpacity: 0.35
        )
    }

    private static func clamp(_ min: CGFloat, _ value: CGFloat, _ max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}
