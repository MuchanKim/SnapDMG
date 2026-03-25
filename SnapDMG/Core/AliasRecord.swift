import Foundation

/// macOS 26 Finder가 생성하는 것과 동일한 최소 Alias Record (v2).
enum AliasRecord {

    static func build(
        volumeName: String,
        volumeMountPoint: String,
        parentDirName: String,
        fileName: String
    ) -> Data {
        var data = Data()

        // === Header (150 bytes) — 대부분 0으로 채움 ===

        data.appendUInt32(0)        // userType
        let sizeOffset = data.count
        data.appendUInt16(0)        // aliasSize (나중에 채움)
        data.appendUInt16(2)        // version = 2
        data.appendUInt16(0)        // kind = file

        // volumeName (1 + 27 bytes)
        let volBytes = Swift.Array(volumeName.utf8.prefix(27))
        data.append(UInt8(volBytes.count))
        data.append(contentsOf: volBytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 27 - volBytes.count))

        data.appendUInt32(0)        // volCreateDate = 0
        data.appendUInt16(0x482B)   // volSignature = H+
        data.appendUInt16(0)        // volType = 0
        data.appendUInt32(2)        // parentDirID = 2 (root)

        // fileName (1 + 63 bytes)
        let fnBytes = Swift.Array(fileName.utf8.prefix(63))
        data.append(UInt8(fnBytes.count))
        data.append(contentsOf: fnBytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 63 - fnBytes.count))

        data.appendUInt32(0)        // fileNumber = 0
        data.appendUInt32(0)        // fileCreateDate = 0
        data.appendUInt32(0)        // fileType = 0
        data.appendUInt32(0)        // fileCreator = 0
        data.appendUInt16(0)        // nlvlFrom = 0
        data.appendUInt16(0)        // nlvlTo = 0
        data.appendUInt32(0)        // volAttrs = 0
        data.appendUInt16(0)        // volFSID = 0
        data.append(contentsOf: [UInt8](repeating: 0, count: 10)) // reserved

        // === Tags — Finder와 동일하게 2개만 ===

        // Tag 0: parent directory name
        let parentBytes = Swift.Array(parentDirName.utf8)
        data.appendUInt16(0)        // tag = 0
        data.appendUInt16(UInt16(parentBytes.count))
        data.append(contentsOf: parentBytes)
        if parentBytes.count % 2 != 0 { data.append(0) }

        // Tag 2: POSIX relative path
        let posixPath = "\(parentDirName)/\(fileName)"
        let pathBytes = Swift.Array(posixPath.utf8)
        data.appendUInt16(2)        // tag = 2
        data.appendUInt16(UInt16(pathBytes.count))
        data.append(contentsOf: pathBytes)
        if pathBytes.count % 2 != 0 { data.append(0) }

        // End marker
        data.appendUInt16(0xFFFF)
        data.appendUInt16(0)

        // === Fill aliasSize ===
        let totalSize = UInt16(data.count)
        var sizeBytes = totalSize.bigEndian
        Swift.withUnsafeBytes(of: &sizeBytes) { buf in
            data[sizeOffset] = buf[0]
            data[sizeOffset + 1] = buf[1]
        }

        return data
    }
}
