import SwiftUI
import AppKit
import GameController

// MARK: - 1. Per-Game RPCS3 Performance Profiles (5b)

enum PerfResolution: Int, CaseIterable {
    case perf540 = 75
    case native720 = 100
    case hd1080 = 150
    case qhd1440 = 200

    var label: String {
        switch self {
        case .perf540: L("540p (%75 · Hızlı)")
        case .native720: L("720p (%100 · Doğal)")
        case .hd1080: L("1080p (%150 · Full HD)")
        case .qhd1440: L("1440p (%200 · 2K)")
        }
    }

    func step(_ d: Int) -> Self {
        let all = Self.allCases
        let i = all.firstIndex(of: self) ?? 1
        return all[(i + d + all.count) % all.count]
    }
}

enum PerfFPS: String, CaseIterable {
    case auto = "Auto"
    case fps30 = "30"
    case fps60 = "60"
    case off = "Off"

    var label: String {
        switch self {
        case .auto: L("Otomatik")
        case .fps30: "30 FPS"
        case .fps60: "60 FPS"
        case .off: L("Limitsiz")
        }
    }

    func step(_ d: Int) -> Self {
        let all = Self.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + d + all.count) % all.count]
    }
}

enum PerfShader: String, CaseIterable {
    case fastAsync = "Async Recompiler (multi-threaded)"
    case legacy = "Legacy Recompiler (single-threaded)"

    var label: String {
        switch self {
        case .fastAsync: L("Çok Çekirdekli (Önerilen · Async)")
        case .legacy: L("Tek Çekirdekli (Kararlı · Legacy)")
        }
    }

    func step(_ d: Int) -> Self {
        self == .fastAsync ? .legacy : .fastAsync
    }
}

struct GamePerfProfile: Codable, Equatable {
    var resolutionScale: Int = 100
    var frameLimit: String = "Auto"
    var shaderMode: String = "Async Recompiler (multi-threaded)"

    var res: PerfResolution {
        get { PerfResolution(rawValue: resolutionScale) ?? .native720 }
        set { resolutionScale = newValue.rawValue }
    }
    var fps: PerfFPS {
        get { PerfFPS(rawValue: frameLimit) ?? .auto }
        set { frameLimit = newValue.rawValue }
    }
    var shader: PerfShader {
        get { PerfShader(rawValue: shaderMode) ?? .fastAsync }
        set { shaderMode = newValue.rawValue }
    }
}

final class PerfProfileStore: ObservableObject {
    static let shared = PerfProfileStore()
    @Published private(set) var profiles: [String: GamePerfProfile] = [:]

