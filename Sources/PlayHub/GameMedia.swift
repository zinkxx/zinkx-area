import SwiftUI
import AppKit
import AVFoundation

struct GameMediaItem: Equatable {
    var themeAudioURL: URL?
    var videoURL: URL?
    var photos: [URL] = []
    var hasDiscAudio: Bool = false
    var hasDiscVideo: Bool = false
}

/// Automatically discovers, converts (via ffmpeg), and caches music (SND0.AT3), videos (.PAM / .BIK / MOVIES.BIN),
/// and artwork (PIC0/1/2.PNG + video stills) directly from PS3 game disc folders.
final class GameMediaStore: ObservableObject {
    static let shared = GameMediaStore()

    @Published var media: [String: GameMediaItem] = [:]

    static let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.zinkx.playhub/media")
    static let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

    private var processing: Set<String> = []
    private let queue = DispatchQueue(label: "com.zinkx.playhub.media", qos: .utility, attributes: .concurrent)

    func load(for game: Game) {
        if media[game.id] != nil || processing.contains(game.id) { return }
        processing.insert(game.id)

        // Immediately publish whatever already exists on disk/cache so there's zero delay
        let initial = Self.scanExisting(for: game)
        media[game.id] = initial

        queue.async { [weak self] in
            Self.extractIfNeeded(for: game)
            let updated = Self.scanExisting(for: game)
            DispatchQueue.main.async {
                self?.media[game.id] = updated
                self?.processing.remove(game.id)
            }
        }
    }

    func loadAll(_ games: [Game]) {
        for g in games { load(for: g) }
    }

    // MARK: - Fast scan of cached & native disc files

    private static func scanExisting(for game: Game) -> GameMediaItem {
        let fm = FileManager.default
        let dir = cacheRoot.appendingPathComponent(game.titleID)
        var item = GameMediaItem()

        // 1. Theme audio (cached theme.m4a from SND0.AT3 or OBB/BIK)
        let themeURL = dir.appendingPathComponent("theme.m4a")
        if fm.fileExists(atPath: themeURL.path) {
            item.themeAudioURL = themeURL
            item.hasDiscAudio = true
        }

        // 2. Background video (cached video.mp4 from disc movies)
        let videoURL = dir.appendingPathComponent("video.mp4")
        if fm.fileExists(atPath: videoURL.path) {
            item.videoURL = videoURL
            item.hasDiscVideo = true
        }

        // 3. Disc artwork + extracted stills
        var photos: [URL] = []
        for name in ["PIC1.PNG", "PIC0.PNG", "PIC2.PNG"] {
            let u = game.baseDir.appendingPathComponent(name)
            if fm.fileExists(atPath: u.path) { photos.append(u) }
        }
        if let cachedFiles = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let slides = cachedFiles
                .filter { $0.lastPathComponent.hasPrefix("slide_") && $0.pathExtension.lowercased() == "jpg" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            photos.append(contentsOf: slides)
        }
        if photos.isEmpty, let icon = game.iconURL {
            photos.append(icon)
        }
        item.photos = photos
        return item
    }

    // MARK: - Background extraction from PS3 disc files via ffmpeg

    private static func extractIfNeeded(for game: Game) {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: ffmpegPath) else { return }

        let dir = cacheRoot.appendingPathComponent(game.titleID)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let themeOut = dir.appendingPathComponent("theme.m4a")
        let videoOut = dir.appendingPathComponent("video.mp4")

        // 1. Convert PS3_GAME/SND0.AT3 -> theme.m4a
        let snd0 = game.baseDir.appendingPathComponent("SND0.AT3")
        if !fm.fileExists(atPath: themeOut.path), fm.fileExists(atPath: snd0.path) {
            runFFmpeg(["-y", "-loglevel", "error", "-i", snd0.path, "-c:a", "aac", "-b:a", "192k", themeOut.path])
        }

        // 2. Check OBB archives (e.g. GTA San Andreas PS3Data.obb -> movies/GTAtitles.bik)
        let obbIdx = game.baseDir.appendingPathComponent("USRDIR/PS3Data.obb.idx")
        let obbFile = game.baseDir.appendingPathComponent("USRDIR/PS3Data.obb")
        if (!fm.fileExists(atPath: themeOut.path) || !fm.fileExists(atPath: videoOut.path)),
           fm.fileExists(atPath: obbIdx.path), fm.fileExists(atPath: obbFile.path),
           let bikTemp = extractBikFromOBB(idxURL: obbIdx, obbURL: obbFile) {
            if !fm.fileExists(atPath: themeOut.path) {
                runFFmpeg(["-y", "-loglevel", "error", "-i", bikTemp.path, "-vn", "-c:a", "aac", "-b:a", "192k", themeOut.path])
            }
            if !fm.fileExists(atPath: videoOut.path) {
                runFFmpeg(["-y", "-loglevel", "error", "-i", bikTemp.path, "-ss", "4", "-t", "60", "-an",
                           "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p", videoOut.path])
            }
            try? fm.removeItem(at: bikTemp)
        }

