import Testing
import AppKit
@testable import SnapDMG

@MainActor
@Suite("Preview Layout Tests")
struct PreviewLayoutTests {
    @Test("좁은 가용 영역 안에 같은 배율로 창과 아이콘 배치")
    func fitsAvailableSpace() {
        let layout = PreviewLayout(windowSize: CGSize(width: 540, height: 380), iconSize: 128)
        let scale = layout.scale(in: CGSize(width: 319, height: 320))
        #expect(abs(540 * scale - 271) < 0.001)
        #expect(380 * scale <= 272)
        #expect(abs((128 * scale) / (540 * scale) - 128.0 / 540) < 0.001)
    }

    @Test("Tall L은 높이에 맞춰 축소하고 넓은 화면에서도 원본보다 확대하지 않음")
    func portraitScale() {
        let layout = PreviewLayout(windowSize: CGSize(width: 480, height: 600), iconSize: 128)
        #expect(layout.scale(in: CGSize(width: 528, height: 448)) == 2.0 / 3)
        #expect(layout.scale(in: CGSize(width: 1000, height: 1000)) == 1)
        #expect(layout.scale(in: .zero) == 0)
    }

    @Test("아이콘 크기별 이미지와 라벨이 창 경계 안에 유지됨", arguments: [48.0, 128.0, 256.0])
    func clampsEntireItem(iconSize: Double) {
        let layout = PreviewLayout(windowSize: CGSize(width: 540, height: 380), iconSize: iconSize)
        let topLeft = layout.clampedPosition(CGPoint(x: -100, y: -100), label: "Applications")
        let bottomRight = layout.clampedPosition(CGPoint(x: 1000, y: 1000), label: "Applications")
        #expect(topLeft.x - iconSize / 2 >= 8)
        #expect(topLeft.y - iconSize / 2 == 8)
        #expect(bottomRight.x + layout.labelWidth(for: "Applications") / 2 <= 532)
        #expect(bottomRight.y + iconSize / 2 + layout.captionHeight == 372)
    }

    @Test("긴 라벨은 창 폭 안에 제한하고 중앙에 배치")
    func longLabelBounds() {
        let layout = PreviewLayout(windowSize: CGSize(width: 540, height: 380), iconSize: 48)
        let label = String(repeating: "Long app name ", count: 20)
        #expect(layout.labelWidth(for: label) == 524)
        #expect(layout.clampedPosition(CGPoint(x: 20, y: 190), label: label).x == 270)
    }

    @Test("창 크기는 아이콘과 라벨이 들어가는 유한 범위여야 함")
    func validatesDimensions() {
        let layout = PreviewLayout(windowSize: CGSize(width: 540, height: 380), iconSize: 128)
        #expect(layout.containsWindowSize(CGSize(width: 540, height: 380)))
        #expect(layout.containsWindowSize(layout.minimumWindowSize))
        for size in [CGSize(width: 0, height: 380), CGSize(width: -1, height: 380),
                     CGSize(width: 540, height: 128), CGSize(width: CGFloat.infinity, height: 380),
                     CGSize(width: CGFloat.nan, height: 380), CGSize(width: 1e100, height: 380)] {
            #expect(!layout.containsWindowSize(size))
        }
    }

    @Test("아이콘 확대 후 두 아이콘의 위치를 보정")
    func reclampsAfterIconResize() {
        var project = SnapDMGProject(appName: "App", windowSize: CGSize(width: 540, height: 380),
                                     backgroundImagePath: nil,
                                     iconPositions: IconPositions(app: CGPoint(x: 32, y: 32),
                                                                  applications: CGPoint(x: 508, y: 348)))
        project.iconSize = 256
        project.clampIconPositions()
        #expect(project.iconPositions.app == CGPoint(x: 136, y: 136))
        #expect(project.iconPositions.applications.x == 404)
        #expect(project.iconPositions.applications.y < 244)
    }

    @Test("Compact에서 최대 아이콘과 모든 배치 프리셋의 경계를 보정", arguments: Preset.allCases)
    func clampsPresetsInCompactWindow(preset: Preset) {
        var project = SnapDMGProject(appName: "App", windowSize: CGSize(width: 480, height: 320),
                                     backgroundImagePath: nil,
                                     iconPositions: preset.iconPositions(for: CGSize(width: 480, height: 320)),
                                     iconSize: 256)
        project.clampIconPositions()
        for position in [project.iconPositions.app, project.iconPositions.applications] {
            #expect((136...344).contains(position.x))
            #expect(position.y >= 136)
            #expect(position.y + 128 + project.previewLayout.captionHeight <= 312)
        }
    }

    @Test("창을 줄인 뒤 두 아이콘이 새 영역 안으로 이동")
    func reclampsAfterWindowResize() {
        var project = SnapDMGProject(appName: "App", windowSize: CGSize(width: 640, height: 600),
                                     backgroundImagePath: nil,
                                     iconPositions: IconPositions(app: CGPoint(x: 72, y: 72),
                                                                  applications: CGPoint(x: 560, y: 500)))
        project.windowSize = CGSize(width: 320, height: 240)
        project.clampIconPositions()
        #expect(project.iconPositions.app == CGPoint(x: 72, y: 72))
        #expect(project.iconPositions.applications.x == 248)
        #expect(project.iconPositions.applications.y + 64 + project.previewLayout.captionHeight == 232)
    }
}
