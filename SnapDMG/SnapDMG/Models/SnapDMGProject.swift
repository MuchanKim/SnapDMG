import Foundation

struct IconPositions: Codable, Equatable {
    var app: CGPoint
    var applications: CGPoint
}

struct SnapDMGProject: Codable, Equatable {
    var appName: String
    var windowSize: CGSize
    var backgroundImagePath: String?
    var iconPositions: IconPositions
    var iconSize: Double = 128

    private enum CodingKeys: String, CodingKey {
        case appName, windowSize, backgroundImagePath, iconPositions, iconSize
    }
}

extension SnapDMGProject {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appName = try container.decode(String.self, forKey: .appName)
        windowSize = try container.decode(CGSize.self, forKey: .windowSize)
        backgroundImagePath = try container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        iconPositions = try container.decode(IconPositions.self, forKey: .iconPositions)
        // iconSize 도입 전 저장 파일에만 기본값 적용
        iconSize = container.contains(.iconSize) ? try container.decode(Double.self, forKey: .iconSize) : 128

        guard iconSize.isFinite, (48...256).contains(iconSize) else {
            throw DecodingError.dataCorruptedError(forKey: .iconSize, in: container,
                                                   debugDescription: "Icon size must be between 48 and 256.")
        }
        guard previewLayout.containsWindowSize(windowSize) else {
            throw DecodingError.dataCorruptedError(forKey: .windowSize, in: container,
                                                   debugDescription: "Window size must be within the supported range and fit the icons and labels.")
        }
        for position in [iconPositions.app, iconPositions.applications] {
            guard position.x.isFinite, position.y.isFinite,
                  (0...windowSize.width).contains(position.x),
                  (0...windowSize.height).contains(position.y) else {
                throw DecodingError.dataCorruptedError(forKey: .iconPositions, in: container,
                                                       debugDescription: "Icon positions must be finite and inside the window.")
            }
        }
    }
}
