import Foundation

/// DropDMG의 802바이트 Alias를 참고한 풀 포맷 Alias Record (v2).
enum AliasRecord {

    static func build(
        volumeName: String,
        volumeMountPoint: String,
        parentDirName: String,
        fileName: String
    ) -> Data {
        let parentPath = "\(volumeMountPoint)/\(parentDirName)"
        let filePath = "\(parentPath)/\(fileName)"

        let parentInode = inodeNumber(atPath: parentPath)
        let fileInode = inodeNumber(atPath: filePath)
        let volCreateDate = creationDateMac(atPath: volumeMountPoint)
        let fileCreateDate = creationDateMac(atPath: filePath)

        var data = Data()

        // === Header (150 bytes) ===
        data.appendUInt32(0)            // userType
        let sizeOffset = data.count
        data.appendUInt16(0)            // aliasSize (나중에)
        data.appendUInt16(2)            // version
        data.appendUInt16(0)            // kind = file

        // volumeName (1+27)
        appendPascal(&data, volumeName, 27)

        data.appendUInt32(volCreateDate)
        data.appendUInt16(0x482B)       // H+
        data.appendUInt16(5)            // volType = 5 (disk image)
        data.appendUInt32(parentInode)   // parentDirID (실제 CNID)

        // fileName (1+63)
        appendPascal(&data, fileName, 63)

        data.appendUInt32(fileInode)     // fileNumber (실제 CNID)
        data.appendUInt32(fileCreateDate)
        data.appendUInt32(0)            // fileType
        data.appendUInt32(0)            // fileCreator
        data.appendUInt16(0xFFFF)       // nlvlFrom
        data.appendUInt16(0xFFFF)       // nlvlTo
        data.appendUInt32(0x00000D02)   // volAttrs
        data.appendUInt16(0)            // volFSID
        data.append(contentsOf: [UInt8](repeating: 0, count: 10))

        // === Tags — DropDMG와 동일한 구조 ===

        // Tag 0: parent dir name (UTF-8)
        appendTagUTF8(&data, tag: 0, string: parentDirName)

        // Tag 16: volume creation date (8 bytes)
        appendTagUInt64(&data, tag: 16, value: UInt64(volCreateDate) << 16)

        // Tag 17: file creation date (8 bytes)
        appendTagUInt64(&data, tag: 17, value: UInt64(fileCreateDate) << 16)

        // Tag 1: parent dir CNID (4 bytes)
        appendTagUInt32(&data, tag: 1, value: parentInode)

        // Tag 2: HFS path (콜론 구분)
        let hfsPath = "\(volumeName):\(parentDirName):\(fileName)"
        appendTagUTF8(&data, tag: 2, string: hfsPath)

        // Tag 14: fileName UTF-16BE
        appendTagUTF16(&data, tag: 14, string: fileName)

        // Tag 15: volumeName UTF-16BE
        appendTagUTF16(&data, tag: 15, string: volumeName)

        // Tag 18: POSIX path (volume root 기준)
        appendTagUTF8(&data, tag: 18, string: "/\(parentDirName)/\(fileName)")

        // Tag 19: volume mount point
        appendTagUTF8(&data, tag: 19, string: volumeMountPoint)

        // End marker
        data.appendUInt16(0xFFFF)
        data.appendUInt16(0)

        // Fill aliasSize
        let totalSize = UInt16(data.count)
        var sizeBytes = totalSize.bigEndian
        Swift.withUnsafeBytes(of: &sizeBytes) { buf in
            data[sizeOffset] = buf[0]
            data[sizeOffset + 1] = buf[1]
        }

        return data
    }

    // MARK: - Helpers

    private static func appendPascal(_ data: inout Data, _ string: String, _ fieldSize: Int) {
        let bytes = Swift.Array(string.utf8.prefix(fieldSize))
        data.append(UInt8(bytes.count))
        data.append(contentsOf: bytes)
        if fieldSize > bytes.count {
            data.append(contentsOf: [UInt8](repeating: 0, count: fieldSize - bytes.count))
        }
    }

    private static func appendTagUTF8(_ data: inout Data, tag: UInt16, string: String) {
        let bytes = Swift.Array(string.utf8)
        data.appendUInt16(tag)
        data.appendUInt16(UInt16(bytes.count))
        data.append(contentsOf: bytes)
        if bytes.count % 2 != 0 { data.append(0) }
    }

    private static func appendTagUTF16(_ data: inout Data, tag: UInt16, string: String) {
        let units = Swift.Array(string.utf16)
        data.appendUInt16(tag)
        data.appendUInt16(UInt16(units.count * 2))
        for u in units { data.appendUInt16(u) }
    }

    private static func appendTagUInt32(_ data: inout Data, tag: UInt16, value: UInt32) {
        data.appendUInt16(tag)
        data.appendUInt16(4)
        data.appendUInt32(value)
    }

    private static func appendTagUInt64(_ data: inout Data, tag: UInt16, value: UInt64) {
        data.appendUInt16(tag)
        data.appendUInt16(8)
        var be = value.bigEndian
        data.append(contentsOf: Swift.withUnsafeBytes(of: &be) { Swift.Array($0) })
    }

    private static func inodeNumber(atPath path: String) -> UInt32 {
        var s = stat()
        if lstat(path, &s) == 0 { return UInt32(s.st_ino) }
        return 0
    }

    private static func creationDateMac(atPath path: String) -> UInt32 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        guard let date = attrs?[.creationDate] as? Date else { return 0 }
        return UInt32(date.timeIntervalSince1970 + 2082844800)
    }
}
