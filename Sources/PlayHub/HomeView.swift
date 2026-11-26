import SwiftUI
import AppKit

enum Tab: CaseIterable { case games, trophies, profile, settings }

enum HomeZone { case row, actions }

struct MenuItem {
    let title: String
    let icon: String
    let action: () -> Void
}

struct HomeView: View {
    @EnvironmentObject var library: GameLibrary
    @EnvironmentObject var input: InputManager
    @EnvironmentObject var launcher: GameLauncher
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var details: DetailsStore

    @State private var selectedID: String?
    @State private var tab: Tab
    @State private var zone: HomeZone = .row
    @State private var actionIndex = 0
    @State private var settingsIndex = 0
    @State private var profileIndex = 0
    @State private var trophyGameIndex = 0
    @State private var trophyRowIndex = 0
    @State private var detailGame: Game?
    @State private var detailFocus = 0
    @State private var editingProfile: Bool
    @State private var showingUserSelect: Bool
    @StateObject private var profileEditor = ProfileEditorController()
    @StateObject private var mediaStore = GameMediaStore.shared
    @StateObject private var userStore = UserAccountStore.shared
    @ObservedObject private var gameActivity = GameActivity.shared
    @State private var slideIndex = 0
    @State private var showingVideo = true
    @State private var mediaDebounceWork: DispatchWorkItem?
    @State private var menuOpen: Bool
    @State private var menuIndex = 0
    @State private var introVisible: Bool
    @State private var screensaver = false

    init(
        initialTab: Tab = .games,
        initialSelectedID: String? = nil,
        initialDetailGame: Game? = nil,
        initialMenuOpen: Bool = false,
        initialEditingProfile: Bool = false,
        initialShowingUserSelect: Bool? = nil,
        initialIntroVisible: Bool? = nil
    ) {
        _tab = State(initialValue: initialTab)
        _selectedID = State(initialValue: initialSelectedID)
        _detailGame = State(initialValue: initialDetailGame)
        _menuOpen = State(initialValue: initialMenuOpen)
        _editingProfile = State(initialValue: initialEditingProfile)
        let intro = initialIntroVisible ?? AppSettings.shared.introEnabled
        _introVisible = State(initialValue: intro)
        _showingUserSelect = State(initialValue: initialShowingUserSelect ?? !intro)
    }

    private let idleTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let slideTimer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    private var games: [Game] { library.games }
    private var selectedIndex: Int { games.firstIndex { $0.id == selectedID } ?? 0 }
    private var selected: Game? { games.isEmpty ? nil : games[min(selectedIndex, games.count - 1)] }
    private var accent: Color { settings.accent.color }
    private var settingsRows: [SettingRow] {
        SettingsBuilder(settings: settings, library: library, launcher: launcher,
                        onEditProfile: { openProfileEditor() }).rows
    }

    private var gameActions: [GameAction] {
        guard let g = selected else { return [] }
        var a: [GameAction] = [.play, .details, .favorite]
        if mediaStore.media[g.id]?.hasDiscVideo == true { a.append(.toggleMedia) }
        if launcher.running?.id == g.id { a.append(.close) }
        return a
    }

    private var menuItems: [MenuItem] {
        [
            MenuItem(title: L("Oyunlar"), icon: "gamecontroller.fill") { switchTab(to: .games) },
            MenuItem(title: L("Kupalar"), icon: "trophy.fill") { switchTab(to: .trophies) },
            MenuItem(title: L("Profil"), icon: "person.crop.circle.fill") { switchTab(to: .profile) },
            MenuItem(title: L("Kullanıcı"), icon: "person.2.fill") {
                AudioManager.shared.play(.open)
                withAnimation(.easeInOut(duration: 0.25)) { showingUserSelect = true }
            },
            MenuItem(title: L("Ayarlar"), icon: "gearshape.fill") { switchTab(to: .settings) },
            MenuItem(title: L("Ekran: \(settings.targetScreenShortName)"), icon: "display.2") {
                settings.cycleScreen(1)
            },
            MenuItem(title: settings.gameMusicEnabled ? L("Müziği Kapat") : L("Müziği Aç"),
                     icon: settings.gameMusicEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill") {
                settings.gameMusicEnabled.toggle()
                AudioManager.shared.refreshMusic()
                ToastCenter.shared.show(
                    icon: settings.gameMusicEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill",
                    title: settings.gameMusicEnabled ? L("Disk Müziği Açıldı") : L("Disk Müziği Kapatıldı"),
                    subtitle: L("SND0.AT3 arka plan müziği")
                )
            },
            MenuItem(title: L("Yenile"), icon: "arrow.clockwise") {
                library.scan()
                ToastCenter.shared.show(icon: "opticaldisc.fill", title: L("Kütüphane Yenilendi"), subtitle: L("\(games.count) PS3 oyunu bulundu"))
            },
            MenuItem(title: "RPCS3", icon: "cpu") {
                NSWorkspace.shared.openApplication(at: GameLauncher.rpcs3App, configuration: .init())
            },
            MenuItem(title: L("Dinlenme"), icon: "moon.zzz.fill") {
                withAnimation(.easeInOut(duration: 0.8)) { screensaver = true }
            },
            MenuItem(title: L("Kapat"), icon: "power") { NSApp.terminate(nil) },
        ]
    }

