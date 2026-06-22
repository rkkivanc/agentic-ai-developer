import UIKit

/// iOS 26 `UIInputSetHostView` liquid-glass keyboard card (Apple Developer Forums #793686).
///
/// Apple DTS: content is inset inside the rounded host; opaque keyboard backgrounds clash with the
/// system card and read as a "gray bar". Use clear roots and let `UIInputView` backdrop show through.
enum KeyboardHostChromePolicy {
    /// iOS 26+ host uses liquid glass; earlier OS versions use solid tray chrome.
    static var usesLiquidGlassHostCard: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static func rootSurfaceColor(isDark: Bool) -> UIColor {
        usesLiquidGlassHostCard ? .clear : KeyboardShellView.surfaceColor(isDark: isDark)
    }
}
