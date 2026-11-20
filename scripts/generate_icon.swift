// Original FORGE artwork made from paths and system drawing primitives.
// Run from the repository root: swift scripts/generate_icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let destination = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func renderIcon(size: Int, filename: String) throws {
    guard let canvas = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { throw CocoaError(.fileWriteUnknown) }
    canvas.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    canvas.setFillColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1)
    canvas.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    canvas.setStrokeColor(red: 0.24, green: 0.30, blue: 0.36, alpha: 1)
    canvas.setLineWidth(24)
    canvas.addPath(CGPath(roundedRect: CGRect(x: 124, y: 124, width: 776, height: 776),
                         cornerWidth: 174, cornerHeight: 174, transform: nil))
    canvas.strokePath()

    // Three rising bars and an angled cap form the original progression mark.
    canvas.setFillColor(red: 1, green: 0.53, blue: 0.28, alpha: 1)
    for (x, height) in [(276, 190), (442, 300), (608, 424)] {
        let rect = CGRect(x: x, y: 277, width: 120, height: height)
        canvas.addPath(CGPath(roundedRect: rect, cornerWidth: 30, cornerHeight: 30, transform: nil))
        canvas.fillPath()
    }
    canvas.setFillColor(red: 1, green: 0.82, blue: 0.62, alpha: 1)
    canvas.move(to: CGPoint(x: 608, y: 736))
    canvas.addLine(to: CGPoint(x: 728, y: 736))
    canvas.addLine(to: CGPoint(x: 728, y: 796))
    canvas.closePath()
    canvas.fillPath()

    let url = destination.appendingPathComponent(filename)
    guard let image = canvas.makeImage(),
          let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(output, image, nil)
    guard CGImageDestinationFinalize(output) else { throw CocoaError(.fileWriteUnknown) }
}

try renderIcon(size: 1024, filename: "Icon.png")
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try renderIcon(size: size, filename: "Mac-\(size).png")
}
