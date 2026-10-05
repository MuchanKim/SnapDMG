import SwiftUI

enum Theme {
    static let canvasBackground = Color(nsColor: .underPageBackgroundColor)
    static let cardBackground = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textAccent = Color.accentColor
    static let accent = Color.accentColor
}

@MainActor
struct EditorControlPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        // Glass 컨트롤이 다른 Glass 표면을 중첩해서 샘플링하지 않도록 일반 배경을 사용한다.
        content
            .background(Theme.cardBackground.opacity(reduceTransparency ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.primary.opacity(0.6), lineWidth: 1)
                }
            }
    }
}
