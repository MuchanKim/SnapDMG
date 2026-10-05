import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import SnapDMG

@Suite("Background Image Tests")
struct BackgroundImageTests {
    @Test("PNG와 JPEG 배경 선택 지원", arguments: [UTType.png.identifier, UTType.jpeg.identifier])
    func loadsSupportedImage(type: String) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).image")
        defer { try? FileManager.default.removeItem(at: url) }
        try BackgroundImageFixtures.writeThreeBands(to: url, type: type)
        let background = try BackgroundImage(url: url)
        #expect(background.image.width == 300)
        #expect(background.image.height == 100)
    }

    @Test("읽을 수 없는 외부 배경은 거부")
    func rejectsUnreadableImage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not an image".utf8).write(to: url)
        #expect(throws: BackgroundImageError.self) { try BackgroundImage(url: url) }
    }

    @Test("JPEG의 EXIF 회전 방향 반영")
    func respectsJPEGOrientation() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try BackgroundImageFixtures.writeThreeBands(to: url, type: UTType.jpeg.identifier, orientation: 6)
        let background = try BackgroundImage(url: url)
        #expect(background.image.width == 100)
        #expect(background.image.height == 300)
    }

    @Test("이미지 중심을 채우기로 잘라 창 크기와 72 DPI로 내보냄", arguments: [
        CGSize(width: 144, height: 144), CGSize(width: 144.75, height: 144.5)
    ])
    func exportsMatchingPreview(windowSize: CGSize) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.png")
        let output = directory.appendingPathComponent("output.png")
        try BackgroundImageFixtures.writeThreeBands(to: input, type: UTType.png.identifier)
        try BackgroundImage(url: input).writePNG(to: output, windowSize: windowSize)

        let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 144)
        #expect(image.height == 144)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let dpi = try #require(properties[kCGImagePropertyDPIWidth] as? NSNumber).doubleValue
        #expect(abs(dpi - 72) < 0.1)
        let context = try #require(CGContext(data: nil, width: 144, height: 144, bitsPerComponent: 8,
                                           bytesPerRow: 144 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 144, height: 144))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        // 원본의 양 끝 빨강·파랑 띠가 잘리고, 중앙 초록 띠가 창 전체를 채워야 한다.
        for (x, y) in [(4, 4), (139, 4), (4, 139), (139, 139)] {
            let offset = (y * 144 + x) * 4
            // ImageIO의 색 공간 변환에서 발생하는 소폭의 채널 값 차이는 허용한다.
            #expect(bytes[offset] < 10 && bytes[offset + 1] > 245 && bytes[offset + 2] < 10)
        }
        #expect(throws: BackgroundImageError.self) {
            try BackgroundImage(url: input).writePNG(to: output, windowSize: CGSize(width: CGFloat(UInt32.max), height: CGFloat(UInt32.max)))
        }
    }
}
