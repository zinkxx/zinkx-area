import SwiftUI

// Zinkx Arena brand mark: a faceted, rounded hexagon "arena" with a slanted Z cut by speed slits.
// Kept free of app dependencies so the icon generator can compile it too.

private let italic: CGFloat = 0.13

private func skewed(_ x: CGFloat, _ y: CGFloat, in r: CGRect) -> CGPoint {
    let sx = x + (0.5 - y) * italic
    return CGPoint(x: r.minX + sx * r.width, y: r.minY + y * r.height)
}

/// Hexagon (pointy top) with softly rounded corners.
struct HexagonShape: Shape {
    var corner: CGFloat = 0.09

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let pts = (0..<6).map { i -> CGPoint in
            let a = (Double(i) * 60 - 90) * .pi / 180
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
        var p = Path()
        let radius = r * corner
        let mid = CGPoint(x: (pts[5].x + pts[0].x) / 2, y: (pts[5].y + pts[0].y) / 2)
        p.move(to: mid)
        for i in 0..<6 {
            p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % 6], radius: radius)
        }
        p.closeSubpath()
        return p
    }
}

/// Six triangles from the centre — shaded alternately for a cut-crystal look.
struct HexFacet: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        func pt(_ i: Int) -> CGPoint {
            let a = (Double(i) * 60 - 90) * .pi / 180
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
        var p = Path()
        p.move(to: c)
        p.addLine(to: pt(index))
        p.addLine(to: pt(index + 1))
        p.closeSubpath()
        return p
    }
}

/// Filled, slanted Z with two speed slits (even-odd holes).
struct ZGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [
            (0.29, 0.28), (0.73, 0.28), (0.73, 0.375), (0.45, 0.625), (0.71, 0.625),
            (0.71, 0.72), (0.27, 0.72), (0.27, 0.625), (0.55, 0.375), (0.29, 0.375),
        ]
        var p = Path()
        p.move(to: skewed(pts[0].0, pts[0].1, in: rect))
        for q in pts.dropFirst() { p.addLine(to: skewed(q.0, q.1, in: rect)) }
        p.closeSubpath()
        // speed slits
        for (x0, x1, y0, y1) in [(0.29, 0.41, 0.318, 0.336), (0.59, 0.71, 0.664, 0.682)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            p.move(to: skewed(x0, y0, in: rect))
            p.addLine(to: skewed(x1, y0, in: rect))
            p.addLine(to: skewed(x1, y1, in: rect))
            p.addLine(to: skewed(x0, y1, in: rect))
            p.closeSubpath()
        }
        return p
    }
}

/// Centre-line of the Z, used as an animated reveal mask.
struct ZPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: skewed(0.22, 0.327, in: rect))
        p.addLine(to: skewed(0.73, 0.327, in: rect))
        p.addLine(to: skewed(0.27, 0.673, in: rect))
        p.addLine(to: skewed(0.78, 0.673, in: rect))
        return p
    }
}

/// Speed streaks flying off the Z.
struct SpeedLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for (x0, x1, y) in [(0.10, 0.22, 0.30), (0.15, 0.24, 0.355), (0.76, 0.88, 0.70), (0.76, 0.84, 0.645)] as [(CGFloat, CGFloat, CGFloat)] {
            p.move(to: skewed(x0, y, in: rect))
            p.addLine(to: skewed(x1, y, in: rect))
        }
        return p
    }
}

struct LogoMark: View {
    var accent: Color
    var ring: Double = 1        // outer thin ring draw-on
    var outline: Double = 1     // main rim draw-on
    var fill: Double = 1        // body gradient
    var facets: Double = 1      // crystal shading
    var mark: Double = 1        // Z reveal
    var speed: Double = 1       // speed streaks
    var spin: Double = 0        // outer ring rotation (degrees)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = s * 0.04
            let light = accent.mix(with: .white, by: 0.55)
            ZStack {
                // Outer ring
                HexagonShape(corner: 0.12)
                    .trim(from: 0, to: ring)
                    .stroke(light.opacity(0.6), style: StrokeStyle(lineWidth: lw * 0.38, lineCap: .round))
                    .rotationEffect(.degrees(spin))

                // Segmented tech halo
                Circle()
                    .trim(from: 0, to: ring)
                    .stroke(
                        AngularGradient(colors: [light.opacity(0.5), .clear, light.opacity(0.35), .clear, light.opacity(0.5)], center: .center),
                        style: StrokeStyle(lineWidth: lw * 0.25, lineCap: .round, dash: [s * 0.08, s * 0.05])
                    )
                    .padding(-s * 0.04)
                    .rotationEffect(.degrees(-spin * 1.4))

                Group {
                    // Body
                    HexagonShape()
                        .fill(LinearGradient(colors: [accent.mix(with: .white, by: 0.18), accent, accent.mix(with: .black, by: 0.58)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(fill)
                    // Facets
                    ZStack {
                        ForEach(0..<6, id: \.self) { i in
                            HexFacet(index: i).fill(Color.white.opacity([0.18, 0.07, 0.0, 0.11, 0.03, 0.22][i]))
                        }
                    }
                    .clipShape(HexagonShape())
                    .opacity(facets * fill)
                    // Top gloss
                    HexagonShape()
                        .fill(LinearGradient(colors: [.white.opacity(0.32), .clear], startPoint: .top, endPoint: .center))
                        .opacity(fill)
                    // Inner bevel
                    HexagonShape()
                        .stroke(.white.opacity(0.22 * fill), lineWidth: lw * 0.5)
                        .padding(lw * 1.4)
                    // Rim
                    HexagonShape()
                        .trim(from: 0, to: outline)
                        .stroke(AngularGradient(colors: [.white, light, .white, light, .white], center: .center),
                                style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                    // Speed streaks
                    SpeedLinesShape()
                        .trim(from: 0, to: speed)
                        .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: lw * 0.55, lineCap: .round))
                    // Z
                    ZGlyphShape()
                        .fill(LinearGradient(colors: [.white, .white.opacity(0.88)], startPoint: .top, endPoint: .bottom),
                              style: FillStyle(eoFill: true))
                        .shadow(color: .black.opacity(0.4), radius: s * 0.018, y: s * 0.012)
                        .mask(
                            ZPathShape()
                                .trim(from: 0, to: mark)
                                .stroke(.white, style: StrokeStyle(lineWidth: s * 0.17, lineCap: .square, lineJoin: .miter))
                        )
                }
                .padding(s * 0.07)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Brand name with a heavy first word and a light, tinted rest. `revealed` letters are visible.
struct BrandWordmark: View {
    let text: String
    let accent: Color
    var size: CGFloat = 64
    var revealed: Int = .max

    var body: some View {
        let chars = Array(text.uppercased())
        let firstSpace = chars.firstIndex(of: " ") ?? chars.count
        HStack(spacing: size * 0.09) {
            ForEach(chars.indices, id: \.self) { i in
                let shown = i < revealed
                let isFirstWord = i < firstSpace
                Text(String(chars[i]))
                    .font(.system(size: size, weight: isFirstWord ? .black : .light))
                    .foregroundStyle(
                        isFirstWord
                            ? LinearGradient(colors: [.white, .white.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [accent.mix(with: .white, by: 0.65), accent.mix(with: .white, by: 0.3)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: isFirstWord ? .white.opacity(0.35) : accent.opacity(0.6), radius: shown ? 14 : 0)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.7)
                    .offset(y: shown ? 0 : size * 0.28)
                    .blur(radius: shown ? 0 : 8)
            }
        }
        .fixedSize()
    }
}
