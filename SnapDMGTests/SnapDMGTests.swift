import Testing
import Foundation
@testable import SnapDMG

@Suite("SnapDMGProject Tests")
struct SnapDMGProjectTests {

    @Test("JSON 인코딩/디코딩 라운드트립")
    func jsonRoundTrip() throws {
        let project = SnapDMGProject(
            appName: "MyApp",
            windowSize: CGSize(width: 540, height: 380),
            backgroundImagePath: "background.png",
            iconPositions: IconPositions(
                app: CGPoint(x: 140, y: 190),
                applications: CGPoint(x: 400, y: 190)
            )
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(SnapDMGProject.self, from: data)

        #expect(decoded.appName == "MyApp")
        #expect(decoded.windowSize.width == 540)
        #expect(decoded.windowSize.height == 380)
        #expect(decoded.backgroundImagePath == "background.png")
        #expect(decoded.iconPositions.app.x == 140)
        #expect(decoded.iconPositions.app.y == 190)
        #expect(decoded.iconPositions.applications.x == 400)
        #expect(decoded.iconPositions.applications.y == 190)
    }

    @Test("배경 이미지 없는 프로젝트")
    func noBackground() throws {
        let project = SnapDMGProject(
            appName: "TestApp",
            windowSize: CGSize(width: 600, height: 400),
            backgroundImagePath: nil,
            iconPositions: IconPositions(
                app: CGPoint(x: 150, y: 200),
                applications: CGPoint(x: 450, y: 200)
            )
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(SnapDMGProject.self, from: data)

        #expect(decoded.backgroundImagePath == nil)
    }
}
