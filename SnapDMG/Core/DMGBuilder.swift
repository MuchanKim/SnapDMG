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
            try writeDSStoreWithPython(
                mountPath: mountPoint.path,
                volumeName: config.volumeName,
                appName: appName,
                windowSize: config.windowSize,
                iconPositions: config.iconPositions,
                iconSize: config.iconSize,
                bgFileName: bgFileName
            )

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

    // MARK: - DS_Store Generation

    private func writeDSStoreWithPython(
        mountPath: String,
        volumeName: String,
        appName: String,
        windowSize: CGSize,
        iconPositions: IconPositions,
        iconSize: Double,
        bgFileName: String?
    ) throws {
        let w = Int(windowSize.width)
        let h = Int(windowSize.height)
        let appX = Int(iconPositions.app.x)
        let appY = Int(iconPositions.app.y)
        let appsX = Int(iconPositions.applications.x)
        let appsY = Int(iconPositions.applications.y)
        let icoSize = Int(iconSize)

        let bgPython: String
        if let bg = bgFileName {
            bgPython = """
            from mac_alias import Alias
            bg_path = os.path.join(mount, '.background', '\(bg)')
            alias = Alias.for_file(bg_path)
            icvp['backgroundType'] = 2
            icvp['backgroundImageAlias'] = bytes(alias.to_bytes())
            """
        } else {
            bgPython = "icvp['backgroundType'] = 0"
        }

        let script = """
        import os, sys
        from ds_store import DSStore, DSStoreEntry
        from mac_alias import Alias
        import plistlib

        mount = '\(mountPath)'
        ds_path = os.path.join(mount, '.DS_Store')

        # bwsp plist
        bwsp = {
            'WindowBounds': '{{100, 100}, {\(w), \(h)}}',
            'ShowSidebar': False,
            'ContainerShowSidebar': False,
            'ShowStatusBar': False,
            'ShowPathbar': False,
            'ShowToolbar': False,
            'ShowTabView': False,
            'SidebarWidth': 0,
            'PreviewPaneVisibility': False,
        }

        # icvp plist
        icvp = {
            'viewOptionsVersion': 1,
            'backgroundColorRed': 1.0,
            'backgroundColorGreen': 1.0,
            'backgroundColorBlue': 1.0,
            'gridOffsetX': 0.0,
            'gridOffsetY': 0.0,
            'gridSpacing': 100.0,
            'iconSize': float(\(icoSize)),
            'textSize': 12.0,
            'labelOnBottom': True,
            'showIconPreview': True,
            'showItemInfo': False,
            'arrangeBy': 'none',
        }
        \(bgPython)

        with DSStore.open(ds_path, 'w+') as d:
            d['.']['vSrn'] = ('long', 1)
            d['.']['bwsp'] = plistlib.dumps(bwsp, fmt=plistlib.FMT_BINARY)
            d['.']['icvp'] = plistlib.dumps(icvp, fmt=plistlib.FMT_BINARY)
            d['\(appName)']['Iloc'] = (\(appX), \(appY))
            d['Applications']['Iloc'] = (\(appsX), \(appsY))
        """

        let scriptFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapdmg-dsstore-\(UUID().uuidString).py")
        try script.write(to: scriptFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptFile) }

        try run("/Library/Frameworks/Python.framework/Versions/3.12/bin/python3", scriptFile.path)
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
