import SwiftUI
import AppKit

// MARK: - Shared buttons

struct ActionButton: View {
    let title: String
    let icon: String
    let focused: Bool
    let accent: Color
    var primary = false
    var large = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.system(size: large ? 22 : 16, weight: .bold))
            .foregroundStyle(primary || focused ? Color.black : .white)
            .padding(.horizontal, large ? 40 : 20)
            .padding(.vertical, large ? 16 : 11)
            .background(primary || focused ? Color.white : Color.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3).padding(-6).opacity(focused ? 1 : 0))
            .shadow(color: focused ? accent.opacity(0.8) : .clear, radius: 16)
            .scaleEffect(focused ? 1.05 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: focused)
        }
        .buttonStyle(.plain)
    }
}

enum GameAction: Equatable {
    case play, details, favorite, toggleMedia, close
}

// MARK: - Home hero info

struct GameInfoView: View {
    let game: Game
    let stats: GameStats?
    let details: GameDetails?
    let compat: CompatInfo?
    let media: GameMediaItem?
    let slideIndex: Int
    let showingVideo: Bool
    let musicPlaying: Bool
    let isRunning: Bool
    let isFavorite: Bool
    let actions: [GameAction]
    let focusedAction: Int?
    let accent: Color
    let onAction: (GameAction) -> Void
    let onSelectSlide: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(game.title)
                            .font(.system(size: 46, weight: .bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.55)
                            .shadow(color: .black.opacity(0.6), radius: 12)
                        if isFavorite {
                            Image(systemName: "star.fill").font(.system(size: 26)).foregroundStyle(.yellow)
                        }
                    }

                    HStack(spacing: 8) {
                        Chip(text: "PlayStation 3")
                        Chip(text: details?.region ?? DetailsStore.region(for: game.titleID))
                        Chip(text: game.titleID)
                        if musicPlaying {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .symbolEffect(.variableColor.iterative, isActive: true)
                                    .foregroundStyle(accent.mix(with: .white, by: 0.45))
                                Text(L("Disk Müziği Çalıyor"))
                            }
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(accent.opacity(0.35), in: Capsule())
                            .overlay(Capsule().strokeBorder(accent.mix(with: .white, by: 0.4).opacity(0.6), lineWidth: 1))
                        }
                        if let last = stats?.lastPlayed {
                            Chip(text: L("Son oynama: \(Format.relative(last))"))
                        } else {
                            Chip(text: L("Hiç oynanmadı"))
                        }
                    }

                    HStack(spacing: 12) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { i, a in
                            let (title, icon) = label(a)
                            ActionButton(title: title, icon: icon, focused: focusedAction == i, accent: accent,
                                         primary: a == .play, large: a == .play) { onAction(a) }
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 12)

                if let media, !media.photos.isEmpty || media.hasDiscVideo {
                    DiscMediaStrip(
                        media: media,
                        slideIndex: slideIndex,
                        showingVideo: showingVideo,
                        accent: accent,
                        onToggleVideo: { onAction(.toggleMedia) },
                        onSelectSlide: onSelectSlide
                    )
                }
            }

            InfoShelf(stats: stats, details: details, compat: compat, accent: accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ a: GameAction) -> (String, String) {
        switch a {
        case .play: isRunning ? (L("Oyuna dön"), "arrow.uturn.forward") : (L("Oyna"), "play.fill")
        case .details: (L("Detaylar"), "info.circle")
        case .favorite: isFavorite ? (L("Favorilerde"), "star.fill") : (L("Favorilere ekle"), "star")
        case .toggleMedia: showingVideo ? (L("Fotoğraf Slaytı"), "photo.on.rectangle.angled") : (L("Disk Videosu"), "film.fill")
        case .close: (L("Oyunu kapat"), "xmark")
        }
    }
}

struct DiscMediaStrip: View {
    let media: GameMediaItem
    let slideIndex: Int
    let showingVideo: Bool
    let accent: Color
    let onToggleVideo: () -> Void
    let onSelectSlide: (Int) -> Void

