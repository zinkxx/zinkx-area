import Foundation
import SwiftUI

// MARK: - Models

struct TrophyInfo: Identifiable {
    let id: Int
    let name: String
    let detail: String
    let type: String        // P G S B
    let hidden: Bool
    var unlocked = false
    var unlockedAt: Date?
    let iconURL: URL?

    var typeName: String {
        switch type {
        case "P": L("Platin")
        case "G": L("Altın")
        case "S": L("Gümüş")
        default: L("Bronz")
        }
    }

    var color: Color {
        switch type {
        case "P": Color(red: 0.72, green: 0.82, blue: 0.95)
        case "G": Color(red: 0.95, green: 0.76, blue: 0.25)
        case "S": Color(red: 0.78, green: 0.8, blue: 0.84)
        default: Color(red: 0.8, green: 0.5, blue: 0.3)
        }
    }
}

struct SaveInfo: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let modified: Date?
    let iconURL: URL?
}

struct CompatInfo: Codable {
    let status: String
    let date: String?
    var fetched: Date

    var label: String {
        switch status {
        case "Playable": L("Oynanabilir")
        case "Ingame": L("Oyun içi (sorunlu)")
        case "Intro": L("Sadece giriş")
        case "Loadable": L("Yükleniyor ama oynanmıyor")
        case "Nothing": L("Çalışmıyor")
        default: status
        }
    }

    var color: Color {
        switch status {
        case "Playable": .green
        case "Ingame": .yellow
        case "Intro": .orange
        default: .red
        }
    }
}

struct GameDetails {
    var region = L("Bilinmiyor")
    var version: String?
    var updateVersion: String?
    var resolutions: [String] = []
    var sound: [String] = []
    var parental: String?
    var systemVersion: String?
    var trophies: [TrophyInfo] = []
    var saves: [SaveInfo] = []
    var sizeBytes: Int64?

    var unlocked: Int { trophies.filter(\.unlocked).count }
    var trophyCounts: [(String, Int, Int, Color)] {
        ["P", "G", "S", "B"].compactMap { t in
            let all = trophies.filter { $0.type == t }
            guard let first = all.first else { return nil }
            return (first.typeName, all.filter(\.unlocked).count, all.count, first.color)
        }
    }
    var sizeText: String? {
        sizeBytes.map { $0.formatted(.byteCount(style: .file).locale(L10n.locale)) }
    }
}

// MARK: - Store

/// Loads extra info for games in the background: PARAM.SFO details, trophies, saves, size, compatibility.
final class DetailsStore: ObservableObject {
    @Published var details: [String: GameDetails] = [:]
    @Published var compat: [String: CompatInfo] = [:]

    static let rpcs3Home = GameLibrary.rpcs3Dir.appendingPathComponent("dev_hdd0/home/00000001")
    static let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.zinkx.playhub")

    private var loading: Set<String> = []
    private let defaults = UserDefaults.standard

    var totalUnlockedTrophies: Int { details.values.reduce(0) { $0 + $1.unlocked } }
    var totalTrophies: Int { details.values.reduce(0) { $0 + $1.trophies.count } }

