import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

nonisolated enum BackgroundImageError: LocalizedError {
    case unreadable(String)
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .unreadable(let name):
            "Cannot read \(name). Choose a valid PNG or JPEG image."
        case .renderingFailed:
            "Could not prepare the background image for this window size."
        }
    }
}

nonisolated struct BackgroundImage {
    let image: CGImage

    init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source),
              [UTType.png.identifier, UTType.jpeg.identifier].contains(type as String),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary) else {
            throw BackgroundImageError.unreadable(url.lastPathComponent)
        }
        self.image = image
    }

    func writePNG(to url: URL, windowSize: CGSize) throws {
        guard let width = Int(exactly: windowSize.width.rounded(.down)), let height = Int(exactly: windowSize.height.rounded(.down)),
              width > 0, height > 0 else { throw BackgroundImageError.renderingFailed }
        let pixels = width.multipliedReportingOverflow(by: height)
        guard !pixels.overflow, !pixels.partialValue.multipliedReportingOverflow(by: 4).overflow else {
            throw BackgroundImageError.renderingFailed
        }
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BackgroundImageError.renderingFailed
        }

        // 프리뷰의 scaledToFill과 동일하게 중심을 유지하며 창 크기에 맞춘다.
        let outputSize = CGSize(width: width, height: height)
        let scale = max(outputSize.width / CGFloat(image.width), outputSize.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let rect = CGRect(x: (outputSize.width - size.width) / 2,
                          y: (outputSize.height - size.height) / 2,
                          width: size.width, height: size.height)
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        guard let rendered = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw BackgroundImageError.renderingFailed
        }
        CGImageDestinationAddImage(destination, rendered, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw BackgroundImageError.renderingFailed }
    }
}