        // 3. Look for disc videos (ICON1.PAM, *MOVIES.BIN, *.bik, *.mp4) if video.mp4 not yet created
        if !fm.fileExists(atPath: videoOut.path), let srcVideo = findDiscVideo(in: game.baseDir) {
            runFFmpeg(["-y", "-loglevel", "error", "-ss", "5", "-t", "45", "-i", srcVideo.path, "-an",
                       "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p", videoOut.path])
            // If game had no SND0.AT3, try extracting audio from the video
            if !fm.fileExists(atPath: themeOut.path) {
                runFFmpeg(["-y", "-loglevel", "error", "-i", srcVideo.path, "-vn", "-c:a", "aac", "-b:a", "192k", themeOut.path])
            }
        }

        // 4. Extract 4 preview stills from video.mp4 if not present
        let slide05 = dir.appendingPathComponent("slide_05.jpg")
        if fm.fileExists(atPath: videoOut.path), !fm.fileExists(atPath: slide05.path) {
            for t in ["05", "14", "25", "36"] {
                let out = dir.appendingPathComponent("slide_\(t).jpg")
                runFFmpeg(["-y", "-loglevel", "error", "-ss", "00:00:\(t)", "-i", videoOut.path, "-frames:v", "1", "-q:v", "2", out.path])
            }
        }
    }

    private static func findDiscVideo(in baseDir: URL) -> URL? {
        let fm = FileManager.default
        let pam = baseDir.appendingPathComponent("ICON1.PAM")
        if fm.fileExists(atPath: pam.path) { return pam }

        guard let e = fm.enumerator(at: baseDir.appendingPathComponent("USRDIR"),
                                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                                    options: [.skipsHiddenFiles]) else { return nil }
        var best: (url: URL, size: Int64)?
        for case let u as URL in e {
            let name = u.lastPathComponent.lowercased()
            let isMovie = name.hasSuffix(".bik") || name.hasSuffix(".pam") || name.hasSuffix(".mp4") || name.hasSuffix("movies.bin")
            guard isMovie, !name.contains("logo"), !name.contains("static") else { continue }
            let sz = Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if sz > 1_000_000, best == nil || sz < best!.size {
                best = (u, sz)
            }
        }
        return best?.url
    }

    private static func extractBikFromOBB(idxURL: URL, obbURL: URL) -> URL? {
        guard let idx = try? Data(contentsOf: idxURL), idx.count > 12 else { return nil }
        let b = [UInt8](idx)
        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 | Int(b[o + 2]) << 16 | Int(b[o + 3]) << 24 }
        let count = u32(0)
        var pos = 4
        for _ in 0..<count {
            guard pos + 10 <= b.count else { break }
            let off = u32(pos), sz = u32(pos + 4), nlen = u16(pos + 8)
            pos += 10
            guard pos + nlen <= b.count else { break }
            let name = String(decoding: b[pos..<pos + nlen], as: UTF8.self)
            pos += nlen
            if name.lowercased().hasSuffix(".bik"), !name.lowercased().contains("logo"), sz > 1_000_000 {
                guard let fh = try? FileHandle(forReadingFrom: obbURL) else { return nil }
                defer { try? fh.close() }
                try? fh.seek(toOffset: UInt64(off))
                guard let chunk = try? fh.read(upToCount: sz) else { return nil }
                let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("obb_\(UUID().uuidString).bik")
                try? chunk.write(to: tmp)
                return tmp
            }
        }
        return nil
    }

    private static func runFFmpeg(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpegPath)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}

// MARK: - Looping Background Video Player (AVQueuePlayer + AVPlayerLooper)

struct LoopingVideoView: NSViewRepresentable {
    let url: URL
    let isPaused: Bool

    func makeNSView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.load(url: url, paused: isPaused)
        return v
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.load(url: url, paused: isPaused)
    }

    final class PlayerContainerView: NSView {
        private let playerLayer = AVPlayerLayer()
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = NSColor.clear.cgColor
            self.layer = playerLayer
            self.wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError() }

        func load(url: URL, paused: Bool) {
            if self.layer !== playerLayer {
                self.layer = playerLayer
                self.wantsLayer = true
            }
            if currentURL != url {
                currentURL = url
                queuePlayer?.pause()
                let item = AVPlayerItem(url: url)
                let qp = AVQueuePlayer()
                qp.isMuted = true
                looper = AVPlayerLooper(player: qp, templateItem: item)
                queuePlayer = qp
                playerLayer.player = qp
            }
            if paused {
                queuePlayer?.pause()
            } else if queuePlayer?.timeControlStatus != .playing {
                queuePlayer?.play()
            }
        }
    }
}