    var body: some View {
        let photos = Array(media.photos.prefix(4))
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "opticaldisc.fill")
                    .foregroundStyle(accent.mix(with: .white, by: 0.45))
                Text(L("CD MEDYA GALERİSİ"))
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.7))
                if media.hasDiscVideo {
                    Button(action: onToggleVideo) {
                        HStack(spacing: 5) {
                            Image(systemName: showingVideo ? "film.fill" : "photo.stack.fill")
                            Text(showingVideo ? L("VİDEO AKTİF") : L("SLAYT AKTİF"))
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(showingVideo ? accent : Color.white.opacity(0.16), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.offset) { idx, url in
                    let active = !showingVideo && (slideIndex % max(1, media.photos.count)) == idx
                    Button {
                        onSelectSlide(idx)
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = ImageCache.shared.image(url) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(16 / 9, contentMode: .fill)
                                    .frame(width: 90, height: 50)
                                    .clipped()
                            } else {
                                Color.white.opacity(0.1)
                                    .frame(width: 90, height: 50)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(active ? .white : .white.opacity(0.18), lineWidth: active ? 2 : 1)
                        )
                        .shadow(color: active ? accent.opacity(0.8) : .black.opacity(0.4), radius: active ? 8 : 3)
                        .scaleEffect(active ? 1.05 : 1.0)
                        .animation(.easeOut(duration: 0.2), value: active)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }
}

struct InfoShelf: View {
    let stats: GameStats?
    let details: GameDetails?
    let compat: CompatInfo?
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            InfoCard(icon: "clock", title: L("Oynama süresi"),
                     value: (stats?.totalSeconds ?? 0) > 0 ? Format.duration(stats!.totalSeconds) : L("Henüz yok"),
                     sub: stats?.sessions.map { L("\($0) oturum") })
            InfoCard(icon: "trophy", title: L("Kupalar"),
                     value: trophyValue,
                     sub: details?.trophyCounts.map { "\($0.2) \($0.0.prefix(1))" }.joined(separator: " · "),
                     progress: trophyProgress, accent: accent)
            InfoCard(icon: "externaldrive.fill.badge.checkmark", title: L("Kayıtlar"),
                     value: details.map { $0.saves.isEmpty ? L("Kayıt yok") : L("\($0.saves.count) kayıt") } ?? "…",
                     sub: details?.saves.first?.modified.map { L("Son: \(Format.relative($0))") })
            InfoCard(icon: "checkmark.seal", title: L("RPCS3 uyumluluğu"),
                     value: compat?.label ?? L("Bilinmiyor"), dot: compat?.color)
            InfoCard(icon: "internaldrive", title: L("Boyut"), value: details?.sizeText ?? L("Hesaplanıyor…"))
            InfoCard(icon: "number", title: L("Sürüm"),
                     value: details?.version ?? "—",
                     sub: details?.updateVersion.map { L("Güncelleme \($0) kurulu") })
        }
    }

    private var trophyValue: String {
        guard let d = details else { return "…" }
        return d.trophies.isEmpty ? L("Kupa yok") : "\(d.unlocked) / \(d.trophies.count)"
    }

    private var trophyProgress: Double? {
        guard let d = details, !d.trophies.isEmpty else { return nil }
        return Double(d.unlocked) / Double(d.trophies.count)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    var sub: String? = nil
    var progress: Double? = nil
    var accent: Color = .white
    var dot: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 6) {
                if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
                Text(value).font(.system(size: 16, weight: .bold)).lineLimit(1).minimumScaleFactor(0.65)
            }
            if let progress {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule().fill(accent).frame(width: max(4, g.size.width * progress))
                    }
                }
                .frame(height: 5)
            }
            if let sub, !sub.isEmpty {
                Text(sub).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 88, alignment: .topLeading)
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Game detail screen

enum DetailAction: CaseIterable {
    case play, favorite, resolution, fps, reveal
}

struct GameDetailView: View {
    @ObservedObject var perfStore = PerfProfileStore.shared
    let game: Game
    let details: GameDetails?
    let compat: CompatInfo?
    let stats: GameStats?
    let isFavorite: Bool
    let isRunning: Bool
    let accent: Color
    let focus: Int
    let onAction: (DetailAction) -> Void

    static let actionCount = DetailAction.allCases.count

    private var perf: GamePerfProfile { perfStore.profile(for: game.titleID) }

