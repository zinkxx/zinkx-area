import SwiftUI
import AppKit

// Renders the Zinkx Arena app icon (compiled together with Sources/PlayHub/Logo.swift).
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

let accent = Color(red: 0.0, green: 0.68, blue: 0.75)

struct IconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.2), Color(red: 0.01, green: 0.02, blue: 0.06)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
            RadialGradient(colors: [accent.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 380)
                .frame(width: 824, height: 824)
                .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            LogoMark(accent: accent)
                .frame(width: 560, height: 560)
                .shadow(color: accent.opacity(0.8), radius: 30)
        }
        .frame(width: 1024, height: 1024)
    }
}

let cg: CGImage = MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1
    guard let img = renderer.cgImage else { fatalError("render failed") }
    return img
}
let full = NSBitmapImageRep(cgImage: cg)

func png(_ size: Int) -> Data {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSImage(cgImage: cg, size: NSSize(width: 1024, height: 1024))
        .draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
]
for (name, size) in sizes {
    try! png(size).write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
try! full.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_512x512@2x.png"))
