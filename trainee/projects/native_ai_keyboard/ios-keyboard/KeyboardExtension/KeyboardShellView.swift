import UIKit

/// Root keyboard chrome: AI toolbar → status → Apple keyplane. Replaces the legacy monolithic layout view.
final class KeyboardShellView: UIView {
    private weak var controller: KeyboardViewController?
    private let surfaceCover = UIView()
    private let ai = KeyboardAICoordinator()
    private let keyplane = AppleKeyboardKeyplane()

    private var toolbarHeightConstraint: NSLayoutConstraint?
    private var lastLayoutSize: CGSize = .zero
    private var didBuildKeyplane = false

    var isDisplayReady: Bool {
        didBuildKeyplane && bounds.width > 1 && bounds.height > 80
    }

    private var metrics: AppleKeyboardMetrics.Resolved {
        let w = bounds.width > 1 ? bounds.width : 390
        let landscape = isLandscapeLayout
        return AppleKeyboardMetrics.resolve(width: w, isLandscape: landscape)
    }

    private var isLandscapeLayout: Bool {
        let w = bounds.width
        let h = bounds.height
        if w > 1, h > 80, h > 1 {
            return w > h
        }
        return traitCollection.verticalSizeClass == .compact && traitCollection.userInterfaceIdiom == .phone
    }

    static func surfaceColor(isDark: Bool) -> UIColor {
        KeyboardNativePalette.surfaceColor(isDark: isDark)
    }

    var chromeToolbarAnchor: UIView { ai.chromeToolbarAnchor }

    init(controller: KeyboardViewController) {
        KeyboardExtensionDiagnostics.logSync("KeyboardShellView init begin")
        self.controller = controller
        super.init(frame: .zero)

        ai.controller = controller
        keyplane.delegate = self

        surfaceCover.translatesAutoresizingMaskIntoConstraints = false
        surfaceCover.isUserInteractionEnabled = false
        insertSubview(surfaceCover, at: 0)
        NSLayoutConstraint.activate([
            surfaceCover.leadingAnchor.constraint(equalTo: leadingAnchor),
            surfaceCover.trailingAnchor.constraint(equalTo: trailingAnchor),
            surfaceCover.topAnchor.constraint(equalTo: topAnchor),
            surfaceCover.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let installed = ai.install(
            on: self,
            keyplane: keyplane,
            toolbarDesignHeight: metrics.aiToolbarHeight
        )
        toolbarHeightConstraint = installed.toolbarHeight
        toolbarHeightConstraint?.constant = metrics.aiToolbarHeight

        applyAppearance(traits: controller.traitCollection)
        finishDeferredBuildIfNeeded()
        KeyboardExtensionDiagnostics.logSync("KeyboardShellView init done")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        ai.stopObserving()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshLayoutMetricsIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            ai.startObserving()
            AppGroupStore.shared.syncHostAppLanguageToKeyboard()
            lastLayoutSize = .zero
            if controller?.isKeyboardDisplaySettling != true {
                controller?.reconcileKeyboardHeight(force: true)
            }
            refreshLayoutMetricsIfNeeded(force: true)
            controller?.noteKeyboardShellLayoutPass()
        } else {
            ai.stopObserving()
        }
    }

    func finishDeferredBuildIfNeeded(completion: (() -> Void)? = nil) {
        guard !didBuildKeyplane else {
            completion?()
            return
        }
        didBuildKeyplane = true
        keyplane.buildIfNeeded()
        keyplane.applyWidthMetrics()
        completion?()
    }

    func syncSystemKeyboardLayout(needsInputModeSwitchKey: Bool) {
        keyplane.updateInputModeSwitchKeyVisibility(needsInputModeSwitchKey)
        lastLayoutSize = .zero
        refreshLayoutMetricsIfNeeded(force: true)
    }

    func applyStableLayoutFit() {
        lastLayoutSize = .zero
        controller?.reconcileKeyboardHeight(force: true)
        refreshLayoutMetricsIfNeeded(force: true)
    }

    func syncSettingsFromAppGroup() {
        ai.syncFromAppGroup()
        keyplane.refreshLocalizedTitles()
        refreshAccentChrome()
        refreshAIActionAvailability()
    }

    func refreshAIActionAvailability() {
        ai.refreshActionAvailability()
    }

    func refreshAccentChrome() {
        keyplane.applyAppearance()
    }

    func refreshChromeStringsFromAppGroup() {
        syncSettingsFromAppGroup()
    }

    func applyAppearance(traits: UITraitCollection) {
        let isDark = traits.userInterfaceStyle == .dark
        let rootSurface = KeyboardHostChromePolicy.rootSurfaceColor(isDark: isDark)

        isOpaque = !KeyboardHostChromePolicy.usesLiquidGlassHostCard
        backgroundColor = rootSurface
        surfaceCover.backgroundColor = rootSurface
        ai.applyToolbarChromeBackground(rootSurface)
        controller?.syncKeyboardSurface()
        ai.applyAppearance(isDark: isDark)
        keyplane.applyAppearance()
    }

    func toggleChromeOptionsPanel() {
        controller?.toggleChromeOptionsPanel()
    }

    // MARK: - Layout

    private func refreshLayoutMetricsIfNeeded(force: Bool = false) {
        let size = bounds.size
        guard size.width > 1 else { return }
        if !force,
           abs(size.width - lastLayoutSize.width) < 0.5,
           abs(size.height - lastLayoutSize.height) < 0.5
        {
            return
        }
        lastLayoutSize = size

        let m = metrics
        toolbarHeightConstraint?.constant = m.aiToolbarHeight
        ai.fitToolbar(height: m.aiToolbarHeight)
        keyplane.applyWidthMetrics()
        controller?.reconcileKeyboardHeight(force: force)
        controller?.noteKeyboardShellLayoutPass()
    }
}

extension KeyboardShellView: AppleKeyboardKeyplaneDelegate {
    func keyplaneInsertText(_ text: String) {
        controller?.insertString(text)
    }

    func keyplaneDeleteBackward() {
        controller?.deleteBackward()
    }

    func keyplaneAccentColor() -> UIColor {
        AppGroupStore.shared.keyboardChromeAccent.uiColor
    }

    func keyplaneAccentPressedColor() -> UIColor {
        let base = keyplaneAccentColor()
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if base.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: max(0, b * 0.82), alpha: a)
        }
        return base.withAlphaComponent(0.85)
    }

    func keyplaneLocalized(_ key: String) -> String {
        ai.localize(key)
    }

    func keyplaneIsDark() -> Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    func keyplaneShouldShowInputModeSwitchKey() -> Bool {
        controller?.needsInputModeSwitchKey ?? false
    }

    func keyplaneWireInputModeSwitchButton(_ button: UIControl) {
        guard let controller else { return }
        button.removeTarget(nil, action: nil, for: .allEvents)
        button.addTarget(
            controller,
            action: #selector(UIInputViewController.handleInputModeList(from:with:)),
            for: .allEvents
        )
    }
}

extension KeyboardShellView: KeyboardChromeOptionsDelegate {
    func chromeOptionsLocalize(_ key: String) -> String {
        ai.localize(key)
    }

    func chromeOptionsDidChangeAccent() {
        syncSettingsFromAppGroup()
    }

    func chromeOptionsIsDark() -> Bool {
        traitCollection.userInterfaceStyle == .dark
    }
}
