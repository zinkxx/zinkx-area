import SwiftUI
import AppKit

// MARK: - PS3/PS5-style silk waves + floating sparks

struct WavesView: View {
    let accent: Color
    var intensity: Double = 1
    var sparks: Bool = false
    @ObservedObject private var activity = GameActivity.shared

    var body: some View {
        // 30 fps is plenty for these slow waves; stop entirely while a game is running.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: activity.isActive)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let ribbons = 3
                let strands = 14
                for r in 0..<ribbons {
                    let fr = Double(r)
                    let baseY = size.height * (0.52 + 0.08 * fr)
                    let amp = size.height * (0.06 + 0.025 * fr)
                    let speed = 0.18 + 0.07 * fr
                    let k = (1.1 + 0.35 * fr) * 2 * .pi / size.width
                    for s in 0..<strands {
                        let fs = Double(s)
                        let spread = fs * (3.5 + fr)
                        let phase = fs * 0.045
                        var path = Path()
                        var x: CGFloat = 0
                        while x <= size.width + 8 {
                            let xd = Double(x)
                            let y = baseY + spread
                                + amp * sin(xd * k + t * speed + fr * 1.7 + phase)
                                + amp * 0.45 * sin(xd * k * 0.47 - t * speed * 0.6 + fr)
                            if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                            x += 10
                        }
                        let edge = 1 - abs(fs - Double(strands) / 2) / (Double(strands) / 2)
                        let alpha = (0.05 + 0.22 * edge) * intensity
                        ctx.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 1.2)
                    }
                }

                if sparks {
                    let count = 36
                    for i in 0..<count {
                        let fi = Double(i)
                        let seed = sin(fi * 12.9898) * 43758.5453
                        let frac = seed - floor(seed)
                        let speed = 0.04 + (frac * 0.05)
                        let progress = (t * speed + frac).truncatingRemainder(dividingBy: 1.0)
                        let x = size.width * ((fi / Double(count)) + 0.03 * sin(t * 0.6 + fi))
                        let y = size.height * (1.05 - progress * 1.1)
                        let fade = sin(progress * .pi)
                        let radius = 1.2 + (fi.truncatingRemainder(dividingBy: 3)) * 0.9
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.45 * fade * intensity)))
                    }
                }
            }
        }
        .background(
            LinearGradient(colors: [accent.opacity(0.55), Color.black], startPoint: .top, endPoint: .bottom)
                .opacity(intensity)
        )
        .drawingGroup()
    }
}

// MARK: - Cinematic Boot Intro (Zinkx Arena)

struct IntroView: View {
    let brand: String
    let greeting: String
    let accent: Color
    let onFinish: () -> Void

    @State private var flareWidth: CGFloat = 0
    @State private var flareOpacity = 0.0
    @State private var ring = 0.0
    @State private var outline = 0.0
    @State private var mark = 0.0
    @State private var speed = 0.0
    @State private var fill = 0.0
    @State private var facets = 0.0
    @State private var spin = -40.0
    @State private var tilt = 28.0
    @State private var glow = false
    @State private var logoScale = 0.68
    @State private var pulseScale = 0.6
    @State private var pulseOpacity = 0.0
    @State private var sweep = -1.5
    @State private var letters = 0
    @State private var dividerWidth: CGFloat = 0
    @State private var showGreeting = false
    @State private var exiting = false

