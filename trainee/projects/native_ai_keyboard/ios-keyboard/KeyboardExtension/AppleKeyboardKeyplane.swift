import UIKit

/// Apple-style QWERTY + numbers keyplane. Metrics from public iOS keyboard measurements (see `AppleKeyboardMetrics`).
protocol AppleKeyboardKeyplaneDelegate: AnyObject {
    func keyplaneInsertText(_ text: String)
    func keyplaneDeleteBackward()
    func keyplaneAccentColor() -> UIColor
    func keyplaneAccentPressedColor() -> UIColor
    func keyplaneLocalized(_ key: String) -> String
    func keyplaneIsDark() -> Bool
    func keyplaneShouldShowInputModeSwitchKey() -> Bool
    func keyplaneWireInputModeSwitchButton(_ button: UIControl)
}

final class AppleKeyboardKeyplane: UIView {
    weak var delegate: AppleKeyboardKeyplaneDelegate?

    private let rowsStack = KeyboardKeyplaneView()
    private weak var shiftButton: AppleKeyButton?

    private enum ShiftPhase { case off, oneShot, locked }
    private enum Keyplane { case letters, numbers }
    private var shiftPhase: ShiftPhase = .off
    private var keyplane: Keyplane = .letters
    private var numbersPage = 0

    private var deleteRepeatTimer: Timer?
    private var deleteRepeatStartWork: DispatchWorkItem?

    private var alternatesHost: UIView?
    private var alternatesOptions: [String] = []
    private var alternatesCells: [UIView] = []
    private var suppressNextLetterTap = false
    private var showsInputModeSwitchKey = false

    private static let staggeredRowID = "kb_row_staggered"

    private var metrics: AppleKeyboardMetrics.Resolved {
        let w = bounds.width > 1 ? bounds.width : 390
        return AppleKeyboardMetrics.resolve(width: w, isLandscape: false)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopDeleteRepeat()
    }

    func buildIfNeeded() {
        guard rowsStack.arrangedSubviews.isEmpty else { return }
        showsInputModeSwitchKey = delegate?.keyplaneShouldShowInputModeSwitchKey() ?? false
        rebuild()
    }

    func applyAppearance() {
        let isDark = delegate?.keyplaneIsDark() ?? false
        backgroundColor = KeyboardNativePalette.surfaceColor(isDark: isDark)
        rowsStack.backgroundColor = backgroundColor
        applyKeyColors(isDark: isDark)
        refreshShiftSymbol()
    }

    func applyWidthMetrics() {
        rowsStack.applyMetrics(metrics)
        applyStaggeredInsets()
    }

    func updateInputModeSwitchKeyVisibility(_ visible: Bool) {
        guard visible != showsInputModeSwitchKey else { return }
        showsInputModeSwitchKey = visible
        guard !rowsStack.arrangedSubviews.isEmpty else { return }
        rebuild()
    }

    // MARK: - Build

    private func rebuild() {
        resetRows()
        switch keyplane {
        case .letters:
            buildLetters()
        case .numbers:
            buildNumbers()
        }
        wireInteractions()
        applyAppearance()
        refreshLetterCaps()
        refreshLocalizedTitles()
    }

