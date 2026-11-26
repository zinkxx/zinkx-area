import SwiftUI
import AppKit

enum ProfileFieldKind: Int, CaseIterable, Identifiable {
    case fullName, gamertag, displayName, bio, location, genre, brandName, avatar

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fullName: L("Ad Soyad")
        case .gamertag: L("Kullanıcı Adı (Gamer Tag)")
        case .displayName: L("Kısa Ad (Karşılama)")
        case .bio: L("Hakkımda")
        case .location: L("Konum")
        case .genre: L("Favori Tür")
        case .brandName: L("Açılış Marka Adı")
        case .avatar: L("Avatar Simgesi")
        }
    }

    var icon: String {
        switch self {
        case .fullName: "person.fill"
        case .gamertag: "at"
        case .displayName: "hand.wave.fill"
        case .bio: "quote.bubble.fill"
        case .location: "mappin.and.ellipse"
        case .genre: "heart.fill"
        case .brandName: "sparkles"
        case .avatar: "face.smiling.fill"
        }
    }

    var placeholder: String {
        switch self {
        case .fullName: L("Örn: Said Kaya")
        case .gamertag: L("Örn: zinkx")
        case .displayName: L("Örn: Zinkx")
        case .bio: L("Kendini veya sevdiğin oyunları anlat…")
        case .location: L("Örn: İstanbul, Türkiye")
        case .genre: L("Seçilmedi")
        case .brandName: L("Örn: Zinkx Arena")
        case .avatar: ""
        }
    }

    var isTextField: Bool {
        switch self {
        case .genre, .avatar: false
        default: true
        }
    }

    var suggestions: [String] {
        switch self {
        case .fullName: ["Zinkx", L("Oyuncu 1"), "Player 1", L("Temizle")]
        case .gamertag: ["zinkx", "zinkx_ps", "pro_zinkx", L("Temizle")]
        case .displayName: ["Zinkx", L("Kaptan"), "Legend", L("Temizle")]
        case .bio: [L("PS3 & Retro Tutkunu 🎮"), L("Zinkx Arena Oyuncusu ⚡"), L("Platin Kupa Avcısı 🏆"), L("Temizle")]
        case .location: [L("İstanbul, Türkiye"), L("Türkiye"), L("Ankara, Türkiye"), L("Temizle")]
        case .brandName: ["Zinkx Arena", "Zinkx Station", "Zinkx Play", "Zinkx OS"]
        default: []
        }
    }
}

enum KeyboardMode {
    case lower, upper, symbols
}

/// Manages both the gamepad-navigable Profile Editor and the PlayStation-style On-Screen Keyboard.
final class ProfileEditorController: ObservableObject {
    // Draft values
    @Published var fullName = ""
    @Published var gamertag = ""
    @Published var displayName = ""
    @Published var bio = ""
    @Published var location = ""
    @Published var genre = ""
    @Published var brandName = ""
    @Published var avatar: Avatar = .controller
    @Published var isCreatingNewUser = false

    // Editor navigation: 0..<8 are fields, 8 is bottom buttons (0 = Kaydet, 1 = Vazgeç)
    @Published var rowIndex = 0
    @Published var buttonCol = 0

    // On-Screen Keyboard state
    @Published var activeField: ProfileFieldKind?
    @Published var kbText = ""
    @Published var kbMode: KeyboardMode = .lower
    @Published var kbRow = 2
    @Published var kbCol = 0

    static let fieldCount = ProfileFieldKind.allCases.count

    func load(from s: AppSettings) {
        isCreatingNewUser = false
        fullName = s.fullName
        gamertag = s.gamertag
        displayName = s.profileName
        bio = s.bio
        location = s.location
        genre = s.favoriteGenre
        brandName = s.brandName
        avatar = s.avatar
        rowIndex = 0
        buttonCol = 0
        activeField = nil
    }