    private let key = "gamePerfProfiles_v3"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: GamePerfProfile].self, from: data) {
            profiles = decoded
        }
    }

    func profile(for titleID: String) -> GamePerfProfile {
        profiles[titleID] ?? GamePerfProfile()
    }

    func update(_ titleID: String, _ block: (inout GamePerfProfile) -> Void) {
        var p = profile(for: titleID)
        block(&p)
        profiles[titleID] = p
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: key)
        }
        _ = writeRPCS3Config(for: titleID, profile: p)
    }

    /// Generates an RPCS3 custom config file for this game if customized.
    func writeRPCS3Config(for titleID: String, profile: GamePerfProfile? = nil) -> URL? {
        let p = profile ?? self.profile(for: titleID)
        let baseConfig = GameLibrary.rpcs3Dir.appendingPathComponent("config.yml")
        guard var yml = try? String(contentsOf: baseConfig, encoding: .utf8) else { return nil }

        let validShader = PerfShader(rawValue: p.shaderMode)?.rawValue ?? PerfShader.fastAsync.rawValue
        // GTA IV family (RAGE engine, heavy SPU streaming).
        // - Write Color Buffers stays on, as before.
        // - Relaxed ZCULL Sync must stay off: with it the boot stage never advances (black screen).
        //   Known issue without it: an occasional freeze on Apple M1 with the PPU stuck in
        //   ZCULL_control::on_access_violation -> rsx::thread::pause (PPU/RSX deadlock).
        // - Accurate XFloat and Driver Wake-Up Delay 100 are kept as before (verified working).
        //   The game is SPU-bound on Apple M1 (overlay: SPU ~64%, RSX ~14%); Approximate XFloat
        //   is the main untested lever for more speed.
        let gta4Titles: Set<String> = ["BLES01128", "BLES00229", "BLUS30127", "BLUS30418", "NPUB30702", "NPEB00882"]
        let isGTA4 = gta4Titles.contains(titleID.uppercased())

        yml = replaceYAML(yml, key: "Resolution Scale", value: "\(p.resolutionScale)")
        yml = replaceYAML(yml, key: "Frame limit", value: p.frameLimit)
        yml = replaceYAML(yml, key: "Shader Mode", value: validShader)
        yml = replaceYAML(yml, key: "VSync Mode", value: "Adaptive")
        yml = replaceYAML(yml, key: "Start games in fullscreen mode", value: AppSettings.shared.fullscreenGames ? "true" : "false")

        yml = replaceYAML(yml, key: "SPU XFloat Accuracy", value: isGTA4 ? "Accurate" : "Approximate")
        yml = replaceYAML(yml, key: "SPU loop detection", value: "false")
        yml = replaceYAML(yml, key: "SPU Block Size", value: "Safe")
        yml = replaceYAML(yml, key: "Preferred SPU Threads", value: "0")
        yml = replaceYAML(yml, key: "Max SPURS Threads", value: "6")
        yml = replaceYAML(yml, key: "Max LLVM Compile Threads", value: "0")
        yml = replaceYAML(yml, key: "Shader Compiler Threads", value: "0")
        yml = replaceYAML(yml, key: "Driver Wake-Up Delay", value: isGTA4 ? "100" : "0")
        yml = replaceYAML(yml, key: "MSAA", value: "Auto")
        // Image quality on high-DPI Macs: the 720p frame is upscaled to the Retina panel with FSR
        // instead of a blurry bilinear stretch, and 16x anisotropic filtering keeps roads and
        // distant textures sharp. Both are cheap on the GPU (games here are CPU/SPU-bound).
        yml = replaceYAML(yml, key: "Output Scaling Mode", value: "FidelityFX Super Resolution")
        yml = replaceYAML(yml, key: "Anisotropic Filter Override", value: "16")
        yml = replaceYAML(yml, key: "Shader Precision", value: "High")
        yml = replaceYAML(yml, key: "Multithreaded RSX", value: "false")
        yml = replaceYAML(yml, key: "Accurate ZCULL stats", value: "false")
        yml = replaceYAML(yml, key: "Relaxed ZCULL Sync", value: "false")
        yml = replaceYAML(yml, key: "Asynchronous Texture Streaming", value: "false")
        yml = replaceYAML(yml, key: "Sleep Timers Accuracy", value: "As Host")
        yml = replaceYAML(yml, key: "Enable Time Stretching", value: "true")
        yml = replaceYAML(yml, key: "Time Stretching Threshold", value: "75")
        yml = replaceYAML(yml, key: "Desired Audio Buffer Duration", value: isGTA4 ? "200" : "150")
        yml = replaceYAML(yml, key: "Convert to 16 bit", value: "false")

        yml = replaceYAML(yml, key: "Write Color Buffers", value: isGTA4 ? "true" : "false")

        // Diagnostics: RPCS3 does not log FPS, so show its on-screen performance overlay (FPS, frame time, CPU per PPU/SPU/RSX).
        // Display-only; does not affect emulation.
        if let re = try? NSRegularExpression(pattern: "(Performance Overlay:\\s*\\n\\s*Enabled:\\s*)\\w+") {
            yml = re.stringByReplacingMatches(in: yml, range: NSRange(yml.startIndex..<yml.endIndex, in: yml), withTemplate: "$1true")
        }
        yml = replaceYAML(yml, key: "Enable Framerate Graph", value: "true")

        let dir = GameLibrary.rpcs3Dir.appendingPathComponent("custom_configs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent("config_\(titleID).yml")
        try? yml.write(to: out, atomically: true, encoding: .utf8)
        return out
    }

    private func replaceYAML(_ text: String, key: String, value: String) -> String {
        let pattern = "(?m)^(\\s*\(NSRegularExpression.escapedPattern(for: key)):\\s*).*$"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let escapedValue = NSRegularExpression.escapedTemplate(for: value)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: "$1\(escapedValue)")
    }
}

