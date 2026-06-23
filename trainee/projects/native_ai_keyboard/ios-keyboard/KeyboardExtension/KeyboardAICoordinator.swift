import UIKit

/// AI rewrite toolbar, status row, and preview overlay — separated from keyplane rendering.
final class KeyboardAICoordinator {
    weak var controller: KeyboardViewController?

    let toolbar = KeyboardToolbarView()
    let statusRow = KeyboardStatusRowView()
    let previewZone = KeyboardPreviewOverlayView()

    private var pendingRewriteFromTouchDown: (text: String, snapshot: RewriteSnapshot)?
    private var previewHeightConstraint: NSLayoutConstraint?
    private var statusHeightConstraint: NSLayoutConstraint?
    private var toolbarHeightConstraint: NSLayoutConstraint?

    private var sessionPollTimer: Timer?
    private var settingsObserver: AppGroupSettingsObserverToken?
    private var lastChromeIsDark: Bool?

    var chromeToolbarAnchor: UIView { toolbar }

    // MARK: - Install

    func install(
        on parent: UIView,
        keyplane: UIView,
        toolbarDesignHeight: CGFloat
    ) -> (toolbarHeight: NSLayoutConstraint?, statusHeight: NSLayoutConstraint?, previewHeight: NSLayoutConstraint?) {
        buildPreviewContent()
        buildAIActions()
        buildStatusRow()
        buildToolbarChrome()

        let constraints = KeyboardRootViewLayout.install(
            on: parent,
            toolbarRow: toolbar,
            statusRow: statusRow,
            keyContainer: keyplane,
            previewOverlay: previewZone,
            toolbarDesignHeight: toolbarDesignHeight
        )

        toolbarHeightConstraint = constraints.toolbarHeight
        statusHeightConstraint = constraints.statusHeight
        previewHeightConstraint = constraints.previewHeight
        setPreviewVisible(false, animated: false)
        updateStatusVisibility()
        return (constraints.toolbarHeight, constraints.statusHeight, constraints.previewHeight)
    }

    func startObserving() {
        settingsObserver = AppGroupSettingsNotifier.observe { [weak self] in
            self?.syncFromAppGroup()
        }
        sessionPollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshOpenAppButton()
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionPollTimer = timer
        refreshOpenAppButton()
        syncFromAppGroup()
        refreshActionAvailability()
    }

    func stopObserving() {
        sessionPollTimer?.invalidate()
        sessionPollTimer = nil
        settingsObserver = nil
    }

    // MARK: - Appearance

    func applyAppearance(isDark: Bool) {
        lastChromeIsDark = isDark
        statusRow.statusLabel.textColor = isDark ? .lightGray : .darkGray
        toolbar.applyDividerAppearance(isDark: isDark)
        applyPreviewColors(isDark: isDark)
        refreshActionButtonChrome(isDark: isDark)
        refreshAccents()
    }

    func refreshActionButtonChrome(isDark: Bool) {
        lastChromeIsDark = isDark
        let accent = AppGroupStore.shared.keyboardChromeAccent.uiColor

        for button in toolbar.actionsRow.arrangedSubviews.compactMap({ $0 as? UIButton }) {
            guard var cfg = button.configuration else { continue }
            cfg.baseForegroundColor = accent
            cfg.background.backgroundColor = .clear
            cfg.background.cornerRadius = 0
            cfg.background.strokeWidth = 0
            cfg.background.strokeColor = nil
            button.configuration = cfg
            button.backgroundColor = .clear
        }
    }

    func applyToolbarChromeBackground(_ color: UIColor) {
        toolbar.backgroundColor = color
        toolbar.aiBar.backgroundColor = color
    }

    func syncFromAppGroup() {
        rebuildAIActionsIfNeeded()
        if !AppGroupStore.shared.aiPreviewBeforeApply {
            hidePreview()
        }
        refreshOpenAppButton()
        refreshAccents()
        refreshActionAvailability()
        controller?.chromeOptionsPresenter?.rebuildIfVisible()
    }

    func refreshActionAvailability() {
        let hasText = controller?.hasRewriteText() ?? false
        for button in toolbar.actionsRow.arrangedSubviews.compactMap({ $0 as? UIButton }) {
            button.isEnabled = hasText
            button.alpha = hasText ? 1 : 0.42
        }
    }

