import Foundation

enum WindowSizePreset: String, CaseIterable, Identifiable {
    case compact
    case standard
    case wide
    case large

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .compact: CGSize(width: 480, height: 320)
        case .standard: CGSize(width: 540, height: 380)
        case .wide: CGSize(width: 640, height: 400)
        case .large: CGSize(width: 720, height: 480)
        }
    }

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .wide: "Wide"
        case .large: "Large"
        }
    }

    var dimensionLabel: String {
        "\(Int(size.width))×\(Int(size.height))"
    }

    static func matching(_ size: CGSize) -> WindowSizePreset? {
        allCases.first {
            $0.size.width == size.width && $0.size.height == size.height
        }
    }
}