// MARK: - 2. Smart DualShock 4 Manager (Ambilight, Police Siren, Trophy Gold Flash, Battery Alert)

enum LightbarEffect: String, CaseIterable {
    case ambilight, theme, siren, gold
    var title: String {
        switch self {
        case .ambilight: L("Oyun Rengi (Ambilight)")
        case .theme: L("Tema Rengi")
        case .siren: L("Polis Sireni (NFS)")
        case .gold: L("Altın Kupa")
        }
    }
}

final class SmartDS4Manager: ObservableObject {
    static let shared = SmartDS4Manager()

    @Published var effect: LightbarEffect = .ambilight
    @Published private(set) var currentGameColor: Color = Color(red: 0, green: 0.44, blue: 0.95)

    private var colorCache: [String: (Float, Float, Float)] = [:]
    private var lastSentRGB: (Int, Int, Int)?
    private var effectTimer: Timer?
    private var sirenPhase = false
    private var warnedLowBattery = false
    private var trophyWatcherTimer: Timer?
    private var knownUnlockedCount: Int?

    private init() {
        trophyWatcherTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.pollBatteryAndTrophies()
        }
    }

    func updateForGame(_ game: Game?) {
        guard let game else { return }
        if let cached = colorCache[game.id] {
            applyRGB(cached)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rgb = Self.extractVibrantColor(from: game.iconURL ?? game.backgroundURL)
            DispatchQueue.main.async {
                self?.colorCache[game.id] = rgb
                self?.applyRGB(rgb)
            }
        }
    }

    func cycleEffect() {
        let all = LightbarEffect.allCases
        let i = all.firstIndex(of: effect) ?? 0
        effect = all[(i + 1) % all.count]
        effectTimer?.invalidate()
        effectTimer = nil

        switch effect {
        case .ambilight:
            let (r, g, b) = AppSettings.shared.accent.rgb
            setPhysicalLED(r, g, b)
        case .theme:
            let (r, g, b) = AppSettings.shared.accent.rgb
            setPhysicalLED(r, g, b)
        case .siren:
            effectTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.sirenPhase.toggle()
                if self.sirenPhase {
                    self.setPhysicalLED(1.0, 0.05, 0.08)
                } else {
                    self.setPhysicalLED(0.05, 0.25, 1.0)
                }
            }
        case .gold:
            setPhysicalLED(1.0, 0.78, 0.1)
        }
    }

    func flashTrophyGold() {
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] t in
            count += 1
            if count % 2 == 1 {
                self?.setPhysicalLED(1.0, 0.82, 0.12)
            } else {
                self?.setPhysicalLED(1.0, 1.0, 1.0)
            }
            if count >= 6 {
                t.invalidate()
                let (r, g, b) = AppSettings.shared.accent.rgb
                self?.setPhysicalLED(r, g, b)
            }
        }
    }

    private func applyRGB(_ rgb: (Float, Float, Float)) {
        currentGameColor = Color(red: Double(rgb.0), green: Double(rgb.1), blue: Double(rgb.2))
        if effect == .ambilight {
            setPhysicalLED(rgb.0, rgb.1, rgb.2)
        }
    }

    private func setPhysicalLED(_ r: Float, _ g: Float, _ b: Float) {
        // Do not send competing USB HID output reports while RPCS3 owns the DualShock 4, unless overlay is open.
        guard !AppDelegate.isGameActive || InGameOverlayManager.shared.isVisible else { return }
        let key = (Int(r * 255), Int(g * 255), Int(b * 255))
        guard lastSentRGB?.0 != key.0 || lastSentRGB?.1 != key.1 || lastSentRGB?.2 != key.2 else { return }
        lastSentRGB = key
        for c in GCController.controllers() {
            c.light?.color = GCColor(red: r, green: g, blue: b)
        }
    }

    private func pollBatteryAndTrophies() {
        // Never query GCController battery over XPC while RPCS3 is running a game (prevents USB HID hotplug resets).
        guard !AppDelegate.isGameActive else { return }
        if let c = GCController.current ?? GCController.controllers().first,
           let bat = c.battery?.batteryLevel, bat > 0, bat <= 0.15, !warnedLowBattery {
            warnedLowBattery = true
            ToastCenter.shared.show(
                icon: "battery.25",
                title: L("🪫 Kontrolcü Pili Azaldı (\(Format.percent(Double(bat))))"),
                subtitle: c.vendorName ?? "DualShock 4",
                tint: .red
            )
            setPhysicalLED(1.0, 0.08, 0.08)
        }
    }

    /// Samples an image and returns a saturated, vibrant RGB tuple for the DualShock 4 lightbar.
    private static func extractVibrantColor(from url: URL?) -> (Float, Float, Float) {
        guard let url,
              let img = NSImage(contentsOf: url),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return AppSettings.shared.accent.rgb
        }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var rSum: Double = 0, gSum: Double = 0, bSum: Double = 0, weightSum: Double = 0
        let stepX = max(1, w / 24), stepY = max(1, h / 24)
        for y in stride(from: 0, to: h, by: stepY) {
            for x in stride(from: 0, to: w, by: stepX) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let sat = Double(c.saturationComponent)
                let bri = Double(c.brightnessComponent)
                guard bri > 0.18 && bri < 0.96 && sat > 0.2 else { continue }
                let w = sat * sat * bri
                rSum += Double(c.redComponent) * w
                gSum += Double(c.greenComponent) * w
                bSum += Double(c.blueComponent) * w
                weightSum += w
            }
        }
        guard weightSum > 0.01 else { return AppSettings.shared.accent.rgb }
        let ns = NSColor(srgbRed: rSum / weightSum, green: gSum / weightSum, blue: bSum / weightSum, alpha: 1)
        let boosted = NSColor(calibratedHue: ns.hueComponent,
                              saturation: min(1.0, max(0.75, ns.saturationComponent * 1.35)),
                              brightness: 0.95, alpha: 1).usingColorSpace(.sRGB) ?? ns
        return (Float(boosted.redComponent), Float(boosted.greenComponent), Float(boosted.blueComponent))
    }
}