    private var hints: [HintItem] {
        if detailGame != nil {
            return [HintItem(symbol: "arrow.up.and.down.circle", text: L("Kupalar / kayıtlar")),
                    HintItem(symbol: "xmark.circle", text: L("Seç")),
                    HintItem(symbol: "square.circle", text: L("Favori")),
                    HintItem(symbol: "circle.circle", text: L("Geri"))]
        }
        switch tab {
        case .games:
            var h = [HintItem(symbol: "xmark.circle", text: zone == .row ? (launcher.running != nil ? L("Oyuna dön") : L("Oyna")) : L("Seç")),
                     HintItem(symbol: "triangle.circle", text: L("Detaylar")),
                     HintItem(symbol: "square.circle", text: L("Favori")),
                     HintItem(symbol: zone == .row ? "arrow.down.circle" : "arrow.up.circle", text: zone == .row ? L("Seçenekler") : L("Oyunlar"))]
            if launcher.running != nil { h.append(HintItem(symbol: "circle.circle", text: L("Oyunu kapat"))) }
            h.append(HintItem(symbol: "line.3.horizontal.circle", text: L("Menü")))
            return h
        case .trophies:
            return [HintItem(symbol: "arrow.left.and.right.circle", text: L("Oyun Seç")),
                    HintItem(symbol: "arrow.up.and.down.circle", text: L("Kupalar")),
                    HintItem(symbol: "triangle.circle", text: L("Kupa Bildirimi Test")),
                    HintItem(symbol: "circle.circle", text: L("Geri")),
                    HintItem(symbol: "line.3.horizontal.circle", text: L("Kontrol Merkezi"))]
        case .profile:
            return [HintItem(symbol: "arrow.left.and.right.circle", text: L("Seç")),
                    HintItem(symbol: "xmark.circle", text: L("Onayla")),
                    HintItem(symbol: "line.3.horizontal.circle", text: L("Menü"))]
        case .settings:
            return [HintItem(symbol: "arrow.up.and.down.circle", text: L("Gezin")),
                    HintItem(symbol: "arrow.left.and.right.circle", text: L("Değiştir")),
                    HintItem(symbol: "xmark.circle", text: L("Seç")),
                    HintItem(symbol: "circle.circle", text: L("Geri")),
                    HintItem(symbol: "line.3.horizontal.circle", text: L("Menü"))]
        }
    }

