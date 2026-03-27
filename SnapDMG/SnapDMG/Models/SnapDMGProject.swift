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
}