// MARK: - 3. Floating In-Game "PS Button" Quick Overlay Window (Item 1)

enum OverlayAction: Int, CaseIterable, Identifiable {
    case resume, savestate, screenshot, switchScreen, lightbar, quit
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .resume: L("Oyuna Devam Et")
        case .savestate: L("Hızlı Kayıt Al (Save State)")
        case .screenshot: L("Ekran Görüntüsü Al")
        case .switchScreen: L("Ekranı Değiştir (Monitör)")
        case .lightbar: L("Kol Işığı (Ambilight)")
        case .quit: L("Ana Menüye Dön (Oyunu Kapat)")
        }
    }

    var subtitle: String {
        switch self {
        case .resume: L("Menüyü gizle ve oyuna dön")
        case .savestate: L("RPCS3 anlık durum kaydı oluştur")
        case .screenshot: L("~/Pictures/Zinkx Arena klasörüne kaydet")
        case .switchScreen: L("Aktif: \(AppSettings.shared.targetScreenTitle)")
        case .lightbar: SmartDS4Manager.shared.effect.title
        case .quit: L("Oyunu güvenli şekilde sonlandır")
        }
    }

    var icon: String {
        switch self {
        case .resume: "play.fill"
        case .savestate: "bolt.horizontal.circle.fill"
        case .screenshot: "camera.viewfinder"
        case .switchScreen: "display.2"
        case .lightbar: "lightbulb.led.fill"
        case .quit: "house.fill"
        }
    }
}

