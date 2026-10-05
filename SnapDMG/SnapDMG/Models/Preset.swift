import Foundation

enum Preset: String, CaseIterable, Identifiable {
    case classic
    case centered
    case topBottom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .centered: "Centered"
        case .topBottom: "Top-Bottom"
        }
    }

    var description: String {
        switch self {
        case .classic: "Horizontal layout (standard)"
        case .centered: "Centered layout"
        case .topBottom: "Vertical layout (Raycast style)"
        }
    }

    func iconPositions(for windowSize: CGSize) -> IconPositions {
        let w = windowSize.width
        let h = windowSize.height

        switch self {
        case .classic:
            return IconPositions(
                app: CGPoint(x: w / 3.0, y: h / 2.0),
                applications: CGPoint(x: w * 2.0 / 3.0, y: h / 2.0)
            )
        case .centered:
            let centerX = w / 2.0
            return IconPositions(
                app: CGPoint(x: centerX - 80, y: h / 2.0),
                applications: CGPoint(x: centerX + 80, y: h / 2.0)
            )
        case .topBottom:
            let centerX = w / 2.0
            return IconPositions(
                app: CGPoint(x: centerX, y: h / 3.0),
                applications: CGPoint(x: centerX, y: h * 2.0 / 3.0)
            )
        }
    }
}