    private func resetRows() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        shiftButton = nil
        rowsStack.applyMetrics(metrics)
    }

    private func buildLetters() {
        KeyboardLayoutEngine.buildSynchronously(
            spec: KeyboardLayoutSpec.lettersQwerty(showInputModeSwitch: showsInputModeSwitchKey),
            context: layoutContext(),
            onRowInstalled: { [weak self] row in
                self?.rowsStack.addArrangedSubview(row)
            }
        )
    }

    private func layoutContext() -> KeyboardLayoutEngine.Context {
        let m = metrics
        return KeyboardLayoutEngine.Context(
            metrics: .init(
                horizontalSpacing: m.keyGap,
                row2HorizontalInset: m.staggerInset,
                shiftDeleteWidth: m.shiftDeleteWidth,
                bottomSideKeyWidth: m.bottomSideKeyWidth
            ),
            makeLetterKey: { [weak self] letter in
                self?.makeLetterKey(letter) ?? UIView()
            },
            makeFunctionalKey: { [weak self] title, width in
                guard let self else { return UIView() }
                let key = self.makeFunctionalKey(title: title)
                if let width {
                    key.widthAnchor.constraint(equalToConstant: width).isActive = true
                }
                return key
            },
            configureExpandableRow: configureExpandableRow,
            configureUniformLetterKey: configureUniformLetterKey,
            appendKey: { key, row in row.addArrangedSubview(key) },
            onShiftKeyResolved: { [weak self] view in
                self?.shiftButton = view as? AppleKeyButton
            },
            log: { _ in }
        )
    }

    private func buildNumbers() {
        if numbersPage == 0 {
            addSymbolRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
            addSymbolRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
        } else {
            addSymbolRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
            addSymbolRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"])
        }

        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = metrics.keyGap
        row3.distribution = .fill
        configureExpandableRow(row3)

        let toggle = makeFunctionalKey(title: numbersPage == 0 ? "#+=" : "123")
        toggle.accessibilityIdentifier = "kb_sym_page"
        toggle.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let mid = UIStackView()
        mid.axis = .horizontal
        mid.spacing = metrics.keyGap
        mid.distribution = .fillEqually
        for sym in [",", ".", "?", "!", "'"] {
            mid.addArrangedSubview(makeOutputKey(sym))
        }
        mid.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let delete = makeFunctionalKey(title: "⌫")
        delete.widthAnchor.constraint(equalToConstant: metrics.shiftDeleteWidth).isActive = true
        row3.addArrangedSubview(toggle)
        row3.addArrangedSubview(mid)
        row3.addArrangedSubview(delete)
        rowsStack.addArrangedSubview(row3)

        addNumbersBottomRow()
    }

    private func addSymbolRow(_ symbols: [String]) {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = metrics.keyGap
        row.distribution = .fillEqually
        configureExpandableRow(row)
        for sym in symbols {
            row.addArrangedSubview(makeOutputKey(sym))
        }
        rowsStack.addArrangedSubview(row)
    }

    private func addNumbersBottomRow() {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = metrics.keyGap
        row.distribution = .fill
        configureExpandableRow(row)

        let abc = makeFunctionalKey(title: "ABC")
        abc.accessibilityIdentifier = "kb_ABC"
        abc.widthAnchor.constraint(equalToConstant: metrics.bottomSideKeyWidth).isActive = true

        let space = makeFunctionalKey(title: "space")
        space.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        space.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let ret = makeFunctionalKey(title: "return")
        ret.widthAnchor.constraint(equalToConstant: metrics.bottomSideKeyWidth).isActive = true

        row.addArrangedSubview(abc)
        row.addArrangedSubview(space)
        row.addArrangedSubview(ret)
        rowsStack.addArrangedSubview(row)
    }

    // MARK: - Keys

    private func makeLetterKey(_ letter: Character) -> AppleLetterKeyControl {
        let key = AppleLetterKeyControl(letter: letter, metrics: metrics)
        key.applyCaps(uppercase: shiftPhase != .off)
        styleLetterKey(key)
        key.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
        return key
    }

    private func makeFunctionalKey(title: String) -> AppleKeyButton {
        let isReturn = title == "return"
        let isSpace = title == "space"
        let isFunctional = ["shift", "⌫", "123", "ABC", "return", "#+=", "globe"].contains(title)
        let kind: AppleKeyButton.Kind = if isReturn {
            .returnKey
        } else if isFunctional {
            .functional
        } else {
            .letter
        }

        let key = AppleKeyButton(kind: kind, metrics: metrics)
        styleFunctionalKey(key, kind: kind, isReturn: isReturn)

        if isSpace {
            key.titleText = nil
        } else if isReturn {
            key.titleText = delegate?.keyplaneLocalized("keyboard.key_return")
        } else if title == "ABC" {
            key.titleText = delegate?.keyplaneLocalized("keyboard.key_abc")
        } else {
            key.titleText = title
        }

        if title == "shift" {
            key.titleText = nil
            key.symbolName = "shift"
        }
        if title == "⌫" {
            key.titleText = nil
            key.symbolName = "delete.left"
        }
        if title == "globe" {
            key.titleText = nil
            key.symbolName = "globe"
            key.accessibilityIdentifier = "kb_globe"
            key.accessibilityLabel = delegate?.keyplaneLocalized("keyboard.key_globe")
        }

        switch title {
        case "space": key.accessibilityIdentifier = "kb_space"
        case "shift": key.accessibilityIdentifier = "kb_shift"
        case "⌫": key.accessibilityIdentifier = "kb_delete"
        case "return": key.accessibilityIdentifier = "kb_return"
        case "123": key.accessibilityIdentifier = "kb_123"
        case "ABC": key.accessibilityIdentifier = "kb_ABC"
        default: key.accessibilityIdentifier = "kb_\(title)"
        }

        if title == "⌫" {
            key.addTarget(self, action: #selector(deleteDown), for: .touchDown)
            key.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        } else if title == "globe" {
            delegate?.keyplaneWireInputModeSwitchButton(key)
        } else if title != "shift" {
            key.addTarget(self, action: #selector(functionalTapped(_:)), for: .touchUpInside)
        }

        return key
    }

    private func makeOutputKey(_ output: String) -> AppleKeyButton {
        let key = AppleKeyButton(kind: .letter, metrics: metrics)
        key.outputValue = output
        let isDigit = output.count == 1 && output.first?.isNumber == true
        key.titleFontSizeOverride = isDigit ? metrics.letterFontSize : 18
        key.titleText = output
        key.accessibilityIdentifier = "kb_output_\(output)"
        styleLetterKey(key)
        key.addTarget(self, action: #selector(outputTapped(_:)), for: .touchUpInside)
        return key
    }

    private func styleLetterKey(_ key: AppleLetterKeyControl) {
        let palette = KeyboardNativePalette.colors(isDark: delegate?.keyplaneIsDark() ?? false)
        key.applyColors(normal: palette.letterKey, pressed: palette.letterKeyPressed, text: palette.primaryText)
    }

    private func styleLetterKey(_ key: AppleKeyButton) {
        let palette = KeyboardNativePalette.colors(isDark: delegate?.keyplaneIsDark() ?? false)
        key.applyColors(normal: palette.letterKey, pressed: palette.letterKeyPressed, text: palette.primaryText)
    }

    private func styleFunctionalKey(_ key: AppleKeyButton, kind: AppleKeyButton.Kind, isReturn: Bool) {
        let palette = KeyboardNativePalette.colors(isDark: delegate?.keyplaneIsDark() ?? false)
        let normal: UIColor = switch kind {
        case .letter: palette.letterKey
        case .functional: palette.functionalKey
        case .returnKey: delegate?.keyplaneAccentColor() ?? palette.returnKey
        }
        let pressed: UIColor = switch kind {
        case .letter: palette.letterKeyPressed
        case .functional: palette.functionalKeyPressed
        case .returnKey: delegate?.keyplaneAccentPressedColor() ?? palette.returnKeyPressed
        }
        key.applyColors(normal: normal, pressed: pressed, text: isReturn ? palette.returnText : palette.primaryText)
    }

    private func configureExpandableRow(_ row: UIStackView) {
        row.setContentHuggingPriority(.defaultLow, for: .vertical)
        row.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    private func configureUniformLetterKey(_ key: UIView) {
        key.setContentHuggingPriority(.defaultLow, for: .vertical)
        key.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        key.setContentHuggingPriority(.required, for: .horizontal)
        key.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    // MARK: - Interaction wiring

    private func wireInteractions() {
        visitKeys { view in
            if let letter = view as? AppleLetterKeyControl {
                attachLongPress(to: letter, base: letter.baseLetter)
            } else if let btn = view as? AppleKeyButton,
                      let id = btn.accessibilityIdentifier,
                      id.hasPrefix("kb_"),
                      id != "kb_shift", id != "kb_delete"
            {
                let suffix = String(id.dropFirst(3))
                if suffix.count == 1, let ch = suffix.lowercased().first {
                    attachLongPress(to: btn, base: ch)
                }
            }
        }
        if let shift = shiftButton {
            wireShift(shift)
        }
        wireInputModeSwitchKey()
    }

    private func wireInputModeSwitchKey() {
        visitKeys { view in
            guard let btn = view as? AppleKeyButton,
                  btn.accessibilityIdentifier == "kb_globe"
            else { return }
            btn.removeTarget(nil, action: nil, for: .allEvents)
            delegate?.keyplaneWireInputModeSwitchButton(btn)
        }
    }

    private func wireShift(_ btn: AppleKeyButton) {
        let double = UITapGestureRecognizer(target: self, action: #selector(shiftDoubleTap))
        double.numberOfTapsRequired = 2
        let single = UITapGestureRecognizer(target: self, action: #selector(shiftSingleTap))
        single.require(toFail: double)
        btn.addGestureRecognizer(double)
        btn.addGestureRecognizer(single)
    }

    private func visitKeys(_ block: (UIView) -> Void) {
        func walk(_ view: UIView) {
            if let stack = view as? UIStackView {
                stack.arrangedSubviews.forEach { walk($0) }
                return
            }
            if view is AppleLetterKeyControl || view is AppleKeyButton {
                block(view)
            }
        }
        rowsStack.arrangedSubviews.forEach { walk($0) }
    }

    // MARK: - Actions

    @objc private func letterTapped(_ sender: AppleLetterKeyControl) {
        if suppressNextLetterTap {
            suppressNextLetterTap = false
            return
        }
        let out = shiftPhase != .off ? String(sender.baseLetter).uppercased() : String(sender.baseLetter)
        delegate?.keyplaneInsertText(out)
        clearOneShotShift()
    }

    @objc private func outputTapped(_ sender: AppleKeyButton) {
        guard let out = sender.outputValue else { return }
        delegate?.keyplaneInsertText(out)
        clearOneShotShift()
    }

    @objc private func functionalTapped(_ sender: AppleKeyButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        switch id {
        case "kb_space":
            delegate?.keyplaneInsertText(" ")
            clearOneShotShift()
        case "kb_return":
            delegate?.keyplaneInsertText("\n")
            clearOneShotShift()
        case "kb_123":
            keyplane = .numbers
            numbersPage = 0
            rebuild()
        case "kb_ABC":
            keyplane = .letters
            numbersPage = 0
            rebuild()
        case "kb_sym_page":
            numbersPage = numbersPage == 0 ? 1 : 0
            rebuild()
        default:
            break
        }
    }

    @objc private func shiftSingleTap() {
        switch shiftPhase {
        case .locked, .oneShot: shiftPhase = .off
        case .off: shiftPhase = .oneShot
        }
        refreshShiftSymbol()
        refreshLetterCaps()
        applyAppearance()
    }

    @objc private func shiftDoubleTap() {
        shiftPhase = shiftPhase == .locked ? .off : .locked
        refreshShiftSymbol()
        refreshLetterCaps()
        applyAppearance()
    }

    @objc private func deleteDown() {
        stopDeleteRepeat()
        delegate?.keyplaneDeleteBackward()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
                self?.delegate?.keyplaneDeleteBackward()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.deleteRepeatTimer = timer
        }
        deleteRepeatStartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: work)
    }

    @objc private func deleteUp() {
        stopDeleteRepeat()
    }

    private func stopDeleteRepeat() {
        deleteRepeatStartWork?.cancel()
        deleteRepeatStartWork = nil
        deleteRepeatTimer?.invalidate()
        deleteRepeatTimer = nil
    }

    private func clearOneShotShift() {
        guard shiftPhase == .oneShot else { return }
        shiftPhase = .off
        refreshShiftSymbol()
        refreshLetterCaps()
        applyAppearance()
    }

    private func refreshShiftSymbol() {
        guard let btn = shiftButton else { return }
        switch shiftPhase {
        case .off: btn.symbolName = "shift"
        case .oneShot: btn.symbolName = "shift.fill"
        case .locked: btn.symbolName = "capslock.fill"
        }
    }

    private func refreshLetterCaps() {
        guard keyplane == .letters else { return }
        let upper = shiftPhase != .off
        visitKeys { view in
            (view as? AppleLetterKeyControl)?.applyCaps(uppercase: upper)
        }
    }

    func refreshLocalizedTitles() {
        visitKeys { view in
            guard let btn = view as? AppleKeyButton, btn.accessibilityIdentifier == "kb_return" else { return }
            btn.titleText = delegate?.keyplaneLocalized("keyboard.key_return")
        }
    }

    private func applyKeyColors(isDark: Bool) {
        let palette = KeyboardNativePalette.colors(isDark: isDark)
        visitKeys { view in
            if let letter = view as? AppleLetterKeyControl {
                letter.applyColors(normal: palette.letterKey, pressed: palette.letterKeyPressed, text: palette.primaryText)
            } else if let btn = view as? AppleKeyButton {
                let isReturn = btn.accessibilityIdentifier == "kb_return"
                let kind: AppleKeyButton.Kind = isReturn ? .returnKey : isFunctional(btn) ? .functional : .letter
                styleFunctionalKey(btn, kind: kind, isReturn: isReturn)
            }
        }
    }

    private func isFunctional(_ btn: AppleKeyButton) -> Bool {
        guard let id = btn.accessibilityIdentifier else { return false }
        return ["kb_shift", "kb_delete", "kb_123", "kb_ABC", "kb_return", "kb_sym_page", "kb_space", "kb_globe"].contains(id)
    }

    private func applyStaggeredInsets() {
        let inset = metrics.staggerInset
        for row in rowsStack.arrangedSubviews {
            guard let stack = row as? UIStackView,
                  stack.accessibilityIdentifier == Self.staggeredRowID
            else { continue }
            stack.layoutMargins = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        }
    }

    // MARK: - Long-press alternates

    private func attachLongPress(to view: UIView, base: Character) {
        let region = KeyboardUIRegion.inferredFromPreferredLanguages()
        guard !region.alternates(forBaseLetter: base).isEmpty else { return }
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        lp.minimumPressDuration = 0.38
        lp.cancelsTouchesInView = false
        view.addGestureRecognizer(lp)
    }

    @objc private func longPress(_ g: UILongPressGestureRecognizer) {
        guard keyplane == .letters else { return }
        let ch: Character? = (g.view as? AppleLetterKeyControl)?.baseLetter
        guard let ch else { return }
        let alts = KeyboardUIRegion.inferredFromPreferredLanguages().alternates(forBaseLetter: ch)
        guard !alts.isEmpty, let source = g.view else { return }

        switch g.state {
        case .began:
            hideAlternates()
            showAlternates(alts, source: source)
        case .changed:
            if let host = alternatesHost {
                highlightAlternate(at: g.location(in: host))
            }
        case .ended:
            var picked = false
            if let host = alternatesHost {
                picked = pickAlternate(at: g.location(in: host))
            }
            hideAlternates()
            if picked { suppressNextLetterTap = true }
        case .cancelled, .failed:
            hideAlternates()
        default:
            break
        }
    }

    private func showAlternates(_ options: [String], source: UIView) {
        alternatesOptions = options
        alternatesCells = []
        let palette = KeyboardNativePalette.colors(isDark: delegate?.keyplaneIsDark() ?? false)
        let btnFrame = source.convert(source.bounds, to: self)
        let margin: CGFloat = 8
        let interKey: CGFloat = 5
        let padH: CGFloat = 10
        let padV: CGFloat = 8
        let keyH: CGFloat = 48
        let n = options.count

        var keyW = max(36, floor(source.bounds.width))
        var barW = padH * 2 + CGFloat(n) * keyW + CGFloat(max(0, n - 1)) * interKey
        let maxW = bounds.width - margin * 2
        if barW > maxW, n > 0 {
            keyW = max(32, floor((maxW - padH * 2 - CGFloat(max(0, n - 1)) * interKey) / CGFloat(n)))
            barW = padH * 2 + CGFloat(n) * keyW + CGFloat(max(0, n - 1)) * interKey
        }

        let host = UIView()
        host.backgroundColor = palette.alternateTray
        host.layer.cornerRadius = 10
        if #available(iOS 13.0, *) { host.layer.cornerCurve = .continuous }
        host.clipsToBounds = true
        host.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = interKey
        stack.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)

        for opt in options {
            let cell = UIView()
            cell.backgroundColor = palette.alternateKey
            cell.layer.cornerRadius = 5
            if #available(iOS 13.0, *) { cell.layer.cornerCurve = .continuous }
            cell.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = opt
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 24)
            label.textColor = palette.alternateText
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)

            NSLayoutConstraint.activate([
                cell.widthAnchor.constraint(equalToConstant: keyW),
                cell.heightAnchor.constraint(equalToConstant: keyH),
                label.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            stack.addArrangedSubview(cell)
            alternatesCells.append(cell)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: padH),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -padH),
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: padV),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -padV),
        ])

        addSubview(host)
        alternatesHost = host
        bringSubviewToFront(host)

        let hostHeight = padV * 2 + keyH
        var x = btnFrame.midX - barW / 2
        x = max(margin, min(x, bounds.width - margin - barW))
        var y = btnFrame.minY - hostHeight - 12
        if y < margin { y = min(btnFrame.maxY + 12, bounds.height - hostHeight - margin) }

        NSLayoutConstraint.activate([
            host.widthAnchor.constraint(equalToConstant: barW),
            host.heightAnchor.constraint(equalToConstant: hostHeight),
            host.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
            host.topAnchor.constraint(equalTo: topAnchor, constant: y),
        ])
    }

    private func highlightAlternate(at point: CGPoint) {
        guard let host = alternatesHost else { return }
        let p = convert(point, from: host)
        let palette = KeyboardNativePalette.colors(isDark: delegate?.keyplaneIsDark() ?? false)
        for cell in alternatesCells {
            let frame = cell.convert(cell.bounds, to: self)
            cell.backgroundColor = frame.contains(p) ? palette.alternateKeyHighlighted : palette.alternateKey
        }
    }

    @discardableResult
    private func pickAlternate(at point: CGPoint) -> Bool {
        guard let host = alternatesHost else { return false }
        let p = convert(point, from: host)
        for (i, cell) in alternatesCells.enumerated() {
            let frame = cell.convert(cell.bounds, to: self)
            if frame.contains(p), i < alternatesOptions.count {
                delegate?.keyplaneInsertText(alternatesOptions[i])
                clearOneShotShift()
                return true
            }
        }
        return false
    }

    private func hideAlternates() {
        alternatesHost?.removeFromSuperview()
        alternatesHost = nil
        alternatesOptions = []
        alternatesCells = []
    }
}
