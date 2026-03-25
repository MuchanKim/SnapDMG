import Foundation

// MARK: - DSStoreRecord

enum DSStoreRecord: Comparable {

    case vSrn
    case bwsp(windowBounds: String)
    case icvl
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
        case .icvl:
            SortKey(filename: ".", code: "icvl")
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

        case .icvl:
            return encodeRecord(filename: ".", code: "icvl", type: "type") { data in
                data.append("icnv".data(using: .ascii)!)
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
            "PreviewPaneVisibility": false,
        ]
    }

    private func icvpPlist(
        iconSize: Double,
        backgroundType: Int,
        backgroundImageAlias: Data?
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "viewOptionsVersion": 0,
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

    /// DropDMG의 .DS_Store 레이아웃을 정확히 따르는 구현.
    ///
    /// Layout (DropDMG 기준):
    /// - 0x0000: File magic (4 bytes)
    /// - 0x0004: Bud1 header (20 bytes)
    /// - 0x0018: padding zeros
    /// - 0x0044: DSDB block (20 bytes, buddy offset 0x40, width=5)
    /// - 0x1004: B-tree leaf node (4096 bytes, buddy offset 0x1000, width=12)
    /// - 0x2004: Root block (2048 bytes, buddy offset 0x2000, width=11)
    static func assemble(records: [DSStoreRecord]) throws -> Data {
        let sorted = records.sorted()

        // Total file size: 0x2004 + 2048 = 0x2804 = 10244 bytes
        var file = Data(count: 0x2804)

        var pos = 0

        func write(_ data: Data, at offset: Int) {
            for (i, byte) in data.enumerated() {
                file[offset + i] = byte
            }
        }

        func writeUInt32(_ value: UInt32, at offset: Int) {
            var be = value.bigEndian
            let bytes = Swift.withUnsafeBytes(of: &be) { Array($0) }
            for (i, b) in bytes.enumerated() {
                file[offset + i] = b
            }
        }

        func writeUInt16(_ value: UInt16, at offset: Int) {
            var be = value.bigEndian
            let bytes = Swift.withUnsafeBytes(of: &be) { Array($0) }
            file[offset] = bytes[0]
            file[offset + 1] = bytes[1]
        }

        // === 1. File magic ===
        writeUInt32(0x00000001, at: 0x0000)

        // === 2. Bud1 header (file offset 0x0004) ===
        write("Bud1".data(using: .ascii)!, at: 0x0004)
        writeUInt32(0x2000, at: 0x0008)  // root block buddy offset
        writeUInt32(0x0800, at: 0x000C)  // root block size (2048)
        writeUInt32(0x2000, at: 0x0010)  // root block buddy offset (copy)
        writeUInt32(0x100C, at: 0x0014)  // unknown (matches DropDMG)

        // === 3. DSDB (file offset 0x0044, buddy offset 0x40) ===
        writeUInt32(2, at: 0x0044)                        // root_node = block[2]
        writeUInt32(0, at: 0x0048)                        // levels = 0
        writeUInt32(UInt32(sorted.count), at: 0x004C)     // record count
        writeUInt32(1, at: 0x0050)                        // node count
        writeUInt32(0x1000, at: 0x0054)                   // page_size = 4096

        // === 4. B-tree leaf node (file offset 0x1004, buddy offset 0x1000) ===
        var btreeData = Data()
        btreeData.appendUInt32(0)                        // next_node = 0 (leaf)
        btreeData.appendUInt32(UInt32(sorted.count))     // record count
        for record in sorted {
            btreeData.append(record.encode())
        }
        // Pad to 4096
        if btreeData.count < 4096 {
            btreeData.append(contentsOf: [UInt8](repeating: 0, count: 4096 - btreeData.count))
        }
        write(btreeData, at: 0x1004)

        // === 5. Root block (file offset 0x2004, buddy offset 0x2000) ===
        let rootBlockStart = 0x2004

        // num_blocks, unknown
        writeUInt32(3, at: rootBlockStart)
        writeUInt32(0, at: rootBlockStart + 4)

        // Block addresses (256 entries, only first 3 used)
        writeUInt32(0x0000_200B, at: rootBlockStart + 8)   // block[0]: root at 0x2000, width=11
        writeUInt32(0x0000_0045, at: rootBlockStart + 12)  // block[1]: DSDB at 0x40, width=5
        writeUInt32(0x0000_100C, at: rootBlockStart + 16)  // block[2]: B-tree at 0x1000, width=12
        // Rest of 256 entries are already zero

        // TOC (after 256 * 4 = 1024 bytes of block addresses)
        let tocOffset = rootBlockStart + 8 + 256 * 4
        writeUInt32(1, at: tocOffset)           // 1 TOC entry
        file[tocOffset + 4] = 4                 // name length = 4
        write("DSDB".data(using: .ascii)!, at: tocOffset + 5)
        writeUInt32(1, at: tocOffset + 9)       // -> block[1]

        // Free lists (after TOC)
        // Match DropDMG's free list structure
        var flOffset = tocOffset + 13
        for width in 0..<32 {
            switch width {
            case 5:
                // Two free 32-byte blocks at 0x20 and 0x60
                writeUInt32(2, at: flOffset)
                writeUInt32(0x20, at: flOffset + 4)
                writeUInt32(0x60, at: flOffset + 8)
                flOffset += 12
            case 7:
                writeUInt32(1, at: flOffset)
                writeUInt32(0x80, at: flOffset + 4)
                flOffset += 8
            case 8:
                writeUInt32(1, at: flOffset)
                writeUInt32(0x100, at: flOffset + 4)
                flOffset += 8
            case 9:
                writeUInt32(1, at: flOffset)
                writeUInt32(0x200, at: flOffset + 4)
                flOffset += 8
            case 10:
                writeUInt32(1, at: flOffset)
                writeUInt32(0x400, at: flOffset + 4)
                flOffset += 8
            case 11:
                writeUInt32(2, at: flOffset)
                writeUInt32(0x800, at: flOffset + 4)
                writeUInt32(0x2800, at: flOffset + 8)
                flOffset += 12
            default:
                writeUInt32(0, at: flOffset)
                flOffset += 4
            }
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