    static func rowCount(_ d: GameDetails?) -> Int {
        (d?.trophies.count ?? 0) + (d?.saves.count ?? 0)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black
                if let img = ImageCache.shared.image(game.backgroundURL ?? game.iconURL) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: game.backgroundURL == nil ? 50 : 18)
                        .clipped()
                        .opacity(0.45)
                }
                LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.4)], startPoint: .leading, endPoint: .trailing)

                VStack(alignment: .leading, spacing: 24) {
                    header
                    HStack(alignment: .top, spacing: 28) {
                        VStack(alignment: .leading, spacing: 18) {
                            infoCard
                            statsCard
                        }
                        .frame(width: min(460, geo.size.width * 0.40))
                        listColumn
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 40)
                .padding(.bottom, 64)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 32) {
            if let img = ImageCache.shared.image(game.iconURL) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 10)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text(game.title).font(.system(size: 48, weight: .bold)).lineLimit(2).minimumScaleFactor(0.6)
                    if isFavorite { Image(systemName: "star.fill").font(.system(size: 28)).foregroundStyle(.yellow) }
                }
                HStack(spacing: 10) {
                    Chip(text: details?.region ?? "")
                    Chip(text: game.titleID)
                    if let v = details?.version { Chip(text: L("Sürüm \(v)")) }
                    if let c = compat {
                        HStack(spacing: 6) { Circle().fill(c.color).frame(width: 8, height: 8); Text(c.label) }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
                HStack(spacing: 12) {
                    ActionButton(title: isRunning ? L("Oyuna dön") : L("Oyna"), icon: isRunning ? "arrow.uturn.forward" : "play.fill",
                                 focused: focus == 0, accent: accent, primary: true, large: true) { onAction(.play) }
                    ActionButton(title: isFavorite ? L("Favorilerde") : L("Favori"), icon: isFavorite ? "star.fill" : "star",
                                 focused: focus == 1, accent: accent) { onAction(.favorite) }
                    ActionButton(title: L("Çözünürlük: \(perf.res.label)"), icon: "sparkles.tv",
                                 focused: focus == 2, accent: accent) { onAction(.resolution) }
                    ActionButton(title: L("FPS: \(perf.fps.label)"), icon: "gauge.with.dots.needle.67percent",
                                 focused: focus == 3, accent: accent) { onAction(.fps) }
                    ActionButton(title: "Finder", icon: "folder", focused: focus == 4, accent: accent) { onAction(.reveal) }
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: Left column

    private var infoCard: some View {
        DetailCard(title: L("Oyun bilgileri"), icon: "info.circle") {
            InfoRow(L("Bölge"), details?.region ?? "—")
            InfoRow(L("Oyun kimliği"), game.titleID)
            InfoRow(L("Tür"), game.isDisc ? L("Disk oyunu") : L("Dijital (PSN)"))
            InfoRow(L("Sürüm"), details?.version ?? "—")
            InfoRow(L("Güncelleme"), details?.updateVersion.map { L("\($0) kurulu") } ?? L("Yok"))
            InfoRow(L("Gerekli firmware"), details?.systemVersion ?? "—")
            InfoRow(L("Çözünürlük"), details?.resolutions.joined(separator: ", ").nilIfEmpty ?? "—")
            InfoRow(L("Ses"), details?.sound.joined(separator: ", ").nilIfEmpty ?? "—")
            InfoRow(L("Yaş sınırı"), details?.parental ?? "—")
            InfoRow(L("Boyut"), details?.sizeText ?? L("Hesaplanıyor…"))
            InfoRow(L("RPCS3 Çözünürlük"), perf.res.label)
            InfoRow(L("RPCS3 FPS Limiti"), perf.fps.label)
            InfoRow(L("Uyumluluk"), compat.map { c in c.date.map { "\(c.label) (\($0))" } ?? c.label } ?? L("Bilinmiyor"))
        }
    }

    private var statsCard: some View {
        DetailCard(title: L("İstatistiklerin"), icon: "chart.bar.fill") {
            InfoRow(L("Toplam süre"), (stats?.totalSeconds ?? 0) > 0 ? Format.duration(stats!.totalSeconds) : L("Henüz oynanmadı"))
            InfoRow(L("Oturum"), "\(stats?.sessions ?? 0)")
            InfoRow(L("İlk oynama"), stats?.firstPlayed.map(fullDate) ?? "—")
            InfoRow(L("Son oynama"), stats?.lastPlayed.map { Format.relative($0) } ?? "—")
        }
    }

    // MARK: Right column

    private var listColumn: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    trophyHeader
                    let trophies = details?.trophies ?? []
                    if trophies.isEmpty {
                        Text(L("Bu oyunun kupa bilgisi bulunamadı.")).foregroundStyle(.white.opacity(0.5)).padding(.bottom, 10)
                    }
                    ForEach(Array(trophies.enumerated()), id: \.element.id) { i, t in
                        TrophyRow(trophy: t, focused: focus == GameDetailView.actionCount + i, accent: accent)
                            .id("t\(t.id)")
                    }

                    Text(L("Kayıtlar")).font(.system(size: 24, weight: .bold)).padding(.top, 24)
                    let saves = details?.saves ?? []
                    if saves.isEmpty {
                        Text(L("Henüz kayıt yok. Oyunda kaydettiğinde burada görünür.")).foregroundStyle(.white.opacity(0.5))
                    }
                    ForEach(Array(saves.enumerated()), id: \.element.id) { i, s in
                        SaveRow(save: s, focused: focus == GameDetailView.actionCount + trophies.count + i, accent: accent)
                            .id("s\(s.id)")
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .onChange(of: focus) { _, f in
                let r = f - GameDetailView.actionCount
                let trophies = details?.trophies ?? []
                let saves = details?.saves ?? []
                withAnimation(.easeOut(duration: 0.2)) {
                    if r < 0 { proxy.scrollTo("trophyHeader", anchor: .top) }
                    else if r < trophies.count { proxy.scrollTo("t\(trophies[r].id)", anchor: .center) }
                    else if r - trophies.count < saves.count { proxy.scrollTo("s\(saves[r - trophies.count].id)", anchor: .center) }
                }
            }
        }
    }

    private var trophyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Kupalar")).font(.system(size: 24, weight: .bold))
                if let d = details, !d.trophies.isEmpty {
                    Text("\(d.unlocked) / \(d.trophies.count)").font(.system(size: 20, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }
            }
            if let d = details, !d.trophies.isEmpty {
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    GeometryReader { g in
                        Capsule().fill(accent).frame(width: max(6, g.size.width * Double(d.unlocked) / Double(d.trophies.count)))
                    }
                }
                .frame(height: 8)
                HStack(spacing: 18) {
                    ForEach(d.trophyCounts, id: \.0) { name, got, total, color in
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill").foregroundStyle(color)
                            Text("\(name) \(got)/\(total)").font(.system(size: 14, weight: .medium))
                        }
                    }
                }
            }
        }
        .padding(.bottom, 6)
        .id("trophyHeader")
    }

    private func fullDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.wide).year().locale(L10n.locale))
    }
}

