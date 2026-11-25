import AVFoundation
import AppKit

/// Synthesised UI sounds + intro jingles (no external audio files needed), and background music.
final class AudioManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()

    static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/PlayHub")
    static let musicFolder = folder.appendingPathComponent("Muzik")
    private static let audioExtensions = ["mp3", "m4a", "wav", "aiff", "aif", "aac", "caf", "flac"]

    private let engine = AVAudioEngine()
    private let sfx = AVAudioPlayerNode()
    private let intro = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    private var customIntroPlayer: AVAudioPlayer?
    private var gameThemePlayer: AVAudioPlayer?
    private var currentGameThemeURL: URL?
    private var musicPlayer: AVAudioPlayer?
    private var musicFiles: [URL] = []
    private var musicIndex = 0

    var gameRunning = false { didSet { refreshMusic() } }
    var introRunning = false { didSet { refreshMusic() } }
    private var settings: AppSettings { .shared }

    private override init() {
        super.init()
        try? FileManager.default.createDirectory(at: Self.musicFolder, withIntermediateDirectories: true)

        engine.attach(sfx)
        engine.attach(intro)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = 40
        engine.connect(sfx, to: engine.mainMixerNode, format: format)
        engine.connect(intro, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        renderAll()
        try? engine.start()

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshMusic()
        }
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshMusic()
        }
    }

    // MARK: - Public API

    enum UISound: String { case tick, confirm, back, open }

    func play(_ sound: UISound) {
        let vol = Float(settings.effectsVolume)
        switch settings.uiSounds {
        case .off:
            return
        case .system:
            let names: [UISound: String] = [.tick: "Tink", .confirm: "Glass", .back: "Pop", .open: "Pop"]
            guard let s = NSSound(named: names[sound]!) else { return }
            s.stop(); s.volume = vol * 0.4; s.play()
        case .soft:
            guard let b = buffers[sound.rawValue] else { return }
            ensureRunning()
            sfx.volume = vol
            sfx.scheduleBuffer(b, at: nil, options: .interrupts)
            if !sfx.isPlaying { sfx.play() }
        }
    }

    func playIntro(_ choice: IntroSound? = nil) {
        let c = choice ?? settings.introSound
        intro.stop()
        customIntroPlayer?.stop()
        let vol = Float(settings.effectsVolume)
        switch c {
        case .off:
            return
        case .custom:
            guard let url = customIntroURL, let p = try? AVAudioPlayer(contentsOf: url) else { return }
            customIntroPlayer = p
            p.volume = vol
            p.play()
        default:
            guard let b = buffers["intro_\(c.rawValue)"] else { return }
            ensureRunning()
            intro.volume = vol
            intro.scheduleBuffer(b, at: nil, options: .interrupts)
            intro.play()
        }
    }

    var customIntroURL: URL? {
        ["mp3", "m4a", "wav", "aiff", "aif", "caf"]
            .map { Self.folder.appendingPathComponent("acilis.\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    var musicTrackCount: Int { scanMusic().count }

    func setGameTheme(_ url: URL?) {
        guard currentGameThemeURL != url else {
            refreshMusic()
            return
        }
        currentGameThemeURL = url
        refreshMusic()
    }

    func refreshMusic() {
        guard NSApp.isActive && !gameRunning && !introRunning else {
            gameThemePlayer?.pause()
            musicPlayer?.pause()
            return
        }

        let vol = Float(max(0.15, settings.musicVolume))
        if settings.gameMusicEnabled, let url = currentGameThemeURL {
            musicPlayer?.pause()
            if gameThemePlayer?.url != url {
                gameThemePlayer?.stop()
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.numberOfLoops = -1
                    p.volume = vol
                    p.play()
                    gameThemePlayer = p
                }
            } else if let p = gameThemePlayer {
                p.volume = vol
                if !p.isPlaying { p.play() }
            }
            return
        }

        gameThemePlayer?.stop()
        gameThemePlayer = nil

        if settings.musicEnabled {
            startMusic()
        } else {
            musicPlayer?.pause()
        }
    }

    func reloadMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
        musicFiles = []
        refreshMusic()
    }

    // MARK: - Music

    private func scanMusic() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: Self.musicFolder, includingPropertiesForKeys: nil)) ?? []
        return items.filter { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
    }

    private func startMusic() {
        if let p = musicPlayer {
            p.volume = Float(settings.musicVolume)
            if !p.isPlaying { p.play() }
            return
        }
        musicFiles = scanMusic().shuffled()
        musicIndex = 0
        playNextTrack()
    }

    private func playNextTrack() {
        guard !musicFiles.isEmpty else { musicPlayer = nil; return }
        let url = musicFiles[musicIndex % musicFiles.count]
        musicIndex += 1
        guard let p = try? AVAudioPlayer(contentsOf: url) else { musicPlayer = nil; return }
        p.delegate = self
        p.volume = Float(settings.musicVolume)
        musicPlayer = p
        p.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === musicPlayer else { return }
        DispatchQueue.main.async { self.playNextTrack() }
    }

    private func ensureRunning() {
        if !engine.isRunning { try? engine.start() }
    }

    // MARK: - Synthesis

    private func renderAll() {
        buffers["tick"] = render(0.12) { t in
            Self.bell(t, at: 0, freq: 1250, decay: 0.028, amp: 0.5, harmonics: false)
        }
        buffers["confirm"] = render(0.45) { t in
            Self.bell(t, at: 0, freq: 880, decay: 0.07, amp: 0.45)
                + Self.bell(t, at: 0.07, freq: 1318.5, decay: 0.16, amp: 0.45)
        }
        buffers["back"] = render(0.35) { t in
            Self.bell(t, at: 0, freq: 987.8, decay: 0.06, amp: 0.4)
                + Self.bell(t, at: 0.06, freq: 659.3, decay: 0.12, amp: 0.4)
        }
        buffers["open"] = render(0.25) { t in
            Self.bell(t, at: 0, freq: 740, decay: 0.07, amp: 0.45)
        }

        // Classic: warm major-7 swell with a shimmer of bells on top.
        buffers["intro_classic"] = render(5.2) { t in
            let chord = [261.63, 329.63, 392.0, 493.88, 587.33]
            var v = chord.reduce(0) { $0 + Self.pad(t, freq: $1, attack: 1.4, releaseAt: 3.0, end: 5.2, amp: 0.07) }
            let bells: [(Double, Double)] = [(0.9, 1046.5), (1.05, 783.99), (1.2, 1318.5), (1.4, 987.77), (1.65, 1567.98)]
            for (at, f) in bells { v += Self.bell(t, at: at, freq: f, decay: 1.1, amp: 0.09) }
            return v
        }

        // Crystal: rising arpeggio of glassy bells.
        buffers["intro_crystal"] = render(4.2) { t in
            let notes = [523.25, 659.25, 783.99, 987.77, 1174.66, 1567.98]
            var v = 0.0
            for (i, f) in notes.enumerated() { v += Self.bell(t, at: Double(i) * 0.11, freq: f, decay: 1.5, amp: 0.13) }
            for f in [392.0, 493.88, 587.33] { v += Self.pad(t, freq: f, attack: 1.0, releaseAt: 2.4, end: 4.2, amp: 0.045, start: 0.6) }
            return v
        }

        // Deep: slow, cinematic low pad.
        buffers["intro_deep"] = render(5.6) { t in
            var v = [110.0, 164.81, 220.0, 277.18, 329.63].reduce(0) {
                $0 + Self.pad(t, freq: $1, attack: 2.0, releaseAt: 3.4, end: 5.6, amp: 0.075)
            }
            v += Self.pad(t, freq: 55, attack: 2.2, releaseAt: 3.4, end: 5.6, amp: 0.12, detune: false)
            v += Self.bell(t, at: 1.8, freq: 880, decay: 1.4, amp: 0.05)
            return v
        }
    }

    private func render(_ duration: Double, _ sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let n = Int(duration * sr)
        var raw = [Float](repeating: 0, count: n)
        var peak: Float = 0.0001
        for i in 0..<n {
            let v = Float(sample(Double(i) / sr))
            raw[i] = v
            peak = max(peak, abs(v))
        }
        let gain = min(1, 0.85 / peak)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let l = buf.floatChannelData![0], r = buf.floatChannelData![1]
        for i in 0..<n { l[i] = raw[i] * gain; r[i] = raw[i] * gain }
        return buf
    }

    private static func bell(_ t: Double, at start: Double, freq: Double, decay: Double, amp: Double, harmonics: Bool = true) -> Double {
        let x = t - start
        guard x >= 0 else { return 0 }
        let attack = min(1, x / 0.004)
        let env = amp * attack * exp(-x / decay)
        guard env > 0.0001 else { return 0 }
        var v = sin(2 * .pi * freq * x)
        if harmonics { v += 0.22 * sin(2 * .pi * freq * 2 * x) + 0.07 * sin(2 * .pi * freq * 3.01 * x) }
        return env * v
    }

    private static func pad(_ t: Double, freq: Double, attack: Double, releaseAt: Double, end: Double, amp: Double,
                            start: Double = 0, detune: Bool = true) -> Double {
        let x = t - start
        guard x >= 0 else { return 0 }
        var env: Double
        if x < attack { env = x / attack } else if t > releaseAt { env = max(0, 1 - (t - releaseAt) / (end - releaseAt)) } else { env = 1 }
        env = env * env
        var v = sin(2 * .pi * freq * x)
        if detune { v += 0.7 * sin(2 * .pi * freq * 1.004 * x) + 0.12 * sin(2 * .pi * freq * 2 * x) }
        return amp * env * v
    }
}
