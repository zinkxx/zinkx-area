import Foundation
import AppKit

final class GameLibrary: ObservableObject {
    @Published var games: [Game] = []
    @Published private(set) var isScanning = false
    @Published var stats: [String: GameStats] = [:]

    /// Automatically checks ~/Games/PS3 and any mounted external volume containing a "PS3 Games" directory.
    static var defaultRoots: [URL] {
        var urls: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Games/PS3")
        ]
        let volumesDir = URL(fileURLWithPath: "/Volumes")
        if let vols = try? FileManager.default.contentsOfDirectory(at: volumesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for v in vols {
                let candidate = v.appendingPathComponent("PS3 Games")
                if FileManager.default.fileExists(atPath: candidate.path) {
                    urls.append(candidate)
                }
            }
        }
        return urls
    }
    static var roots: [URL] {
        defaultRoots + AppSettings.shared.extraFolders.map { URL(fileURLWithPath: $0) }
    }
    static let rpcs3Dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/rpcs3")

    private let statsKey = "gameStats"

    init() {
        loadStats()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.scan() }
            }
        }
        scan()
    }

    func scan() {
        if CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--export-screenshots") {
            isScanning = false
            return
        }
        isScanning = true
        let roots = Self.roots
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = GameLibrary.discover(roots: roots)
            DispatchQueue.main.async {
                guard let self else { return }
                self.games = self.sorted(found)
                self.isScanning = false
            }
        }
    }

    func record(_ game: Game, seconds: Double) {
        var s = stats[game.id] ?? GameStats()
        s.lastPlayed = Date()
        s.totalSeconds += seconds
        if seconds >= 4 {
            s.sessions = (s.sessions ?? 0) + 1
            if s.firstPlayed == nil { s.firstPlayed = Date() }
        }
        stats[game.id] = s
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
        games = sorted(games)
    }

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let s = try? JSONDecoder().decode([String: GameStats].self, from: data) {
            stats = s
        }
    }

    func resort() {
        games = sorted(games)
    }

    /// Most recently played first (like the PS5 home screen), then alphabetical.
    private func sorted(_ list: [Game]) -> [Game] {
        if AppSettings.shared.sortOrder == .alphabetical {
            return list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list.sorted { a, b in
            let da = stats[a.id]?.lastPlayed, db = stats[b.id]?.lastPlayed
            switch (da, db) {
            case let (x?, y?): return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    // MARK: - Discovery

    static func discover(roots: [URL]) -> [Game] {
        let fm = FileManager.default
        var candidates: [URL] = []

        for root in roots {
            if let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                candidates += items
            }
        }

        // Games the user added inside RPCS3 (File > Add Games)
        let yml = rpcs3Dir.appendingPathComponent("games.yml")
        if let text = try? String(contentsOf: yml, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                guard let r = line.range(of: ": ") else { continue }
                var p = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if p.hasPrefix("\""), p.hasSuffix("\""), p.count >= 2 { p = String(p.dropFirst().dropLast()) }
                if !p.isEmpty { candidates.append(URL(fileURLWithPath: p)) }
            }
        }

        // Games installed from .pkg files
        let hdd = rpcs3Dir.appendingPathComponent("dev_hdd0/game")
        if let items = try? fm.contentsOfDirectory(at: hdd, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            candidates += items
        }

        var result: [String: Game] = [:]
        for dir in candidates {
            guard let g = makeGame(dir) else { continue }
            if let existing = result[g.id], existing.isDisc, !g.isDisc { continue }
            result[g.id] = g
        }
        return Array(result.values)
    }

    static func makeGame(_ dir: URL) -> Game? {
        let fm = FileManager.default
        let discDir = dir.appendingPathComponent("PS3_GAME")
        let isDisc = fm.fileExists(atPath: discDir.appendingPathComponent("PARAM.SFO").path)
        let base = isDisc ? discDir : dir
        let sfoURL = base.appendingPathComponent("PARAM.SFO")
        guard fm.fileExists(atPath: sfoURL.path) else { return nil }

        let sfo = SFO.parse(sfoURL)
        // DG = disc game, HG = HDD game. Skips updates (GD), PS2 Classics (2P), etc.
        guard ["DG", "HG"].contains(sfo["CATEGORY"] ?? "") else { return nil }
        guard fm.fileExists(atPath: base.appendingPathComponent("USRDIR/EBOOT.BIN").path) else { return nil }

        let titleID = sfo["TITLE_ID"] ?? dir.lastPathComponent
        let title = (sfo["TITLE"] ?? dir.lastPathComponent)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        func img(_ name: String) -> URL? {
            let u = base.appendingPathComponent(name)
            return fm.fileExists(atPath: u.path) ? u : nil
        }

        return Game(id: titleID, title: title, titleID: titleID, bootPath: dir, baseDir: base,
                    iconURL: img("ICON0.PNG"), backgroundURL: img("PIC1.PNG"), isDisc: isDisc, sfo: sfo)
    }
}
