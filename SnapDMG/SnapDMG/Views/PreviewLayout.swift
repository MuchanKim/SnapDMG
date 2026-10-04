import AppKit

struct PreviewLayout {
    static let textSize: CGFloat = 12
    static let labelSpacing: CGFloat = 4
    static let labelHeight = ceil(NSFont.systemFont(ofSize: textSize).ascender
        - NSFont.systemFont(ofSize: textSize).descender
        + NSFont.systemFont(ofSize: textSize).leading)
    static let edgePadding: CGFloat = 8
    static let canvasPadding: CGFloat = 24

    let windowSize: CGSize
    let iconSize: CGFloat

    var captionHeight: CGFloat { Self.labelSpacing + Self.labelHeight }

    var minimumWindowSize: CGSize {
        CGSize(width: iconSize + Self.edgePadding * 2,
               height: iconSize + captionHeight + Self.edgePadding * 2)
    }

    func scale(in availableSize: CGSize) -> CGFloat {
        guard windowSize.width > 0, windowSize.height > 0 else { return 0 }
        let width = max(0, availableSize.width - Self.canvasPadding * 2)
        let height = max(0, availableSize.height - Self.canvasPadding * 2)
        return min(width / windowSize.width, height / windowSize.height, 1)
    }

    func containsWindowSize(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite
            && size.width >= minimumWindowSize.width
            && size.height >= minimumWindowSize.height
            && size.width <= CGFloat(UInt32.max)
            && size.height <= CGFloat(UInt32.max)
    }

    func labelWidth(for label: String) -> CGFloat {
        let textWidth = (label as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: Self.textSize)
        ]).width
        return max(iconSize, min(ceil(textWidth), windowSize.width - Self.edgePadding * 2))
    }

    // Iloc 좌표는 라벨을 제외한 아이콘 이미지의 중심이다.
    func clampedPosition(_ position: CGPoint, label: String) -> CGPoint {
        let halfWidth = labelWidth(for: label) / 2
        let minX = halfWidth + Self.edgePadding
        let maxX = windowSize.width - halfWidth - Self.edgePadding
        let minY = iconSize / 2 + Self.edgePadding
        let maxY = windowSize.height - iconSize / 2 - captionHeight - Self.edgePadding
        return CGPoint(
            x: max(minX, min(maxX, position.x)),
            y: max(minY, min(maxY, position.y))
        )
    }
}

extension SnapDMGProject {
    var previewLayout: PreviewLayout {
        PreviewLayout(windowSize: windowSize, iconSize: iconSize)
    }

    var previewAppName: String { appName.isEmpty ? "App" : appName }

    mutating func clampIconPositions() {
        iconPositions.app = previewLayout.clampedPosition(iconPositions.app, label: previewAppName)
        iconPositions.applications = previewLayout.clampedPosition(iconPositions.applications, label: "Applications")
    }
}
