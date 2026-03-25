import Foundation

enum WindowSizePreset: String, CaseIterable, Identifiable {
    // 가로형
    case compact
    case standard
    case wide
    // 세로형
    case tall
    case tallLarge

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .compact: CGSize(width: 480, height: 320)
        case .standard: CGSize(width: 540, height: 380)
        case .wide: CGSize(width: 640, height: 400)
        case .tall: CGSize(width: 400, height: 500)
        case .tallLarge: CGSize(width: 480, height: 600)
        }
    }

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .wide: "Wide"
        case .tall: "Tall"
        case .tallLarge: "Tall L"
        }
    }

    var dimensionLabel: String {
        "\(Int(size.width))×\(Int(size.height))"
    }

    var isLandscape: Bool {
        size.width > size.height
    }

    static func matching(_ size: CGSize) -> WindowSizePreset? {
        allCases.first {
            $0.size.width == size.width && $0.size.height == size.height
        }
    }
}