struct DetailCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.system(size: 18, weight: .bold)).padding(.bottom, 4)
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct InfoRow: View {
    let key: String
    let value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 16)
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing).lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.system(size: 15))
    }
}

struct TrophyRow: View {
    let trophy: TrophyInfo
    let focused: Bool
    let accent: Color

    var body: some View {
        let secret = trophy.hidden && !trophy.unlocked
        HStack(spacing: 14) {
            ZStack {
                if let img = ImageCache.shared.image(trophy.iconURL), !secret {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.1)
                    Image(systemName: secret ? "lock.fill" : "trophy.fill").foregroundStyle(trophy.color)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .saturation(trophy.unlocked ? 1 : 0)
            .opacity(trophy.unlocked ? 1 : 0.55)

            VStack(alignment: .leading, spacing: 3) {
                Text(secret ? L("Gizli kupa") : trophy.name).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(secret ? L("Açınca ortaya çıkacak.") : trophy.detail)
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill").foregroundStyle(trophy.color)
                    Text(trophy.typeName)
                }
                .font(.system(size: 12, weight: .semibold))
                if trophy.unlocked {
                    Label(trophy.unlockedAt.map { Format.relative($0) } ?? L("Kazanıldı"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(focused ? accent.opacity(0.85) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(focused ? 0.9 : 0), lineWidth: 2))
    }
}

struct SaveRow: View {
    let save: SaveInfo
    let focused: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let img = ImageCache.shared.image(save.iconURL) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.1)
                    Image(systemName: "doc.fill")
                }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(save.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(save.detail.isEmpty ? save.subtitle : save.detail)
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
            }
            Spacer()
            if let m = save.modified {
                Text(Format.relative(m)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(focused ? accent.opacity(0.85) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(focused ? 0.9 : 0), lineWidth: 2))
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