    func loadForNewUser(from s: AppSettings) {
        isCreatingNewUser = true
        let avatars: [Avatar] = [.crown, .bolt, .star, .moon, .flame, .hare, .paw]
        let nextNum = UserAccountStore.shared.accounts.count + 1
        fullName = ""
        gamertag = ""
        displayName = ""
        bio = ""
        location = ""
        genre = ""
        brandName = s.brandName
        avatar = avatars[nextNum % avatars.count]
        rowIndex = 0
        buttonCol = 0
        activeField = nil
    }

    func save(to s: AppSettings) {
        func clean(_ str: String) -> String { str.trimmingCharacters(in: .whitespacesAndNewlines) }
        let cFull = clean(fullName)
        let cTag = clean(gamertag).replacingOccurrences(of: "@", with: "")
        let cDisp = clean(displayName)
        let cBio = clean(bio)
        let cLoc = clean(location)
        let cBrand = clean(brandName)

        if isCreatingNewUser {
            let nextNum = UserAccountStore.shared.accounts.count + 1
            let finalDisplay = !cDisp.isEmpty ? cDisp : (!cFull.isEmpty ? cFull : L("Oyuncu \(nextNum)"))
            let finalFull = !cFull.isEmpty ? cFull : finalDisplay
            let finalTag = !cTag.isEmpty ? cTag : finalDisplay.lowercased().replacingOccurrences(of: " ", with: "")
            if !cBrand.isEmpty { s.brandName = cBrand }
            UserAccountStore.shared.createAndSwitchAccount(
                displayName: finalDisplay,
                fullName: finalFull,
                gamertag: finalTag,
                bio: cBio,
                location: cLoc,
                genre: genre,
                avatar: avatar,
                settings: s
            )
            isCreatingNewUser = false
            return
        }

        s.fullName = cFull
        s.gamertag = cTag
        if !cDisp.isEmpty { s.profileName = cDisp }
        s.bio = cBio
        s.location = cLoc
        s.favoriteGenre = genre
        if !cBrand.isEmpty { s.brandName = cBrand }
        s.avatar = avatar
        UserAccountStore.shared.syncCurrentFromSettings(s)
    }

    func value(for field: ProfileFieldKind) -> String {
        switch field {
        case .fullName: fullName
        case .gamertag: gamertag.isEmpty ? "" : "@\(gamertag)"
        case .displayName: displayName
        case .bio: bio
        case .location: location
        case .genre: genre.isEmpty ? L("Seçilmedi") : L(key: genre)
        case .brandName: brandName
        case .avatar: avatar.title
        }
    }

    func rawValue(for field: ProfileFieldKind) -> String {
        switch field {
        case .fullName: fullName
        case .gamertag: gamertag
        case .displayName: displayName
        case .bio: bio
        case .location: location
        case .genre: genre
        case .brandName: brandName
        case .avatar: avatar.title
        }
    }

    func setValue(_ val: String, for field: ProfileFieldKind) {
        switch field {
        case .fullName: fullName = val
        case .gamertag: gamertag = val.replacingOccurrences(of: "@", with: "")
        case .displayName: displayName = val
        case .bio: bio = val
        case .location: location = val
        case .brandName: brandName = val
        default: break
        }
    }

    // MARK: - Keyboard grid definition