    private func rebuildAIActionsIfNeeded() {
        let expectedCount = 4
        if toolbar.actionsRow.arrangedSubviews.count == expectedCount {
            refreshActionTitles()
            refreshActionAvailability()
            return
        }
        toolbar.actionsRow.arrangedSubviews.forEach { view in
            toolbar.actionsRow.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buildAIActions()
        refreshActionAvailability()
        let isDark = lastChromeIsDark ?? (toolbar.traitCollection.userInterfaceStyle == .dark)
        refreshActionButtonChrome(isDark: isDark)
    }

    func refreshAccents() {
        let accent = AppGroupStore.shared.keyboardChromeAccent.uiColor
        statusRow.openAppButton.tintColor = accent
        var ocfg = statusRow.openAppButton.configuration
        ocfg?.baseForegroundColor = accent
        statusRow.openAppButton.configuration = ocfg

        if var ac = previewZone.applyButton.configuration {
            ac.baseBackgroundColor = accent
            previewZone.applyButton.configuration = ac
        }

        let accentColor = accent
        for button in toolbar.plusButtonHost.arrangedSubviews.compactMap({ $0 as? UIButton }) {
            button.tintColor = accentColor
        }

        let isDark = lastChromeIsDark ?? (toolbar.traitCollection.userInterfaceStyle == .dark)
        refreshActionButtonChrome(isDark: isDark)
        controller?.refreshKeyboardAccentChrome()
    }

    func fitToolbar(height: CGFloat) {
        toolbarHeightConstraint?.constant = height
    }

    // MARK: - Localization

    func localize(_ key: String) -> String {
        let code = AppGroupStore.shared.keyboardChromeStringsLanguageCode
        let main = Bundle(for: KeyboardAICoordinator.self)
        if let path = main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            let s = NSLocalizedString(key, tableName: nil, bundle: bundle, value: "\u{1}", comment: "")
            if s != "\u{1}" { return s }
        }
        if let path = main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    // MARK: - AI actions

    private func buildAIActions() {
        let items: [(String, String, RewriteMode)] = [
            ("checkmark.circle", "keyboard.action_grammar", .proofread),
            ("arrow.up.circle", "keyboard.action_improve", .rewrite),
            ("arrow.down.right.and.arrow.up.left", "keyboard.action_shorten", .shorten),
            ("arrow.up.left.and.arrow.down.right", "keyboard.action_expand", .expand),
        ]
        for (symbol, key, mode) in items {
            let button = makeActionButton(symbol: symbol, titleKey: key)
            button.addAction(UIAction { [weak self] _ in self?.runTransform(mode: mode) }, for: .touchUpInside)
            toolbar.actionsRow.addArrangedSubview(button)
        }
    }

    private func makeActionButton(symbol: String, titleKey: String) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.image = symbolImage(symbol)
        cfg.title = localize(titleKey)
        cfg.imagePlacement = .top
        cfg.imagePadding = 4
        cfg.titleLineBreakMode = .byTruncatingTail
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 4, trailing: 8)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 11, weight: .semibold)
            return out
        }
        let button = UIButton(configuration: cfg)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.addTarget(self, action: #selector(rewriteTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(rewriteTouchCancel), for: [.touchUpOutside, .touchCancel])
        return button
    }

    private func symbolImage(_ name: String) -> UIImage {
        let fallback: String = switch name {
        case "checkmark.circle": "✓"
        case "textformat.abc": "G"
        case "arrow.up.circle": "I"
        case "arrow.down.right.and.arrow.up.left": "S"
        case "arrow.up.left.and.arrow.down.right": "X"
        default: "•"
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        if let img = UIImage(systemName: name, withConfiguration: cfg) {
            return img.withRenderingMode(.alwaysTemplate)
        }
        let size = CGSize(width: 22, height: 22)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.label,
            ]
            let str = fallback as NSString
            let ts = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2), withAttributes: attrs)
        }.withRenderingMode(.alwaysTemplate)
    }

    private func refreshActionTitles() {
        let items: [(String, String)] = [
            ("checkmark.circle", "keyboard.action_grammar"),
            ("arrow.up.circle", "keyboard.action_improve"),
            ("arrow.down.right.and.arrow.up.left", "keyboard.action_shorten"),
            ("arrow.up.left.and.arrow.down.right", "keyboard.action_expand"),
        ]
        let buttons = toolbar.actionsRow.arrangedSubviews.compactMap { $0 as? UIButton }
        for (i, button) in buttons.enumerated() where i < items.count {
            var cfg = button.configuration
            cfg?.title = localize(items[i].1)
            cfg?.image = symbolImage(items[i].0)
            button.configuration = cfg
        }
        previewZone.titleLabel.text = localize("keyboard.result_preview_title")
        var discard = previewZone.discardButton.configuration
        discard?.title = localize("keyboard.discard_result")
        previewZone.discardButton.configuration = discard
        var apply = previewZone.applyButton.configuration
        apply?.title = localize("keyboard.apply_result")
        previewZone.applyButton.configuration = apply
    }

    private func buildToolbarChrome() {
        let settings = UIButton(type: .system)
        let sym = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        settings.setImage(UIImage(systemName: "gearshape", withConfiguration: sym), for: .normal)
        settings.tintColor = AppGroupStore.shared.keyboardChromeAccent.uiColor
        settings.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 0)
        settings.accessibilityLabel = localize("keyboard.chrome_more_accessibility")
        settings.addAction(UIAction { [weak self] _ in
            self?.controller?.toggleChromeOptionsPanel()
        }, for: .touchUpInside)
        toolbar.plusButtonHost.addArrangedSubview(settings)
    }

    // MARK: - Status + preview

    private func buildStatusRow() {
        statusRow.statusLabel.font = .preferredFont(forTextStyle: .caption2)
        var cfg = UIButton.Configuration.bordered()
        cfg.title = localize("keyboard.tap_open_app")
        cfg.baseForegroundColor = AppGroupStore.shared.keyboardChromeAccent.uiColor
        cfg.buttonSize = .mini
        cfg.cornerStyle = .capsule
        statusRow.openAppButton.configuration = cfg
        statusRow.openAppButton.addAction(UIAction { [weak self] _ in
            self?.controller?.openHostAppForSessionRefresh()
        }, for: .touchUpInside)
    }

    private func buildPreviewContent() {
        let outer = UIStackView()
        outer.axis = .vertical
        outer.spacing = 8
        outer.translatesAutoresizingMaskIntoConstraints = false
        previewZone.addSubview(outer)

        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: previewZone.leadingAnchor, constant: 12),
            outer.trailingAnchor.constraint(equalTo: previewZone.trailingAnchor, constant: -12),
            outer.topAnchor.constraint(equalTo: previewZone.topAnchor, constant: 10),
            outer.bottomAnchor.constraint(equalTo: previewZone.bottomAnchor, constant: -10),
        ])

        previewZone.titleLabel.text = localize("keyboard.result_preview_title")
        previewZone.textView.isScrollEnabled = true
        previewZone.textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        previewZone.textView.layer.cornerRadius = 10
        previewZone.textView.clipsToBounds = true
        previewZone.textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

        var discard = UIButton.Configuration.bordered()
        discard.title = localize("keyboard.discard_result")
        discard.cornerStyle = .capsule
        discard.buttonSize = .small
        previewZone.discardButton.configuration = discard
        previewZone.discardButton.addAction(UIAction { [weak self] _ in self?.hidePreview() }, for: .touchUpInside)

        var apply = UIButton.Configuration.filled()
        apply.title = localize("keyboard.apply_result")
        apply.cornerStyle = .capsule
        apply.buttonSize = .small
        apply.baseBackgroundColor = AppGroupStore.shared.keyboardChromeAccent.uiColor
        apply.baseForegroundColor = .white
        previewZone.applyButton.configuration = apply
        previewZone.applyButton.addAction(UIAction { [weak self] _ in self?.applyPreview() }, for: .touchUpInside)

        outer.addArrangedSubview(previewZone.titleLabel)
        outer.addArrangedSubview(previewZone.textView)
        outer.addArrangedSubview(previewZone.buttonRow)
    }

    private func applyPreviewColors(isDark: Bool) {
        let palette = KeyboardNativePalette.colors(isDark: isDark)
        previewZone.backgroundColor = palette.previewPanel
        previewZone.titleLabel.textColor = palette.primaryText
        previewZone.textView.backgroundColor = palette.previewField
        previewZone.textView.textColor = palette.primaryText
    }

    private func refreshOpenAppButton() {
        let need = !AppGroupStore.shared.isSessionValid()
        statusRow.openAppButton.isHidden = !need
        var cfg = statusRow.openAppButton.configuration
        cfg?.title = localize("keyboard.tap_open_app")
        statusRow.openAppButton.configuration = cfg
        updateStatusVisibility()
    }

    private func updateStatusVisibility() {
        let hasText = !(statusRow.statusLabel.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let show = hasText || !statusRow.openAppButton.isHidden
        statusRow.isHidden = !show
        statusHeightConstraint?.constant = show ? 22 : 0
    }

    private func setPreviewVisible(_ visible: Bool, animated: Bool) {
        previewZone.isHidden = !visible
        previewHeightConstraint?.constant = visible ? 218 : 0
        if animated {
            previewZone.superview?.layoutIfNeeded()
        }
    }

    func hidePreview() {
        previewZone.textView.text = ""
        setPreviewVisible(false, animated: true)
        controller?.clearPendingApplySnapshot()
    }

    private func showPreview(with text: String) {
        guard AppGroupStore.shared.aiPreviewBeforeApply else { return }
        previewZone.textView.text = text
        setPreviewVisible(true, animated: true)
    }

    private func applyPreview() {
        guard let controller else { return }
        controller.applyPreviewResult(previewZone.textView.text ?? "")
        previewZone.textView.text = ""
        setPreviewVisible(false, animated: true)
        statusRow.statusLabel.text = ""
        updateStatusVisibility()
    }

    // MARK: - Rewrite

    @objc private func rewriteTouchDown() {
        pendingRewriteFromTouchDown = controller?.rewriteContext()
    }

    @objc private func rewriteTouchCancel() {
        pendingRewriteFromTouchDown = nil
    }

    private func runTransform(mode: RewriteMode) {
        guard let controller else { return }

        guard KeyboardExtensionFullAccess.allowsNetwork(for: controller.hasFullAccess) else {
            statusRow.statusLabel.text = localize("keyboard.ai_need_full_access")
            updateStatusVisibility()
            return
        }

        let touchDown = pendingRewriteFromTouchDown
        pendingRewriteFromTouchDown = nil

        let live = controller.rewriteContext()
        let locked = KeyboardActionService.mergeRewriteContexts(touchDown: touchDown, live: live)
        let lockedText = locked.0.trimmingCharacters(in: .whitespacesAndNewlines)
        let lockedSnapshot = locked.1

        controller.clearPendingApplySnapshot()
        hidePreview()

        guard !lockedText.isEmpty else { return }

        guard AppGroupStore.shared.isSessionValid() else {
            statusRow.statusLabel.text = localize("keyboard.open_host")
            updateStatusVisibility()
            refreshOpenAppButton()
            return
        }

        let workingKey: String = switch mode {
        case .proofread: "keyboard.working_grammar"
        case .rewrite: "keyboard.working_improve"
        case .shorten: "keyboard.working_shorten"
        case .expand: "keyboard.working_expand"
        }
        statusRow.statusLabel.text = localize(workingKey)
        updateStatusVisibility()

        let style = AppGroupStore.shared.conversationStyle
        let text = lockedText
        let snap = lockedSnapshot

        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                guard let self, let controller = self.controller else { return }

                if AppConfig.usesSupabaseTransform,
                   AppGroupStore.shared.deviceTransformToken?.isEmpty ?? true
                {
                    do {
                        try await SupabaseDeviceAPI.registerForceRefresh()
                    } catch {
                        self.statusRow.statusLabel.text = KeyboardExtensionL10n.userFacingError(error)
                        self.updateStatusVisibility()
                        return
                    }
                }

                do {
                    let out = try await RewriteAPI.rewrite(text: text, mode: mode, style: style)
                    if AppGroupStore.shared.aiPreviewBeforeApply {
                        controller.setPendingApplySnapshot(snap)
                        self.showPreview(with: out)
                        self.statusRow.statusLabel.text = self.localize("keyboard.preview_ready")
                    } else {
                        controller.applyRewrite(result: out, snapshot: snap)
                        self.statusRow.statusLabel.text = self.localize("keyboard.done")
                    }
                    self.updateStatusVisibility()
                    self.refreshOpenAppButton()
                } catch {
                    self.statusRow.statusLabel.text = KeyboardExtensionL10n.userFacingError(error)
                    self.updateStatusVisibility()
                }
            }
        }
    }
}
