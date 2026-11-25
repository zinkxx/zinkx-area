import SwiftUI
import AppKit

private let accentBlue = Color(red: 0.0, green: 0.44, blue: 0.95)
private let defaultGradient = LinearGradient(
    colors: [Color(red: 0.01, green: 0.04, blue: 0.14), Color(red: 0.03, green: 0.16, blue: 0.42)],
    startPoint: .bottomLeading, endPoint: .topTrailing
)

// MARK: - Background

struct BackgroundView: View {
    let game: Game?
    let media: GameMediaItem?
    let style: BackgroundStyle
    let mediaDisplay: GameMediaDisplay
    let slideIndex: Int
    let showingVideo: Bool
    let videoPaused: Bool
    let accent: Color
    let dimmed: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                defaultGradient
                if style != .waves, let g = game {
                    ZStack {
                        artwork(for: g)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .id("\(g.id)_\(activePhotoURL(for: g)?.path ?? "art")")
                            .transition(.opacity)

                        if showingVideo, mediaDisplay == .videoAndSlides, let vURL = media?.videoURL {
                            LoopingVideoView(url: vURL, isPaused: videoPaused)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .transition(.opacity)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .animation(.easeInOut(duration: 0.75), value: slideIndex)
                    .animation(.easeInOut(duration: 0.65), value: showingVideo)
                }
                if style == .waves {
                    WavesView(accent: accent)
                }
                LinearGradient(colors: [.black.opacity(0.82), .black.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .opacity(style == .waves ? 0.5 : 1)
                LinearGradient(colors: [.clear, .black.opacity(0.92)],
                               startPoint: UnitPoint(x: 0.5, y: 0.42), endPoint: .bottom)
                LinearGradient(colors: [.black.opacity(0.65), .clear],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3))
                if style == .both {
                    WavesView(accent: .clear, intensity: 0.8).blendMode(.screen)
                }
                Color.black.opacity(dimmed ? 0.55 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.5), value: game?.id)
            .animation(.easeInOut(duration: 0.3), value: dimmed)
        }
    }

    private func activePhotoURL(for g: Game) -> URL? {
        if mediaDisplay != .staticArt, let photos = media?.photos, !photos.isEmpty {
            return photos[slideIndex % photos.count]
        }
        return g.backgroundURL
    }

    @ViewBuilder
    private func artwork(for g: Game) -> some View {
        if let url = activePhotoURL(for: g), let bg = ImageCache.shared.image(url) {
            Image(nsImage: bg).resizable().aspectRatio(contentMode: .fill)
                .scaleEffect((slideIndex % 2 == 0) ? 1.0 : 1.07)
                .animation(.easeInOut(duration: 4.5), value: slideIndex)
        } else if let icon = ImageCache.shared.image(g.iconURL) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fill)
                .blur(radius: 45).saturation(1.4).scaleEffect(1.25).opacity(0.9)
        } else {
            defaultGradient
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var input: InputManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var details: DetailsStore
    let tab: Tab
    let running: Game?
    let onTab: (Tab) -> Void

    var body: some View {
        let trophyLevel = details.trophySummary.level
        HStack(alignment: .center, spacing: 22) {
            LogoMark(accent: settings.accent.color)
                .frame(width: 34, height: 34)
                .padding(.trailing, 6)
            HStack(spacing: 26) {
                tabLabel("Oyunlar", .games)
                tabLabel("Kupalar", .trophies)
                tabLabel("Profil", .profile)
                tabLabel("Ayarlar", .settings)
            }
            Text("L1 / R1")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white.opacity(0.45))
            if let running {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("\(running.title) çalışıyor").lineLimit(1)
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.1), in: Capsule())
            }
            Spacer()
            if NSScreen.screens.count > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "display.2")
                        .foregroundStyle(settings.accent.color.mix(with: .white, by: 0.45))
                    Text(settings.targetScreenShortName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .contentShape(Capsule())
                .onTapGesture {
                    AudioManager.shared.play(.confirm)
                    settings.cycleScreen(1)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.28))
                Text("Sv. \(trophyLevel)")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(.white.opacity(0.1), in: Capsule())
            .onTapGesture { onTab(.trophies) }

            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                if let name = input.controllerName {
                    Text(name).lineLimit(1)
                    if let level = input.batteryLevel { BatteryIcon(level: level) }
                } else {
                    Text("Kol bağlı değil").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 15, weight: .medium))
            HStack(spacing: 10) {
                AvatarView(size: 34)
                Text(settings.greetingName).font(.system(size: 16, weight: .semibold))
            }
            .contentShape(Rectangle())
            .onTapGesture { onTab(.profile) }
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(ctx.date, format: .dateTime.hour().minute())
                    .font(.system(size: 24, weight: .medium))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 48)
        .padding(.top, 36)
    }

    private func tabLabel(_ title: String, _ t: Tab) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: tab == t ? .bold : .medium))
                .foregroundStyle(.white.opacity(tab == t ? 1 : 0.5))
            Capsule().fill(.white).frame(width: tab == t ? 30 : 0, height: 3)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTab(t) }
    }
}

