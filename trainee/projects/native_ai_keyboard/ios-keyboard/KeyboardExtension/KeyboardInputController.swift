import UIKit

/// KeyboardKit-style base controller: `viewWillSetupKeyboardKit` → `viewWillSetupKeyboardView`, deferred keyplane build.
class KeyboardInputController: UIInputViewController {
    enum KeyboardSetupResult {
        case success
        case degraded(reason: String)
    }

    let keyboardState = KeyboardState()
    private var didApplyConfiguration = false
    private var didInstallKeyboardView = false
    private var accessReportFalseStreak = 0
    private var accessReportTimers: [Timer] = []
    private var isSyncingSurface = false
    private(set) var chromeOptionsPresenter: KeyboardChromeOptionsPresenter?
    private let appearanceGate = KeyboardAppearanceGate()
    private let composeTracker = KeyboardComposeTracker()

    var actions: KeyboardActionService {
        KeyboardActionService(proxy: textDocumentProxy)
    }

    /// KeyboardKit `setupKeyboardKit(for:completion:)` — App Group, settings, state.
    func setupKeyboardKit(for config: KeyboardAppConfiguration, completion: @escaping (KeyboardSetupResult) -> Void) {
        guard !didApplyConfiguration else {
            completion(.success)
            return
        }
        KeyboardExtensionSigningDiagnostics.logInfrastructure()
        didApplyConfiguration = true
        KeyboardSettingsService.syncHostConfiguration(config)
        keyboardState.apply(config)
        let appGroupOK = AppGroupStore.shared.isSharedContainerAvailable
        KeyboardExtensionDiagnostics.logSync(
            "controller.setupKeyboardKit.done appGroup=\(appGroupOK)"
        )
        if appGroupOK {
            completion(.success)
        } else {
            completion(.degraded(reason: "app_group_unavailable"))
        }
    }

