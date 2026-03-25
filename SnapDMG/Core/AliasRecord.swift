import Foundation

/// Classic Mac Alias Record (v2) 생성기.
/// DropDMG의 802바이트 Alias를 역분석하여 구현.
enum AliasRecord {

    /// DMG 볼륨 내 파일에 대한 Alias 레코드를 생성합니다.
    /// - Parameters:
    ///   - volumeName: DMG 볼륨 이름
    ///   - volumeMountPoint: 마운트 경로 (e.g., "/tmp/.../mount")
    ///   - parentDirName: 상위 디렉토리 이름 (e.g., ".background")
    ///   - fileName: 파일 이름 (e.g., "bg.png")
    static func build(
        volumeName: String,
        volumeMountPoint: String,
        parentDirName: String,
        fileName: String
    ) -> Data {
        let fm = FileManager.default

        // 실제 파일/디렉토리 속성 조회
        let parentPath = "\(volumeMountPoint)/\(parentDirName)"
        let filePath = "\(parentPath)/\(fileName)"

        let parentInode = inodeNumber(atPath: parentPath)
        let fileInode = inodeNumber(atPath: filePath)
        let volCreateDate = creationDateMac(atPath: volumeMountPoint)
        let fileCreateDate = creationDateMac(atPath: filePath)

        var data = Data()

        // === Fixed Header (150 bytes) ===

        // userType (4 bytes)
        data.appendUInt32(0)

        // aliasSize placeholder
        let sizeOffset = data.count
        data.appendUInt16(0)

        // version = 2
        data.appendUInt16(2)

        // kind = 0 (file)
        data.appendUInt16(0)

        // volumeName — pascal string (1 byte length + 27 bytes)
        appendPascalString(&data, string: volumeName, fieldSize: 27)

        // volumeCreationDate
        data.appendUInt32(volCreateDate)

        // volumeSignature = 'H+' (HFS+)
        data.appendUInt16(0x482B)

        // volumeType = 5 (DMG/disk image)
        data.appendUInt16(5)

        // parentDirID (CNID)
        data.appendUInt32(parentInode)

        // fileName — pascal string (1 byte length + 63 bytes)
        appendPascalString(&data, string: fileName, fieldSize: 63)

        // fileNumber (CNID)
        data.appendUInt32(fileInode)

        // fileCreationDate
        data.appendUInt32(fileCreateDate)

        // fileType
        data.appendUInt32(0)

        // fileCreator
        data.appendUInt32(0)

        // nlvlFrom = 0xFFFF (unknown)
        data.appendUInt16(0xFFFF)

        // nlvlTo = 0xFFFF (unknown)
        data.appendUInt16(0xFFFF)

        // volumeAttributes
        data.appendUInt32(0x00000D02)

        // volumeFSID = 0
        data.appendUInt16(0)

        // reserved (10 bytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 10))

        // === Tagged Extra Data ===

        // Tag 0: parent directory name (UTF-8)
        appendTag(&data, tag: 0, utf8String: parentDirName)

        // Tag 16: volume creation date (8 bytes, big-endian)
        appendTag(&data, tag: 16, uint64: UInt64(volCreateDate) << 16)

        // Tag 17: file creation date (8 bytes, big-endian)
        appendTag(&data, tag: 17, uint64: UInt64(fileCreateDate) << 16)

        // Tag 1: parent directory CNID (4 bytes)
        appendTag(&data, tag: 1, uint32: parentInode)

        // Tag 2: HFS path (colon-separated) — VolumeName:parentDir:fileName
        let hfsPath = "\(volumeName):\(parentDirName):\(fileName)"
        appendTag(&data, tag: 2, utf8String: hfsPath)

        // Tag 14: fileName in UTF-16BE
        appendTag(&data, tag: 14, utf16String: fileName)

        // Tag 15: volumeName in UTF-16BE
        appendTag(&data, tag: 15, utf16String: volumeName)

        // Tag 18: POSIX path relative to volume root
        let posixPath = "/\(parentDirName)/\(fileName)"
        appendTag(&data, tag: 18, utf8String: posixPath)

        // Tag 19: volume mount point
        appendTag(&data, tag: 19, utf8String: volumeMountPoint)

        // Tag -1 (0xFFFF): end marker
        data.appendUInt16(0xFFFF)
        data.appendUInt16(0)

        // === Fill in aliasSize ===
        let totalSize = UInt16(data.count)
        var sizeBytes = totalSize.bigEndian
        Swift.withUnsafeBytes(of: &sizeBytes) { buf in
            data[sizeOffset] = buf[0]
            data[sizeOffset + 1] = buf[1]
        }

        return data
    }

    // MARK: - Helpers

    private static func appendPascalString(_ data: inout Data, string: String, fieldSize: Int) {
        let bytes = Array(string.utf8.prefix(fieldSize))
        data.append(UInt8(bytes.count))
        data.append(contentsOf: bytes)
        let padding = fieldSize - bytes.count
        if padding > 0 {
            data.append(contentsOf: [UInt8](repeating: 0, count: padding))
        }
    }

    private static func appendTag(_ data: inout Data, tag: UInt16, utf8String: String) {
        let utf8 = Swift.Array(utf8String.utf8)
        data.appendUInt16(tag)
        data.appendUInt16(UInt16(utf8.count))
        data.append(contentsOf: utf8)
        if utf8.count % 2 != 0 { data.append(0) }
    }

    private static func appendTag(_ data: inout Data, tag: UInt16, utf16String: String) {
        let utf16 = Swift.Array(utf16String.utf16)
        let byteCount = utf16.count * 2
        data.appendUInt16(tag)
        data.appendUInt16(UInt16(byteCount))
        for unit in utf16 {
            data.appendUInt16(unit)
        }
        if byteCount % 2 != 0 { data.append(0) }
    }

    private static func appendTag(_ data: inout Data, tag: UInt16, uint32 value: UInt32) {
        data.appendUInt16(tag)
        data.appendUInt16(4)
        data.appendUInt32(value)
    }

    private static func appendTag(_ data: inout Data, tag: UInt16, uint64 value: UInt64) {
        data.appendUInt16(tag)
        data.appendUInt16(8)
        var be = value.bigEndian
        data.append(contentsOf: Swift.withUnsafeBytes(of: &be) { Array($0) })
    }

    /// 파일의 inode 번호 (HFS+ CNID) 를 가져옵니다.
    private static func inodeNumber(atPath path: String) -> UInt32 {
        var stat = stat()
        if lstat(path, &stat) == 0 {
            return UInt32(stat.st_ino)
        }
        return 0
    }

    /// Mac epoch (1904-01-01) 기준 생성일을 가져옵니다.
    private static func creationDateMac(atPath path: String) -> UInt32 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        guard let date = attrs?[.creationDate] as? Date else { return 0 }
        // Mac epoch: 1904-01-01 00:00:00 UTC
        // Unix epoch: 1970-01-01 00:00:00 UTC
        // Difference: 2082844800 seconds
        let macEpochOffset: TimeInterval = 2082844800
        return UInt32(date.timeIntervalSince1970 + macEpochOffset)
    }
}