final class InGameOverlayManager: ObservableObject {
    static let shared = InGameOverlayManager()

    @Published var isVisible = false
    @Published var selectedIndex = 0
    @Published var statusBanner: String?

    private var panel: NSPanel?
    weak var launcher: GameLauncher?

    func toggle(launcher: GameLauncher) {
        self.launcher = launcher
        if isVisible {
            hide(refocusGame: true)
        } else {
            show()
        }
    }

    func show() {
        guard let launcher, launcher.running != nil else { return }
        selectedIndex = 0
        statusBanner = nil
        isVisible = true
        AudioManager.shared.play(.open)

        if panel == nil {
            let screen = (AppSettings.shared.targetScreen ?? NSScreen.main)?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let p = NSPanel(
                contentRect: screen,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.level = .screenSaver
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            panel = p
        }
        if let screen = (AppSettings.shared.targetScreen ?? NSScreen.main)?.frame {
            panel?.setFrame(screen, display: true)
        }
        panel?.contentView = NSHostingView(rootView: InGameOverlayView(manager: self))
        panel?.orderFrontRegardless()
    }

    func hide(refocusGame: Bool) {
        guard isVisible else { return }
        isVisible = false
        panel?.orderOut(nil)
        if refocusGame {
            launcher?.focusGame()
        }
    }

    func handle(_ action: NavAction) {
        let count = OverlayAction.allCases.count
        switch action {
        case .up:
            selectedIndex = (selectedIndex - 1 + count) % count
            AudioManager.shared.play(.tick)
        case .down:
            selectedIndex = (selectedIndex + 1) % count
            AudioManager.shared.play(.tick)
        case .confirm:
            guard let act = OverlayAction(rawValue: selectedIndex) else { return }
            execute(act)
        case .back, .options:
            AudioManager.shared.play(.back)
            hide(refocusGame: true)
        default:
            break
        }
    }

    func execute(_ action: OverlayAction) {
        AudioManager.shared.play(.confirm)
        switch action {
        case .resume:
            hide(refocusGame: true)
        case .savestate:
            triggerRPCS3SaveState()
        case .screenshot:
            captureInGameScreenshot()
        case .switchScreen:
            AppSettings.shared.cycleScreen(1)
            if let screen = (AppSettings.shared.targetScreen ?? NSScreen.main)?.frame {
                panel?.setFrame(screen, display: true)
            }
            statusBanner = L("🖥️ Ekran: \(AppSettings.shared.targetScreenShortName)")
        case .lightbar:
            SmartDS4Manager.shared.cycleEffect()
            statusBanner = L("Kol ışığı: \(SmartDS4Manager.shared.effect.title)")
        case .quit:
            hide(refocusGame: false)
            launcher?.stop()
        }
    }

    private func triggerRPCS3SaveState() {
        // Focus RPCS3 briefly and send Ctrl+S (RPCS3's default savestate shortcut)
        hide(refocusGame: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let src = CGEventSource(stateID: .hidSystemState)
            if let down = CGEvent(keyboardEventSource: src, virtualKey: 1, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: 1, keyDown: false) {
                down.flags = .maskControl
                up.flags = .maskControl
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
            ToastCenter.shared.show(
                icon: "bolt.horizontal.circle.fill",
                title: L("Hızlı Kayıt (Save State) Gönderildi"),
                subtitle: L("RPCS3 anlık durum kaydı")
            )
        }
    }

    private func captureInGameScreenshot() {
        let gameTitle = launcher?.running?.title ?? L("Oyun")
        let gameID = launcher?.running?.titleID ?? "PS3"
        panel?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            let pics = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Pictures/Zinkx Arena/\(gameTitle)")
            try? FileManager.default.createDirectory(at: pics, withIntermediateDirectories: true)
            let stamp = Int(Date().timeIntervalSince1970)
            let file = pics.appendingPathComponent("shot_\(stamp).jpg")

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", "-t", "jpg", file.path]
            try? p.run()
            p.waitUntilExit()

            // Also copy into game media cache so it immediately rotates in CD Medya Galerisi!
            let mediaDir = GameMediaStore.cacheRoot.appendingPathComponent(gameID)
            try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: file, to: mediaDir.appendingPathComponent("slide_user_\(stamp).jpg"))

            self?.panel?.orderFrontRegardless()
            self?.statusBanner = L("📸 Ekran görüntüsü kaydedildi!")
        }
    }
}

