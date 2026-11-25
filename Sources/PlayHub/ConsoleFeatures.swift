import SwiftUI
import AppKit

// MARK: - PlayStation 5 Style Top-Right Notification Toast

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color? = nil
    var imageURL: URL? = nil
}

final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var current: ToastMessage?

    func show(icon: String, title: String, subtitle: String, tint: Color? = nil, imageURL: URL? = nil) {
        let msg = ToastMessage(icon: icon, title: title, subtitle: subtitle, tint: tint, imageURL: imageURL)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                self.current = msg
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if self.current?.id == msg.id {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.current = nil
                    }
                }
            }
        }
    }
}

struct PS5ToastOverlay: View {
    @ObservedObject var center = ToastCenter.shared
    let accent: Color

    var body: some View {
        VStack {
            HStack {
                Spacer()
                if let msg = center.current {
                    HStack(spacing: 14) {
                        ZStack {
                            if let url = msg.imageURL, let img = ImageCache.shared.image(url) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            } else {
                                Circle()
                                    .fill((msg.tint ?? accent).gradient)
                                    .frame(width: 44, height: 44)
                                Image(systemName: msg.icon)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Text(msg.subtitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(width: 370)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .background(Color(red: 0.05, green: 0.07, blue: 0.14).opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder((msg.tint ?? accent).opacity(0.75), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 22, y: 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 26)
            .padding(.trailing, 36)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - PlayStation Trophy Level Calculator & Kupalar Tab

struct TrophySummary {
    var platinum = 0
    var gold = 0
    var silver = 0
    var bronze = 0
    var totalUnlocked = 0
    var totalAvailable = 0

    var points: Int { platinum * 300 + gold * 90 + silver * 30 + bronze * 15 }
    var level: Int { max(1, 1 + points / 60) }
    var progress: Double { Double(points % 60) / 60.0 }
}

extension DetailsStore {
    var trophySummary: TrophySummary {
        var s = TrophySummary()
        for d in details.values {
            s.totalAvailable += d.trophies.count
            for t in d.trophies where t.unlocked {
                s.totalUnlocked += 1
                switch t.type {
                case "P": s.platinum += 1
                case "G": s.gold += 1
                case "S": s.silver += 1
                default: s.bronze += 1
                }
            }
        }
        return s
    }
}

struct TrophyRoomView: View {
    @EnvironmentObject var library: GameLibrary
    @EnvironmentObject var details: DetailsStore
    @EnvironmentObject var settings: AppSettings

    let gameIndex: Int
    let trophyIndex: Int
    let onSelectGame: (Int) -> Void

    private var accent: Color { settings.accent.color }
    private var games: [Game] { library.games }
    private var currentGame: Game? {
        games.indices.contains(gameIndex) ? games[gameIndex] : games.first
    }
    private var currentDetails: GameDetails? {
        currentGame.flatMap { details.details[$0.id] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Top Trophy Level & Counts banner
            summaryBanner

            // Game selector strip
            HStack(spacing: 14) {
                ForEach(Array(games.enumerated()), id: \.element.id) { idx, g in
                    let selected = idx == gameIndex
                    let gd = details.details[g.id]
                    let total = gd?.trophies.count ?? 0
                    let unlocked = gd?.unlocked ?? 0
                    Button {
                        onSelectGame(idx)
                    } label: {
                        HStack(spacing: 12) {
                            if let img = ImageCache.shared.image(g.iconURL) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .lineLimit(1)
                                Text(total > 0 ? "\(unlocked) / \(total) Kupa" : "Kupa seti yok")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(selected ? accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(selected ? 0.95 : 0.12), lineWidth: selected ? 2 : 1)
                        )
                        .scaleEffect(selected ? 1.03 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Trophy list for selected game
            let list = currentDetails?.trophies ?? []
            if list.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "trophy.circle")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Bu oyuna ait kupa listesi bulunmuyor")
                        .font(.system(size: 20, weight: .bold))
                    Text("Bazı eski PS3 oyunları kupa sisteminden önce çıkmıştır veya ilk açılışta kupa paketini kurar.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { idx, t in
                                TrophyRow(trophy: t, focused: idx == trophyIndex, accent: accent)
                                    .id("tr_\(idx)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onAppear {
                        proxy.scrollTo("tr_0", anchor: .top)
                    }
                    .onChange(of: trophyIndex) { _, idx in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("tr_\(idx)", anchor: idx == 0 ? .top : .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    private var summaryBanner: some View {
        let s = details.trophySummary
        return HStack(spacing: 28) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(accent.gradient).frame(width: 66, height: 66)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.28))
                }
                .shadow(color: accent.opacity(0.7), radius: 16)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text("Kupa Seviyesi \(s.level)")
                            .font(.system(size: 26, weight: .bold))
                        Text("\(s.totalUnlocked) / \(s.totalAvailable)")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.14), in: Capsule())
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.16)).frame(width: 220, height: 7)
                        Capsule().fill(accent).frame(width: max(12, 220 * max(0.08, s.progress)), height: 7)
                    }
                }
            }

            Spacer()

            HStack(spacing: 24) {
                gradePill("Platin", count: s.platinum, color: Color(red: 0.72, green: 0.82, blue: 0.95))
                gradePill("Altın", count: s.gold, color: Color(red: 0.95, green: 0.76, blue: 0.25))
                gradePill("Gümüş", count: s.silver, color: Color(red: 0.78, green: 0.8, blue: 0.84))
                gradePill("Bronz", count: s.bronze, color: Color(red: 0.8, green: 0.5, blue: 0.3))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func gradePill(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)").font(.system(size: 20, weight: .bold))
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - PS5 Bottom Control Center Quick Dock

struct ControlCenterDock: View {
    let items: [MenuItem]
    let index: Int
    let accent: Color
    let controllerName: String?
    let batteryLevel: Float?
    let onPick: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                // Selected card title & status pill
                HStack(spacing: 14) {
                    Text(items.indices.contains(index) ? items[index].title : "Kontrol Merkezi")
                        .font(.system(size: 22, weight: .bold))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                        Text(controllerName ?? "Klavye & Kontrolcü")
                        if let batteryLevel {
                            Text("%\(Int(batteryLevel * 100))")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))

                // Horizontal dock of PS5 Control Center tiles
                HStack(spacing: 10) {
                    ForEach(items.indices, id: \.self) { i in
                        let focused = i == index
                        Button {
                            onPick(i)
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: items[i].icon)
                                    .font(.system(size: 21, weight: .semibold))
                                Text(items[i].title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .frame(width: 92, height: 74)
                            .background(
                                focused ? Color.white : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .foregroundStyle(focused ? Color.black : .white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 21, style: .continuous)
                                    .strokeBorder(accent, lineWidth: 3)
                                    .padding(-4)
                                    .opacity(focused ? 1 : 0)
                            )
                            .shadow(color: focused ? accent.opacity(0.85) : .black.opacity(0.4), radius: focused ? 18 : 6, y: 6)
                            .scaleEffect(focused ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .background(Color(red: 0.04, green: 0.06, blue: 0.13).opacity(0.88), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.75), radius: 36, y: 14)

                Text("◀ ▶ Seç   ✕ Çalıştır   ○ Kapat")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 34)
            .animation(.spring(response: 0.24, dampingFraction: 0.8), value: index)
        }
    }
}
