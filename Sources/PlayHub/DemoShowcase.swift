import SwiftUI
import AppKit

/// Generates 100% copyright-free, original homebrew/indie showcase games, procedural artwork,
/// trophies, save data, and high-resolution screenshots for documentation and `--demo` mode.
enum DemoShowcase {

    struct Spec {
        let id: String
        let title: String
        let subtitle: String
        let genreBadge: String
        let c1: NSColor
        let c2: NSColor
        let accent: NSColor
        let hours: Double
        let lastHoursAgo: Double
        let unlockedTrophies: Int
        let totalTrophies: Int
        let sizeGB: Double
        let version: String
    }

    static let specs: [Spec] = [
        Spec(
            id: "HB00101",
            title: "Cyber Drift: Neon Horizon",
            subtitle: "SYNTHWAVE STREET RACING · 60 FPS",
            genreBadge: "ARCADE RACING",
            c1: NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.24, alpha: 1),
            c2: NSColor(calibratedRed: 0.52, green: 0.08, blue: 0.48, alpha: 1),
            accent: NSColor(calibratedRed: 0.0, green: 0.88, blue: 1.0, alpha: 1),
            hours: 42.5,
            lastHoursAgo: 1.5,
            unlockedTrophies: 18,
            totalTrophies: 20,
            sizeGB: 14.8,
            version: "1.04"
        ),
        Spec(
            id: "HB00204",
            title: "Aether Chronicles: Odyssey",
            subtitle: "OPEN-WORLD FANTASY ACTION RPG",
            genreBadge: "ACTION RPG",
            c1: NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.22, alpha: 1),
            c2: NSColor(calibratedRed: 0.10, green: 0.42, blue: 0.34, alpha: 1),
            accent: NSColor(calibratedRed: 0.35, green: 0.98, blue: 0.72, alpha: 1),
            hours: 28.0,
            lastHoursAgo: 18,
            unlockedTrophies: 14,
            totalTrophies: 20,
            sizeGB: 22.4,
            version: "1.12"
        ),
        Spec(
            id: "HB00309",
            title: "Valkyrie Protocol Zero",
            subtitle: "TACTICAL MECHA & ORBITAL COMBAT",
            genreBadge: "MECHA ACTION",
            c1: NSColor(calibratedRed: 0.18, green: 0.06, blue: 0.14, alpha: 1),
            c2: NSColor(calibratedRed: 0.48, green: 0.12, blue: 0.18, alpha: 1),
            accent: NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.28, alpha: 1),
            hours: 19.3,
            lastHoursAgo: 40,
            unlockedTrophies: 11,
            totalTrophies: 16,
            sizeGB: 18.1,
            version: "1.02"
        ),
        Spec(
            id: "HB00412",
            title: "Solaris Assault 2099",
            subtitle: "DEEP-SPACE FLEET & STARFIGHTER SIM",
            genreBadge: "SPACE SIM",
            c1: NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.18, alpha: 1),
            c2: NSColor(calibratedRed: 0.14, green: 0.25, blue: 0.58, alpha: 1),
            accent: NSColor(calibratedRed: 0.38, green: 0.68, blue: 1.0, alpha: 1),
            hours: 12.8,
            lastHoursAgo: 72,
            unlockedTrophies: 9,
            totalTrophies: 15,
            sizeGB: 11.6,
            version: "1.00"
        ),
        Spec(
            id: "HB00518",
            title: "Shadow Blade: Ronin",
            subtitle: "STEALTH SAMURAI & DUELING ENGINE",
            genreBadge: "STEALTH ACTION",
            c1: NSColor(calibratedRed: 0.12, green: 0.05, blue: 0.06, alpha: 1),
            c2: NSColor(calibratedRed: 0.36, green: 0.08, blue: 0.12, alpha: 1),
            accent: NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.24, alpha: 1),
            hours: 8.4,
            lastHoursAgo: 120,
            unlockedTrophies: 7,
            totalTrophies: 14,
            sizeGB: 9.4,
            version: "1.01"
        ),
        Spec(
            id: "HB00625",
            title: "Hyperion Rally GT",
            subtitle: "NEXT-GEN OFFROAD & WEATHER PHYSICS",
            genreBadge: "SIM RACING",
            c1: NSColor(calibratedRed: 0.14, green: 0.12, blue: 0.04, alpha: 1),
            c2: NSColor(calibratedRed: 0.44, green: 0.28, blue: 0.06, alpha: 1),
            accent: NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.22, alpha: 1),
            hours: 5.2,
            lastHoursAgo: 190,
            unlockedTrophies: 5,
            totalTrophies: 12,
            sizeGB: 12.9,
            version: "1.03"
        ),
    ]

    @MainActor
    static func populate(library: GameLibrary, details: DetailsStore, settings: AppSettings) {
        let artDir = URL(fileURLWithPath: "/tmp/zinkx-demo-art")
        try? FileManager.default.createDirectory(at: artDir, withIntermediateDirectories: true)

        var demoGames: [Game] = []
        var demoStats: [String: GameStats] = [:]
        var demoDetails: [String: GameDetails] = [:]
        var demoCompat: [String: CompatInfo] = [:]

        for (idx, s) in specs.enumerated() {
            let gameDir = artDir.appendingPathComponent(s.id)
            try? FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
            let iconURL = gameDir.appendingPathComponent("ICON0.PNG")
            let bgURL = gameDir.appendingPathComponent("PIC1.PNG")
            let slide1URL = gameDir.appendingPathComponent("SLIDE1.PNG")
            let slide2URL = gameDir.appendingPathComponent("SLIDE2.PNG")

            renderArtwork(spec: s, size: NSSize(width: 640, height: 360), isHero: false, variant: 0, to: iconURL)
            renderArtwork(spec: s, size: NSSize(width: 1920, height: 1080), isHero: true, variant: 0, to: bgURL)
            renderArtwork(spec: s, size: NSSize(width: 1280, height: 720), isHero: true, variant: 1, to: slide1URL)
            renderArtwork(spec: s, size: NSSize(width: 1280, height: 720), isHero: true, variant: 2, to: slide2URL)

            let g = Game(
                id: s.id,
                title: s.title,
                titleID: s.id,
                bootPath: gameDir,
                baseDir: gameDir,
                iconURL: iconURL,
                backgroundURL: bgURL,
                isDisc: true,
                sfo: [
                    "TITLE": s.title,
                    "TITLE_ID": s.id,
                    "CATEGORY": "DG",
                    "APP_VER": s.version,
                    "PS3_SYSTEM_VER": "4.90",
                ]
            )
            demoGames.append(g)

            demoStats[s.id] = GameStats(
                lastPlayed: Date().addingTimeInterval(-s.lastHoursAgo * 3600),
                totalSeconds: s.hours * 3600,
                sessions: max(3, Int(s.hours / 1.8)),
                firstPlayed: Date().addingTimeInterval(-Double(14 + idx * 5) * 86400)
            )

            let trophies = buildDemoTrophies(for: s, iconURL: iconURL)
            let saves = [
                SaveInfo(
                    id: "\(s.id)-SAVE01",
                    title: "Bölüm \(max(2, s.unlockedTrophies / 2)) · Ana Hikaye Kaydı",
                    subtitle: s.title,
                    detail: "İlerleme: %\(min(98, Int(Double(s.unlockedTrophies) / Double(s.totalTrophies) * 100))) · Süre: \(Int(s.hours))s",
                    modified: Date().addingTimeInterval(-s.lastHoursAgo * 3600),
                    iconURL: iconURL
                ),
                SaveInfo(
                    id: "\(s.id)-SAVE02",
                    title: "Hızlı Kayıt · Otomatik Yedek",
                    subtitle: s.title,
                    detail: "Kontrol Noktası #\(12 + idx * 4)",
                    modified: Date().addingTimeInterval(-(s.lastHoursAgo + 4) * 3600),
                    iconURL: iconURL
                ),
            ]

            demoDetails[s.id] = GameDetails(
                region: L("Avrupa"),
                version: s.version,
                updateVersion: "1.05",
                resolutions: ["1080p", "720p"],
                sound: ["Dolby Digital", "LPCM 7.1"],
                parental: L("Seviye \(9)"),
                systemVersion: "4.90",
                trophies: trophies,
                saves: saves,
                sizeBytes: Int64(s.sizeGB * 1_073_741_824)
            )

            demoCompat[s.id] = CompatInfo(status: "Playable", date: "2026-11-20", fetched: Date())
            GameMediaStore.shared.media[s.id] = GameMediaItem(
                themeAudioURL: nil,
                videoURL: nil,
                photos: [bgURL, slide1URL, slide2URL, iconURL],
                hasDiscVideo: false
            )
        }

        library.games = demoGames
        library.stats = demoStats
        details.details = demoDetails
        details.compat = demoCompat

        if !settings.favorites.contains("HB00101") {
            settings.favorites.append("HB00101")
        }
        if !settings.favorites.contains("HB00204") {
            settings.favorites.append("HB00204")
        }
    }

    private static func buildDemoTrophies(for s: Spec, iconURL: URL) -> [TrophyInfo] {
        let templates: [(String, String, String)] = [
            ("P", "Kusursuz Efsane", "\(s.title) içindeki tüm kupaları açarak zirveye ulaş."),
            ("G", "Neon Şampiyonu", "Ana senaryoyu en yüksek zorluk seviyesinde tamamla."),
            ("G", "Işık Hızı Ustası", "Hiç hasar almadan tüm zamana karşı etapları bitir."),
            ("S", "Gece Avcısı", "Gizli bölgedeki tüm koleksiyon parçalarını keşfet."),
            ("S", "Tam İsabette", "Arka arkaya 25 kusursuz kombo zinciri yakala."),
            ("S", "Yüksek Gerilim", "Özel yetenek modunu tek bölümde 10 kez etkinleştir."),
            ("B", "İlk Kıvılcım", "Giriş görevini ve temel eğitim parkurunu tamamla."),
            ("B", "Hız Sınırı Yok", "Maksimum hıza ulaşıp 30 saniye boyunca koru."),
            ("B", "Koleksiyoncu", "İlk özel ekipman yükseltmesini atölyede üret."),
            ("B", "Takım Kaptanı", "Bir yan görevi tam yıldız derecesiyle bitir."),
        ]
        var out: [TrophyInfo] = []
        for i in 0..<s.totalTrophies {
            let t = templates[i % templates.count]
            let type = i == 0 ? "P" : t.0
            let unlocked = i < s.unlockedTrophies
            out.append(
                TrophyInfo(
                    id: i + 1,
                    name: i < templates.count ? t.1 : "\(t.1) #\(i + 1)",
                    detail: t.2,
                    type: type,
                    hidden: false,
                    unlocked: unlocked,
                    unlockedAt: unlocked ? Date().addingTimeInterval(-Double(i + 2) * 14400) : nil,
                    iconURL: iconURL
                )
            )
        }
        return out
    }

    /// Draws clean, original sci-fi/synthwave/geometric vector artwork so no copyrighted art is ever used.
    private static func renderArtwork(spec: Spec, size: NSSize, isHero: Bool, variant: Int, to url: URL) {
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            img.unlockFocus()
            return
        }

        let rect = CGRect(origin: .zero, size: size)
        let grad = NSGradient(colors: [spec.c1, spec.c2, NSColor.black])
        grad?.draw(in: rect, angle: isHero ? -25 : -35)

        // Glowing perspective grid & horizon glow
        ctx.saveGState()
        let glowColor = spec.accent.withAlphaComponent(isHero ? 0.26 : 0.38)
        glowColor.setStroke()
        ctx.setLineWidth(isHero ? 1.8 : 1.4)

        let horizonY = size.height * (isHero ? 0.42 : 0.45)
        for i in 0...14 {
            let y = horizonY * pow(CGFloat(i) / 14.0, 1.55)
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: size.width, y: y))
        }
        let centerX = size.width * (isHero ? 0.62 : 0.5)
        for i in -12...12 {
            ctx.move(to: CGPoint(x: centerX + CGFloat(i) * (size.width * 0.02), y: horizonY))
            ctx.addLine(to: CGPoint(x: centerX + CGFloat(i) * (size.width * 0.16), y: 0))
        }
        ctx.strokePath()

        // Glowing neon sun / core emblem
        let sunR = min(size.width, size.height) * (isHero ? 0.24 : 0.28)
        let sunCenter = CGPoint(
            x: centerX + CGFloat(variant) * 28,
            y: horizonY + sunR * 0.55
        )
        let sunRect = CGRect(x: sunCenter.x - sunR, y: sunCenter.y - sunR, width: sunR * 2, height: sunR * 2)
        let sunGrad = NSGradient(colors: [
            spec.accent.withAlphaComponent(isHero ? 0.65 : 0.85),
            spec.c2.withAlphaComponent(0.25),
            NSColor.clear
        ])
        sunGrad?.draw(in: NSBezierPath(ovalIn: sunRect), angle: 90)

        // Geometric crystalline rings
        spec.accent.withAlphaComponent(isHero ? 0.45 : 0.7).setStroke()
        ctx.setLineWidth(isHero ? 3.0 : 2.4)
        ctx.strokeEllipse(in: sunRect.insetBy(dx: sunR * 0.22, dy: sunR * 0.22))
        ctx.strokeEllipse(in: sunRect.insetBy(dx: sunR * 0.48, dy: sunR * 0.48))
        ctx.restoreGState()

        if !isHero {
            // Draw stylized badge + title on card cover art
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .left

            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .heavy),
                .foregroundColor: spec.accent,
                .paragraphStyle: pStyle
            ]
            NSString(string: spec.genreBadge).draw(at: NSPoint(x: 28, y: size.height - 42), withAttributes: badgeAttrs)

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 28, weight: .black),
                .foregroundColor: NSColor.white,
                .paragraphStyle: pStyle
            ]
            NSString(string: spec.title).draw(
                in: NSRect(x: 28, y: 44, width: size.width - 56, height: 74),
                withAttributes: titleAttrs
            )

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.75),
                .paragraphStyle: pStyle
            ]
            NSString(string: spec.subtitle).draw(at: NSPoint(x: 28, y: 24), withAttributes: subAttrs)
        }

        img.unlockFocus()
        savePNG(img, to: url)
    }

    @MainActor
    static func exportAllScreenshots(
        to outDir: URL,
        library: GameLibrary,
        details: DetailsStore,
        settings: AppSettings,
        input: InputManager,
        launcher: GameLauncher
    ) {
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        // Ensure clean, attractive demo settings without overwriting user's real defaults permanently
        settings.brandName = "Zinkx Arena"
        settings.profileName = "Zinkx"
        settings.gamertag = "zinkx"
        settings.fullName = "Zinkx"
        settings.favoriteGenre = "Aksiyon / Macera"
        settings.bio = "Next-Gen macOS Console Experience ⚡"
        settings.accent = .blue
        settings.showHints = true

        input.controllerName = "DualShock 4"
        input.batteryLevel = 0.85

        // Populate 7-day activity chart
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let sampleHours: [Double] = [1.8, 3.2, 2.4, 4.5, 1.5, 3.8, 2.9]
        for (offset, hrs) in sampleHours.enumerated() {
            if let d = cal.date(byAdding: .day, value: -(6 - offset), to: Date()) {
                WrapUpStore.shared.dailySeconds[f.string(from: d)] = hrs * 3600
            }
        }

        let firstGame = library.games.first

        // 0. Hero Banner (1600x720)
        let bannerView = HeroBannerExportView(accent: settings.accent.color)
        renderSwiftUIView(bannerView, size: CGSize(width: 1600, height: 720), to: outDir.appendingPathComponent("hero-banner.png"))

        // 1. Home Media Hub (1920x1080)
        let homeHub = makeHostedHome(
            HomeView(initialTab: .games, initialSelectedID: firstGame?.id, initialShowingUserSelect: false, initialIntroVisible: false),
            library: library, details: details, settings: settings, input: input, launcher: launcher
        )
        renderSwiftUIView(homeHub, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("01-home-hub.png"))

        // 2. Game Details, Trophies & Per-Game Performance Profile (1920x1080)
        let detailsScreen = makeHostedHome(
            HomeView(initialTab: .games, initialSelectedID: firstGame?.id, initialDetailGame: firstGame, initialShowingUserSelect: false, initialIntroVisible: false),
            library: library, details: details, settings: settings, input: input, launcher: launcher
        )
        renderSwiftUIView(detailsScreen, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("02-game-details.png"))

        // 3. Trophy Room & Level Calculator (1920x1080)
        let trophyScreen = makeHostedHome(
            HomeView(initialTab: .trophies, initialSelectedID: firstGame?.id, initialShowingUserSelect: false, initialIntroVisible: false),
            library: library, details: details, settings: settings, input: input, launcher: launcher
        )
        renderSwiftUIView(trophyScreen, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("03-trophy-room.png"))

        // 4. Gamer Profile, 7-Day Activity Chart & Badges (1920x1080)
        let profileScreen = makeHostedHome(
            HomeView(initialTab: .profile, initialSelectedID: firstGame?.id, initialShowingUserSelect: false, initialIntroVisible: false),
            library: library, details: details, settings: settings, input: input, launcher: launcher
        )
        renderSwiftUIView(profileScreen, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("04-profile-wrapup.png"))

        // 5. PS5-Style Bottom Control Center Quick Dock (1920x1080)
        let controlCenterScreen = makeHostedHome(
            HomeView(initialTab: .games, initialSelectedID: firstGame?.id, initialMenuOpen: true, initialShowingUserSelect: false, initialIntroVisible: false),
            library: library, details: details, settings: settings, input: input, launcher: launcher
        )
        renderSwiftUIView(controlCenterScreen, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("05-control-center.png"))

        // 6. Multi-User Login Switcher ("Kim Oynuyor?") (1920x1080)
        let loginScreen = makeHostedHome(
            HomeView(initialTab: .games, initialSelectedID: firstGame?.id, initialShowingUserSelect: true, initialIntroVisible: false),
            library: library, details: details, settings: settings, input: input, launcher: launcher
        )
        renderSwiftUIView(loginScreen, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("06-user-login.png"))

        // 7. New-player sign-up wizard, review step (1920x1080)
        let editor = ProfileEditorController()
        editor.loadForNewUser(from: settings)
        editor.displayName = "Nova"
        editor.gamertag = "nova"
        editor.avatar = .bolt
        editor.accentChoice = .purple
        editor.genre = LKey("Yarış")
        editor.wizardStep = .review
        let wizard = NewUserWizardView(editor: editor, onClose: {})
            .environmentObject(settings)
            .preferredColorScheme(.dark)
        renderSwiftUIView(wizard, size: CGSize(width: 1920, height: 1080), to: outDir.appendingPathComponent("07-new-player.png"))

        // 8. The home screen in four UI languages as a labeled 2×2 collage (1920x1080)
        let originalLanguage = settings.language
        var tiles: [(NSImage, String)] = []
        for lang in [AppLanguage.tr, .en, .de, .ja] {
            settings.language = lang
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("zinkx-lang-\(lang.rawValue).png")
            let home = makeHostedHome(
                HomeView(initialTab: .games, initialSelectedID: firstGame?.id, initialShowingUserSelect: false, initialIntroVisible: false),
                library: library, details: details, settings: settings, input: input, launcher: launcher
            )
            renderSwiftUIView(home, size: CGSize(width: 1920, height: 1080), to: tmp)
            if let img = NSImage(contentsOf: tmp) { tiles.append((img, lang.title)) }
            try? FileManager.default.removeItem(at: tmp)
        }
        settings.language = originalLanguage
        savePNG(languageCollage(tiles), to: outDir.appendingPathComponent("08-languages.png"))
    }

    private static func languageCollage(_ tiles: [(NSImage, String)]) -> NSImage {
        let size = NSSize(width: 1920, height: 1080)
        let gap: CGFloat = 12
        let tileW = (size.width - gap * 3) / 2, tileH = (size.height - gap * 3) / 2
        let out = NSImage(size: size)
        out.lockFocus()
        NSColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        for (i, (img, label)) in tiles.prefix(4).enumerated() {
            let col = CGFloat(i % 2), row = CGFloat(1 - i / 2)
            let rect = NSRect(x: gap + col * (tileW + gap), y: gap + row * (tileH + gap), width: tileW, height: tileH)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).addClip()
            img.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: NSColor.white,
            ]
            let text = NSAttributedString(string: label, attributes: attrs)
            let ts = text.size()
            let pill = NSRect(x: rect.maxX - ts.width - 44, y: rect.minY + 18, width: ts.width + 28, height: ts.height + 12)
            NSColor(white: 0, alpha: 0.72).setFill()
            NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            text.draw(at: NSPoint(x: pill.minX + 14, y: pill.minY + 6))
        }
        out.unlockFocus()
        return out
    }

    @MainActor
    private static func makeHostedHome(
        _ view: HomeView,
        library: GameLibrary,
        details: DetailsStore,
        settings: AppSettings,
        input: InputManager,
        launcher: GameLauncher
    ) -> some View {
        view
            .environmentObject(settings)
            .environmentObject(details)
            .environmentObject(library)
            .environmentObject(input)
            .environmentObject(launcher)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private static func renderSwiftUIView<V: View>(_ view: V, size: CGSize, to url: URL) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let rect = NSRect(origin: .zero, size: size)
        let win = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = .black
        win.isOpaque = true

        let root = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = rect
        hosting.appearance = NSAppearance(named: .darkAqua)
        win.contentView = hosting

        // Position offscreen and run loop briefly so NSScrollViews and SwiftUI geometry settle
        win.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        win.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))
        hosting.layoutSubtreeIfNeeded()

        if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url, options: .atomic)
            }
        }
        win.orderOut(nil)
    }

    private static func savePNG(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url, options: .atomic)
    }
}