struct InGameOverlayView: View {
    @ObservedObject var manager: InGameOverlayManager
    private var accent: Color { AppSettings.shared.accent.color }
    private var game: Game? { manager.launcher?.running }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { manager.hide(refocusGame: true) }

            VStack(alignment: .leading, spacing: 20) {
                // Header with logo & running game
                HStack(spacing: 14) {
                    LogoMark(accent: accent).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZINKX ARENA")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(1.8)
                            .foregroundStyle(accent.mix(with: .white, by: 0.5))
                        Text(game?.title ?? L("Oyun İçi Hızlı Menü"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                // Live System & Performance Telemetry Bar
                HStack(spacing: 12) {
                    telemetryPill(icon: "timer", label: L("Oturum"), value: manager.launcher?.elapsedText ?? L("0 dk"))
                    telemetryPill(icon: "cpu", label: L("M1 Bellek"), value: Self.ramUsageText())
                    telemetryPill(icon: "laptopcomputer", label: L("Mac Pil"), value: Self.macBatteryText())
                }

                Divider().overlay(.white.opacity(0.16))

                // Action rows
                VStack(spacing: 10) {
                    ForEach(OverlayAction.allCases) { act in
                        let focused = manager.selectedIndex == act.rawValue
                        Button {
                            manager.selectedIndex = act.rawValue
                            manager.execute(act)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: act.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .frame(width: 32)
                                    .foregroundStyle(focused ? .black : (act == .quit ? .red : .white))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(act.title)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(focused ? .black : .white)
                                    Text(act.subtitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(focused ? .black.opacity(0.7) : .white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                focused ? Color.white : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(accent, lineWidth: 2.5)
                                    .padding(-2)
                                    .opacity(focused ? 1 : 0)
                            )
                            .scaleEffect(focused ? 1.02 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let banner = manager.statusBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(banner).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: Capsule())
                }

                Spacer()

                Text(L("▲▼ Seç   ✕ Onayla   ○ Oyuna Dön"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(28)
            .frame(width: 440)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .background(Color(red: 0.04, green: 0.06, blue: 0.14).opacity(0.92))
            .overlay(alignment: .trailing) {
                Rectangle().fill(.white.opacity(0.15)).frame(width: 1)
            }
            .shadow(color: .black.opacity(0.8), radius: 40, x: 14)
        }
    }

    private func telemetryPill(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private static func ramUsageText() -> String {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let res = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard res == KERN_SUCCESS else { return "16 GB" }
        let page = UInt64(vm_kernel_page_size)
        let used = Double((UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page) / 1_073_741_824
        return String(format: "%.1f / 16 GB", used)
    }

    private static func macBatteryText() -> String {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["-g", "batt"]
        p.standardOutput = pipe
        try? p.run()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let m = out.range(of: #"\d+%"#, options: .regularExpression) {
            return String(out[m])
        }
        return L("AC Güç")
    }
}