    var body: some View {
        GeometryReader { geo in
            // While RPCS3 is running the window is hidden; drop the whole view tree so no
            // animation, video, timeline or image work competes with the emulator for CPU.
            if gameActivity.isActive {
                Color.black
            } else {
            ZStack {
                Color.black.ignoresSafeArea()
                BackgroundView(
                    game: selected,
                    media: selected.flatMap { mediaStore.media[$0.id] },
                    style: settings.background,
                    mediaDisplay: settings.gameMediaDisplay,
                    slideIndex: slideIndex,
                    showingVideo: showingVideo,
                    videoPaused: introVisible || screensaver || launcher.running != nil || tab != .games,
                    accent: accent,
                    dimmed: tab != .games
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                VStack(alignment: .leading, spacing: 0) {
                    TopBar(tab: tab, running: launcher.running, onTab: { switchTab(to: $0) })

                    switch tab {
                    case .games:
                        gamesContent
                    case .trophies:
                        TrophyRoomView(gameIndex: trophyGameIndex, trophyIndex: trophyRowIndex) { idx in
                            AudioManager.shared.play(.tick)
                            trophyGameIndex = idx
                            trophyRowIndex = 0
                        }
                        .transition(.opacity)
                    case .profile:
                        ProfileView(focusedAction: profileIndex) { runProfileAction($0) }
                            .transition(.opacity)
                    case .settings:
                        SettingsView(rows: settingsRows, index: settingsIndex, accent: accent) { i in
                            settingsIndex = i
                            settingsRows[i].confirm?()
                        }
                        .transition(.opacity)
                    }

                    if settings.showHints { HintBar(items: hints) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                if let g = detailGame {
                    ZStack(alignment: .bottom) {
                        GameDetailView(game: g, details: details.details[g.id], compat: details.compat[g.id],
                                       stats: library.stats[g.id], isFavorite: settings.isFavorite(g.id),
                                       isRunning: launcher.running?.id == g.id, accent: accent, focus: detailFocus) {
                            runDetailAction($0, game: g)
                        }
                        if settings.showHints { HintBar(items: hints) }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }

                if editingProfile {
                    ProfileEditorOverlay(editor: profileEditor) {
                        let cancelledNewUser = profileEditor.isCreatingNewUser
                        profileEditor.isCreatingNewUser = false
                        withAnimation(.easeInOut(duration: 0.25)) {
                            editingProfile = false
                            if cancelledNewUser { showingUserSelect = true }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }

                if showingUserSelect {
                    UserSelectOverlay(
                        onAddNewUser: { startCreatingNewUser() },
                        onClose: { withAnimation(.easeInOut(duration: 0.25)) { showingUserSelect = false } }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }

                if launcher.launching, let g = launcher.running {
                    LaunchingOverlay(game: g)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity)
                }

                if menuOpen {
                    ControlCenterDock(
                        items: menuItems,
                        index: menuIndex,
                        accent: accent,
                        controllerName: input.controllerName,
                        batteryLevel: input.batteryLevel,
                        onPick: { i in
                            menuOpen = false
                            menuItems[i].action()
                        },
                        onClose: { menuOpen = false }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                PS5ToastOverlay(accent: accent)
                    .frame(width: geo.size.width, height: geo.size.height)

                if let err = launcher.errorMessage {
                    VStack {
                        Spacer()
                        ErrorToast(message: err).padding(.bottom, 90)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if screensaver {
                    ScreensaverView(game: selected, accent: accent)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity)
                }

                if introVisible {
                    IntroView(brand: settings.brandName, greeting: L("Hoş geldin, \(settings.greetingName)"), accent: accent) {
                        UserAccountStore.shared.selectedIndex = 0
                        withAnimation(.easeOut(duration: 0.3)) {
                            introVisible = false
                            showingUserSelect = true
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            // Rebuild every screen when the UI language changes so all text is re-translated.
            .id(settings.language)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: editingProfile)
        .animation(.easeInOut(duration: 0.25), value: launcher.launching)
        .animation(.easeInOut(duration: 0.25), value: launcher.errorMessage)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: menuOpen)
        .animation(.easeInOut(duration: 0.25), value: tab)
        .animation(.easeInOut(duration: 0.3), value: detailGame?.id)
        .onAppear(perform: wire)
        .onReceive(idleTimer) { _ in checkIdle() }
        .onReceive(slideTimer) { _ in
            guard !introVisible, !screensaver, launcher.running == nil, !gameActivity.isActive else { return }
            slideIndex += 1
        }
        .onChange(of: introVisible) { _, vis in
            AudioManager.shared.introRunning = vis
            syncSelectedMedia()
        }
        .onChange(of: userStore.activeID) { _, _ in
            detailGame = nil
            editingProfile = false
            menuOpen = false
            resetPageFocus(resetGameSelection: true)
            withAnimation(.easeInOut(duration: 0.25)) { tab = .games }
        }
        .onChange(of: settings.accent) { _, newAccent in
            input.syncLightbar(newAccent)
            ToastCenter.shared.show(
                icon: "paintpalette.fill",
                title: L("Tema & Işık Çubuğu: \(newAccent.title)"),
                subtitle: L("Kontrolcü LED rengi senkronlandı")
            )
        }
        .onChange(of: mediaStore.media) { _, _ in
            syncSelectedMedia()
        }
        .onChange(of: library.games) { _, newGames in
            if selectedID == nil || !newGames.contains(where: { $0.id == selectedID }) {
                selectedID = newGames.first?.id
            }
            details.loadAll(newGames)
            mediaStore.loadAll(newGames)
            syncSelectedMedia()
        }
        .onChange(of: selectedID) { _, _ in
            slideIndex = 0
            showingVideo = false
            scheduleDebouncedMediaSync()
        }
    }

    @ViewBuilder
    private var gamesContent: some View {
        if games.isEmpty {
            EmptyStateView(scanning: library.isScanning)
        } else {
            GameRow(
                games: games,
                selectedID: selected?.id,
                scale: settings.cardSize.scale,
                favorites: settings.favorites,
                rowFocused: zone == .row,
                onSelect: { g in zone = .row; select(g.id) },
                onLaunch: { g in launch(g) }
            )
            .padding(.top, 22)

            Spacer(minLength: 0)

            if let g = selected {
                let m = mediaStore.media[g.id]
                GameInfoView(
                    game: g,
                    stats: library.stats[g.id],
                    details: details.details[g.id],
                    compat: details.compat[g.id],
                    media: m,
                    slideIndex: slideIndex,
                    showingVideo: showingVideo && settings.gameMediaDisplay == .videoAndSlides && m?.hasDiscVideo == true,
                    musicPlaying: settings.gameMusicEnabled && m?.hasDiscAudio == true,
                    isRunning: launcher.running?.id == g.id,
                    isFavorite: settings.isFavorite(g.id),
                    actions: gameActions,
                    focusedAction: zone == .actions ? actionIndex : nil,
                    accent: accent,
                    onAction: { runGameAction($0, game: g) },
                    onSelectSlide: { idx in
                        AudioManager.shared.play(.tick)
                        showingVideo = false
                        slideIndex = idx
                    }
                )
                .padding(.horizontal, 48)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Wiring

    private func wire() {
        input.onAction = { handle($0) }
        input.onActivity = { deliberate in
            if introVisible {
                guard deliberate else { return false }
                UserAccountStore.shared.selectedIndex = 0
                withAnimation(.easeOut(duration: 0.4)) {
                    introVisible = false
                    showingUserSelect = true
                }
                return true
            }
            if screensaver {
                withAnimation(.easeInOut(duration: 0.6)) { screensaver = false }
                return true
            }
            return false
        }
        input.onCloseCombo = {
            if launcher.running != nil {
                InGameOverlayManager.shared.toggle(launcher: launcher)
            } else if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            } else if !introVisible && !showingUserSelect && !editingProfile {
                AudioManager.shared.play(menuOpen ? .back : .open)
                menuIndex = 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    menuOpen.toggle()
                }
            }
        }
        launcher.onFinished = { game, seconds in
            library.record(game, seconds: seconds)
            details.load(game, force: true)
            selectedID = game.id
        }
        if selectedID == nil { selectedID = games.first?.id }
        AudioManager.shared.introRunning = introVisible
        details.loadAll(games)
        mediaStore.loadAll(games)
        syncSelectedMedia()
    }

    private func scheduleDebouncedMediaSync() {
        mediaDebounceWork?.cancel()
        let work = DispatchWorkItem {
            if let g = selected {
                details.load(g)
                mediaStore.load(for: g)
            }
            showingVideo = (settings.gameMediaDisplay == .videoAndSlides)
            syncSelectedMedia()
        }
        mediaDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func syncSelectedMedia() {
        guard launcher.running == nil else { return }
        guard let g = selected else {
            AudioManager.shared.setGameTheme(nil)
            return
        }
        let themeURL = mediaStore.media[g.id]?.themeAudioURL
        AudioManager.shared.setGameTheme(themeURL)
        SmartDS4Manager.shared.updateForGame(g)
    }

    // MARK: - Input routing

    private func handle(_ action: NavAction) {
        let audio = AudioManager.shared
        if launcher.errorMessage != nil {
            launcher.errorMessage = nil
            if action == .confirm || action == .back { return }
        }

        if menuOpen {
            switch action {
            case .left, .up:
                menuIndex = (menuIndex - 1 + menuItems.count) % menuItems.count
                audio.play(.tick)
            case .right, .down:
                menuIndex = (menuIndex + 1) % menuItems.count
                audio.play(.tick)
            case .confirm:
                audio.play(.confirm)
                menuOpen = false
                menuItems[menuIndex].action()
            case .back, .options:
                audio.play(.back)
                menuOpen = false
            default: break
            }
            return
        }

        if editingProfile {
            if profileEditor.handle(action, settings: settings) {
                let cancelledNewUser = profileEditor.isCreatingNewUser
                profileEditor.isCreatingNewUser = false
                UserAccountStore.shared.syncCurrentFromSettings(settings)
                withAnimation(.easeInOut(duration: 0.25)) {
                    editingProfile = false
                    if cancelledNewUser { showingUserSelect = true }
                }
            }
            return
        }

        if showingUserSelect {
            let store = UserAccountStore.shared
            let total = store.accounts.count + 1
            switch action {
            case .left:
                store.selectedIndex = (store.selectedIndex - 1 + total) % total
                audio.play(.tick)
            case .right:
                store.selectedIndex = (store.selectedIndex + 1) % total
                audio.play(.tick)
            case .confirm:
                if store.selectedIndex == store.accounts.count {
                    startCreatingNewUser()
                } else {
                    audio.play(.confirm)
                    store.switchTo(index: store.selectedIndex, settings: settings)
                    withAnimation(.easeInOut(duration: 0.25)) { showingUserSelect = false }
                }
            case .square:
                if store.selectedIndex < store.accounts.count {
                    store.deleteAccount(at: store.selectedIndex, settings: settings)
                }
            case .back:
                audio.play(.back)
                withAnimation(.easeInOut(duration: 0.25)) { showingUserSelect = false }
            default: break
            }
            return
        }

        if action == .options {
            audio.play(.open)
            menuIndex = 0
            menuOpen = true
            return
        }

        if let g = detailGame {
            handleDetail(action, game: g)
            return
        }

        switch action {
        case .l1: cycleTab(-1); return
        case .r1: cycleTab(1); return
        default: break
        }

        switch tab {
        case .games: handleGames(action)
        case .trophies: handleTrophies(action)
        case .profile: handleProfile(action)
        case .settings: handleSettings(action)
        }
    }

    private func handleTrophies(_ action: NavAction) {
        let audio = AudioManager.shared
        let g = games.indices.contains(trophyGameIndex) ? games[trophyGameIndex] : games.first
        let list = g.flatMap { details.details[$0.id]?.trophies } ?? []
        switch action {
        case .left:
            if trophyGameIndex > 0 {
                trophyGameIndex -= 1
                trophyRowIndex = 0
                audio.play(.tick)
            }
        case .right:
            if trophyGameIndex < games.count - 1 {
                trophyGameIndex += 1
                trophyRowIndex = 0
                audio.play(.tick)
            }
        case .up:
            if trophyRowIndex > 0 { trophyRowIndex -= 1; audio.play(.tick) }
        case .down:
            if trophyRowIndex < list.count - 1 { trophyRowIndex += 1; audio.play(.tick) }
        case .triangle, .confirm:
            audio.play(.confirm)
            if list.indices.contains(trophyRowIndex) {
                let t = list[trophyRowIndex]
                ToastCenter.shared.show(
                    icon: "trophy.fill",
                    title: L("🏆 \(t.typeName) Kupa: \(t.name)"),
                    subtitle: t.detail,
                    tint: t.color,
                    imageURL: t.iconURL
                )
            } else {
                ToastCenter.shared.show(
                    icon: "trophy.fill",
                    title: L("Kupa Seviyesi \(details.trophySummary.level)"),
                    subtitle: L("Toplam \(details.trophySummary.totalUnlocked) / \(details.trophySummary.totalAvailable) kupa açıldı")
                )
            }
        case .back:
            switchTab(to: .games)
        default: break
        }
    }

    private func handleGames(_ action: NavAction) {
        let audio = AudioManager.shared
        guard let g = selected else {
            if action == .triangle { library.scan() }
            return
        }
        switch (zone, action) {
        case (.row, .left): move(-1)
        case (.row, .right): move(1)
        case (.row, .down):
            audio.play(.tick)
            withAnimation(.easeOut(duration: 0.2)) { zone = .actions; actionIndex = 0 }
        case (.row, .confirm): launch(g)
        case (.actions, .left):
            guard actionIndex > 0 else { return }
            actionIndex -= 1; audio.play(.tick)
        case (.actions, .right):
            guard actionIndex < gameActions.count - 1 else { return }
            actionIndex += 1; audio.play(.tick)
        case (.actions, .up), (.actions, .back):
            audio.play(.tick)
            withAnimation(.easeOut(duration: 0.2)) { zone = .row }
        case (.actions, .confirm):
            let a = gameActions[min(actionIndex, gameActions.count - 1)]
            runGameAction(a, game: g)
        case (_, .triangle): openDetail(g)
        case (_, .square): toggleFavorite(g)
        case (.row, .back):
            if launcher.running != nil { audio.play(.back); launcher.stop() }
        default: break
        }
    }

    private func handleDetail(_ action: NavAction, game g: Game) {
        let audio = AudioManager.shared
        let actionsCount = GameDetailView.actionCount
        let total = actionsCount + GameDetailView.rowCount(details.details[g.id])
        switch action {
        case .left:
            if detailFocus > 0 && detailFocus < actionsCount { detailFocus -= 1; audio.play(.tick) }
        case .right:
            if detailFocus < actionsCount - 1 { detailFocus += 1; audio.play(.tick) }
        case .down:
            let next = detailFocus < actionsCount ? actionsCount : detailFocus + 1
            if next < total { detailFocus = next; audio.play(.tick) }
        case .up:
            if detailFocus > actionsCount { detailFocus -= 1; audio.play(.tick) }
            else if detailFocus == actionsCount { detailFocus = 0; audio.play(.tick) }
        case .confirm:
            if detailFocus < actionsCount { runDetailAction(DetailAction.allCases[detailFocus], game: g) }
        case .square: toggleFavorite(g)
        case .back, .triangle: closeDetail()
        default: break
        }
    }

    private func handleProfile(_ action: NavAction) {
        let audio = AudioManager.shared
        let count = ProfileAction.allCases.count
        switch action {
        case .left, .up: if profileIndex > 0 { profileIndex -= 1; audio.play(.tick) }
        case .right, .down: if profileIndex < count - 1 { profileIndex += 1; audio.play(.tick) }
        case .confirm: audio.play(.confirm); runProfileAction(ProfileAction.allCases[profileIndex])
        case .back: switchTab(to: .games)
        default: break
        }
    }

    private func handleSettings(_ action: NavAction) {
        let audio = AudioManager.shared
        let rows = settingsRows
        guard !rows.isEmpty else { return }
        let i = min(settingsIndex, rows.count - 1)
        switch action {
        case .up:
            guard i > 0 else { return }
            settingsIndex = i - 1; audio.play(.tick)
        case .down:
            guard i < rows.count - 1 else { return }
            settingsIndex = i + 1; audio.play(.tick)
        case .left:
            if let f = rows[i].left { f(); audio.play(.tick) }
        case .right:
            if let f = rows[i].right { f(); audio.play(.tick) }
        case .confirm:
            if let f = rows[i].confirm { audio.play(.confirm); f() }
        case .back:
            switchTab(to: .games)
        default: break
        }
    }

    // MARK: - Actions

    private func runGameAction(_ a: GameAction, game g: Game) {
        switch a {
        case .play: launch(g)
        case .details: openDetail(g)
        case .favorite: toggleFavorite(g)
        case .toggleMedia:
            AudioManager.shared.play(.tick)
            if settings.gameMediaDisplay != .videoAndSlides {
                settings.gameMediaDisplay = .videoAndSlides
                showingVideo = true
            } else {
                showingVideo.toggle()
            }
        case .close: AudioManager.shared.play(.back); launcher.stop()
        }
    }

    private func runDetailAction(_ a: DetailAction, game g: Game) {
        switch a {
        case .play: launch(g)
        case .favorite: toggleFavorite(g)
        case .resolution:
            AudioManager.shared.play(.tick)
            PerfProfileStore.shared.update(g.titleID) { $0.res = $0.res.step(1) }
            let label = PerfProfileStore.shared.profile(for: g.titleID).res.label
            ToastCenter.shared.show(icon: "sparkles.tv", title: L("Çözünürlük: \(label)"), subtitle: L("\(g.title) özel RPCS3 profili"))
        case .fps:
            AudioManager.shared.play(.tick)
            PerfProfileStore.shared.update(g.titleID) { $0.fps = $0.fps.step(1) }
            let label = PerfProfileStore.shared.profile(for: g.titleID).fps.label
            ToastCenter.shared.show(icon: "gauge.with.dots.needle.67percent", title: L("FPS Limiti: \(label)"), subtitle: L("\(g.title) özel RPCS3 profili"))
        case .reveal:
            AudioManager.shared.play(.confirm)
            NSWorkspace.shared.activateFileViewerSelecting([g.bootPath])
        }
    }

    private func runProfileAction(_ a: ProfileAction) {
        switch a {
        case .edit: openProfileEditor()
        case .switchUser:
            AudioManager.shared.play(.open)
            withAnimation(.easeInOut(duration: 0.25)) { showingUserSelect = true }
        case .photo: ProfilePhoto.pick(into: settings)
        case .avatar:
            if settings.avatarImagePath != nil { ProfilePhoto.remove(from: settings) }
            settings.avatar = settings.avatar.step(1)
        }
    }

    private func openProfileEditor() {
        AudioManager.shared.play(.open)
        profileEditor.load(from: settings)
        withAnimation(.easeInOut(duration: 0.25)) { editingProfile = true }
    }

    private func startCreatingNewUser() {
        AudioManager.shared.play(.open)
        profileEditor.loadForNewUser(from: settings)
        withAnimation(.easeInOut(duration: 0.25)) {
            showingUserSelect = false
            editingProfile = true
        }
    }

    private func openDetail(_ g: Game) {
        AudioManager.shared.play(.open)
        details.load(g)
        detailFocus = 0
        withAnimation(.easeInOut(duration: 0.3)) { detailGame = g }
    }

    private func closeDetail() {
        AudioManager.shared.play(.back)
        withAnimation(.easeInOut(duration: 0.3)) { detailGame = nil }
    }

    private func toggleFavorite(_ g: Game) {
        let willAdd = !settings.isFavorite(g.id)
        AudioManager.shared.play(willAdd ? .confirm : .back)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { settings.toggleFavorite(g.id) }
        ToastCenter.shared.show(
            icon: willAdd ? "star.fill" : "star.slash",
            title: willAdd ? L("Favorilere Eklendi") : L("Favorilerden Çıkarıldı"),
            subtitle: g.title,
            imageURL: g.iconURL
        )
    }

    private func cycleTab(_ d: Int) {
        let all = Tab.allCases
        let i = all.firstIndex(of: tab) ?? 0
        let next = min(max(i + d, 0), all.count - 1)
        switchTab(to: all[next])
    }

    private func resetPageFocus(resetGameSelection: Bool = false) {
        zone = .row
        actionIndex = 0
        settingsIndex = 0
        profileIndex = 0
        trophyGameIndex = 0
        trophyRowIndex = 0
        detailFocus = 0
        menuIndex = 0
        if resetGameSelection {
            selectedID = games.first?.id
            slideIndex = 0
        }
    }

    private func switchTab(to new: Tab) {
        resetPageFocus(resetGameSelection: new == .games)
        guard new != tab else { return }
        AudioManager.shared.play(.open)
        withAnimation(.easeInOut(duration: 0.25)) { tab = new }
    }

    private func move(_ delta: Int) {
        guard !games.isEmpty else { return }
        let next = min(max(selectedIndex + delta, 0), games.count - 1)
        guard next != selectedIndex else { return }
        AudioManager.shared.play(.tick)
        select(games[next].id)
    }

    private func select(_ id: String) {
        withAnimation(.spring(response: 0.20, dampingFraction: 0.9)) { selectedID = id }
    }

    private func launch(_ game: Game) {
        select(game.id)
        if launcher.running == nil { AudioManager.shared.play(.confirm) }
        launcher.launch(game)
    }

    private func checkIdle() {
        guard !screensaver, !introVisible, !menuOpen, !editingProfile, launcher.running == nil, NSApp.isActive,
              let minutes = settings.screensaver.minutes else { return }
        if Date().timeIntervalSince(input.lastInput) > Double(minutes * 60) {
            withAnimation(.easeInOut(duration: 1.5)) { screensaver = true }
        }
    }
}
