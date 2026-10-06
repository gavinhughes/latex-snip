import CoreGraphics
import Foundation
import ImageIO

/// Turns a snip into Texo's encoder input. Mirrors Texo-web's imageProcessor.ts:
/// grayscale on white, invert dark-mode snips, crop to the ink, fit into
/// 384×384 keeping the aspect ratio (black padding), then normalize.
public enum TexoPreprocessor {
    public static let side = 384
    static let mean: Float = 0.7931
    static let std: Float = 0.1738
    static let inkThreshold: UInt8 = 200

    /// 8-bit grayscale pixels, row-major.
    struct Gray: Equatable {
        var width: Int
        var height: Int
        var pixels: [UInt8]
    }

    public enum Error: Swift.Error, LocalizedError {
        case unreadableImage
        public var errorDescription: String? { "Could not read the captured image." }
    }

    public static func loadImage(at url: URL) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw Error.unreadableImage
        }
        return image
    }

    /// `[1, 3, 384, 384]` float tensor data (the gray channel repeated 3×).
    public static func pixelValues(for image: CGImage) throws -> [Float] {
        var g = try grayscale(image)
        g = invertIfDark(g)
        g = cropToInk(g)
        let fitted = try fit(g)
        let channel = fitted.pixels.map { (Float($0) / 255 - mean) / std }
        return channel + channel + channel
    }

    static func grayscale(_ image: CGImage) throws -> Gray {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 255, count: w * h)
        let ok = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            // White first so transparent snips read as white background.
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { throw Error.unreadableImage }
        return Gray(width: w, height: h, pixels: pixels)
    }

    /// White-on-dark snips (dark mode) are inverted to dark-on-white.
    static func invertIfDark(_ g: Gray) -> Gray {
        let dark = g.pixels.reduce(0) { $0 + ($1 < inkThreshold ? 1 : 0) }
        guard dark >= g.pixels.count - dark else { return g }
        return Gray(width: g.width, height: g.height, pixels: g.pixels.map { 255 - $0 })
    }

    /// Crop to the bounding box of pixels darker than the threshold, after
    /// stretching contrast to the full 0–255 range.
    static func cropToInk(_ g: Gray) -> Gray {
        guard let lo = g.pixels.min(), let hi = g.pixels.max(), hi > lo else { return g }
        let range = Float(hi - lo)
        var minX = g.width, minY = g.height, maxX = 0, maxY = 0
        for y in 0..<g.height {
            for x in 0..<g.width {
                let v = (Float(g.pixels[y * g.width + x] - lo) / range) * 255
                if v < Float(inkThreshold) {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        // Same extent as Texo-web (max is exclusive there); keep at least 1px.
        let w = max(maxX - minX, 1), h = max(maxY - minY, 1)
        guard maxX >= minX, maxY >= minY else { return g }
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            let src = (minY + y) * g.width + minX
            out.replaceSubrange(y * w..<(y + 1) * w, with: g.pixels[src..<src + w])
        }
        return Gray(width: w, height: h, pixels: out)
    }

    /// Scale so the short side is 384, shrink further if the long side
    /// overflows, then center on a black 384×384 canvas.
    static func fit(_ g: Gray) throws -> Gray {
        let target = Double(side)
        let scale = target / Double(min(g.width, g.height))
        var newW = Int((Double(g.width) * scale).rounded())
        var newH = Int((Double(g.height) * scale).rounded())
        if newW > side || newH > side {
            let r = min(target / Double(newW), target / Double(newH))
            newW = Int((Double(newW) * r).rounded())
            newH = Int((Double(newH) * r).rounded())
        }
        newW = max(newW, 1); newH = max(newH, 1)

        let resized = try resize(g, width: newW, height: newH)
        var canvas = [UInt8](repeating: 0, count: side * side)
        let padX = (side - newW) / 2, padY = (side - newH) / 2
        for y in 0..<newH {
            let dst = (y + padY) * side + padX
            canvas.replaceSubrange(dst..<dst + newW, with: resized.pixels[y * newW..<(y + 1) * newW])
        }
        return Gray(width: side, height: side, pixels: canvas)
    }

    static func resize(_ g: Gray, width: Int, height: Int) throws -> Gray {
        var src = g.pixels
        let space = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: Data(bytes: &src, count: src.count) as CFData),
              let image = CGImage(
                width: g.width, height: g.height, bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: g.width, space: space, bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { throw Error.unreadableImage }
        var out = [UInt8](repeating: 0, count: width * height)
        let ok = out.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { throw Error.unreadableImage }
        return Gray(width: width, height: height, pixels: out)
    }
}
