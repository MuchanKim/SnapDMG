import Foundation

enum DMGBuilderError: LocalizedError {
    case appNotFound(String)
    case backgroundImageNotFound(String)
    case hdiutilFailed(String)
    case buildFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let path):
            "App not found: \(path)"
        case .backgroundImageNotFound(let path):
            "Background image not found: \(path)"
        case .hdiutilFailed(let message):
            "hdiutil failed: \(message)"
        case .buildFailed(let message):
            "Build failed: \(message)"
        }
    }
}

final class DMGBuilder {

    struct BuildConfig {
        let appPath: URL
        let outputPath: URL
        let volumeName: String
        let windowSize: CGSize
        let backgroundImagePath: URL?
        let iconPositions: IconPositions
        let iconSize: Double
    }

    var onProgress: ((String) -> Void)?

    func build(config: BuildConfig) async throws {
        let fm = FileManager.default

        guard fm.fileExists(atPath: config.appPath.path) else {
            throw DMGBuilderError.appNotFound(config.appPath.path)
        }
        if let bgPath = config.backgroundImagePath {
            guard fm.fileExists(atPath: bgPath.path) else {
                throw DMGBuilderError.backgroundImageNotFound(bgPath.path)
            }
        }

        let tempDir = fm.temporaryDirectory.appendingPathComponent("snapdmg-\(UUID().uuidString)")
        let tempDMG = tempDir.appendingPathComponent("temp.dmg")
        let mountPoint = tempDir.appendingPathComponent("mount")

        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            let appSize = try directorySize(at: config.appPath)
            let bgSize = config.backgroundImagePath.flatMap { try? Data(contentsOf: $0).count } ?? 0
            let totalSize = appSize + bgSize + 10_000_000
            let sizeMB = max(16, (totalSize / 1_000_000) + 1)

            onProgress?("Creating temporary DMG...")

            try run("hdiutil", "create",
                     "-size", "\(sizeMB)m",
                     "-fs", "HFS+",
                     "-volname", config.volumeName,
                     tempDMG.path)

            onProgress?("Mounting...")

            try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
            try run("hdiutil", "attach", tempDMG.path,
                     "-mountpoint", mountPoint.path,
                     "-nobrowse")

            defer {
                do { try run("hdiutil", "detach", mountPoint.path, "-quiet") } catch {}
            }

            onProgress?("Copying files...")

            let appDest = mountPoint.appendingPathComponent(config.appPath.lastPathComponent)
            try fm.copyItem(at: config.appPath, to: appDest)

            let appsLink = mountPoint.appendingPathComponent("Applications")
            try fm.createSymbolicLink(atPath: appsLink.path,
                                       withDestinationPath: "/Applications")

            var bgFileName: String?
            if let bgPath = config.backgroundImagePath {
                let bgDir = mountPoint.appendingPathComponent(".background")
                try fm.createDirectory(at: bgDir, withIntermediateDirectories: true)
                bgFileName = bgPath.lastPathComponent
                try fm.copyItem(at: bgPath, to: bgDir.appendingPathComponent(bgFileName!))
            }

            onProgress?("Writing .DS_Store...")

            let appName = config.appPath.lastPathComponent
            var records: [DSStoreRecord] = [
                .vSrn,
                .icvl,
                .bwsp(windowBounds: "{{100, 100}, {\(Int(config.windowSize.width)), \(Int(config.windowSize.height))}}"),
                .iloc(filename: appName, x: UInt32(config.iconPositions.app.x), y: UInt32(config.iconPositions.app.y)),
                .iloc(filename: "Applications", x: UInt32(config.iconPositions.applications.x), y: UInt32(config.iconPositions.applications.y)),
            ]

            if let bg = bgFileName {
                let aliasData = AliasRecord.build(
                    volumeName: config.volumeName,
                    volumeMountPoint: mountPoint.path,
                    parentDirName: ".background",
                    fileName: bg
                )
                records.append(.icvp(iconSize: config.iconSize, backgroundType: 2, backgroundImageAlias: aliasData))
            } else {
                records.append(.icvp(iconSize: config.iconSize, backgroundType: 0, backgroundImageAlias: nil))
            }

            let dsStorePath = mountPoint.appendingPathComponent(".DS_Store")
            try DSStoreWriter.write(records: records, to: dsStorePath)

            // Clean up system artifacts
            let fseventsd = mountPoint.appendingPathComponent(".fseventsd")
            if fm.fileExists(atPath: fseventsd.path) {
                try? fm.removeItem(at: fseventsd)
            }

            onProgress?("Detaching...")

            try run("hdiutil", "detach", mountPoint.path)

            onProgress?("Compressing...")

            try run("hdiutil", "convert", tempDMG.path,
                     "-format", "UDZO",
                     "-o", config.outputPath.path)

            onProgress?("Done!")

        } catch {
            do { try run("hdiutil", "detach", mountPoint.path, "-quiet") } catch {}
            throw error
        }
    }

    // MARK: - Private

    @discardableResult
    private func run(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw DMGBuilderError.hdiutilFailed("\(args.joined(separator: " ")): \(output)")
        }

        return output
    }

    private func directorySize(at url: URL) throws -> Int {
        let fm = FileManager.default
        var size = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                size += values.fileSize ?? 0
            }
        }
        return size
    }
}
