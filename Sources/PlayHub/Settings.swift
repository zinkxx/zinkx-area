import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Option types

protocol SettingOption: CaseIterable, Equatable, RawRepresentable where RawValue == String {
    var title: String { get }
}

extension SettingOption {
    func step(_ delta: Int) -> Self {
        let all = Array(Self.allCases)
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + delta + all.count) % all.count]
    }
}

enum IntroSound: String, SettingOption {
    case classic, crystal, deep, custom, off
    var title: String {
        switch self {
        case .classic: L("Klasik")
        case .crystal: L("Kristal")
        case .deep: L("Derin")
        case .custom: L("Özel dosya")
        case .off: L("Sessiz")
        }
    }
}

enum UISoundStyle: String, SettingOption {
    case soft, system, off
    var title: String {
        switch self {
        case .soft: L("Yumuşak")
        case .system: L("Sistem")
        case .off: L("Kapalı")
        }
    }
}

enum BackgroundStyle: String, SettingOption {
    case artwork, both, waves
    var title: String {
        switch self {
        case .artwork: L("Oyun medyası")
        case .both: L("Medya + dalgalar")
        case .waves: L("PS3 dalgaları")
        }
    }
}

enum GameMediaDisplay: String, SettingOption {
    case videoAndSlides, slidesOnly, staticArt
    var title: String {
        switch self {
        case .videoAndSlides: L("Video + Fotoğraf Slaytı")
        case .slidesOnly: L("Fotoğraf Slaytı")
        case .staticArt: L("Sabit Görsel")
        }
    }
}

enum AccentChoice: String, SettingOption {
    case blue, purple, pink, red, orange, green, teal
    var title: String {
        switch self {
        case .blue: L("Mavi")
        case .purple: L("Mor")
        case .pink: L("Pembe")
        case .red: L("Kırmızı")
        case .orange: L("Turuncu")
        case .green: L("Yeşil")
        case .teal: L("Turkuaz")
        }
    }
    var color: Color {
        switch self {
        case .blue: Color(red: 0.0, green: 0.44, blue: 0.95)
        case .purple: Color(red: 0.52, green: 0.28, blue: 0.95)
        case .pink: Color(red: 0.93, green: 0.27, blue: 0.6)
        case .red: Color(red: 0.9, green: 0.2, blue: 0.22)
        case .orange: Color(red: 0.96, green: 0.5, blue: 0.1)
        case .green: Color(red: 0.15, green: 0.72, blue: 0.38)
        case .teal: Color(red: 0.0, green: 0.68, blue: 0.75)
        }
    }
    var rgb: (Float, Float, Float) {
        switch self {
        case .blue: (0.0, 0.44, 0.95)
        case .purple: (0.52, 0.28, 0.95)
        case .pink: (0.93, 0.27, 0.60)
        case .red: (0.90, 0.20, 0.22)
        case .orange: (0.96, 0.50, 0.10)
        case .green: (0.15, 0.72, 0.38)
        case .teal: (0.0, 0.68, 0.75)
        }
    }
}

enum CardSize: String, SettingOption {
    case small, normal, large
    var title: String {
        switch self {
        case .small: L("Küçük")
        case .normal: L("Normal")
        case .large: L("Büyük")
        }
    }
    var scale: CGFloat {
        switch self {
        case .small: 0.8
        case .normal: 1
        case .large: 1.2
        }
    }
}

enum SortOrder: String, SettingOption {
    case recent, alphabetical
    var title: String { self == .recent ? L("Son oynanan") : L("A – Z") }
}

enum ScreensaverDelay: String, SettingOption {
    case off, two, five, ten
    var title: String {
        switch self {
        case .off: L("Kapalı")
        case .two: L("2 dakika")
        case .five: L("5 dakika")
        case .ten: L("10 dakika")
        }
    }
    var minutes: Int? {
        switch self {
        case .off: nil
        case .two: 2
        case .five: 5
        case .ten: 10
        }
    }
}

