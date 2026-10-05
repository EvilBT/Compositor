import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import PortraitCore
import UniformTypeIdentifiers

/// Image file failures are kept separate from MCP protocol errors.
public enum PhotoIOError: Error, Sendable { case unreadableImage, invalidSize, encoding }

/// An upright, bounded preview plus the full-resolution document reference.
public struct LoadedPhoto: @unchecked Sendable {
    public let image: CGImage
    public let reference: PhotoReference
    public let id: String

    /// Supply already-upright pixels, also useful for generated test fixtures.
    public init(image: CGImage, reference: PhotoReference, id: String) {
        self.image = image
        self.reference = reference
        self.id = id
    }
}

/// Orientation-aware image I/O for the headless host; full-size camera pixels are not decoded.
public enum PhotoIO {
    /// Open a local photo and apply EXIF orientation exactly once.
    public static func load(_ url: URL, maximumDimension: Int = 2048) throws -> LoadedPhoto {
        guard (64...2048).contains(maximumDimension),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = metadata[kCGImagePropertyPixelWidth] as? Int,
              let h = metadata[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { throw PhotoIOError.unreadableImage }
        let orientation = metadata[kCGImagePropertyOrientation] as? Int ?? 1
        let swaps = [5, 6, 7, 8].contains(orientation)
        let size = SIMD2(swaps ? h : w, swaps ? w : h)
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary) else { throw PhotoIOError.unreadableImage }
        let digest = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        return LoadedPhoto(image: image,
            reference: PhotoReference(source: .file(relativePath: url.lastPathComponent), pixelSize: size, contentHash: digest),
            id: String(digest.prefix(16)))
    }

    /// Decode upright native pixels with an explicit export memory bound.
    public static func loadFullResolution(_ url: URL, maximumPixels: Int = 40_000_000) throws -> CGImage {
        guard maximumPixels > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = metadata[kCGImagePropertyPixelWidth] as? Int,
              let height = metadata[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= maximumPixels / height else { throw PhotoIOError.invalidSize }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary) else { throw PhotoIOError.unreadableImage }
        return image
    }

    /// Expand frozen preview coverage to the export surface without redetecting the face.
    public static func resizeMask(_ mask: CGImage, width: Int, height: Int) throws -> CGImage {
        guard width > 0, height > 0, width <= 40_000_000 / height,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw PhotoIOError.invalidSize
        }
        context.interpolationQuality = .high
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw PhotoIOError.encoding }
        return image
    }

    /// Canonical RGBA8 bytes for comparisons and review overlays, with top-left row order.
    public static func bytes(_ image: CGImage) throws -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try result.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PhotoIOError.encoding }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return result
    }

    /// Build an immutable image from canonical bytes, preserving exact review/test pixels.
    public static func image(_ bytes: [UInt8], width: Int, height: Int) throws -> CGImage {
        guard width > 0, height > 0, width <= 16_000_000 / height, bytes.count == width * height * 4,
              let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { throw PhotoIOError.invalidSize }
        return image
    }

    /// Resize an upright image; callers resize its mask with the same bounds.
    public static func resize(_ image: CGImage, maximumDimension: Int) throws -> CGImage {
        guard (1...2048).contains(maximumDimension) else { throw PhotoIOError.invalidSize }
        let scale = min(1, Double(maximumDimension) / Double(max(image.width, image.height)))
        if scale == 1 { return image }
        let w = max(1, Int((Double(image.width) * scale).rounded())), h = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PhotoIOError.encoding }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let output = context.makeImage() else { throw PhotoIOError.encoding }
        return output
    }

    /// Encode previews for MCP image content, or PNG artifacts for lossless verification.
    public static func encode(_ image: CGImage, jpeg: Bool = false) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, (jpeg ? UTType.jpeg : UTType.png).identifier as CFString, 1, nil) else { throw PhotoIOError.encoding }
        CGImageDestinationAddImage(destination, image, jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.94] as CFDictionary : nil)
        guard CGImageDestinationFinalize(destination) else { throw PhotoIOError.encoding }
        return data as Data
    }

    /// A native-resolution face crop for inspecting texture that a whole-frame preview loses.
    /// Decodes the upright source temporarily; the returned crop is copied to release it.
    public static func closeup(_ url: URL, rect: NormalizedRect) throws -> CGImage {
        guard rect.origin.x >= 0, rect.origin.y >= 0, rect.maxX <= 1.0001, rect.maxY <= 1.0001,
              rect.size.x > 0, rect.size.y > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = metadata[kCGImagePropertyPixelWidth] as? Int,
              let height = metadata[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 100_000_000 / height,
              let original = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary) else { throw PhotoIOError.unreadableImage }
        let crop = CGRect(x: rect.origin.x * Double(original.width), y: rect.origin.y * Double(original.height),
                          width: rect.size.x * Double(original.width), height: rect.size.y * Double(original.height)).integral
        guard let image = original.cropping(to: crop) else { throw PhotoIOError.invalidSize }
        return try self.image(bytes(image), width: image.width, height: image.height)
    }
}