    func load(_ game: Game, force: Bool = false) {
        if !force && (details[game.id] != nil || loading.contains(game.id)) { return }
        loading.insert(game.id)
        let cachedSize = defaults.object(forKey: "size_\(game.bootPath.path)") as? Int64
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var d = Self.build(game)
            d.sizeBytes = cachedSize
            DispatchQueue.main.async {
                self?.details[game.id] = d
                self?.loading.remove(game.id)
            }
            if cachedSize == nil, let size = Self.folderSize(game.bootPath) {
                DispatchQueue.main.async {
                    self?.defaults.set(size, forKey: "size_\(game.bootPath.path)")
                    self?.details[game.id]?.sizeBytes = size
                }
            }
        }
        loadCompat(game)
    }

    func loadAll(_ games: [Game]) { games.forEach { load($0) } }

    // MARK: Compatibility (rpcs3.net)

    private func loadCompat(_ game: Game) {
        let key = "compat_\(game.titleID)"
        if let data = defaults.data(forKey: key), let c = try? JSONDecoder().decode(CompatInfo.self, from: data) {
            compat[game.id] = c
            if Date().timeIntervalSince(c.fetched) < 7 * 86400 { return }
        }
        guard let url = URL(string: "https://rpcs3.net/compatibility?api=v1&g=\(game.titleID)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [String: Any],
                  let entry = results[game.titleID] as? [String: Any],
                  let status = entry["status"] as? String else { return }
            let info = CompatInfo(status: status, date: entry["date"] as? String, fetched: Date())
            DispatchQueue.main.async {
                self?.compat[game.id] = info
                if let enc = try? JSONEncoder().encode(info) { self?.defaults.set(enc, forKey: key) }
            }
        }.resume()
    }

    // MARK: Building

    private static func build(_ game: Game) -> GameDetails {
        var d = GameDetails()
        let sfo = game.sfo
        d.region = region(for: game.titleID)
        d.version = sfo["APP_VER"].map(trimVersion)
        d.parental = sfo["PARENTAL_LEVEL"].flatMap { Int($0) }.map { "Seviye \($0)" }
        if let sys = sfo["PS3_SYSTEM_VER"] { d.systemVersion = trimVersion(sys) }
        if let r = sfo["RESOLUTION"].flatMap({ Int($0) }) { d.resolutions = resolutions(r) }
        if let s = sfo["SOUND_FORMAT"].flatMap({ Int($0) }) { d.sound = soundFormats(s) }

        let update = GameLibrary.rpcs3Dir.appendingPathComponent("dev_hdd0/game/\(game.titleID)/PARAM.SFO")
        let upd = SFO.parse(update)
        if upd["CATEGORY"] == "GD", let v = upd["APP_VER"] { d.updateVersion = trimVersion(v) }

        d.trophies = trophies(for: game)
        d.saves = saves(for: game)
        return d
    }

    private static func trimVersion(_ v: String) -> String {
        // "01.02" -> "1.02", "04.7600" -> "4.76"
        var s = v
        while s.hasPrefix("0") && s.count > 1 && !s.hasPrefix("0.") { s.removeFirst() }
        if let dot = s.firstIndex(of: ".") {
            var frac = String(s[s.index(after: dot)...])
            while frac.count > 2 && frac.hasSuffix("0") { frac.removeLast() }
            s = String(s[..<dot]) + "." + frac
        }
        return s
    }

    static func region(for id: String) -> String {
        let chars = Array(id)
        guard chars.count >= 3 else { return L("Bilinmiyor") }
        switch chars[2] {
        case "E": return L("Avrupa")
        case "U": return L("Amerika")
        case "J": return L("Japonya")
        case "A": return L("Asya")
        case "K": return L("Kore")
        case "H": return "Hong Kong"
        default: return L("Bilinmiyor")
        }
    }

    private static func resolutions(_ mask: Int) -> [String] {
        var out: [String] = []
        if mask & 0x08 != 0 { out.append("1080p") }
        if mask & 0x04 != 0 { out.append("720p") }
        if mask & 0x22 != 0 { out.append("576p") }
        if mask & 0x11 != 0 { out.append("480p") }
        return out
    }

    private static func soundFormats(_ mask: Int) -> [String] {
        var out: [String] = []
        if mask & 0x10 != 0 { out.append("LPCM 7.1") }
        if mask & 0x04 != 0 { out.append("LPCM 5.1") }
        if mask & 0x100 != 0 { out.append("Dolby Digital") }
        if mask & 0x200 != 0 { out.append("DTS") }
        if mask & 0x01 != 0 && out.isEmpty { out.append(L("Stereo")) }
        return out
    }

    static func folderSize(_ url: URL) -> Int64? {
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return nil }
        var total: Int64 = 0
        for case let f as URL in e {
            if let v = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), v.isRegularFile == true {
                total += Int64(v.fileSize ?? 0)
            }
        }
        return total
    }

    // MARK: Saves

    private static func saves(for game: Game) -> [SaveInfo] {
        let dir = rpcs3Home.appendingPathComponent("savedata")
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return items
            .filter { $0.lastPathComponent.hasPrefix(game.titleID) }
            .compactMap { folder -> SaveInfo? in
                let sfo = SFO.parse(folder.appendingPathComponent("PARAM.SFO"))
                guard !sfo.isEmpty else { return nil }
                let mod = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let icon = folder.appendingPathComponent("ICON0.PNG")
                return SaveInfo(id: folder.lastPathComponent,
                                title: sfo["SUB_TITLE"].flatMap { $0.isEmpty ? nil : $0 } ?? sfo["TITLE"] ?? folder.lastPathComponent,
                                subtitle: sfo["TITLE"] ?? "",
                                detail: sfo["DETAIL"] ?? "",
                                modified: mod,
                                iconURL: fm.fileExists(atPath: icon.path) ? icon : nil)
            }
            .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    // MARK: Trophies

    private static func trophies(for game: Game) -> [TrophyInfo] {
        let fm = FileManager.default
        let tropDir = game.baseDir.appendingPathComponent("TROPDIR")
        guard let comm = (try? fm.contentsOfDirectory(atPath: tropDir.path))?.first(where: { !$0.hasPrefix(".") }) else { return [] }

        // RPCS3 installs the trophy set on first boot; otherwise unpack TROPHY.TRP ourselves.
        var dir = rpcs3Home.appendingPathComponent("trophy/\(comm)")
        let installed = fm.fileExists(atPath: dir.appendingPathComponent("TROPCONF.SFM").path)
        if !installed {
            dir = cacheDir.appendingPathComponent("trophies/\(comm)")
            if !fm.fileExists(atPath: dir.appendingPathComponent("TROPCONF.SFM").path) {
                extractTRP(tropDir.appendingPathComponent("\(comm)/TROPHY.TRP"), to: dir)
            }
        }
        guard let xml = try? String(contentsOf: dir.appendingPathComponent("TROPCONF.SFM"), encoding: .utf8) else { return [] }

        var list = parseTropConf(xml, iconDir: dir)
        if installed {
            let states = parseTropUsr(dir.appendingPathComponent("TROPUSR.DAT"))
            for i in list.indices {
                if let s = states[list[i].id] { list[i].unlocked = s.0; list[i].unlockedAt = s.1 }
            }
        }
        return list
    }

    private static func parseTropConf(_ xml: String, iconDir: URL) -> [TrophyInfo] {
        let pattern = #"<trophy id="(\d+)" hidden="(\w+)" ttype="(\w)"[^>]*>\s*<name>(.*?)</name>\s*<detail>(.*?)</detail>"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = xml as NSString
        func unescape(_ s: String) -> String {
            s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'").replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
        }
        return re.matches(in: xml, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            guard let id = Int(ns.substring(with: m.range(at: 1))) else { return nil }
            let icon = iconDir.appendingPathComponent(String(format: "TROP%03d.PNG", id))
            return TrophyInfo(id: id,
                              name: unescape(ns.substring(with: m.range(at: 4))),
                              detail: unescape(ns.substring(with: m.range(at: 5))),
                              type: ns.substring(with: m.range(at: 3)),
                              hidden: ns.substring(with: m.range(at: 2)) == "yes",
                              iconURL: FileManager.default.fileExists(atPath: icon.path) ? icon : nil)
        }
    }

    /// TROPUSR.DAT (big-endian): header, table headers, entries. Table type 6 = trophy states.
    private static func parseTropUsr(_ url: URL) -> [Int: (Bool, Date?)] {
        guard let data = try? Data(contentsOf: url), data.count > 0x30 else { return [:] }
        let b = [UInt8](data)
        func u32(_ o: Int) -> Int { o + 4 <= b.count ? Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) : 0 }
        func u64(_ o: Int) -> UInt64 { o + 8 <= b.count ? (0..<8).reduce(UInt64(0)) { $0 << 8 | UInt64(b[o + $1]) } : 0 }
        guard u32(0) == 0x818F54AD else { return [:] }
        let tables = u32(8)
        var out: [Int: (Bool, Date?)] = [:]
        for t in 0..<tables {
            let th = 0x30 + t * 0x20
            guard u32(th) == 6 else { continue }
            let count = u32(th + 12)
            var pos = Int(u64(th + 16))
            for _ in 0..<count {
                guard pos + 16 <= b.count else { break }
                let size = u32(pos + 4)
                let id = u32(pos + 16)
                let state = u32(pos + 20)
                let tick = u64(pos + 32)
                var date: Date?
                if tick > 0 {
                    let secs = Double(tick) / 1_000_000 - 62_135_596_800
                    if secs > 0 { date = Date(timeIntervalSince1970: secs) }
                }
                out[id] = (state != 0, state != 0 ? date : nil)
                pos += 16 + size
            }
        }
        return out
    }

    /// Unpacks a TROPHY.TRP archive (TROPCONF.SFM + icons).
    private static func extractTRP(_ url: URL, to dir: URL) {
        guard let data = try? Data(contentsOf: url), data.count > 0x40 else { return }
        let b = [UInt8](data)
        func u32(_ o: Int) -> Int { Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) }
        func u64(_ o: Int) -> Int { (0..<8).reduce(0) { $0 << 8 | Int(b[o + $1]) } }
        guard u32(0) == 0xDCA24D00 else { return }
        let count = u32(0x10), elementSize = u32(0x14)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for i in 0..<count {
            let e = 0x40 + i * elementSize
            guard e + 48 <= b.count else { break }
            let nameBytes = b[e..<e + 32].prefix { $0 != 0 }
            let name = String(decoding: nameBytes, as: UTF8.self)
            let off = u64(e + 32), size = u64(e + 40)
            guard !name.isEmpty, off >= 0, size > 0, off + size <= b.count else { continue }
            try? Data(b[off..<off + size]).write(to: dir.appendingPathComponent(name))
        }
    }
}