    /// Override point — default runs `setupKeyboardKit` then installs the keyboard view on success/degraded.
    func viewWillSetupKeyboardKit() {
        KeyboardExtensionDiagnostics.logSync("controller.viewWillSetupKeyboardKit.begin")
        setupKeyboardKit(for: .current) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                KeyboardExtensionDiagnostics.logSync("controller.setupKeyboardKit.success")
            case .degraded(let reason):
                KeyboardExtensionDiagnostics.logSync("controller.setupKeyboardKit.degraded reason=\(reason)")
            }
            self.viewWillSetupKeyboardView()
        }
    }

    /// Override point — default installs `makeKeyboardContentView()` after kit setup completes.
    func viewWillSetupKeyboardView() {
        KeyboardExtensionDiagnostics.logSync("controller.viewWillSetupKeyboardView.begin")
        installFullKeyboardView()
        layoutContentView()?.syncSettingsFromAppGroup()
        KeyboardExtensionDiagnostics.logSync("controller.viewWillSetupKeyboardView.done")
    }

    func makeKeyboardContentView() -> UIView {
        KeyboardMinimalView(controller: self)
    }

    func installFullKeyboardView() {
        guard !didInstallKeyboardView else { return }
        didInstallKeyboardView = true
        KeyboardExtensionDiagnostics.logSync("controller.installLayout.begin")

        let layoutView = makeKeyboardContentView()
        layoutView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layoutView)
        NSLayoutConstraint.activate([
            layoutView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            layoutView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            layoutView.topAnchor.constraint(equalTo: view.topAnchor),
            layoutView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        if let shell = layoutView as? KeyboardShellView {
            installChromeOptionsPresenter(layoutView: shell)
        }
        applyKeyboardAppearancePreference()
        syncKeyboardSurface()
        KeyboardExtensionDiagnostics.logSync("controller.installLayout.done")
        reportKeyboardAccessToAppGroup()
    }

    func installChromeOptionsPresenter(layoutView: KeyboardShellView) {
        guard chromeOptionsPresenter == nil else { return }
        let presenter = KeyboardChromeOptionsPresenter(delegate: layoutView)
        presenter.install(on: layoutView, toolbarAnchor: layoutView.chromeToolbarAnchor)
        chromeOptionsPresenter = presenter
    }

    func toggleChromeOptionsPanel() {
        chromeOptionsPresenter?.toggle()
    }

    func hideChromeOptionsPanel() {
        chromeOptionsPresenter?.hide()
    }

    override func loadView() {
        KeyboardExtensionDiagnostics.logSync("controller.loadView")
        // `.keyboard` — Apple's style for custom keyboards (blur/tint siblings managed below).
        // See: https://developer.apple.com/documentation/uikit/uiinputview/style/keyboard
        let inputView = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView.allowsSelfSizing = true
        view = inputView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardExtensionDiagnostics.logSync("controller.viewDidLoad.begin")
        ensureKeyboardReadyForDisplay()
        if KeyboardAppearanceGate.isEnabled, let shell = layoutContentView() {
            appearanceGate.onBeforeReveal = { [weak self] in
                self?.finalizeKeyboardDisplayBeforeReveal()
            }
            appearanceGate.onDidReveal = { [weak self] in
                self?.restoreKeyboardSurfaceAfterLoading()
            }
            appearanceGate.install(on: view, contentView: shell)
        }
        beginAppearanceGateIfNeeded()
        KeyboardExtensionDiagnostics.logSync("controller.viewDidLoad.end")
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        prepareKeyboardForDisplay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        beginAppearanceGateIfNeeded()
        prepareKeyboardForDisplay()
        KeyboardExtensionDiagnostics.logSync(
            "controller.viewWillAppear bounds=\(view.bounds.size) hasFullAccess=\(hasFullAccess)"
        )
        AppGroupStore.shared.purgeLegacyKeyboardUIRegionIfPresent()
        AIWritingLocale.syncFromDevice()
        syncComposeTrackerFromProxy()
        reportKeyboardAccessToAppGroup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncKeyboardLayoutForSystemContext()
        prepareKeyboardForDisplay()
        scheduleFollowUpAccessReports()
        ExtensionFirebaseBootstrap.configureOnceIfNeeded { [weak self] in
            self?.reportKeyboardAccessToAppGroup()
        }
        KeyboardExtensionDiagnostics.logSync("controller.viewDidAppear bounds=\(view.bounds.size) liquidGlass=\(KeyboardHostChromePolicy.usesLiquidGlassHostCard)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appearanceGate.endTransitionImmediately()
        hideChromeOptionsPanel()
        KeyboardExtensionDiagnostics.log("controller.viewWillDisappear")
    }

    deinit {
        accessReportTimers.forEach { $0.invalidate() }
        KeyboardExtensionDiagnostics.log("controller.deinit")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reconcileKeyboardHeight(force: appearanceGate.isBlockingDisplay)
        syncKeyboardSurface()
        noteAppearanceGateLayoutPass()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        syncKeyboardLayoutForSystemContext()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        syncComposeTrackerFromProxy()
        notifyComposeTextChanged()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyKeyboardAppearancePreference()
        appearanceGate.updateTransitionColors(isDark: traitCollection.userInterfaceStyle == .dark)
        if previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass
            || previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass
        {
            syncKeyboardLayoutForSystemContext()
        }
    }

    /// Apple: height + globe visibility follow the active text field and orientation.
    func syncKeyboardLayoutForSystemContext() {
        let context = KeyboardTextInputContext.snapshot(from: textDocumentProxy)
        KeyboardExtensionDiagnostics.log(
            "textContext keyboardType=\(context.keyboardType.rawValue) secure=\(context.isSecure)"
        )
        layoutContentView()?.syncSystemKeyboardLayout(needsInputModeSwitchKey: needsInputModeSwitchKey)
        syncKeyboardHeightToContent()
    }

    private var isLandscapeKeyboardLayout: Bool {
        let w = view.bounds.width
        let h = view.bounds.height
        if w > 1, h > 80, h > 1 {
            return w > h
        }
        return traitCollection.verticalSizeClass == .compact && traitCollection.userInterfaceIdiom == .phone
    }

    func syncKeyboardSurface() {
        guard !isSyncingSurface else { return }
        isSyncingSurface = true
        defer { isSyncingSurface = false }

        let isDark = traitCollection.userInterfaceStyle == .dark
        let content = view.subviews.first { $0 is KeyboardShellView || $0 is KeyboardMinimalView }
        guard let content else { return }

        if appearanceGate.isBlockingDisplay {
            let mask = KeyboardHostChromePolicy.loadingMaskColor(isDark: isDark)
            InputViewBackdropNeutralizer.maskForLoading(
                in: view,
                fillColor: mask,
                overlay: appearanceGate.maskingOverlay,
                content: content
            )
            appearanceGate.bringToFront()
        } else {
            let surface = KeyboardHostChromePolicy.rootSurfaceColor(isDark: isDark)
            InputViewBackdropNeutralizer.neutralize(in: view, fillColor: surface, content: content)
        }
    }

    private func restoreKeyboardSurfaceAfterLoading() {
        applyKeyboardAppearancePreference()
        syncKeyboardSurface()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    var isKeyboardDisplaySettling: Bool {
        appearanceGate.isBlockingDisplay
    }

    func noteKeyboardShellLayoutPass() {
        noteAppearanceGateLayoutPass()
    }

    func reconcileKeyboardHeight(force: Bool) {
        KeyboardPresentationLayout.reconcileHeight(
            for: view,
            isLandscape: isLandscapeKeyboardLayout,
            force: force
        )
    }

    func syncKeyboardHeightToContent() {
        reconcileKeyboardHeight(force: false)
    }

    func refreshKeyboardAccentChrome() {
        layoutContentView()?.refreshAccentChrome()
    }

    func applyKeyboardAppearancePreference() {
        // Always follow the system light/dark appearance (Apple keyboard behaviour).
        overrideUserInterfaceStyle = .unspecified
        layoutContentView()?.applyAppearance(traits: traitCollection)
    }

    func reportKeyboardAccessToAppGroup() {
        let appGroupOK = AppGroupStore.shared.isSharedContainerAvailable
        guard appGroupOK else {
            KeyboardExtensionDiagnostics.log("accessReport skipped appGroupWrite=false")
            return
        }

        if hasFullAccess {
            accessReportFalseStreak = 0
            AppGroupStore.shared.updateKeyboardAccessReport(hasFullAccess: true)
        } else {
            accessReportFalseStreak += 1
            // iOS often reports transient `false` on first frames — avoid overwriting a confirmed `true`.
            if accessReportFalseStreak >= 2 {
                AppGroupStore.shared.updateKeyboardAccessReport(hasFullAccess: false)
            }
        }

        KeyboardExtensionDiagnostics.log(
            "accessReport hasFullAccess=\(hasFullAccess) streak=\(accessReportFalseStreak) appGroupWrite=\(appGroupOK)"
        )
    }

    private func scheduleFollowUpAccessReports() {
        accessReportTimers.forEach { $0.invalidate() }
        accessReportTimers = [0.35, 0.75, 1.5, 3.0].map { delay in
            Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.reportKeyboardAccessToAppGroup()
            }
        }
    }

    func dismissKeyboardFromChrome() {
        dismissKeyboard()
    }

    func insertString(_ s: String) {
        actions.insertString(s)
        composeTracker.noteInsertion(s)
        notifyComposeTextChanged()
    }

    func deleteBackward() {
        actions.deleteBackward()
        composeTracker.noteDeleteBackward()
        notifyComposeTextChanged()
    }

    func rewriteContext() -> (text: String, snapshot: RewriteSnapshot) {
        let proxyRead = actions.readRewriteContextFromProxy()
        if !proxyRead.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            composeTracker.reconcile(proxyText: proxyRead.text)
            return proxyRead
        }
        let fallback = composeTracker.fallbackText
        return actions.rewriteContext(fallbackText: fallback.isEmpty ? nil : fallback)
    }

    func hasRewriteText() -> Bool {
        !rewriteContext().text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func notifyComposeTextChanged() {
        layoutContentView()?.refreshAIActionAvailability()
    }

    private func syncComposeTrackerFromProxy() {
        composeTracker.noteProxyBecameExplicitlyEmpty(textDocumentProxy)
        let proxyRead = actions.readRewriteContextFromProxy()
        composeTracker.reconcile(proxyText: proxyRead.text)
    }

    func currentTextForRewrite() -> String {
        rewriteContext().text
    }

    func makeRewriteSnapshot() -> RewriteSnapshot {
        rewriteContext().snapshot
    }

    func applyRewrite(result: String, snapshot: RewriteSnapshot) {
        if snapshot.replaceWholeDocumentPreferred {
            if let input = textDocumentProxy as? UITextInput {
                let start = input.beginningOfDocument
                let end = input.endOfDocument
                if let range = input.textRange(from: start, to: end) {
                    input.replace(range, withText: result)
                    finishApplyRewrite(result: result)
                    return
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.actions.applyRewrite(result: result, snapshot: snapshot)
                self.finishApplyRewrite(result: result)
            }
            return
        }
        actions.applyRewrite(result: result, snapshot: snapshot)
        finishApplyRewrite(result: result)
    }

    private func finishApplyRewrite(result: String) {
        composeTracker.setText(result)
        notifyComposeTextChanged()
    }

    func openHostAppForSessionRefresh() {
        guard hasFullAccess, let url = KeyboardAppConfiguration.current.deepLinkRefreshURL else { return }
        extensionContext?.open(url, completionHandler: nil)
    }

    private func layoutContentView() -> KeyboardShellView? {
        view.subviews.compactMap { $0 as? KeyboardShellView }.first
    }

    /// Install shell + keyplane before the first frame (no async placeholder flash).
    private func ensureKeyboardReadyForDisplay() {
        if !didApplyConfiguration {
            didApplyConfiguration = true
            KeyboardExtensionSigningDiagnostics.logInfrastructure()
            KeyboardSettingsService.syncHostConfiguration(KeyboardAppConfiguration.current)
            keyboardState.apply(KeyboardAppConfiguration.current)
        }
        guard !didInstallKeyboardView else { return }
        installFullKeyboardView()
        layoutContentView()?.syncSettingsFromAppGroup()
    }

    /// Every globe switch / re-appear: height, keyplane, and chrome in one pass.
    private func prepareKeyboardForDisplay() {
        ensureKeyboardReadyForDisplay()
        layoutContentView()?.finishDeferredBuildIfNeeded()
        reconcileKeyboardHeight(force: true)
        layoutContentView()?.applyStableLayoutFit()
        applyKeyboardAppearancePreference()
        syncKeyboardSurface()
        view.layoutIfNeeded()
        noteAppearanceGateLayoutPass()
    }

    private func beginAppearanceGateIfNeeded() {
        guard KeyboardAppearanceGate.isEnabled else { return }
        appearanceGate.beginTransition(isDark: traitCollection.userInterfaceStyle == .dark)
    }

    private func noteAppearanceGateLayoutPass() {
        guard KeyboardAppearanceGate.isEnabled else { return }
        guard let shell = layoutContentView() else { return }
        let width = KeyboardPresentationLayout.effectiveLayoutWidth(for: view)
        let target = KeyboardPresentationLayout.targetContentHeight(
            for: width,
            isLandscape: isLandscapeKeyboardLayout
        )
        appearanceGate.noteLayoutPass(
            KeyboardAppearanceGate.LayoutSnapshot(
                hostHeight: view.bounds.height,
                targetHeight: target,
                shellHeight: shell.bounds.height,
                inWindow: view.window != nil && shell.window != nil,
                contentReady: shell.isDisplayReady
            )
        )
    }

    /// Last sync while overlay still covers the keyboard — avoids post-loading color/layout jumps.
    private func finalizeKeyboardDisplayBeforeReveal() {
        layoutContentView()?.finishDeferredBuildIfNeeded()
        reconcileKeyboardHeight(force: true)
        layoutContentView()?.applyStableLayoutFit()
        applyKeyboardAppearancePreference()
        layoutContentView()?.refreshAccentChrome()
        syncKeyboardSurface()
        view.layoutIfNeeded()
        layoutContentView()?.layoutIfNeeded()
        appearanceGate.bringToFront()
    }
}