struct BatteryIcon: View {
    let level: Float
    var body: some View {
        let name: String = switch level {
        case ..<0.15: "battery.0percent"
        case ..<0.4: "battery.25percent"
        case ..<0.65: "battery.50percent"
        case ..<0.9: "battery.75percent"
        default: "battery.100percent"
        }
        Image(systemName: name).foregroundStyle(level < 0.15 ? .red : .white)
    }
}

// MARK: - Game row

struct GameRow: View {
    let games: [Game]
    let selectedID: String?
    let scale: CGFloat
    var favorites: [String] = []
    var rowFocused = true
    let onSelect: (Game) -> Void
    let onLaunch: (Game) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 22) {
                    ForEach(games) { g in
                        GameCard(game: g, selected: g.id == selectedID, scale: scale,
                                 favorite: favorites.contains(g.id), ring: rowFocused)
                            .id(g.id)
                            .onTapGesture(count: 2) { onLaunch(g) }
                            .onTapGesture { onSelect(g) }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 18)
            }
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0.05, y: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220 * scale)
    }
}

struct GameCard: View {
    let game: Game
    let selected: Bool
    var scale: CGFloat = 1
    var favorite = false
    var ring = true

    var body: some View {
        let w: CGFloat = (selected ? 300 : 200) * scale
        let h = w * 176 / 320
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                if let img = ImageCache.shared.image(game.iconURL) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: w, height: h)
                } else {
                    defaultGradient
                    Text(game.title)
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center).padding(10)
                        .frame(width: w, height: h)
                }
                if favorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13 * scale, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(7)
                        .background(.black.opacity(0.55), in: Circle())
                        .padding(8)
                }
            }
            .frame(width: w, height: h)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3)
                    .padding(-6)
                    .opacity(selected && ring ? 1 : 0)
            )
            .shadow(color: .black.opacity(selected ? 0.6 : 0.35), radius: selected ? 22 : 8, y: 10)
            .saturation(selected ? 1 : 0.85)
            .opacity(selected ? 1 : 0.8)

            Text(game.title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .frame(width: w, alignment: .leading)
                .opacity(selected ? 1 : 0)
        }
        .contentShape(Rectangle())
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
    }
}

// MARK: - Hints

struct Hint: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 17))
            Text(text)
        }
    }
}

// MARK: - Overlays

struct LaunchingOverlay: View {
    let game: Game
    @State private var zoom = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                if let bg = ImageCache.shared.image(game.backgroundURL ?? game.iconURL) {
                    Image(nsImage: bg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: game.backgroundURL == nil ? 35 : 8)
                        .scaleEffect(zoom ? 1.12 : 1.0)
                        .opacity(0.55)
                        .clipped()
                }
                RadialGradient(colors: [.clear, .black.opacity(0.88)], center: .center, startRadius: 80, endRadius: 720)

                VStack(spacing: 24) {
                    if let img = ImageCache.shared.image(game.iconURL) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 2.5))
                            .shadow(color: .black.opacity(0.8), radius: 36, y: 14)
                            .scaleEffect(zoom ? 1.04 : 0.94)
                    }
                    Text(game.title)
                        .font(.system(size: 42, weight: .bold))
                        .shadow(color: .black.opacity(0.7), radius: 14)
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text("KONSOL SİSTEMİ  ·  OYUN BAŞLATILIYOR")
                            .font(.system(size: 14, weight: .heavy))
                            .tracking(2.0)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 3.5)) { zoom = true }
        }
    }
}

struct OptionsMenu: View {
    let items: [MenuItem]
    let index: Int
    let accent: Color
    let onPick: (Int) -> Void

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Text("Menü").font(.system(size: 22, weight: .bold)).padding(.bottom, 12)
                ForEach(items.indices, id: \.self) { i in
                    HStack(spacing: 14) {
                        Image(systemName: items[i].icon).frame(width: 24)
                        Text(items[i].title)
                        Spacer()
                    }
                    .font(.system(size: 18, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(i == index ? accent : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(i) }
                }
                Spacer()
                Text("✕ Seç   ○ Kapat").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(width: 400)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.5))
        }
        .ignoresSafeArea()
    }
}

struct ErrorToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message)
        }
        .font(.system(size: 17, weight: .medium))
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView: View {
    let scanning: Bool
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            if scanning {
                ProgressView()
                Text("Oyunlar aranıyor…").font(.system(size: 20))
            } else {
                Image(systemName: "externaldrive.badge.questionmark").font(.system(size: 64))
                Text("Oyun bulunamadı").font(.system(size: 30, weight: .bold))
                Text("Kendi yedeklediğin oyun klasörlerini Ayarlar → Oyun Klasörü Ekle menüsünden veya ~/Games/PS3 dizininden ekleyebilirsin.\nHarici diskinde “PS3 Games” klasörü varsa bağladığında otomatik algılanır (ya da △ tuşuna bas).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 17))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hints

struct HintItem: Hashable {
    let symbol: String
    let text: String
}

struct HintBar: View {
    let items: [HintItem]

    var body: some View {
        HStack(spacing: 26) {
            Spacer()
            ForEach(items, id: \.self) { Hint(symbol: $0.symbol, text: $0.text) }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 48)
        .padding(.bottom, 20)
        .padding(.top, 8)
    }
}
