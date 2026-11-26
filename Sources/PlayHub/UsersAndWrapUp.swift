import SwiftUI
import AppKit

// MARK: - 5a. Weekly Playtime Activity & Gamer Badges (Wrap-Up)

struct GamerBadge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let unlocked: Bool
    let color: Color
}

final class WrapUpStore: ObservableObject {
    static let shared = WrapUpStore()
    @Published var dailySeconds: [String: Double] = [:]

    private let key = "wrapUpDailySeconds"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            dailySeconds = decoded
        }
    }

    func recordPlaytime(seconds: Double) {
        guard seconds >= 4 else { return }
        let k = Self.dayKey(for: Date())
        dailySeconds[k, default: 0] += seconds
        if let data = try? JSONEncoder().encode(dailySeconds) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func last7Days() -> [(label: String, seconds: Double)] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = L10n.locale
        fmt.dateFormat = "EEE"
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let k = Self.dayKey(for: d)
            return (fmt.string(from: d), dailySeconds[k] ?? 0)
        }
    }

    func badges(gamesCount: Int, totalSeconds: Double, unlockedTrophies: Int, favoritesCount: Int) -> [GamerBadge] {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNightOwl = hour >= 22 || hour <= 4 || totalSeconds > 0
        return [
            GamerBadge(id: "founder", icon: "hexagon.fill", title: L("Arena Kurucusu"),
                       subtitle: L("Zinkx Arena konsol sistemini kurdu"), unlocked: true,
                       color: Color(red: 0.0, green: 0.68, blue: 0.75)),
            GamerBadge(id: "collector", icon: "opticaldisc.fill", title: L("Koleksiyoncu"),
                       subtitle: L("Kütüphaneye 3+ PS3 oyunu ekledi"), unlocked: gamesCount >= 3,
                       color: Color(red: 0.55, green: 0.35, blue: 0.98)),
            GamerBadge(id: "nightowl", icon: "moon.stars.fill", title: L("Gece Kuşu"),
                       subtitle: L("Gece seansında konsolu açtı"), unlocked: isNightOwl,
                       color: Color(red: 0.95, green: 0.55, blue: 0.15)),
            GamerBadge(id: "fav", icon: "star.fill", title: L("Seçici Oyuncu"),
                       subtitle: L("Favori oyun listesini oluşturdu"), unlocked: favoritesCount >= 1,
                       color: Color(red: 0.96, green: 0.78, blue: 0.2)),
            GamerBadge(id: "trophy", icon: "trophy.fill", title: L("Kupa Avcısı"),
                       subtitle: L("İlk PlayStation kupasını kazandı"), unlocked: unlockedTrophies >= 1,
                       color: Color(red: 0.9, green: 0.25, blue: 0.45)),
            GamerBadge(id: "marathon", icon: "flame.fill", title: L("Maratoncu"),
                       subtitle: L("Toplam 1+ saat oyun oynadı"), unlocked: totalSeconds >= 3600,
                       color: Color(red: 0.15, green: 0.78, blue: 0.45)),
        ]
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

struct WrapUpSectionView: View {
    @ObservedObject var store = WrapUpStore.shared
    let gamesCount: Int
    let totalSeconds: Double
    let unlockedTrophies: Int
    let favoritesCount: Int
    let accent: Color

    var body: some View {
        let days = store.last7Days()
        let maxSec = max(60, days.map(\.seconds).max() ?? 60)
        let badges = store.badges(
            gamesCount: gamesCount,
            totalSeconds: totalSeconds,
            unlockedTrophies: unlockedTrophies,
            favoritesCount: favoritesCount
        )

        HStack(alignment: .top, spacing: 20) {
            // Left: 7-Day Activity Bar Chart
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L("Haftalık Aktivite"), systemImage: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(L("Son 7 Gün"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                        let ratio = min(1.0, d.seconds / maxSec)
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottom) {
                                Capsule()
                                    .fill(.white.opacity(0.08))
                                    .frame(width: 24, height: 84)
                                Capsule()
                                    .fill(d.seconds > 0 ? accent.gradient : Color.white.opacity(0.18).gradient)
                                    .frame(width: 24, height: max(8, 84 * ratio))
                            }
                            Text(d.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(width: 320)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Right: Unlockable Gamer Badges Grid
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L("Oyuncu Rozetleri"), systemImage: "medal.fill")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(L("\(badges.filter(\.unlocked).count) / \(badges.count) Açıldı"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent.mix(with: .white, by: 0.45))
                }

                let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(badges) { b in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(b.unlocked ? b.color.gradient : Color.white.opacity(0.1).gradient)
                                    .frame(width: 36, height: 36)
                                Image(systemName: b.unlocked ? b.icon : "lock.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white.opacity(b.unlocked ? 1 : 0.4))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)
                                Text(b.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color.white.opacity(b.unlocked ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .opacity(b.unlocked ? 1 : 0.55)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

// MARK: - 5c. Multi-User Profile Switcher ("Kim Oynuyor?" PS5 Login Screen)

struct UserProfileAccount: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var fullName: String
    var gamertag: String
    var bio: String
    var location: String?
    var favoriteGenre: String?
    var avatarRaw: String
    var accentRaw: String
    var rpcs3UserID: String
}

final class UserAccountStore: ObservableObject {
    static let shared = UserAccountStore()

    @Published var accounts: [UserProfileAccount] = []
    @Published var activeID: String = "main"
    @Published var selectedIndex: Int = 0

    private let key = "zinkxUserAccounts"

    private init() {
        let s = AppSettings.shared
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([UserProfileAccount].self, from: data),
           !decoded.isEmpty {
            accounts = decoded
        } else {
            accounts = [
                UserProfileAccount(
                    id: "main",
                    displayName: s.profileName,
                    fullName: s.fullName,
                    gamertag: s.gamertag,
                    bio: s.bio.isEmpty ? L("Ana Konsol Hesabı") : s.bio,
                    location: s.location,
                    favoriteGenre: s.favoriteGenre,
                    avatarRaw: s.avatar.rawValue,
                    accentRaw: s.accent.rawValue,
                    rpcs3UserID: "00000001"
                ),
                UserProfileAccount(
                    id: "guest",
                    displayName: L("Misafir"),
                    fullName: L("Misafir Oyuncu"),
                    gamertag: "player2",
                    bio: L("Hızlı Oyun & 2. Oyuncu Hesabı"),
                    location: "",
                    favoriteGenre: "",
                    avatarRaw: Avatar.flame.rawValue,
                    accentRaw: AccentChoice.purple.rawValue,
                    rpcs3UserID: "00000002"
                ),
            ]
            persist()
        }
    }

    func syncCurrentFromSettings(_ s: AppSettings) {
        guard let i = accounts.firstIndex(where: { $0.id == activeID }) else { return }
        accounts[i].displayName = s.profileName
        accounts[i].fullName = s.fullName
        accounts[i].gamertag = s.gamertag
        accounts[i].bio = s.bio
        accounts[i].location = s.location
        accounts[i].favoriteGenre = s.favoriteGenre
        accounts[i].avatarRaw = s.avatar.rawValue
        accounts[i].accentRaw = s.accent.rawValue
        persist()
    }

    func switchTo(index: Int, settings s: AppSettings) {
        syncCurrentFromSettings(s)
        guard accounts.indices.contains(index) else { return }
        let acc = accounts[index]
        activeID = acc.id
        s.profileName = acc.displayName
        s.fullName = acc.fullName
        s.gamertag = acc.gamertag
        s.bio = acc.bio
        s.location = acc.location ?? ""
        s.favoriteGenre = acc.favoriteGenre ?? ""
        if let av = Avatar(rawValue: acc.avatarRaw) { s.avatar = av }
        if let ac = AccentChoice(rawValue: acc.accentRaw) { s.accent = ac }
        ToastCenter.shared.show(
            icon: "person.crop.circle.badge.checkmark",
            title: L("Hoş geldin, \(acc.displayName)"),
            subtitle: L("@\(acc.gamertag) oturumu açıldı")
        )
    }

    func createAndSwitchAccount(
        displayName: String,
        fullName: String,
        gamertag: String,
        bio: String,
        location: String,
        genre: String,
        avatar: Avatar,
        accent: AccentChoice? = nil,
        settings s: AppSettings
    ) {
        syncCurrentFromSettings(s)
        let num = accounts.count + 1
        let accents: [AccentChoice] = [.teal, .orange, .pink, .green, .red, .purple, .blue]
        let newAcc = UserProfileAccount(
            id: "user_\(Int(Date().timeIntervalSince1970))",
            displayName: displayName,
            fullName: fullName,
            gamertag: gamertag,
            bio: bio.isEmpty ? L("Zinkx Arena Oyuncusu") : bio,
            location: location,
            favoriteGenre: genre,
            avatarRaw: avatar.rawValue,
            accentRaw: (accent ?? accents[num % accents.count]).rawValue,
            rpcs3UserID: String(format: "%08d", num)
        )
        accounts.append(newAcc)
        persist()
        selectedIndex = accounts.count - 1
        switchTo(index: accounts.count - 1, settings: s)
    }

    func deleteAccount(at index: Int, settings s: AppSettings) {
        guard accounts.indices.contains(index) else { return }
        guard accounts.count > 1 else {
            AudioManager.shared.play(.back)
            ToastCenter.shared.show(
                icon: "exclamationmark.triangle.fill",
                title: L("Son Kullanıcı Silinemez"),
                subtitle: L("Konsolda en az 1 oyuncu profili bulunmalıdır")
            )
            return
        }
        let removed = accounts.remove(at: index)
        persist()
        AudioManager.shared.play(.back)
        if selectedIndex >= accounts.count {
            selectedIndex = max(0, accounts.count - 1)
        }
        if activeID == removed.id, !accounts.isEmpty {
            let nextIdx = min(selectedIndex, accounts.count - 1)
            let acc = accounts[nextIdx]
            activeID = acc.id
            s.profileName = acc.displayName
            s.fullName = acc.fullName
            s.gamertag = acc.gamertag
            s.bio = acc.bio
            s.location = acc.location ?? ""
            s.favoriteGenre = acc.favoriteGenre ?? ""
            if let av = Avatar(rawValue: acc.avatarRaw) { s.avatar = av }
            if let ac = AccentChoice(rawValue: acc.accentRaw) { s.accent = ac }
        }
        ToastCenter.shared.show(
            icon: "trash.fill",
            title: L("Kullanıcı Silindi"),
            subtitle: L("\(removed.displayName) (@\(removed.gamertag)) kaldırıldı")
        )
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct UserSelectOverlay: View {
    @ObservedObject var store = UserAccountStore.shared
    @EnvironmentObject var settings: AppSettings
    /// Fully hides the home screen behind it (startup picker).
    var opaque = false
    let onAddNewUser: () -> Void
    let onClose: () -> Void

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.black.opacity(opaque ? 1 : 0.88).ignoresSafeArea()
            WavesView(accent: accent, intensity: 0.65, sparks: true).ignoresSafeArea()

            VStack(spacing: 38) {
                VStack(spacing: 12) {
                    LogoMark(accent: accent)
                        .frame(width: 74, height: 74)
                        .shadow(color: accent.opacity(0.8), radius: 22)
                    Text(L("Zinkx Arena'ya Hoş Geldin"))
                        .font(.system(size: 40, weight: .bold))
                    Text(L("Kim oynuyor? Kontrolcüyle profilini seç."))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(spacing: 28) {
                    ForEach(Array(store.accounts.enumerated()), id: \.element.id) { idx, acc in
                        let focused = store.selectedIndex == idx
                        let av = Avatar(rawValue: acc.avatarRaw) ?? .controller
                        let col = (AccentChoice(rawValue: acc.accentRaw) ?? .blue).color
                        Button {
                            store.selectedIndex = idx
                            AudioManager.shared.play(.confirm)
                            store.switchTo(index: idx, settings: settings)
                            onClose()
                        } label: {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(col.gradient)
                                        .frame(width: 128, height: 128)
                                    Image(systemName: av.symbol)
                                        .font(.system(size: 54, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: focused ? 4 : 1.5)
                                        .opacity(focused ? 1 : 0.35)
                                )
                                .shadow(color: focused ? col.opacity(0.9) : .black.opacity(0.5), radius: focused ? 28 : 10)

                                VStack(spacing: 4) {
                                    Text(acc.displayName)
                                        .font(.system(size: 24, weight: .bold))
                                    Text("@\(acc.gamertag)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(col.mix(with: .white, by: 0.5))
                                }

                                if store.activeID == acc.id {
                                    Text(L("AKTİF"))
                                        .font(.system(size: 10, weight: .heavy))
                                        .tracking(1.4)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.18), in: Capsule())
                                }

                                if store.accounts.count > 1 && focused {
                                    Button {
                                        store.deleteAccount(at: idx, settings: settings)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash.fill")
                                            Text(L("Sil (□)"))
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.red.mix(with: .white, by: 0.35))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.18), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(22)
                            .frame(width: 220, height: 285)
                            .background(
                                focused ? Color.white.opacity(0.16) : Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .strokeBorder(focused ? .white : .white.opacity(0.12), lineWidth: focused ? 2.5 : 1)
                            )
                            .scaleEffect(focused ? 1.08 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }

                    // "+ Yeni Kullanıcı" tile
                    let addIndex = store.accounts.count
                    let addFocused = store.selectedIndex == addIndex
                    Button {
                        store.selectedIndex = addIndex
                        onAddNewUser()
                    } label: {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 128, height: 128)
                                Image(systemName: "plus")
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: addFocused ? 4 : 1.5)
                                    .opacity(addFocused ? 1 : 0.3)
                            )

                            VStack(spacing: 4) {
                                Text(L("Kullanıcı Ekle"))
                                    .font(.system(size: 22, weight: .bold))
                                Text(L("Yeni Oyuncu Profili"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(22)
                        .frame(width: 220, height: 285)
                        .background(
                            addFocused ? Color.white.opacity(0.16) : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(addFocused ? .white : .white.opacity(0.12), lineWidth: addFocused ? 2.5 : 1)
                        )
                        .scaleEffect(addFocused ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
                .animation(.spring(response: 0.26, dampingFraction: 0.8), value: store.selectedIndex)

                Text(opaque ? L("◀ ▶ Oyuncu Seç   ✕ Oturum Aç   □ Kullanıcıyı Sil") : L("◀ ▶ Oyuncu Seç   ✕ Oturum Aç   □ Kullanıcıyı Sil   ○ Kapat"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 10)
            }
        }
    }
}
