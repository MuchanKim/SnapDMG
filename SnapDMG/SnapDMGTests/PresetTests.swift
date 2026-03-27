import Testing
import Foundation
@testable import SnapDMG

@Suite("Preset Tests")
struct PresetTests {

    @Test("Classic 프리셋 — 좌우 배치, 수직 중앙")
    func classicPreset() {
        let windowSize = CGSize(width: 540, height: 380)
        let positions = Preset.classic.iconPositions(for: windowSize)

        let w = windowSize.width
        let h = windowSize.height
        #expect(positions.app.x == w / 3.0)
        #expect(positions.applications.x == w * 2.0 / 3.0)
        #expect(positions.app.y == h / 2.0)
        #expect(positions.applications.y == h / 2.0)
    }

    @Test("Centered 프리셋 — 중앙 나란히")
    func centeredPreset() {
        let windowSize = CGSize(width: 540, height: 380)
        let positions = Preset.centered.iconPositions(for: windowSize)

        let centerX = windowSize.width / 2.0
        let centerY = windowSize.height / 2.0
        #expect(positions.app.x == centerX - 80)
        #expect(positions.applications.x == centerX + 80)
        #expect(positions.app.y == centerY)
        #expect(positions.applications.y == centerY)
    }

    @Test("Top-Bottom 프리셋 — 상하 배치")
    func topBottomPreset() {
        let windowSize = CGSize(width: 540, height: 380)
        let positions = Preset.topBottom.iconPositions(for: windowSize)

        let centerX = windowSize.width / 2.0
        let h = windowSize.height
        #expect(positions.app.x == centerX)
        #expect(positions.applications.x == centerX)
        #expect(positions.app.y == h / 3.0)
        #expect(positions.applications.y == h * 2.0 / 3.0)
    }

    @Test("모든 프리셋 나열")
    func allPresets() {
        #expect(Preset.allCases.count == 3)
    }
}
