import Foundation
import AppKit

struct Game: Identifiable, Hashable {
    let id: String          // TITLE_ID
    let title: String
    let titleID: String
    let bootPath: URL       // game folder passed to RPCS3
    let baseDir: URL        // folder that holds PARAM.SFO (PS3_GAME for discs)
    let iconURL: URL?       // ICON0.PNG (320x176)
    let backgroundURL: URL? // PIC1.PNG (1920x1080)
    let isDisc: Bool
    let sfo: [String: String]
}

struct GameStats: Codable {
    var lastPlayed: Date?
    var totalSeconds: Double = 0
    var sessions: Int?
    var firstPlayed: Date?
}

/// Minimal PARAM.SFO reader (PS3 game metadata).
enum SFO {
    static func parse(_ url: URL) -> [String: String] {
        guard let d = try? Data(contentsOf: url), d.count > 20 else { return [:] }
        let b = [UInt8](d)
        guard b[0] == 0x00, b[1] == 0x50, b[2] == 0x53, b[3] == 0x46 else { return [:] }
        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24 }

        let keyStart = u32(8), dataStart = u32(12), count = u32(16)
        var out: [String: String] = [:]
        for i in 0..<count {
            let e = 20 + i * 16
            guard e + 16 <= b.count else { break }
            let keyOff = u16(e), fmt = u16(e + 2), len = u32(e + 4), dataOff = u32(e + 12)

            var k = keyStart + keyOff
            var keyBytes: [UInt8] = []
            while k < b.count, b[k] != 0 { keyBytes.append(b[k]); k += 1 }
            let key = String(decoding: keyBytes, as: UTF8.self)

            let ds = dataStart + dataOff
            guard ds >= 0, ds + len <= b.count else { continue }
            switch fmt {
            case 0x0204, 0x0004:
                var v = Array(b[ds..<ds + len])
                while v.last == 0 { v.removeLast() }
                out[key] = String(decoding: v, as: UTF8.self)
            case 0x0404 where len >= 4:
                out[key] = String(u32(ds))
            default:
                break
            }
        }
        return out
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, NSImage>()

    func image(_ url: URL?) -> NSImage? {
        guard let url else { return nil }
        if let img = cache.object(forKey: url as NSURL) { return img }
        guard let img = NSImage(contentsOf: url) else { return nil }
        cache.setObject(img, forKey: url as NSURL)
        return img
    }
}

enum Format {
    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds) / 60
        let h = total / 60, m = total % 60
        if h > 0 { return "\(h) sa \(m) dk" }
        return "\(max(m, 1)) dk"
    }
}
