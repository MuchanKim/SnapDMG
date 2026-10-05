import Foundation

enum EditorWindowLayout {
    case standard
    case compact

    static func fitting(screenSize: CGSize) -> Self {
        // 창 프레임과 화면 가장자리 여백을 포함한 기본형의 최소 가용 영역
        let standardSize = Self.standard.windowSize
        if screenSize.width >= standardSize.width + 32,
           screenSize.height >= standardSize.height + 60 {
            return .standard
        }
        return .compact
    }

    var windowSize: CGSize {
        switch self {
        case .standard: CGSize(width: 840, height: 452)
        case .compact: CGSize(width: 720, height: 432)
        }
    }

    var sidebarWidth: CGFloat { self == .standard ? 236 : 220 }
    var collapsedSidebarWidth: CGFloat { 54 }
    var contentPadding: CGFloat { 10 }
    var contentSpacing: CGFloat { 8 }
}
