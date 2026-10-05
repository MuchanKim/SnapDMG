import Foundation
import CoreGraphics
import ImageIO
import Testing

enum BackgroundImageFixtures {
    static func writeThreeBands(to url: URL, type: String, orientation: Int = 1) throws {
        let context = try #require(CGContext(data: nil, width: 300, height: 100,
                                           bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for (index, color) in [CGColor(red: 1, green: 0, blue: 0, alpha: 1),
                               CGColor(red: 0, green: 1, blue: 0, alpha: 1),
                               CGColor(red: 0, green: 0, blue: 1, alpha: 1)].enumerated() {
            context.setFillColor(color)
            context.fill(CGRect(x: index * 100, y: 0, width: 100, height: 100))
        }
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }
}
