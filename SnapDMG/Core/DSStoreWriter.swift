import Foundation

// MARK: - DSStoreRecord

enum DSStoreRecord: Comparable {

    case vSrn
    case bwsp(windowBounds: String)
    case icvp(iconSize: Double, backgroundType: Int, backgroundImageAlias: Data?)
    case iloc(filename: String, x: UInt32, y: UInt32)

    struct SortKey: Comparable, Equatable {
        let filename: String  // lowercased for comparison
        let code: String

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.filename != rhs.filename {
                return lhs.filename < rhs.filename
            }
            return lhs.code < rhs.code
        }
    }

    var sortKey: SortKey {
        switch self {
        case .vSrn:
            SortKey(filename: ".", code: "vSrn")
        case .bwsp:
            SortKey(filename: ".", code: "bwsp")
        case .icvp:
            SortKey(filename: ".", code: "icvp")
        case .iloc(let filename, _, _):
            SortKey(filename: filename.lowercased(), code: "Iloc")
        }
    }

    static func < (lhs: DSStoreRecord, rhs: DSStoreRecord) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    static func == (lhs: DSStoreRecord, rhs: DSStoreRecord) -> Bool {
        lhs.sortKey == rhs.sortKey
    }

    // MARK: - Encoding

    func encode() -> Data {
        switch self {
        case .vSrn:
            return encodeRecord(filename: ".", code: "vSrn", type: "long") { data in
                data.appendUInt32(1)
            }

        case .bwsp(let windowBounds):
            let plist = bwspPlist(windowBounds: windowBounds)
            return encodeRecord(filename: ".", code: "bwsp", type: "blob") { data in
                let plistData = try! PropertyListSerialization.data(
                    fromPropertyList: plist, format: .binary, options: 0
                )
                data.appendUInt32(UInt32(plistData.count))
                data.append(plistData)
            }

        case .icvp(let iconSize, let backgroundType, let backgroundImageAlias):
            let plist = icvpPlist(
                iconSize: iconSize,
                backgroundType: backgroundType,
                backgroundImageAlias: backgroundImageAlias
            )
            return encodeRecord(filename: ".", code: "icvp", type: "blob") { data in
                let plistData = try! PropertyListSerialization.data(
                    fromPropertyList: plist, format: .binary, options: 0
                )
                data.appendUInt32(UInt32(plistData.count))
                data.append(plistData)
            }

        case .iloc(let filename, let x, let y):
            return encodeRecord(filename: filename, code: "Iloc", type: "blob") { data in
                data.appendUInt32(16) // blob length
                data.appendUInt32(x)
                data.appendUInt32(y)
                data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF] as [UInt8])
                data.append(contentsOf: [0xFF, 0xFF, 0x00, 0x00] as [UInt8])
            }
        }
    }

    private func encodeRecord(
        filename: String,
        code: String,
        type: String,
        valueWriter: (inout Data) -> Void
    ) -> Data {
        var data = Data()

        // Filename in UTF-16BE
        let utf16 = Array(filename.utf16)
        data.appendUInt32(UInt32(utf16.count))
        for unit in utf16 {
            data.appendUInt16(unit)
        }

        // Structure code (4 bytes ASCII)
        data.append(code.data(using: .ascii)!)

        // Data type (4 bytes ASCII)
        data.append(type.data(using: .ascii)!)

        // Value
        valueWriter(&data)

        return data
    }

    private func bwspPlist(windowBounds: String) -> [String: Any] {
        [
            "WindowBounds": windowBounds,
            "ShowSidebar": false,
            "ContainerShowSidebar": false,
            "ShowStatusBar": false,
            "ShowPathbar": false,
            "ShowToolbar": false,
            "ShowTabView": false,
            "SidebarWidth": 0,
        ]
    }

    private func icvpPlist(
        iconSize: Double,
        backgroundType: Int,
        backgroundImageAlias: Data?
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "viewOptionsVersion": 1,
            "backgroundType": backgroundType,
            "backgroundColorRed": 1.0,
            "backgroundColorGreen": 1.0,
            "backgroundColorBlue": 1.0,
            "gridOffsetX": 0.0,
            "gridOffsetY": 0.0,
            "gridSpacing": 100.0,
            "iconSize": iconSize,
            "textSize": 12.0,
            "labelOnBottom": true,
            "showIconPreview": true,
            "showItemInfo": false,
            "arrangeBy": "none",
        ]
        if let alias = backgroundImageAlias {
            dict["backgroundImageAlias"] = alias
        }
        return dict
    }
}

