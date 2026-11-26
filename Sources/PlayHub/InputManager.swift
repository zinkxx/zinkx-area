import AppKit
import GameController

enum NavAction {
    case left, right, up, down, confirm, back, triangle, square, options, l1, r1
}

/// Turns gamepad (DualShock/DualSense/Xbox) and keyboard input into menu navigation.
final class InputManager: ObservableObject {
    @Published var controllerName: String?
    @Published var batteryLevel: Float?
    private(set) var lastInput = Date()
    /// While true (e.g. a text form is open) menu navigation is paused.
    var suspended = false

    var onAction: ((NavAction) -> Void)?
    /// Called on any input first; return true to swallow it (e.g. waking the screensaver).
    /// `deliberate` is false for plain mouse movement.
    var onActivity: ((_ deliberate: Bool) -> Bool)?
    /// Fired when Share + Options are held for 1.5 s (works while a game is in front).
    var onCloseCombo: (() -> Void)?

    private var dpadDir: NavAction?
    private var stickDir: NavAction?
    private var heldDir: NavAction?
    private var repeatTimer: Timer?
    private var comboTimer: Timer?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var infoTimer: Timer?

    init() {
        GCController.shouldMonitorBackgroundEvents = true

        let nc = NotificationCenter.default
        nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            guard !AppDelegate.isGameActive else { return }
            if let c = n.object as? GCController {
                self?.setup(c)
                self?.syncLightbar()
                ToastCenter.shared.show(
                    icon: "gamecontroller.fill",
                    title: L("Kontrolcü Bağlandı"),
                    subtitle: c.vendorName ?? L("Kablosuz Kontrolcü")
                )
            }
        }
        nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            guard !AppDelegate.isGameActive else { return }
            self?.refreshInfo()
            ToastCenter.shared.show(
                icon: "gamecontroller",
                title: L("Kontrolcü Bağlantısı Kesildi"),
                subtitle: L("Bluetooth bağlantısını kontrol et")
            )
        }
        GCController.controllers().forEach { setup($0) }
        syncLightbar()
        refreshInfo()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, NSApp.modalWindow == nil, !self.suspended else { return e }
            if e.modifierFlags.contains(.command) && e.charactersIgnoringModifiers?.lowercased() == "e" {
                AudioManager.shared.play(.confirm)
                AppSettings.shared.cycleScreen(1)
                return nil
            }
            if let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.isEditable { return e }
            if !e.modifierFlags.intersection([.command, .control, .option]).isEmpty { return e }
            let map: [UInt16: NavAction] = [
                123: .left, 124: .right, 125: .down, 126: .up,
                36: .confirm, 76: .confirm, 49: .confirm,
                53: .back, 51: .back, 17: .triangle, 3: .square, 48: .options,
                12: .l1, 14: .r1,
            ]
            if let a = map[e.keyCode] { self.fire(a); return nil }
            return e
        }

        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .scrollWheel]) { [weak self] e in
            guard let self else { return e }
            self.lastInput = Date()
            let click = e.type == .leftMouseDown
            if self.onActivity?(click) == true, click { return nil }
            return e
        }

        infoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, !AppDelegate.isGameActive else { return }
            self.rebindControllers()
        }
    }

    func rebindControllers(force: Bool = false) {
        for c in GCController.controllers() {
            if force || c.extendedGamepad?.buttonA.pressedChangedHandler == nil {
                setup(c)
            }
        }
        refreshInfo()
    }

    private func setup(_ c: GCController) {
        c.handlerQueue = .main
        if c.playerIndex == .indexUnset {
            c.playerIndex = .index1
        }
        refreshInfo()
        guard let pad = c.extendedGamepad else { return }

        pad.dpad.valueChangedHandler = { [weak self] _, x, y in
            guard !AppDelegate.isGameActive || InGameOverlayManager.shared.isVisible else {
                self?.dpadDir = nil
                self?.updateHeld()
                return
            }
            self?.dpadDir = Self.direction(x, y, current: self?.dpadDir, activeThreshold: 0.35, releaseThreshold: 0.20)
            self?.updateHeld()
        }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard !AppDelegate.isGameActive || InGameOverlayManager.shared.isVisible else {
                self?.stickDir = nil
                self?.updateHeld()
                return
            }
            self?.stickDir = Self.direction(x, y, current: self?.stickDir, activeThreshold: 0.32, releaseThreshold: 0.18)
            self?.updateHeld()
        }
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, p in if p { self?.fire(.confirm) } }
        pad.buttonB.pressedChangedHandler = { [weak self] _, _, p in if p { self?.fire(.back) } }
        pad.buttonY.pressedChangedHandler = { [weak self] _, _, p in if p { self?.fire(.triangle) } }
        pad.buttonX.pressedChangedHandler = { [weak self] _, _, p in if p { self?.fire(.square) } }
        pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, p in if p { self?.fire(.l1) } }
        pad.rightShoulder.pressedChangedHandler = { [weak self] _, _, p in if p { self?.fire(.r1) } }
        pad.buttonMenu.pressedChangedHandler = { [weak self, weak pad] _, _, p in
            guard let self, let pad else { return }
            let comboActive = pad.buttonOptions?.isPressed ?? false
            if p && !comboActive { self.fire(.options) }
            self.checkCombo(pad)
        }
        pad.buttonOptions?.pressedChangedHandler = { [weak self, weak pad] _, _, _ in
            guard let self, let pad else { return }
            self.checkCombo(pad)
        }
        pad.buttonMenu.preferredSystemGestureState = .disabled
        pad.buttonOptions?.preferredSystemGestureState = .disabled
        pad.buttonHome?.preferredSystemGestureState = .disabled
        pad.buttonHome?.pressedChangedHandler = { [weak self] _, _, p in
            if p { self?.onCloseCombo?() }
        }
    }

    private static func direction(_ x: Float, _ y: Float, current: NavAction?, activeThreshold: Float, releaseThreshold: Float) -> NavAction? {
        let threshold = (current == nil) ? activeThreshold : releaseThreshold
        if abs(x) < threshold && abs(y) < threshold { return nil }
        if abs(x) >= abs(y) { return x > 0 ? .right : .left }
        return y > 0 ? .up : .down
    }

    private func updateHeld() {
        let dir = dpadDir ?? stickDir
        guard dir != heldDir else { return }
        heldDir = dir
        repeatTimer?.invalidate()
        repeatTimer = nil
        guard let dir else { return }
        fire(dir)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.24, repeats: false) { [weak self] _ in
            self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.fire(dir)
            }
        }
    }

    private func checkCombo(_ pad: GCExtendedGamepad) {
        let both = AppSettings.shared.closeComboEnabled
            && pad.buttonMenu.isPressed && (pad.buttonOptions?.isPressed ?? false)
        if both {
            guard comboTimer == nil else { return }
            comboTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.comboTimer = nil
                self?.onCloseCombo?()
            }
        } else {
            comboTimer?.invalidate()
            comboTimer = nil
        }
    }

    private func fire(_ action: NavAction) {
        if InGameOverlayManager.shared.isVisible {
            InGameOverlayManager.shared.handle(action)
            return
        }
        // Only navigate when no game is running in RPCS3.
        guard !AppDelegate.isGameActive, NSApp.modalWindow == nil, !suspended else { return }
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
            AppDelegate.mainWindow?.makeKeyAndOrderFront(nil)
        }
        NSCursor.setHiddenUntilMouseMoves(true)
        lastInput = Date()
        if onActivity?(true) == true { return }
        onAction?(action)
    }

    func syncLightbar(_ choice: AccentChoice = AppSettings.shared.accent) {
        guard !AppDelegate.isGameActive else { return }
        let (r, g, b) = choice.rgb
        for c in GCController.controllers() {
            c.light?.color = GCColor(red: r, green: g, blue: b)
        }
    }

    private func refreshInfo() {
        if CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--export-screenshots") {
            controllerName = "DualShock 4"
            batteryLevel = 0.85
            return
        }
        guard !AppDelegate.isGameActive else { return }
        let c = GCController.current ?? GCController.controllers().first
        controllerName = c?.vendorName
        if let level = c?.battery?.batteryLevel, level > 0 {
            batteryLevel = level
        } else {
            batteryLevel = nil
        }
    }
}
