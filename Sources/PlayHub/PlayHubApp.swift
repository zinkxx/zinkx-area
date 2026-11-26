import SwiftUI
import AppKit

@main
struct PlayHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

/// Custom borderless fullscreen console window that never triggers SwiftUI.AppKitWindow constraint loops.
final class ConsoleWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Observable mirror of `AppDelegate.isGameActive` so views can pause continuous
/// animations while RPCS3 is in front (the hidden window keeps rendering otherwise).
final class GameActivity: ObservableObject {
    static let shared = GameActivity()
    @Published private(set) var isActive = false
    fileprivate func set(_ active: Bool) { if isActive != active { isActive = active } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isGameActive = false {
        didSet {
            GameActivity.shared.set(isGameActive)
            GameMediaStore.setPaused(isGameActive)
        }
    }
    static private(set) var mainWindow: ConsoleWindow?
    static private(set) var shared: AppDelegate?

    private let settings = AppSettings.shared
    private let library = GameLibrary()
    let input = InputManager()
    private let launcher = GameLauncher()
    private let details = DetailsStore()

    func applicationWillFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame main")
        NSApp.setActivationPolicy(.regular)
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--export-screenshots"), idx + 1 < args.count {
            let outDir = URL(fileURLWithPath: args[idx + 1])
            DemoShowcase.populate(library: library, details: details, settings: settings)
            DemoShowcase.exportAllScreenshots(
                to: outDir,
                library: library,
                details: details,
                settings: settings,
                input: input,
                launcher: launcher
            )
            NSApp.terminate(nil)
            return
        }
        if args.contains("--demo") {
            DemoShowcase.populate(library: library, details: details, settings: settings)
        }
        _ = AudioManager.shared
        createConsoleWindow()
        Self.ensureFullScreen()
        NSApp.activate(ignoringOtherApps: true)
        input.rebindControllers()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Self.ensureFullScreen()
        }

        for delay in [0.1, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Self.ensureFullScreen()
                self.input.rebindControllers()
            }
        }
    }

    private func createConsoleWindow() {
        guard Self.mainWindow == nil else { return }
        let targetScreen = AppSettings.shared.targetScreen ?? NSScreen.main
        let screenFrame = targetScreen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let win = ConsoleWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Zinkx Arena"
        win.isReleasedWhenClosed = false
        win.isRestorable = false
        win.backgroundColor = .black
        win.isOpaque = true
        win.hasShadow = false
        win.isMovable = false
        win.level = .normal
        win.collectionBehavior = [.fullScreenAuxiliary, .stationary, .ignoresCycle]

        let rootView = HomeView()
            .environmentObject(settings)
            .environmentObject(details)
            .environmentObject(library)
            .environmentObject(input)
            .environmentObject(launcher)
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: rootView)
        // Disable NSHostingView intrinsic window sizing to prevent AppKit constraint update loops.
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: screenFrame.size)
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        Self.mainWindow = win
        win.setFrame(screenFrame, display: true)
        win.makeKeyAndOrderFront(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if !Self.isGameActive {
            Self.ensureFullScreen()
            input.rebindControllers()
        }
    }

    static func ensureFullScreen() {
        guard !isGameActive else { return }
        guard let w = mainWindow else { return }

        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        w.level = .normal
        if let screen = AppSettings.shared.targetScreen ?? NSScreen.main ?? w.screen {
            if w.frame != screen.frame {
                w.setFrame(screen.frame, display: true, animate: false)
            }
        }
        if !w.isVisible || !w.isKeyWindow {
            w.makeKeyAndOrderFront(nil)
        }
    }

    /// Hides the console window cleanly in 0ms on the same Space so RPCS3 can enter fullscreen without Space contention.
    static func prepareForGameLaunch() {
        isGameActive = true
        NSApp.presentationOptions = []
        mainWindow?.orderOut(nil)
    }

    /// Restores the console window immediately after RPCS3 exits.
    static func restoreFromGame() {
        isGameActive = false
        NSApp.activate(ignoringOtherApps: true)
        ensureFullScreen()
        shared?.input.rebindControllers(force: true)
        for delay in [0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                shared?.input.rebindControllers(force: true)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !Self.isGameActive {
            Self.ensureFullScreen()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
