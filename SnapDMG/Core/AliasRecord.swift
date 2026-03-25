import Foundation

/// Classic Mac Alias Record (v2) 생성기.
/// Finder의 .DS_Store icvp backgroundImageAlias에 사용.
enum AliasRecord {

    /// DMG 볼륨 내 파일에 대한 Alias 레코드를 생성합니다.
    static func build(
        volumeName: String,
        parentDirName: String,
        fileName: String,
        posixPath: String
    ) -> Data {
        var data = Data()

        // === Fixed Header (150 bytes) ===

        // userType (4 bytes)
        data.appendUInt32(0)

        // aliasSize placeholder — 나중에 채움
        let sizeOffset = data.count
        data.appendUInt16(0)

        // version = 2
        data.appendUInt16(2)

        // kind = 0 (file)
        data.appendUInt16(0)

        // volumeName — pascal string (1 byte length + 27 bytes padded)
        let volNameBytes = Array(volumeName.utf8.prefix(27))
        data.append(UInt8(volNameBytes.count))
        data.append(contentsOf: volNameBytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 27 - volNameBytes.count))

        // volumeCreationDate (4 bytes) — dummy
        data.appendUInt32(0)

        // volumeSignature = 'H+' (HFS+)
        data.appendUInt16(0x482B)

        // volumeType = 0 (fixed disk)
        data.appendUInt16(0)

        // parentDirID (4 bytes) — use 2 (root)
        data.appendUInt32(2)

        // fileName — pascal string (1 byte length + 63 bytes padded)
        let fileNameBytes = Array(fileName.utf8.prefix(63))
        data.append(UInt8(fileNameBytes.count))
        data.append(contentsOf: fileNameBytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 63 - fileNameBytes.count))

        // fileNumber (CNID) = 0
        data.appendUInt32(0)

        // fileCreationDate = 0
        data.appendUInt32(0)

        // fileType = 0
        data.appendUInt32(0)

        // fileCreator = 0
        data.appendUInt32(0)

        // nlvlFrom = 0
        data.appendUInt16(0)

        // nlvlTo = 0
        data.appendUInt16(0)

        // volumeAttributes
        data.appendUInt32(0)

        // volumeFSID = 0
        data.appendUInt16(0)

        // reserved (10 bytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 10))

        // === Tagged Extra Data ===

        // Tag 0: parent directory name (UTF-8)
        appendTag(&data, tag: 0, string: parentDirName)

        // Tag 2: full POSIX path relative to volume root
        appendTag(&data, tag: 2, string: posixPath)

        // Tag -1 (0xFFFF): end marker
        data.appendUInt16(0xFFFF)
        data.appendUInt16(0)

        // === Fill in aliasSize ===
        let totalSize = UInt16(data.count)
        var bigEndianSize = totalSize.bigEndian
        let sizeBytes = Swift.withUnsafeBytes(of: &bigEndianSize) { Array($0) }
        data[sizeOffset] = sizeBytes[0]
        data[sizeOffset + 1] = sizeBytes[1]

        return data
    }

    private static func appendTag(_ data: inout Data, tag: UInt16, string: String) {
        let utf8 = Array(string.utf8)
        data.appendUInt16(tag)
        data.appendUInt16(UInt16(utf8.count))
        data.append(contentsOf: utf8)
        // Pad to even length
        if utf8.count % 2 != 0 {
            data.append(0)
        }
    }
}