    var gridRows: [[String]] {
        let numRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "@", "_"]
        switch kbMode {
        case .lower:
            return [numRow] + Self.letterRows(upper: false)
        case .upper:
            return [numRow] + Self.letterRows(upper: true)
        case .symbols:
            return [
                numRow,
                ["!", "?", "#", "$", "%", "&", "*", "+", "-", "=", "/", "\\"],
                ["(", ")", "[", "]", "{", "}", "<", ">", "|", "~", "^", ":"],
                [";", "\"", "'", "`", "•", "★", "⚡", "🎮", "🏆", "🔥", "❤️", "👑"],
            ]
        }
    }

    /// Letter rows (3 × 12 keys) for the active UI language; CJK languages use the English layout.
    static func letterRows(upper: Bool) -> [[String]] {
        if L10n.code == "tr" {
            return upper
                ? [["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Ğ", "Ü"],
                   ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ş", "İ", ","],
                   ["Z", "X", "C", "V", "B", "N", "M", "Ö", "Ç", ".", "-", "'"]]
                : [["q", "w", "e", "r", "t", "y", "u", "ı", "o", "p", "ğ", "ü"],
                   ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ş", "i", ","],
                   ["z", "x", "c", "v", "b", "n", "m", "ö", "ç", ".", "-", "'"]]
        }
        let lower: [String] = switch L10n.code {
        case "de": ["qwertzuiopüß", "asdfghjklöä,", "yxcvbnm.-'!?"]
        case "fr": ["azertyuiopéè", "qsdfghjklmàç", "wxcvbnêù',.-"]
        case "es": ["qwertyuiopáé", "asdfghjklñíó", "zxcvbnmúü,.-"]
        default: ["qwertyuiop-'", "asdfghjkl,.!", "zxcvbnm?&+/#"]
        }
        return lower.map { row in
            row.map { ch in
                let s = String(ch)
                return upper && s != "ß" ? s.uppercased(with: L10n.locale) : s
            }
        }
    }

    var actionTitles: [(icon: String, label: String)] {
        [
            (kbMode == .upper ? "shift.fill" : "shift", kbMode == .upper ? L("BÜYÜK") : L("küçük")),
            ("number", kbMode == .symbols ? L("Harfler") : "#+="),
            ("space", L("Boşluk (△)")),
            ("delete.left.fill", L("Sil (□)")),
            ("trash", L("Temizle")),
            ("checkmark.circle.fill", L("Tamam (R1)")),
        ]
    }

    func openKeyboard(for field: ProfileFieldKind) {
        guard field.isTextField else { return }
        activeField = field
        kbText = rawValue(for: field)
        kbMode = kbText.isEmpty && field != .gamertag ? .upper : .lower
        kbRow = 2
        kbCol = 0
        AudioManager.shared.play(.open)
    }

    func commitKeyboard() {
        guard let field = activeField else { return }
        setValue(kbText, for: field)
        AudioManager.shared.play(.confirm)
        activeField = nil
    }

    func cancelKeyboard() {
        AudioManager.shared.play(.back)
        activeField = nil
    }

    // MARK: - Input handling

    /// Returns true if the editor should close.
    func handle(_ action: NavAction, settings: AppSettings) -> Bool {
        if activeField != nil {
            handleKeyboard(action)
            return false
        }
        return handleForm(action, settings: settings)
    }

    private func handleForm(_ action: NavAction, settings: AppSettings) -> Bool {
        let audio = AudioManager.shared
        let maxRow = Self.fieldCount // row 8 = bottom buttons
        switch action {
        case .up:
            if rowIndex > 0 { rowIndex -= 1; audio.play(.tick) }
        case .down:
            if rowIndex < maxRow { rowIndex += 1; audio.play(.tick) }
        case .left:
            if rowIndex == maxRow {
                if buttonCol > 0 { buttonCol -= 1; audio.play(.tick) }
            } else if let f = ProfileFieldKind(rawValue: rowIndex) {
                stepField(f, delta: -1)
            }
        case .right:
            if rowIndex == maxRow {
                if buttonCol < 1 { buttonCol += 1; audio.play(.tick) }
            } else if let f = ProfileFieldKind(rawValue: rowIndex) {
                stepField(f, delta: 1)
            }
        case .confirm:
            if rowIndex == maxRow {
                if buttonCol == 0 {
                    audio.play(.confirm)
                    save(to: settings)
                } else {
                    audio.play(.back)
                }
                return true
            } else if let f = ProfileFieldKind(rawValue: rowIndex) {
                if f.isTextField {
                    openKeyboard(for: f)
                } else {
                    stepField(f, delta: 1)
                }
            }
        case .r1:
            audio.play(.confirm)
            save(to: settings)
            return true
        case .back:
            audio.play(.back)
            return true
        default:
            break
        }
        return false
    }

    private func stepField(_ field: ProfileFieldKind, delta: Int) {
        let audio = AudioManager.shared
        switch field {
        case .genre:
            let options = [""] + AppSettings.genres
            let idx = options.firstIndex(of: genre) ?? 0
            genre = options[(idx + delta + options.count) % options.count]
            audio.play(.tick)
        case .avatar:
            avatar = avatar.step(delta)
            audio.play(.tick)
        default:
            break
        }
    }

    private func handleKeyboard(_ action: NavAction) {
        let audio = AudioManager.shared
        switch action {
        case .up:
            moveRow(to: kbRow - 1)
            audio.play(.tick)
        case .down:
            moveRow(to: kbRow + 1)
            audio.play(.tick)
        case .left:
            let count = colCount(for: kbRow)
            kbCol = (kbCol - 1 + count) % count
            audio.play(.tick)
        case .right:
            let count = colCount(for: kbRow)
            kbCol = (kbCol + 1) % count
            audio.play(.tick)
        case .confirm:
            pressCurrentKey()
        case .square:
            backspace()
        case .triangle:
            insert(" ")
        case .l1:
            toggleCase()
        case .r1:
            commitKeyboard()
        case .back:
            cancelKeyboard()
        default:
            break
        }
    }

    private func colCount(for r: Int) -> Int {
        switch r {
        case 0: 4
        case 5: 6
        default: 12
        }
    }

    private func moveRow(to newRow: Int) {
        let target = (newRow + 6) % 6
        // Map column proportionally between 4-col (row 0), 12-col (rows 1..4), and 6-col (row 5)
        let norm = Double(kbCol) / Double(max(1, colCount(for: kbRow)))
        kbRow = target
        let newCount = colCount(for: target)
        kbCol = min(newCount - 1, Int((norm * Double(newCount)).rounded(.down)))
    }

    func pressCurrentKey() {
        let audio = AudioManager.shared
        if kbRow == 0 {
            guard let f = activeField else { return }
            let list = f.suggestions
            guard list.indices.contains(kbCol) else { return }
            let val = list[kbCol]
            if val == L("Temizle") {
                kbText = ""
                audio.play(.back)
            } else {
                kbText = val
                audio.play(.confirm)
            }
        } else if (1...4).contains(kbRow) {
            let row = gridRows[kbRow - 1]
            guard row.indices.contains(kbCol) else { return }
            let ch = row[kbCol]
            insert(ch)
            // Auto-switch from initial uppercase after first letter
            if kbMode == .upper && kbText.count == 1 { kbMode = .lower }
        } else if kbRow == 5 {
            triggerAction(at: kbCol)
        }
    }

    func triggerAction(at index: Int) {
        let audio = AudioManager.shared
        switch index {
        case 0: toggleCase()
        case 1:
            kbMode = (kbMode == .symbols) ? .lower : .symbols
            audio.play(.tick)
        case 2: insert(" ")
        case 3: backspace()
        case 4:
            kbText = ""
            audio.play(.back)
        case 5: commitKeyboard()
        default: break
        }
    }

    func insert(_ s: String) {
        kbText.append(s)
        AudioManager.shared.play(.tick)
    }

    func backspace() {
        guard !kbText.isEmpty else { return }
        kbText.removeLast()
        AudioManager.shared.play(.back)
    }

    func toggleCase() {
        kbMode = (kbMode == .upper) ? .lower : .upper
        AudioManager.shared.play(.tick)
    }
}

