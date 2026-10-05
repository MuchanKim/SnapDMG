import Testing
import Foundation
@testable import SnapDMG

@MainActor
@Suite("Project Loading Tests", .bug("https://github.com/MuchanKim/SnapDMG/issues/3"))
struct ProjectLoadingTests {
    @Test("iconSize 없는 기존 파일은 128로 열고 기존 좌표를 유지")
    func loadsLegacyProject() throws {
        let data = ProjectJSON.data(iconSize: nil, appX: "32", appY: "32")
        let project = try JSONDecoder().decode(SnapDMGProject.self, from: data)

        #expect(project.iconSize == 128)
        #expect(project.iconPositions.app == CGPoint(x: 32, y: 32))
        #expect(project.appName == "OtherApp")
    }

    @Test("지원하는 아이콘 크기와 프로젝트 내용은 저장 후 동일하게 복원", arguments: [48.0, 96.0, 128.0, 256.0])
    func preservesProjectOnRoundTrip(iconSize: Double) throws {
        let project = SnapDMGProject(
            appName: "테스트 앱",
            windowSize: CGSize(width: 540, height: 380),
            backgroundImagePath: "/tmp/배경.png",
            iconPositions: IconPositions(app: CGPoint(x: 180, y: 190), applications: CGPoint(x: 360, y: 190)),
            iconSize: iconSize
        )
        let data = try JSONEncoder().encode(project)
        let loaded = try JSONDecoder().decode(SnapDMGProject.self, from: data)

        #expect(loaded == project)
    }

    @Test("범위를 벗어난 아이콘 크기는 기본값으로 대체하지 않고 거부", arguments: ["0", "-1", "47", "257", "1e100"])
    func rejectsInvalidIconSize(iconSize: String) {
        let data = ProjectJSON.data(iconSize: iconSize)
        do {
            _ = try JSONDecoder().decode(SnapDMGProject.self, from: data)
            Issue.record("Invalid icon size was accepted.")
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.last?.stringValue == "iconSize")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("iconSize null은 누락된 키로 취급하지 않음")
    func rejectsNullIconSize() {
        do {
            _ = try JSONDecoder().decode(SnapDMGProject.self, from: ProjectJSON.data(iconSize: "null"))
            Issue.record("Null icon size was accepted.")
        } catch DecodingError.valueNotFound(_, let context) {
            #expect(context.codingPath.last?.stringValue == "iconSize")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("유효하지 않은 창 크기는 로딩 경계에서 거부", arguments: [
        ("0", "380"), ("-1", "380"), ("143", "380"), ("540", "0"),
        ("540", "-1"), ("540", "128"), ("4294967296", "380"), ("540", "4294967296")
    ])
    func rejectsInvalidWindowSize(width: String, height: String) {
        let data = ProjectJSON.data(width: width, height: height)
        do {
            _ = try JSONDecoder().decode(SnapDMGProject.self, from: data)
            Issue.record("Invalid window size was accepted.")
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.last?.stringValue == "windowSize")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("두 아이콘의 각 축이 창을 벗어나면 거부", arguments: [
        ("-1", "190", "360", "190"), ("541", "190", "360", "190"),
        ("180", "-1", "360", "190"), ("180", "381", "360", "190"),
        ("180", "190", "-1", "190"), ("180", "190", "541", "190"),
        ("180", "190", "360", "-1"), ("180", "190", "360", "381")
    ])
    func rejectsInvalidPosition(appX: String, appY: String, applicationsX: String, applicationsY: String) {
        let data = ProjectJSON.data(appX: appX, appY: appY, applicationsX: applicationsX, applicationsY: applicationsY)
        do {
            _ = try JSONDecoder().decode(SnapDMGProject.self, from: data)
            Issue.record("Invalid icon position was accepted.")
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.last?.stringValue == "iconPositions")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("유한하지 않은 숫자를 표현한 외부 JSON은 거부", arguments: [
        ProjectJSON.data(iconSize: "1e400"), ProjectJSON.data(width: "1e400"),
        ProjectJSON.data(height: "1e400"), ProjectJSON.data(appX: "1e400"),
        ProjectJSON.data(applicationsY: "1e400")
    ])
    func rejectsNonFiniteJSON(data: Data) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SnapDMGProject.self, from: data)
        }
    }
}
