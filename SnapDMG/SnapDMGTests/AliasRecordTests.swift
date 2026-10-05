import Testing
import Foundation
import CoreFoundation
@testable import SnapDMG

@Suite("Background Alias Tests")
struct AliasRecordTests {
    @Test("macOS가 배경 참조의 Unicode 파일명을 해석함", arguments: ["background.png", "배경 🌄.png"])
    func readsBackgroundFileName(fileName: String) throws {
        let alias = AliasRecord.build(
            volumeName: "Background Test",
            volumeMountPoint: "/Volumes/Background Test",
            parentDirName: ".background",
            fileName: fileName
        )
        // Finder가 사용하는 기존 Alias Record를 macOS 파서로 검증한다.
        let bookmark = try #require(CFURLCreateBookmarkDataFromAliasRecord(nil, alias as CFData)?.takeRetainedValue())
        let properties = CFURLCreateResourcePropertiesForKeysFromBookmarkData(
            nil, [kCFURLNameKey] as CFArray, bookmark
        ).takeRetainedValue() as NSDictionary
        #expect(properties[kCFURLNameKey] as? String == fileName)
    }
}
