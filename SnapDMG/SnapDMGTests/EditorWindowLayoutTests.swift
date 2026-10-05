import Testing
import Foundation
@testable import SnapDMG

@MainActor
@Suite("Editor Window Layout Tests")
struct EditorWindowLayoutTests {
    @Test("기본형이 창 프레임과 여백까지 들어가는 화면에서만 선택됨", arguments: [
        (CGSize(width: 1440, height: 900), EditorWindowLayout.standard),
        (CGSize(width: 872, height: 512), EditorWindowLayout.standard),
        (CGSize(width: 871, height: 900), EditorWindowLayout.compact),
        (CGSize(width: 1440, height: 511), EditorWindowLayout.compact),
        (CGSize(width: 1024, height: 576), EditorWindowLayout.standard)
    ])
    func selectsFixedLayout(screenSize: CGSize, expected: EditorWindowLayout) {
        #expect(EditorWindowLayout.fitting(screenSize: screenSize) == expected)
    }
}
