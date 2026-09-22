import CoreGraphics
import ImageIO
import Foundation

let bgTop = CGColor(red: 0.086, green: 0.122, blue: 0.176, alpha: 1)
let bgBot = CGColor(red: 0.020, green: 0.031, blue: 0.055, alpha: 1)
let glyph = CGColor(red: 0.298, green: 0.729, blue: 0.984, alpha: 1)

func renderIcon(_ S: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high

    let margin = S * 0.09
    let rect = CGRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
    let radius = rect.width * 0.2237                              // Apple squircle corner ratio
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    let grad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBot] as CFArray, locations: [0, 1])!

    ctx.saveGState(); ctx.addPath(squircle); ctx.clip()
    ctx.drawLinearGradient(grad, start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    ctx.restoreGState()

    let cupWidth = rect.width * 0.20
    let cupHeight = rect.height * 0.30
    let headWidth = rect.width * 0.62
    let leftX = rect.midX - headWidth / 2
    let rightX = rect.midX + headWidth / 2
    let cupBottomY = rect.minY + rect.height * 0.30
    let cupTopY = cupBottomY + cupHeight
    let bandPeakY = rect.minY + rect.height * 0.88
    let bandWidth = rect.width * 0.10

    let leftCup = CGPath(
        roundedRect: CGRect(x: leftX - cupWidth / 2, y: cupBottomY, width: cupWidth, height: cupHeight),
        cornerWidth: cupWidth * 0.4, cornerHeight: cupWidth * 0.4, transform: nil
    )
    let rightCup = CGPath(
        roundedRect: CGRect(x: rightX - cupWidth / 2, y: cupBottomY, width: cupWidth, height: cupHeight),
        cornerWidth: cupWidth * 0.4, cornerHeight: cupWidth * 0.4, transform: nil
    )
    let dotCount = 4
    let dotRadius = rect.width * 0.035
    let dotSpacing = rect.width * 0.12
    let dotY = rect.minY + rect.height * 0.16
    let firstDotX = rect.midX - dotSpacing * CGFloat(dotCount - 1) / 2

    let band = CGMutablePath()
    band.move(to: CGPoint(x: leftX, y: cupTopY))
    band.addCurve(
        to: CGPoint(x: rightX, y: cupTopY),
        control1: CGPoint(x: leftX, y: bandPeakY),
        control2: CGPoint(x: rightX, y: bandPeakY)
    )

    ctx.saveGState(); ctx.addPath(squircle); ctx.clip()
    ctx.setShadow(offset: .zero, blur: S * 0.05, color: glyph.copy(alpha: 0.85))

    ctx.setFillColor(glyph)
    ctx.addPath(leftCup); ctx.fillPath()
    ctx.addPath(rightCup); ctx.fillPath()
    for i in 0..<dotCount {
        let x = firstDotX + dotSpacing * CGFloat(i)
        ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
    }

    ctx.setStrokeColor(glyph)
    ctx.setLineWidth(bandWidth)
    ctx.setLineCap(.round)
    ctx.addPath(band)
    ctx.strokePath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func writePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    _ = CGImageDestinationFinalize(dest)
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: makeicon <AppIcon.appiconset dir>\n".utf8))
    exit(1)
}
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in specs { writePNG(renderIcon(size), "\(outDir)/\(name).png") }
print("wrote \(specs.count) png(s) to \(outDir)")
