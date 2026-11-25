import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Avatar

struct AvatarView: View {
    @EnvironmentObject var settings: AppSettings
    var size: CGFloat
    var overrideAvatar: Avatar? = nil

    var body: some View {
        let av = overrideAvatar ?? settings.avatar
        ZStack {
            if overrideAvatar == nil, let path = settings.avatarImagePath, let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Circle().fill(settings.accent.color.gradient)
                Image(systemName: av.symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

enum ProfilePhoto {
    static let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ZinkxArena")

    /// Lets the user pick a photo and copies it into the app's support folder.
    static func pick(into settings: AppSettings) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Seç"
        panel.message = "Profil fotoğrafı seç"
        guard panel.runModal() == .OK, let src = panel.url else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let old = settings.avatarImagePath { try? FileManager.default.removeItem(atPath: old) }
        let dest = dir.appendingPathComponent("avatar-\(Int(Date().timeIntervalSince1970)).\(src.pathExtension.lowercased())")
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            settings.avatarImagePath = dest.path
        } catch {
            NSSound.beep()
        }
    }

    static func remove(from settings: AppSettings) {
        if let old = settings.avatarImagePath { try? FileManager.default.removeItem(atPath: old) }
        settings.avatarImagePath = nil
    }
}

// MARK: - Profile page

enum ProfileAction: CaseIterable {
    case edit, switchUser, photo, avatar
    var title: String {
        switch self {
        case .edit: "Profili düzenle"
        case .switchUser: "Kullanıcı değiştir"
        case .photo: "Fotoğraf seç"
        case .avatar: "Simgeyi değiştir"
        }
    }
    var icon: String {
        switch self {
        case .edit: "keyboard.fill"
        case .switchUser: "person.2.fill"
        case .photo: "photo"
        case .avatar: "face.smiling"
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var library: GameLibrary
    @EnvironmentObject var details: DetailsStore
    let focusedAction: Int
    let onAction: (ProfileAction) -> Void

    private var accent: Color { settings.accent.color }
    private var allStats: [GameStats] { Array(library.stats.values) }
    private var totalSeconds: Double { allStats.reduce(0) { $0 + $1.totalSeconds } }
    private var sessions: Int { allStats.reduce(0) { $0 + ($1.sessions ?? 0) } }
    private var playedGames: [Game] {
        library.games
            .filter { (library.stats[$0.id]?.totalSeconds ?? 0) > 0 }
            .sorted { (library.stats[$0.id]?.lastPlayed ?? .distantPast) > (library.stats[$1.id]?.lastPlayed ?? .distantPast) }
    }
    private var mostPlayed: Game? {
        library.games.max { (library.stats[$0.id]?.totalSeconds ?? 0) < (library.stats[$1.id]?.totalSeconds ?? 0) }
            .flatMap { (library.stats[$0.id]?.totalSeconds ?? 0) > 0 ? $0 : nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            identityCard.frame(width: 400)
            VStack(alignment: .leading, spacing: 18) {
                statsGrid
                WrapUpSectionView(
                    gamesCount: library.games.count,
                    totalSeconds: totalSeconds,
                    unlockedTrophies: details.totalUnlockedTrophies,
                    favoritesCount: settings.favorites.count,
                    accent: accent
                )
                recentSection
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 48)
        .padding(.top, 26)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            AvatarView(size: 150)
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 3))
                .shadow(color: accent.opacity(0.7), radius: 25)

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.fullName.isEmpty ? settings.profileName : settings.fullName)
                    .font(.system(size: 38, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                if !settings.gamertag.isEmpty {
                    Text("@\(settings.gamertag)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent.mix(with: .white, by: 0.4))
                }
            }

            Text(settings.bio.isEmpty ? "Henüz bir şey yazmadın. “Profili düzenle”ye basıp kontrolcü klavyesiyle kendini anlat." : settings.bio)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(settings.bio.isEmpty ? 0.45 : 0.85))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                if !settings.location.isEmpty { infoLine("mappin.and.ellipse", settings.location) }
                if !settings.favoriteGenre.isEmpty { infoLine("heart.fill", "Favori tür: \(settings.favoriteGenre)") }
                infoLine("calendar", "Üyelik: \(settings.memberSince.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))))")
            }

            let btnCols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: btnCols, spacing: 10) {
                ForEach(Array(ProfileAction.allCases.enumerated()), id: \.offset) { i, a in
                    ActionButton(title: a.title, icon: a.icon, focused: i == focusedAction, accent: accent, primary: i == 0) {
                        onAction(a)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(30)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func infoLine(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(accent.mix(with: .white, by: 0.3))
            Text(text)
        }
        .font(.system(size: 16, weight: .medium))
    }

    private var statsGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: cols, spacing: 16) {
            StatTile(icon: "clock.fill", title: "Toplam oynama", value: totalSeconds > 0 ? Format.duration(totalSeconds) : "—", accent: accent)
            StatTile(icon: "gamecontroller.fill", title: "Kütüphane", value: "\(library.games.count) oyun", accent: accent)
            StatTile(icon: "play.circle.fill", title: "Oynanan", value: "\(playedGames.count) oyun · \(sessions) oturum", accent: accent)
            StatTile(icon: "trophy.fill", title: "Kupalar", value: details.totalTrophies > 0 ? "\(details.totalUnlockedTrophies) / \(details.totalTrophies)" : "—", accent: accent)
            StatTile(icon: "star.fill", title: "Favoriler", value: "\(settings.favorites.count) oyun", accent: accent)
            StatTile(icon: "flame.fill", title: "En çok oynanan", value: mostPlayed?.title ?? "—", accent: accent)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Son oynananlar").font(.system(size: 22, weight: .bold))
            if playedGames.isEmpty {
                Text("Bir oyun oynadığında burada görünecek.")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.system(size: 16))
            } else {
                HStack(spacing: 16) {
                    ForEach(playedGames.prefix(4)) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            if let img = ImageCache.shared.image(g.iconURL) {
                                Image(nsImage: img).resizable().aspectRatio(320 / 176, contentMode: .fill)
                                    .frame(width: 200, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            Text(g.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            if let s = library.stats[g.id] {
                                Text("\(Format.duration(s.totalSeconds)) · \(s.lastPlayed.map(Format.relative) ?? "")")
                                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                            }
                        }
                        .frame(width: 200)
                    }
                }
            }
        }
    }
}

struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(accent.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                Text(value).font(.system(size: 18, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Console-style Gamepad Profile Editor Overlay

struct ProfileEditorOverlay: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var editor: ProfileEditorController
    let onClose: () -> Void

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()
            WavesView(accent: accent, intensity: 0.45, sparks: true).ignoresSafeArea()

            VStack(spacing: 22) {
                // Header
                HStack(spacing: 16) {
                    LogoMark(accent: accent).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(editor.isCreatingNewUser ? "Yeni Oyuncu Profili Oluştur" : "Oyuncu Profilini Düzenle")
                            .font(.system(size: 30, weight: .bold))
                        Text(editor.isCreatingNewUser
                             ? "Yeni kullanıcının bilgilerini kontrolcü klavyesiyle (✕) girip R1 ile oluşturabilirsin."
                             : "Kontrolcüyle bir alan seçip ✕ tuşuna basarak PlayStation ekran klavyesini açabilirsin.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                }
                .padding(.horizontal, 80)
                .padding(.top, 36)

                HStack(alignment: .top, spacing: 34) {
                    // Left: Live preview card
                    livePreviewCard
                        .frame(width: 380)

                    // Right: Gamepad-navigable fields + Save/Cancel buttons
                    VStack(spacing: 8) {
                        ForEach(ProfileFieldKind.allCases) { field in
                            let selected = editor.rowIndex == field.rawValue
                            fieldRow(field, selected: selected)
                                .onTapGesture {
                                    editor.rowIndex = field.rawValue
                                    if field.isTextField {
                                        editor.openKeyboard(for: field)
                                    } else if field == .genre {
                                        let opts = [""] + AppSettings.genres
                                        let i = opts.firstIndex(of: editor.genre) ?? 0
                                        editor.genre = opts[(i + 1) % opts.count]
                                    } else if field == .avatar {
                                        editor.avatar = editor.avatar.step(1)
                                    }
                                }
                        }

                        // Bottom action buttons row (rowIndex == 8)
                        let buttonsSelected = editor.rowIndex == ProfileEditorController.fieldCount
                        HStack(spacing: 16) {
                            Spacer()
                            ActionButton(
                                title: editor.isCreatingNewUser ? "Oluştur & Giriş Yap (R1)" : "Kaydet (R1)",
                                icon: "checkmark.circle.fill",
                                focused: buttonsSelected && editor.buttonCol == 0,
                                accent: accent,
                                primary: true
                            ) {
                                AudioManager.shared.play(.confirm)
                                editor.save(to: settings)
                                onClose()
                            }
                            ActionButton(
                                title: "Vazgeç (○)",
                                icon: "xmark.circle",
                                focused: buttonsSelected && editor.buttonCol == 1,
                                accent: accent
                            ) {
                                AudioManager.shared.play(.back)
                                onClose()
                            }
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 80)

                Spacer(minLength: 0)

                HintBar(items: [
                    HintItem(symbol: "arrow.up.and.down.circle", text: "Alan Seç"),
                    HintItem(symbol: "xmark.circle", text: "Ekran Klavyesi / Değiştir"),
                    HintItem(symbol: "arrow.left.and.right.circle", text: "Seçenek Değiştir"),
                    HintItem(symbol: "r1.rectangle.roundedbottom", text: "Kaydet"),
                    HintItem(symbol: "circle.circle", text: "Vazgeç"),
                ])
            }

            // PlayStation On-Screen Keyboard modal
            if let field = editor.activeField {
                OnScreenKeyboardView(editor: editor, field: field, accent: accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: editor.activeField)
    }

    private var livePreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CANLI ÖNİZLEME")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(accent.mix(with: .white, by: 0.5))

            HStack(spacing: 16) {
                AvatarView(size: 86, overrideAvatar: editor.avatar)
                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2.5))
                    .shadow(color: accent.opacity(0.6), radius: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(editor.fullName.isEmpty ? (editor.displayName.isEmpty ? "Oyuncu" : editor.displayName) : editor.fullName)
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                    if !editor.gamertag.isEmpty {
                        Text("@\(editor.gamertag)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accent.mix(with: .white, by: 0.45))
                    }
                }
            }

            Text(editor.bio.isEmpty ? "Hakkımda yazısı burada görünecek…" : editor.bio)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(editor.bio.isEmpty ? 0.4 : 0.85))
                .lineLimit(3)

            Divider().overlay(.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 8) {
                if !editor.location.isEmpty {
                    Label(editor.location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .medium))
                }
                if !editor.genre.isEmpty {
                    Label("Favori tür: \(editor.genre)", systemImage: "heart.fill")
                        .font(.system(size: 14, weight: .medium))
                }
                Label("Karşılama: Hoş geldin, \(editor.gamertag.isEmpty ? editor.displayName : editor.gamertag)", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Divider().overlay(.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                Text("AÇILIŞ MARKASI")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))
                BrandWordmark(text: editor.brandName.isEmpty ? "ZINKX ARENA" : editor.brandName, accent: accent, size: 24)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    private func fieldRow(_ field: ProfileFieldKind, selected: Bool) -> some View {
        let val = editor.value(for: field)
        return HStack(spacing: 14) {
            Image(systemName: field == .avatar ? editor.avatar.symbol : field.icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 28)
                .foregroundStyle(selected ? .white : accent.mix(with: .white, by: 0.45))

            Text(field.title)
                .font(.system(size: 17, weight: .semibold))

            Spacer(minLength: 16)

            if field.isTextField {
                HStack(spacing: 10) {
                    Text(val.isEmpty ? field.placeholder : val)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(val.isEmpty ? 0.38 : 0.92))
                        .lineLimit(1)
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(selected ? 0.95 : 0.4))
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).opacity(selected ? 1 : 0.3)
                    Text(val).font(.system(size: 16, weight: .semibold)).frame(minWidth: 110)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).opacity(selected ? 1 : 0.3)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(selected ? accent : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.95 : 0.08), lineWidth: selected ? 2 : 1)
        )
        .scaleEffect(selected ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: selected)
        .contentShape(Rectangle())
    }
}
