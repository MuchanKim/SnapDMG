import Testing
import Foundation
@testable import SnapDMG

@Suite("DSStoreWriter Tests")
struct DSStoreWriterTests {

    // MARK: - Helpers

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let slice = data[offset..<offset+4]
        var value: UInt32 = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { dest in
            slice.copyBytes(to: dest)
        }
        return UInt32(bigEndian: value)
    }

    // MARK: - Record Encoding

    @Test("vSrn 레코드 인코딩")
    func encodeVSrnRecord() throws {
        let record = DSStoreRecord.vSrn
        let data = record.encode()

        #expect(data.count == 18)

        #expect(data[0...3] == Data([0x00, 0x00, 0x00, 0x01]))
        #expect(data[4...5] == Data([0x00, 0x2E]))
        #expect(String(data: Data(data[6...9]), encoding: .ascii) == "vSrn")
        #expect(String(data: Data(data[10...13]), encoding: .ascii) == "long")
        #expect(data[14...17] == Data([0x00, 0x00, 0x00, 0x01]))
    }

    @Test("Iloc 레코드 인코딩")
    func encodeIlocRecord() throws {
        let record = DSStoreRecord.iloc(filename: "MyApp.app", x: 140, y: 190)
        let data = record.encode()

        #expect(data.count == 50)

        let blobStart = data.count - 16
        let x = readUInt32(data, at: blobStart)
        let y = readUInt32(data, at: blobStart + 4)
        #expect(x == 140)
        #expect(y == 190)
        #expect(Data(data[blobStart+8..<blobStart+12]) == Data([0xFF, 0xFF, 0xFF, 0xFF]))
        #expect(Data(data[blobStart+12..<blobStart+16]) == Data([0xFF, 0xFF, 0x00, 0x00]))
    }

    @Test("bwsp 레코드 — 유효한 binary plist 포함")
    func encodeBwspRecord() throws {
        let record = DSStoreRecord.bwsp(
            windowBounds: "{{100, 100}, {540, 380}}"
        )
        let data = record.encode()

        #expect(data.count > 18)

        let blobLenStart = 14
        let blobLen = Int(readUInt32(data, at: blobLenStart))
        let blobData = Data(data[(blobLenStart+4)..<(blobLenStart+4+blobLen)])

        let plist = try PropertyListSerialization.propertyList(from: blobData, format: nil)
        let dict = try #require(plist as? [String: Any])
        #expect(dict["WindowBounds"] as? String == "{{100, 100}, {540, 380}}")
        #expect(dict["ShowSidebar"] as? Bool == false)
        #expect(dict["ShowToolbar"] as? Bool == false)
    }

    @Test("icvp 레코드 — 배경 이미지 타입 설정")
    func encodeIcvpRecord() throws {
        let record = DSStoreRecord.icvp(
            iconSize: 128,
            backgroundType: 2,
            backgroundImageAlias: Data([0xDE, 0xAD])
        )
        let data = record.encode()

        let blobLenStart = 14
        let blobLen = Int(readUInt32(data, at: blobLenStart))
        let blobData = Data(data[(blobLenStart+4)..<(blobLenStart+4+blobLen)])

        let plist = try PropertyListSerialization.propertyList(from: blobData, format: nil)
        let dict = try #require(plist as? [String: Any])
        #expect(dict["backgroundType"] as? Int == 2)
        #expect(dict["iconSize"] as? Double == 128.0)
        #expect(dict["backgroundImageAlias"] as? Data == Data([0xDE, 0xAD]))
    }

    // MARK: - Record Sorting

    @Test("레코드 정렬 — 파일명(소문자) → 구조코드 순")
    func recordSorting() {
        let records: [DSStoreRecord] = [
            .iloc(filename: "Applications", x: 400, y: 190),
            .vSrn,
            .bwsp(windowBounds: "{{0,0},{540,380}}"),
            .iloc(filename: "MyApp.app", x: 140, y: 190),
            .icvp(iconSize: 128, backgroundType: 0, backgroundImageAlias: nil),
        ]

        let sorted = records.sorted()

        #expect(sorted[0].sortKey == DSStoreRecord.SortKey(filename: ".", code: "bwsp"))
        #expect(sorted[1].sortKey == DSStoreRecord.SortKey(filename: ".", code: "icvp"))
        #expect(sorted[2].sortKey == DSStoreRecord.SortKey(filename: ".", code: "vSrn"))
        #expect(sorted[3].sortKey == DSStoreRecord.SortKey(filename: "applications", code: "Iloc"))
        #expect(sorted[4].sortKey == DSStoreRecord.SortKey(filename: "myapp.app", code: "Iloc"))
    }

    // MARK: - Full File Assembly

    @Test(".DS_Store 파일 — 매직 헤더 검증")
    func fileHeader() throws {
        let records: [DSStoreRecord] = [
            .vSrn,
            .iloc(filename: "Test.app", x: 100, y: 200),
            .iloc(filename: "Applications", x: 400, y: 200),
        ]

        let fileData = try DSStoreWriter.assemble(records: records)

        #expect(fileData[0...3] == Data([0x00, 0x00, 0x00, 0x01]))
        #expect(String(data: Data(fileData[4...7]), encoding: .ascii) == "Bud1")
    }

    @Test(".DS_Store 파일 — DSDB 슈퍼블록의 레코드 카운트")
    func dsdbRecordCount() throws {
        let records: [DSStoreRecord] = [
            .vSrn,
            .bwsp(windowBounds: "{{0,0},{540,380}}"),
            .iloc(filename: "Test.app", x: 100, y: 200),
        ]

        let fileData = try DSStoreWriter.assemble(records: records)

        let recordCountOffset = 0x0024 + 8
        let recordCount = readUInt32(fileData, at: recordCountOffset)
        #expect(recordCount == 3)
    }

    @Test(".DS_Store 파일 — B-tree 노드의 레코드 카운트")
    func btreeRecordCount() throws {
        let records: [DSStoreRecord] = [
            .vSrn,
            .iloc(filename: "Test.app", x: 100, y: 200),
        ]

        let fileData = try DSStoreWriter.assemble(records: records)

        let btreeStart = 0x1004
        let leafMarker = readUInt32(fileData, at: btreeStart)
        #expect(leafMarker == 0)

        let recordCount = readUInt32(fileData, at: btreeStart + 4)
        #expect(recordCount == 2)
    }

    @Test(".DS_Store 파일을 디스크에 쓰고 읽기")
    func writeAndRead() throws {
        let records: [DSStoreRecord] = [
            .vSrn,
            .bwsp(windowBounds: "{{100, 100}, {540, 380}}"),
            .icvp(iconSize: 128, backgroundType: 0, backgroundImageAlias: nil),
            .iloc(filename: "MyApp.app", x: 140, y: 190),
            .iloc(filename: "Applications", x: 400, y: 190),
        ]

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let filePath = tempDir.appendingPathComponent(".DS_Store")
        try DSStoreWriter.write(records: records, to: filePath)

        let data = try Data(contentsOf: filePath)
        #expect(data.count >= 0x1004 + 4096)
    }

    // MARK: - Integration

    @Test("통합: .DS_Store 파일을 포함한 DMG 생성 및 검증")
    func integrationDMGBuild() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("snapdmg-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // 가짜 .app 디렉토리 생성
        let fakeApp = tempDir.appendingPathComponent("TestApp.app/Contents/MacOS", isDirectory: true)
        try fm.createDirectory(at: fakeApp, withIntermediateDirectories: true)
        try "fake".write(to: fakeApp.appendingPathComponent("TestApp"), atomically: true, encoding: .utf8)

        let outputDMG = tempDir.appendingPathComponent("TestApp.dmg")
        let appPath = tempDir.appendingPathComponent("TestApp.app")

        let builder = DMGBuilder()
        try await builder.build(config: .init(
            appPath: appPath,
            outputPath: outputDMG,
            volumeName: "TestApp",
            windowSize: CGSize(width: 540, height: 380),
            backgroundImagePath: nil,
            iconPositions: IconPositions(
                app: CGPoint(x: 180, y: 190),
                applications: CGPoint(x: 360, y: 190)
            ),
            iconSize: 128
        ))

        // DMG 파일 존재 확인
        #expect(fm.fileExists(atPath: outputDMG.path))

        // DMG 크기가 유효한지 확인 (최소 1KB)
        let attrs = try fm.attributesOfItem(atPath: outputDMG.path)
        let size = attrs[.size] as? Int ?? 0
        #expect(size > 1024)
    }
}
