import SwiftUI
import AppKit

enum RowDisplay {
    case toggle(Bool)
    case choice(String)
    case slider(Double)
    case action(String?)
    case info(String)
}

struct SettingRow: Identifiable {
    let id: String
    let section: String
    let icon: String
    let title: String
    var subtitle: String? = nil
    let display: RowDisplay
    var left: (() -> Void)? = nil
    var right: (() -> Void)? = nil
    var confirm: (() -> Void)? = nil
}

/// Builds the gamepad-friendly settings list.
struct SettingsBuilder {
    let settings: AppSettings
    let library: GameLibrary
    let launcher: GameLauncher
    let onEditProfile: () -> Void

    private var audio: AudioManager { .shared }

    var rows: [SettingRow] {
        var r: [SettingRow] = []
        let s = settings

        // Ses
        r.append(toggle("introEnabled", L("Ses"), "sparkles", L("Açılış animasyonu"), nil, \.introEnabled))
        r.append(choice("introSound", L("Ses"), "music.note", L("Açılış sesi"),
                        s.introSound == .custom
                            ? (audio.customIntroURL == nil ? L("Dosya yok: ~/Music/PlayHub/acilis.mp3") : L("~/Music/PlayHub/acilis dosyası"))
                            : L("◀ ▶ ile değiştirince önizleme çalar"),
                        \.introSound) { audio.playIntro($0) })
        r.append(SettingRow(id: "introPreview", section: L("Ses"), icon: "play.circle", title: L("Açılış sesini dinle"),
                            display: .action(nil), confirm: { audio.playIntro() }))
        r.append(choice("uiSounds", L("Ses"), "speaker.wave.2", L("Menü sesleri"), nil, \.uiSounds) { _ in audio.play(.tick) })
        r.append(slider("effectsVolume", L("Ses"), "speaker.wave.3", L("Efekt ses seviyesi"), \.effectsVolume) { audio.play(.tick) })
        r.append(toggle("gameMusic", L("Ses"), "opticaldisc.fill", L("Seçili oyunun disk müziği (SND0.AT3)"),
                        L("Oyunun üzerine gelince CD içindeki orijinal müziği çalar"),
                        \.gameMusicEnabled) { audio.refreshMusic() })
        let tracks = audio.musicTrackCount
        r.append(toggle("musicEnabled", L("Ses"), "music.note.list", L("Genel arka plan müziği"),
                        tracks == 0 ? L("Müzik klasörüne şarkı ekle (mp3, m4a…)") : L("\(tracks) şarkı · oyun müziği yoksa çalar"),
                        \.musicEnabled) { audio.refreshMusic() })
        r.append(slider("musicVolume", L("Ses"), "dial.medium", L("Müzik ses seviyesi"), \.musicVolume) { audio.refreshMusic() })
        r.append(SettingRow(id: "musicFolder", section: L("Ses"), icon: "folder", title: L("Müzik klasörünü aç"),
                            subtitle: L("~/Music/PlayHub — açılış sesi ve şarkılar burada"),
                            display: .action(nil), confirm: {
                                NSWorkspace.shared.open(AudioManager.folder)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { audio.reloadMusic() }
                            }))

        // Görünüm
        r.append(choice("language", L("Görünüm"), "globe", L10n.code == "en" ? "Language" : L("Dil") + " · Language",
                        nil, \.language))
        r.append(SettingRow(
            id: "targetScreen",
            section: L("Görünüm"),
            icon: "display.2",
            title: L("Aktif ekran (Monitör)"),
            subtitle: NSScreen.screens.count > 1
                ? L("◀ ▶ veya ✕ ile menüyü ve oyunları diğer ekrana taşı (Kısayol: ⌘E)")
                : L("Tek ekran bağlı"),
            display: .choice(s.targetScreenTitle),
            left: { s.cycleScreen(-1); audio.play(.tick) },
            right: { s.cycleScreen(1); audio.play(.tick) },
            confirm: { s.cycleScreen(1); audio.play(.confirm) }
        ))
        r.append(choice("background", L("Görünüm"), "photo", L("Arka plan"), nil, \.background))
        r.append(choice("gameMediaDisplay", L("Görünüm"), "film.stack", L("Oyun disk medyası (CD içeriği)"),
                        L("Seçili oyunun içindeki video ve fotoğrafları arka planda döndürür"), \.gameMediaDisplay))
        r.append(choice("accent", L("Görünüm"), "paintpalette", L("Vurgu rengi"), nil, \.accent))
        r.append(choice("cardSize", L("Görünüm"), "rectangle.grid.1x2", L("Kart boyutu"), nil, \.cardSize))
        r.append(choice("sortOrder", L("Görünüm"), "arrow.up.arrow.down", L("Sıralama"), nil, \.sortOrder) { _ in library.resort() })
        r.append(toggle("showHints", L("Görünüm"), "questionmark.circle", L("Tuş ipuçlarını göster"), nil, \.showHints))
        r.append(choice("screensaver", L("Görünüm"), "moon.zzz", L("Ekran koruyucu"), L("Bu süre boyunca dokunulmazsa açılır"), \.screensaver))

        // Profil
        r.append(SettingRow(id: "editProfile", section: L("Profil"), icon: "person.text.rectangle", title: L("Profili düzenle"),
                            subtitle: L("İsim, kullanıcı adı, hakkımda, konum, marka adı"), display: .action(s.greetingName),
                            confirm: { onEditProfile() }))
        r.append(SettingRow(id: "photo", section: L("Profil"), icon: "photo", title: L("Profil fotoğrafı"),
                            display: .action(s.avatarImagePath == nil ? L("Seç") : L("Değiştir")),
                            confirm: { ProfilePhoto.pick(into: s) }))
        if s.avatarImagePath != nil {
            r.append(SettingRow(id: "removePhoto", section: L("Profil"), icon: "trash", title: L("Fotoğrafı kaldır"),
                                display: .action(nil), confirm: { ProfilePhoto.remove(from: s) }))
        }
        r.append(choice("avatar", L("Profil"), s.avatar.symbol, L("Avatar simgesi"), L("Fotoğraf yoksa kullanılır"), \.avatar))

        // Oyunlar
        r.append(toggle("fullscreen", L("Oyunlar"), "arrow.up.left.and.arrow.down.right", L("Oyunları tam ekran başlat"), nil, \.fullscreenGames))
        r.append(toggle("combo", L("Oyunlar"), "hand.raised", L("Share + Options ile oyunu kapat"),
                        L("Oyundayken 1,5 sn basılı tut"), \.closeComboEnabled))
        let folders = GameLibrary.roots.map { $0.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
        r.append(SettingRow(id: "folders", section: L("Oyunlar"), icon: "externaldrive", title: L("Oyun klasörleri"),
                            subtitle: folders.joined(separator: "  ·  "), display: .info(L("\(library.games.count) oyun"))))
        r.append(SettingRow(id: "addFolder", section: L("Oyunlar"), icon: "folder.badge.plus", title: L("Oyun klasörü ekle"),
                            subtitle: L("İçinde oyun klasörleri olan bir klasör seç"), display: .action(nil),
                            confirm: { addFolder() }))
        if !s.extraFolders.isEmpty {
            r.append(SettingRow(id: "clearFolders", section: L("Oyunlar"), icon: "folder.badge.minus",
                                title: L("Eklenen klasörleri kaldır"), display: .action("\(s.extraFolders.count)"),
                                confirm: { s.extraFolders = []; library.scan() }))
        }

        // Sistem
        r.append(SettingRow(id: "login", section: L("Sistem"), icon: "power.circle", title: L("Mac açılınca Zinkx Arena'yı başlat"),
                            display: .toggle(s.launchAtLogin),
                            left: { toggleLogin() }, right: { toggleLogin() }, confirm: { toggleLogin() }))
        r.append(SettingRow(id: "rescan", section: L("Sistem"), icon: "arrow.clockwise", title: L("Kütüphaneyi yenile"),
                            display: .action(nil), confirm: { library.scan() }))
        r.append(SettingRow(id: "about", section: L("Sistem"), icon: "info.circle", title: L("Hakkında"),
                            subtitle: L("RPCS3 ile çalışan PS5 tarzı oyun menüsü"), display: .info("\(s.brandName) 2.0")))
        return r
    }

    // MARK: - Row helpers

    private func toggle(_ id: String, _ section: String, _ icon: String, _ title: String, _ subtitle: String?,
                        _ kp: ReferenceWritableKeyPath<AppSettings, Bool>, onChange: (() -> Void)? = nil) -> SettingRow {
        let s = settings
        let flip = { s[keyPath: kp].toggle(); onChange?() }
        return SettingRow(id: id, section: section, icon: icon, title: title, subtitle: subtitle,
                          display: .toggle(s[keyPath: kp]), left: flip, right: flip, confirm: flip)
    }

    private func choice<T: SettingOption>(_ id: String, _ section: String, _ icon: String, _ title: String, _ subtitle: String?,
                                          _ kp: ReferenceWritableKeyPath<AppSettings, T>,
                                          onChange: ((T) -> Void)? = nil) -> SettingRow {
        let s = settings
        func go(_ d: Int) { s[keyPath: kp] = s[keyPath: kp].step(d); onChange?(s[keyPath: kp]) }
        return SettingRow(id: id, section: section, icon: icon, title: title, subtitle: subtitle,
                          display: .choice(s[keyPath: kp].title),
                          left: { go(-1) }, right: { go(1) }, confirm: { go(1) })
    }

    private func slider(_ id: String, _ section: String, _ icon: String, _ title: String,
                        _ kp: ReferenceWritableKeyPath<AppSettings, Double>, onChange: (() -> Void)? = nil) -> SettingRow {
        let s = settings
        func go(_ d: Double) { s[keyPath: kp] = (min(1, max(0, s[keyPath: kp] + d)) * 10).rounded() / 10; onChange?() }
        return SettingRow(id: id, section: section, icon: icon, title: title,
                          display: .slider(s[keyPath: kp]), left: { go(-0.1) }, right: { go(0.1) })
    }

    // MARK: - Actions

    private func promptName() {
        let alert = NSAlert()
        alert.messageText = L("Profil adı")
        alert.informativeText = L("Açılışta ve üst çubukta görünecek isim.")
        alert.addButton(withTitle: L("Kaydet"))
        alert.addButton(withTitle: L("Vazgeç"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = settings.profileName
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let v = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { settings.profileName = v }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L("Ekle")
        panel.message = L("İçinde PS3 oyun klasörleri olan klasörü seç")
        if panel.runModal() == .OK, let url = panel.url, !settings.extraFolders.contains(url.path) {
            settings.extraFolders.append(url.path)
            library.scan()
        }
    }

    private func toggleLogin() {
        do { try settings.setLaunchAtLogin(!settings.launchAtLogin) } catch {
            launcher.errorMessage = L("Otomatik başlatma ayarlanamadı: \(error.localizedDescription)")
        }
    }
}

// MARK: - View

struct SettingsView: View {
    let rows: [SettingRow]
    let index: Int
    let accent: Color
    let onTap: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        if i == 0 || rows[i - 1].section != row.section {
                            Text(row.section.uppercased())
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, i == 0 ? 0 : 26)
                                .padding(.bottom, 6)
                                .padding(.leading, 18)
                                .id(i == 0 ? "settings_top" : "section_\(row.section)")
                        }
                        SettingRowView(row: row, selected: i == index, accent: accent)
                            .id(row.id)
                            .onTapGesture { onTap(i) }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 24)
                .frame(maxWidth: 1100, alignment: .leading)
            }
            .onAppear {
                if index == 0 {
                    proxy.scrollTo("settings_top", anchor: .top)
                } else if rows.indices.contains(index) {
                    proxy.scrollTo(rows[index].id, anchor: .center)
                }
            }
            .onChange(of: index) { _, i in
                guard rows.indices.contains(i) else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    if i == 0 {
                        proxy.scrollTo("settings_top", anchor: .top)
                    } else {
                        proxy.scrollTo(rows[i].id, anchor: .center)
                    }
                }
            }
        }
    }
}

