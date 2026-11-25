import AppKit
import ApplicationServices

/// Starts games in RPCS3 (no GUI, fullscreen) and brings PlayHub back when they close.
final class GameLauncher: ObservableObject {
    @Published private(set) var running: Game?
    @Published private(set) var launching = false
    @Published var errorMessage: String? {
        didSet {
            guard let msg = errorMessage else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                if self?.errorMessage == msg { self?.errorMessage = nil }
            }
        }
    }

    var onFinished: ((Game, TimeInterval) -> Void)?

    static let rpcs3App = URL(fileURLWithPath: "/Applications/RPCS3.app")

    private var app: NSRunningApplication?
    private var startDate: Date?

    var elapsedText: String {
        guard let startDate else { return "0 dk" }
        return Format.duration(Date().timeIntervalSince(startDate))
    }

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] n in
            guard let self,
                  let term = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let app = self.app, term.processIdentifier == app.processIdentifier else { return }
            self.finished()
        }
    }

    private var otherRPCS3Running: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.lastPathComponent == "RPCS3.app" && $0.processIdentifier != app?.processIdentifier
        }
    }

    func launch(_ game: Game) {
        if let current = running {
            if current.id == game.id { focusGame() } else {
                errorMessage = "Önce çalışan oyunu kapat: \(current.title)"
            }
            return
        }
        guard FileManager.default.fileExists(atPath: Self.rpcs3App.path) else {
            errorMessage = "RPCS3 bulunamadı (/Applications/RPCS3.app)."
            return
        }
        guard FileManager.default.fileExists(atPath: game.bootPath.path) else {
            errorMessage = "Oyun dosyaları bulunamadı. Harici disk bağlı mı?"
            return
        }
        guard !otherRPCS3Running else {
            errorMessage = "RPCS3 zaten açık. Önce RPCS3 penceresini kapat (⌘Q)."
            return
        }

        let wantFullscreen = AppSettings.shared.fullscreenGames
        let cfg = NSWorkspace.OpenConfiguration()
        var args: [String] = ["--no-gui"]
        if wantFullscreen {
            args.append("--fullscreen")
            Self.enforceRPCS3FullScreenINI()
        }
        if let customCfg = PerfProfileStore.shared.writeRPCS3Config(for: game.titleID) {
            args.append(contentsOf: ["--config", customCfg.path])
        }
        args.append(game.bootPath.path)
        cfg.arguments = args
        cfg.createsNewApplicationInstance = true
        cfg.activates = true

        running = game
        launching = true
        startDate = Date()
        AudioManager.shared.gameRunning = true

        // Hide Zinkx Arena's borderless window on the current Space before spawning RPCS3
        // so macOS never rejects RPCS3's fullscreen request due to Space contention.
        AppDelegate.prepareForGameLaunch()

        NSWorkspace.shared.openApplication(at: Self.rpcs3App, configuration: cfg) { [weak self] app, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.running = nil
                    self.launching = false
                    AudioManager.shared.gameRunning = false
                    AppDelegate.restoreFromGame()
                    self.errorMessage = "Oyun başlatılamadı: \(error.localizedDescription)"
                    return
                }
                self.app = app
                app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                if app?.isTerminated == true {
                    self.finished()
                } else if wantFullscreen, let app {
                    self.scheduleFullscreenWatchdog(for: app)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.launching = false }
    }

    func focusGame() {
        app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    /// Closes the running game (like quitting from the PS home menu).
    func stop() {
        guard let app, !app.isTerminated else { return }
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if !app.isTerminated { app.forceTerminate() }
        }
    }

    private func finished() {
        InGameOverlayManager.shared.hide(refocusGame: false)
        guard let game = running else { return }
        let seconds = Date().timeIntervalSince(startDate ?? Date())
        WrapUpStore.shared.recordPlaytime(seconds: seconds)
        running = nil
        launching = false
        app = nil
        AudioManager.shared.gameRunning = false
        if seconds < 4 {
            errorMessage = "\(game.title) açılamadı. RPCS3'ü normal açıp oyunu oradan dene."
        }
        onFinished?(game, seconds)
        AppDelegate.restoreFromGame()
    }

    /// Watches RPCS3's game window during startup and sets AXFullScreen=true if needed (never toggles off).
    private func scheduleFullscreenWatchdog(for rpcs3: NSRunningApplication) {
        let pid = rpcs3.processIdentifier
        for delay in [1.5, 3.0, 5.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      let current = self.app,
                      current.processIdentifier == pid,
                      !current.isTerminated else { return }
                self.ensureRPCS3WindowIsFullScreen(app: current)
            }
        }
    }

    private func ensureRPCS3WindowIsFullScreen(app: NSRunningApplication) {
        let pid = app.processIdentifier
        let targetScreen = AppSettings.shared.targetScreen ?? NSScreen.main
        let screenFrame = targetScreen?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let primaryH = NSScreen.screens.first?.frame.height ?? screenFrame.height
        let targetCGOriginX = screenFrame.minX
        let targetCGOriginY = primaryH - screenFrame.maxY

        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var gameWindowBounds: CGRect?
        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let w = boundsDict["Width"],
                  let h = boundsDict["Height"],
                  w >= 400, h >= 300 else { continue }
            gameWindowBounds = CGRect(x: x, y: y, width: w, height: h)
            break
        }

        guard let bounds = gameWindowBounds else { return }
        let onTargetScreen = abs(bounds.minX - targetCGOriginX) <= 8 && abs(bounds.minY - targetCGOriginY) <= 4
        let isAlreadyFullScreen = onTargetScreen && bounds.height >= screenFrame.height - 4 && bounds.width >= screenFrame.width - 4
        guard !isAlreadyFullScreen else { return }

        app.activate()

        // Set window position to target monitor and AXFullScreen = true idempotently.
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement],
           let firstWin = windows.first {
            if !onTargetScreen {
                var pt = CGPoint(x: targetCGOriginX, y: targetCGOriginY)
                if let posVal = AXValueCreate(.cgPoint, &pt) {
                    _ = AXUIElementSetAttributeValue(firstWin, kAXPositionAttribute as CFString, posVal)
                }
            }
            _ = AXUIElementSetAttributeValue(firstWin, "AXFullScreen" as CFString, kCFBooleanTrue)
        }
    }

    /// Ensures RPCS3's GuiConfigs/CurrentSettings.ini has [GSFrame] screen, visibility=FullScreen and full screen geometry for the chosen monitor.
    static func enforceRPCS3FullScreenINI() {
        let iniURL = GameLibrary.rpcs3Dir.appendingPathComponent("GuiConfigs/CurrentSettings.ini")
        guard var text = try? String(contentsOf: iniURL, encoding: .utf8) else { return }
        let idx = AppSettings.shared.targetScreenIndex
        let screen = (AppSettings.shared.targetScreen ?? NSScreen.main)?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.height
        let qtX = Int(screen.minX)
        let qtY = Int(primaryH - screen.maxY)
        let w = Int(screen.width)
        let h = Int(screen.height)

        if let gsRange = text.range(of: "[GSFrame]") {
            let afterGS = text[gsRange.upperBound...]
            let nextSection = afterGS.range(of: "\n[")?.lowerBound ?? text.endIndex
            var section = String(text[gsRange.upperBound..<nextSection])
            section = section.replacingOccurrences(of: "visibility=Windowed", with: "visibility=FullScreen")
            section = section.replacingOccurrences(of: "visibility=Maximized", with: "visibility=FullScreen")
            if !section.contains("visibility=") {
                section += "\nvisibility=FullScreen"
            }
            if let screenRegex = try? NSRegularExpression(pattern: "(?m)^screen=\\d+$") {
                let range = NSRange(section.startIndex..<section.endIndex, in: section)
                if screenRegex.firstMatch(in: section, range: range) != nil {
                    section = screenRegex.stringByReplacingMatches(in: section, range: range, withTemplate: "screen=\(idx)")
                } else {
                    section += "\nscreen=\(idx)"
                }
            }
            if let geomRegex = try? NSRegularExpression(pattern: "(?m)^geometry=@Rect\\([^\\)]*\\)$") {
                let range = NSRange(section.startIndex..<section.endIndex, in: section)
                if geomRegex.firstMatch(in: section, range: range) != nil {
                    section = geomRegex.stringByReplacingMatches(
                        in: section, range: range, withTemplate: "geometry=@Rect(\(qtX) \(qtY) \(w) \(h))"
                    )
                } else {
                    section += "\ngeometry=@Rect(\(qtX) \(qtY) \(w) \(h))"
                }
            }
            text.replaceSubrange(gsRange.upperBound..<nextSection, with: section)
            try? text.write(to: iniURL, atomically: true, encoding: .utf8)
        }
    }
}