// MARK: - DSStoreWriter

enum DSStoreWriter {

    static func assemble(records: [DSStoreRecord]) throws -> Data {
        let sorted = records.sorted()
        var file = Data()

        // === 1. File magic prefix ===
        file.appendUInt32(0x00000001)

        // === 2. Buddy header (32 bytes at file offset 0x0004) ===
        file.append("Bud1".data(using: .ascii)!)
        file.appendUInt32(0x0800)   // root block buddy offset
        file.appendUInt32(0x0800)   // root block size
        file.appendUInt32(0x0800)   // root block buddy offset (copy)
        // unknown1: 16 bytes
        file.appendUInt32(0x0000100C)
        file.append(contentsOf: [UInt8](repeating: 0, count: 12))

        // === 3. DSDB super block (20 bytes at file offset 0x0024) ===
        file.appendUInt32(2)                        // root_node = block[2]
        file.appendUInt32(0)                        // levels = 0 (leaf only)
        file.appendUInt32(UInt32(sorted.count))     // record count
        file.appendUInt32(1)                        // node count
        file.appendUInt32(0x1000)                   // page_size = 4096

        // === 4. Padding to root block (file offset 0x0804) ===
        let paddingToRoot = 0x0804 - file.count
        file.append(contentsOf: [UInt8](repeating: 0, count: paddingToRoot))

        // === 5. Buddy root block (at file offset 0x0804) ===
        file.appendUInt32(3)        // num_blocks
        file.appendUInt32(0)        // unknown2

        // Block address array: [root_block, dsdb, btree_node]
        file.appendUInt32(0x0000_080B)  // block[0]: root block at 0x0800, width=11 (2048)
        file.appendUInt32(0x0000_0025)  // block[1]: DSDB at 0x0020, width=5 (32)
        file.appendUInt32(0x0000_100C)  // block[2]: B-tree at 0x1000, width=12 (4096)
        // Pad to 256 entries
        file.append(contentsOf: [UInt8](repeating: 0, count: (256 - 3) * 4))

        // TOC: 1 entry "DSDB" -> block[1]
        file.appendUInt32(1)
        file.append(UInt8(4))
        file.append("DSDB".data(using: .ascii)!)
        file.appendUInt32(1)

        // Free lists (32 entries)
        for width in 0..<32 {
            switch width {
            case 0, 1, 2, 3, 4, 5, 11, 12, 31:
                file.appendUInt32(0)    // no free blocks
            default:
                file.appendUInt32(1)    // one free block
                file.appendUInt32(UInt32(1 << width))
            }
        }

        // === 6. Padding to B-tree node (file offset 0x1004) ===
        let paddingToBTree = 0x1004 - file.count
        if paddingToBTree > 0 {
            file.append(contentsOf: [UInt8](repeating: 0, count: paddingToBTree))
        }

        // === 7. B-tree leaf node (4096 bytes at file offset 0x1004) ===
        let btreeStart = file.count
        file.appendUInt32(0)                        // next_node = 0 (leaf)
        file.appendUInt32(UInt32(sorted.count))     // record count

        for record in sorted {
            file.append(record.encode())
        }

        // Pad to page_size
        let btreeUsed = file.count - btreeStart
        if btreeUsed < 4096 {
            file.append(contentsOf: [UInt8](repeating: 0, count: 4096 - btreeUsed))
        }

        return file
    }

    static func write(records: [DSStoreRecord], to url: URL) throws {
        let data = try assemble(records: records)
        try data.write(to: url)
    }
}

// MARK: - Data Helpers

extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &bigEndian) { Array($0) })
    }

    mutating func appendUInt16(_ value: UInt16) {
        var bigEndian = value.bigEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &bigEndian) { Array($0) })
    }
}