private struct HeroBannerExportView: View {
    let accent: Color

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.12)
            WavesView(accent: accent, intensity: 1.0, sparks: true)

            HStack(spacing: 56) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.28))
                        .frame(width: 290, height: 290)
                        .blur(radius: 45)
                    LogoMark(accent: accent)
                        .frame(width: 230, height: 230)
                        .shadow(color: accent.opacity(0.65), radius: 28, y: 10)
                }

                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Text("NATIVE MACOS CONSOLE FRONTEND")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(2.4)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(accent.opacity(0.35), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))

                        Text("SWIFTUI · APPKIT · APPLE SILICON")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    BrandWordmark(text: "ZINKX ARENA", accent: accent, size: 68)

                    Text("PlayStation 5 tarzı tam ekran konsol arayüzü, DualShock 4 / DualSense Ambilight ışık çubuğu senkronizasyonu, TROPHY.TRP kupa okuyucu ve çoklu monitör yönetimi.")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineSpacing(4)
                        .frame(maxWidth: 880, alignment: .leading)

                    HStack(spacing: 14) {
                        bannerPill(icon: "gamecontroller.fill", text: "DualShock / DualSense LED")
                        bannerPill(icon: "trophy.fill", text: "TROPHY.TRP & Seviye")
                        bannerPill(icon: "display.2", text: "Çoklu Ekran (⌘E)")
                        bannerPill(icon: "waveform", text: "SND0.AT3 & BIK Medya")
                        bannerPill(icon: "gauge.with.dots.needle.67percent", text: "Oyun Bazlı Performans")
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 80)
        }
    }

    private func bannerPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accent.mix(with: .white, by: 0.45))
            Text(text)
        }
        .font(.system(size: 14, weight: .bold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
    }
}