// MARK: - On-Screen Keyboard View (PS5 Console Style)

struct OnScreenKeyboardView: View {
    @ObservedObject var editor: ProfileEditorController
    let field: ProfileFieldKind
    let accent: Color

    @State private var blink = true
    private let blinkTimer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
                .onTapGesture { editor.cancelKeyboard() }

            VStack(spacing: 18) {
                headerBox
                suggestionsRow
                characterGrid
                actionsRow
                shortcutsRow
            }
            .padding(28)
            .frame(width: 920)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .background(Color(red: 0.05, green: 0.07, blue: 0.14).opacity(0.9), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.75), radius: 40, y: 18)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: editor.kbRow)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: editor.kbCol)
        }
        .onReceive(blinkTimer) { _ in blink.toggle() }
    }

    private var headerBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(field.title, systemImage: field.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent.mix(with: .white, by: 0.45))
                Spacer()
                Text(L("\(editor.kbText.count) karakter"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 2) {
                if editor.kbText.isEmpty {
                    Text(field.placeholder)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    Text(editor.kbText)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Rectangle()
                    .fill(accent.mix(with: .white, by: 0.35))
                    .frame(width: 3, height: 28)
                    .opacity(blink ? 1 : 0.15)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.7), lineWidth: 1.5)
            )
        }
    }

    private var suggestionsRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(field.suggestions.enumerated()), id: \.offset) { c, text in
                suggestionChip(c: c, text: text)
            }
        }
    }

    private func suggestionChip(c: Int, text: String) -> some View {
        let focused = editor.kbRow == 0 && editor.kbCol == c
        let bg = focused ? accent : Color.white.opacity(0.08)
        return Button {
            editor.kbRow = 0; editor.kbCol = c
            editor.pressCurrentKey()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: text == L("Temizle") ? "xmark.circle" : "sparkles")
                    .font(.system(size: 13))
                Text(text).lineLimit(1)
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(focused ? 0.95 : 0.12), lineWidth: focused ? 2 : 1)
            )
            .scaleEffect(focused ? 1.04 : 1)
        }
        .buttonStyle(.plain)
    }

    private var characterGrid: some View {
        let rows = editor.gridRows
        return VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { r in
                let rowKeys = rows[r]
                HStack(spacing: 8) {
                    ForEach(0..<rowKeys.count, id: \.self) { c in
                        charKeyButton(r: r, c: c, key: rowKeys[c])
                    }
                }
            }
        }
    }

    private func charKeyButton(r: Int, c: Int, key: String) -> some View {
        let focused = editor.kbRow == (r + 1) && editor.kbCol == c
        let bg = focused ? Color.white : Color.white.opacity(0.1)
        let fg = focused ? Color.black : Color.white
        return Button {
            editor.kbRow = r + 1; editor.kbCol = c
            editor.pressCurrentKey()
        } label: {
            Text(key)
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .foregroundStyle(fg)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(accent, lineWidth: 2.5)
                        .padding(-3)
                        .opacity(focused ? 1 : 0)
                )
                .shadow(color: focused ? accent.opacity(0.85) : .clear, radius: 12)
                .scaleEffect(focused ? 1.08 : 1)
        }
        .buttonStyle(.plain)
    }

    private var actionsRow: some View {
        let actions = editor.actionTitles
        return HStack(spacing: 10) {
            ForEach(0..<actions.count, id: \.self) { c in
                actionKeyButton(c: c, icon: actions[c].icon, label: actions[c].label)
            }
        }
    }

    private func actionKeyButton(c: Int, icon: String, label: String) -> some View {
        let focused = editor.kbRow == 5 && editor.kbCol == c
        let isDone = c == 5
        let bg: Color = focused ? .white : (isDone ? accent : Color.white.opacity(0.13))
        let fg: Color = focused ? .black : .white
        return Button {
            editor.kbRow = 5; editor.kbCol = c
            editor.triggerAction(at: c)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(fg)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white, lineWidth: 2.5)
                    .padding(-3)
                    .opacity(focused ? 1 : 0)
            )
            .shadow(color: focused ? accent.opacity(0.85) : .clear, radius: 12)
            .scaleEffect(focused ? 1.05 : 1)
        }
        .buttonStyle(.plain)
    }

    private var shortcutsRow: some View {
        HStack(spacing: 22) {
            Hint(symbol: "xmark.circle", text: L("Seç"))
            Hint(symbol: "square.circle", text: L("Sil"))
            Hint(symbol: "triangle.circle", text: L("Boşluk"))
            Hint(symbol: "l1.rectangle.roundedbottom", text: L("Büyük/Küçük"))
            Hint(symbol: "r1.rectangle.roundedbottom", text: L("Tamam"))
            Hint(symbol: "circle.circle", text: L("İptal"))
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .padding(.top, 4)
    }
}