enum Avatar: String, SettingOption {
    case controller, person, star, flame, bolt, moon, crown, hare, paw
    var title: String {
        switch self {
        case .controller: L("Gamepad")
        case .person: L("Kişi")
        case .star: L("Yıldız")
        case .flame: L("Alev")
        case .bolt: L("Şimşek")
        case .moon: L("Ay")
        case .crown: L("Taç")
        case .hare: L("Tavşan")
        case .paw: L("Pati")
        }
    }
    var symbol: String {
        switch self {
        case .controller: "gamecontroller.fill"
        case .person: "person.fill"
        case .star: "star.fill"
        case .flame: "flame.fill"
        case .bolt: "bolt.fill"
        case .moon: "moon.stars.fill"
        case .crown: "crown.fill"
        case .hare: "hare.fill"
        case .paw: "pawprint.fill"
        }
    }
}

// MARK: - Persistent settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private static let d = UserDefaults.standard

    // Sound
    @Published var introEnabled: Bool { didSet { Self.d.set(introEnabled, forKey: "introEnabled") } }
    @Published var introSound: IntroSound { didSet { Self.d.set(introSound.rawValue, forKey: "introSound") } }
    @Published var uiSounds: UISoundStyle { didSet { Self.d.set(uiSounds.rawValue, forKey: "uiSounds") } }
    @Published var effectsVolume: Double { didSet { Self.d.set(effectsVolume, forKey: "effectsVolume") } }
    @Published var gameMusicEnabled: Bool { didSet { Self.d.set(gameMusicEnabled, forKey: "gameMusicEnabled") } }
    @Published var musicEnabled: Bool { didSet { Self.d.set(musicEnabled, forKey: "musicEnabled") } }
    @Published var musicVolume: Double { didSet { Self.d.set(musicVolume, forKey: "musicVolume") } }

    // Look
    @Published var language: AppLanguage {
        didSet {
            Self.d.set(language.rawValue, forKey: "language")
            L10n.apply(language)
        }
    }
    @Published var preferredScreenName: String { didSet { Self.d.set(preferredScreenName, forKey: "preferredScreenName") } }
    @Published var background: BackgroundStyle { didSet { Self.d.set(background.rawValue, forKey: "background") } }
    @Published var gameMediaDisplay: GameMediaDisplay { didSet { Self.d.set(gameMediaDisplay.rawValue, forKey: "gameMediaDisplay") } }
    @Published var accent: AccentChoice { didSet { Self.d.set(accent.rawValue, forKey: "accent") } }
    @Published var cardSize: CardSize { didSet { Self.d.set(cardSize.rawValue, forKey: "cardSize") } }
    @Published var sortOrder: SortOrder { didSet { Self.d.set(sortOrder.rawValue, forKey: "sortOrder") } }
    @Published var showHints: Bool { didSet { Self.d.set(showHints, forKey: "showHints") } }
    @Published var screensaver: ScreensaverDelay { didSet { Self.d.set(screensaver.rawValue, forKey: "screensaver") } }

    // Profile
    @Published var profileName: String { didSet { Self.d.set(profileName, forKey: "profileName") } }
    @Published var avatar: Avatar { didSet { Self.d.set(avatar.rawValue, forKey: "avatar") } }
    @Published var fullName: String { didSet { Self.d.set(fullName, forKey: "fullName") } }
    @Published var gamertag: String { didSet { Self.d.set(gamertag, forKey: "gamertag") } }
    @Published var bio: String { didSet { Self.d.set(bio, forKey: "bio") } }
    @Published var location: String { didSet { Self.d.set(location, forKey: "location") } }
    @Published var favoriteGenre: String { didSet { Self.d.set(favoriteGenre, forKey: "favoriteGenre") } }
    @Published var brandName: String { didSet { Self.d.set(brandName, forKey: "brandName") } }
    @Published var avatarImagePath: String? { didSet { Self.d.set(avatarImagePath, forKey: "avatarImagePath") } }
    @Published var favorites: [String] { didSet { Self.d.set(favorites, forKey: "favorites") } }
    let memberSince: Date

    static let genres = [LKey("Aksiyon"), LKey("Macera"), LKey("Yarış"), LKey("RPG"), LKey("Spor"), LKey("Dövüş"), LKey("Korku"), LKey("Nişancı"), LKey("Platform"), LKey("Strateji"), LKey("Açık dünya")]

    var greetingName: String { gamertag.isEmpty ? profileName : gamertag }

    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }
    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.append(id) }
    }

    // Games
    @Published var fullscreenGames: Bool { didSet { Self.d.set(fullscreenGames, forKey: "fullscreenGames") } }
    @Published var closeComboEnabled: Bool { didSet { Self.d.set(closeComboEnabled, forKey: "closeComboEnabled") } }
    @Published var extraFolders: [String] { didSet { Self.d.set(extraFolders, forKey: "extraFolders") } }

    private init() {
        let d = Self.d
        func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) as? Bool ?? def }
        func double(_ k: String, _ def: Double) -> Double { d.object(forKey: k) as? Double ?? def }
        func option<T: SettingOption>(_ k: String, _ def: T) -> T { T(rawValue: d.string(forKey: k) ?? "") ?? def }

        introEnabled = bool("introEnabled", true)
        introSound = option("introSound", IntroSound.classic)
        uiSounds = option("uiSounds", UISoundStyle.soft)
        effectsVolume = double("effectsVolume", 0.7)
        gameMusicEnabled = bool("gameMusicEnabled", true)
        musicEnabled = bool("musicEnabled", false)
        musicVolume = double("musicVolume", 0.45)

        let lang = option("language", AppLanguage.system)
        L10n.apply(lang)
        language = lang
        preferredScreenName = d.string(forKey: "preferredScreenName") ?? ""
        background = option("background", BackgroundStyle.artwork)
        gameMediaDisplay = option("gameMediaDisplay", GameMediaDisplay.videoAndSlides)
        accent = option("accent", AccentChoice.blue)
        cardSize = option("cardSize", CardSize.normal)
        sortOrder = option("sortOrder", SortOrder.recent)
        showHints = bool("showHints", true)
        screensaver = option("screensaver", ScreensaverDelay.five)

        let firstName = NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
        profileName = d.string(forKey: "profileName") ?? firstName
        avatar = option("avatar", Avatar.controller)
        fullName = d.string(forKey: "fullName") ?? NSFullUserName()
        gamertag = d.string(forKey: "gamertag") ?? NSUserName()
        bio = d.string(forKey: "bio") ?? ""
        location = d.string(forKey: "location") ?? ""
        favoriteGenre = d.string(forKey: "favoriteGenre") ?? ""
        brandName = d.string(forKey: "brandName") ?? "Zinkx Arena"
        avatarImagePath = d.string(forKey: "avatarImagePath")
        favorites = d.stringArray(forKey: "favorites") ?? []
        if let since = d.object(forKey: "memberSince") as? Date {
            memberSince = since
        } else {
            memberSince = Date()
            d.set(memberSince, forKey: "memberSince")
        }

        fullscreenGames = bool("fullscreenGames", true)
        closeComboEnabled = bool("closeComboEnabled", true)
        extraFolders = d.stringArray(forKey: "extraFolders") ?? []
    }

    // Launch at login (managed by macOS, not stored here)
    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        objectWillChange.send()
    }

    // MARK: - Multi-Monitor / Display Selection

    var targetScreenIndex: Int {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return 0 }
        if !preferredScreenName.isEmpty,
           let idx = screens.firstIndex(where: { $0.localizedName == preferredScreenName }) {
            return idx
        }
        return 0
    }

    var targetScreen: NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return NSScreen.main }
        return screens[min(targetScreenIndex, screens.count - 1)]
    }

    var targetScreenTitle: String {
        guard let s = targetScreen else { return L("Ana Ekran") }
        return "\(s.localizedName) (\(Int(s.frame.width))×\(Int(s.frame.height)))"
    }

    var targetScreenShortName: String {
        guard let s = targetScreen else { return L("Ekran 1") }
        return s.localizedName
    }

    func cycleScreen(_ delta: Int = 1) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let nextIdx = (targetScreenIndex + delta + screens.count) % screens.count
        let chosen = screens[nextIdx]
        preferredScreenName = chosen.localizedName
        objectWillChange.send()
        AppDelegate.ensureFullScreen()
        GameLauncher.enforceRPCS3FullScreenINI()
        ToastCenter.shared.show(
            icon: "display.2",
            title: L("🖥️ Aktif Ekran: \(chosen.localizedName)"),
            subtitle: L("\(Int(chosen.frame.width))×\(Int(chosen.frame.height)) · Menü ve oyunlar bu ekrana taşındı")
        )
    }
}