    var body: some View {
        ZStack {
            Color.black

            // Silk waves + floating light particles
            WavesView(accent: accent, intensity: 0.72, sparks: true)
                .opacity(glow ? 0.9 : 0)

            // Deep ambient radial aura
            RadialGradient(
                colors: [accent.mix(with: .white, by: 0.2).opacity(glow ? 0.48 : 0), accent.opacity(glow ? 0.18 : 0), .clear],
                center: .center, startRadius: 10, endRadius: 720
            )

            // Anamorphic horizontal ignition flare
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.clear, accent.mix(with: .white, by: 0.5), .white, accent.mix(with: .white, by: 0.5), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: flareWidth, height: 3)
                .shadow(color: accent, radius: 18)
                .opacity(flareOpacity)
                .offset(y: -70)

            // Expanding shockwave hexagon pulse on Z impact
            HexagonShape(corner: 0.12)
                .stroke(accent.mix(with: .white, by: 0.5).opacity(pulseOpacity), lineWidth: 2.5)
                .frame(width: 240, height: 240)
                .scaleEffect(pulseScale)
                .offset(y: -70)

            VStack(spacing: 30) {
                // 3D Crystal Arena Emblem
                LogoMark(
                    accent: accent,
                    ring: ring,
                    outline: outline,
                    fill: fill,
                    facets: facets,
                    mark: mark,
                    speed: speed,
                    spin: spin
                )
                .frame(width: 230, height: 230)
                .overlay(
                    LinearGradient(colors: [.clear, .white.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 80)
                        .rotationEffect(.degrees(22))
                        .offset(x: sweep * 190)
                        .mask(HexagonShape())
                )
                .shadow(color: accent.opacity(glow ? 0.95 : 0), radius: 55)
                .shadow(color: .white.opacity(fill * 0.35), radius: 22)
                .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: -0.6, z: 0), perspective: 0.5)
                .scaleEffect(logoScale)

                VStack(spacing: 14) {
                    BrandWordmark(text: brand, accent: accent, size: 68, revealed: letters)

                    // Glowing metallic underline bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, accent.mix(with: .white, by: 0.6), .white, accent.mix(with: .white, by: 0.6), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: dividerWidth, height: 2.5)
                        .shadow(color: accent, radius: 10)
                }

                // PlayStation-style player login toast pill
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(accent.gradient).frame(width: 38, height: 38)
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white)
                        Text(L("KONTROLCÜ HAZIR  ·  PS3 SİSTEMİ AKTİF"))
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.6)
                            .foregroundStyle(accent.mix(with: .white, by: 0.55))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial.opacity(0.75), in: Capsule())
                .background(Color.black.opacity(0.4), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .shadow(color: accent.opacity(0.45), radius: 20, y: 6)
                .scaleEffect(showGreeting ? 1 : 0.88)
                .offset(y: showGreeting ? 0 : 18)
                .opacity(showGreeting ? 1 : 0)
                .padding(.top, 6)
            }
        }
        .ignoresSafeArea()
        .scaleEffect(exiting ? 1.12 : 1)
        .opacity(exiting ? 0 : 1)
        .onAppear(perform: run)
    }

    private func run() {
        // Stage 1: Horizontal light beam ignition + outer ring draw
        after(0.55) {
            AudioManager.shared.playIntro()
            withAnimation(.easeOut(duration: 0.7)) {
                flareWidth = 980
                flareOpacity = 0.95
            }
            withAnimation(.easeOut(duration: 1.5)) {
                ring = 1
                glow = true
            }
            withAnimation(.linear(duration: 5.5)) {
                spin = 30
            }
        }

        // Stage 2: 3D Hexagon assembly & Z slash
        after(0.85) {
            withAnimation(.easeInOut(duration: 1.0)) {
                outline = 1
                flareOpacity = 0.0
            }
            withAnimation(.spring(response: 1.15, dampingFraction: 0.72)) {
                logoScale = 1.0
                tilt = 0
            }
        }
        after(1.45) {
            withAnimation(.easeOut(duration: 0.55)) {
                mark = 1
            }
        }
        after(1.85) {
            withAnimation(.easeOut(duration: 0.45)) {
                speed = 1
                fill = 1
                facets = 1
                pulseOpacity = 0.85
            }
            withAnimation(.easeOut(duration: 1.1)) {
                pulseScale = 1.85
                pulseOpacity = 0
            }
            withAnimation(.easeInOut(duration: 0.95)) {
                sweep = 1.5
            }
        }

        // Stage 3: Wordmark reveal & underline
        let count = brand.count
        for i in 0..<count {
            after(2.1 + Double(i) * 0.05) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    letters = i + 1
                }
            }
        }
        after(2.25 + Double(count) * 0.05) {
            withAnimation(.easeOut(duration: 0.7)) {
                dividerWidth = 420
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                showGreeting = true
            }
        }

        // Stage 4: Smooth exit
        after(5.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                exiting = true
            }
        }
        after(6.3) {
            onFinish()
        }
    }

    private func after(_ s: Double, _ f: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: f)
    }
}

// MARK: - Screensaver

struct ScreensaverView: View {
    let game: Game?
    let accent: Color
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color.black
                if let g = game, let img = ImageCache.shared.image(g.backgroundURL ?? g.iconURL) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: g.backgroundURL == nil ? 40 : 0)
                        .scaleEffect(drift ? 1.2 : 1.05)
                        .offset(x: drift ? -50 : 50)
                        .clipped()
                        .opacity(0.5)
                } else {
                    WavesView(accent: accent, intensity: 0.7, sparks: true)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 6) {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ctx.date, format: .dateTime.hour().minute())
                                .font(.system(size: 130, weight: .thin))
                                .monospacedDigit()
                            Text(ctx.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(L10n.locale)))
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    if let g = game {
                        Text(g.title).font(.system(size: 20)).foregroundStyle(.white.opacity(0.55)).padding(.top, 10)
                    }
                }
                .padding(90)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 40).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}