struct SettingRowView: View {
    let row: SettingRow
    let selected: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: row.icon)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.system(size: 19, weight: .semibold))
                if let sub = row.subtitle {
                    Text(sub).font(.system(size: 13)).foregroundStyle(.white.opacity(selected ? 0.85 : 0.55)).lineLimit(1)
                }
            }
            Spacer(minLength: 20)
            control
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? accent : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.9 : 0), lineWidth: 2)
        )
        .scaleEffect(selected ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: selected)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var control: some View {
        switch row.display {
        case .toggle(let on):
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(on ? (selected ? .white.opacity(0.95) : accent) : .white.opacity(0.2))
                    .frame(width: 52, height: 30)
                Circle().fill(on && selected ? accent : .white).frame(width: 24, height: 24).padding(3)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: on)
        case .choice(let value):
            HStack(spacing: 12) {
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold)).opacity(selected ? 1 : 0.3)
                Text(value).font(.system(size: 17, weight: .medium)).frame(minWidth: 130)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).opacity(selected ? 1 : 0.3)
            }
        case .slider(let v):
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2)).frame(width: 200, height: 8)
                    Capsule().fill(selected ? .white : accent).frame(width: max(8, 200 * v), height: 8)
                }
                Text(Format.percent(v)).font(.system(size: 16, weight: .medium)).monospacedDigit().frame(width: 50, alignment: .trailing)
            }
        case .action(let value):
            HStack(spacing: 8) {
                if let value { Text(value).font(.system(size: 17, weight: .medium)) }
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).opacity(0.6)
            }
        case .info(let value):
            Text(value).font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.7))
        }
    }
}
