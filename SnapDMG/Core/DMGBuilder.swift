import Foundation

enum DMGBuilderError: LocalizedError {
    case appNotFound(String)
    case backgroundImageNotFound(String)
    case hdiutilFailed(String)
    case finderSetupFailed(String)
    case buildFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let path):
            "App not found: \(path)"
        case .backgroundImageNotFound(let path):
            "Background image not found: \(path)"
        case .hdiutilFailed(let message):
            "hdiutil failed: \(message)"
        case .finderSetupFailed(let message):
            "Finder setup failed: \(message)"
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

        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            // 1. Calculate size
            let appSize = try directorySize(at: config.appPath)
            let bgSize = config.backgroundImagePath.flatMap { try? Data(contentsOf: $0).count } ?? 0
            let totalSize = appSize + bgSize + 10_000_000
            let sizeMB = max(16, (totalSize / 1_000_000) + 1)

            onProgress?("Creating temporary DMG...")

            // 2. Create temp RW DMG
            try run("hdiutil", "create",
                     "-size", "\(sizeMB)m",
                     "-fs", "HFS+",
                     "-volname", config.volumeName,
                     tempDMG.path)

            onProgress?("Mounting...")

            // 3. Mount WITHOUT -nobrowse (Finder needs access for background alias)
            let volumePath = "/Volumes/\(config.volumeName)"
            try run("hdiutil", "attach", tempDMG.path,
                     "-mountpoint", volumePath)

            defer {
                do { try run("hdiutil", "detach", volumePath, "-quiet") } catch {}
            }

            onProgress?("Copying files...")

            let volumeURL = URL(fileURLWithPath: volumePath)

            // 4. Copy .app
            let appDest = volumeURL.appendingPathComponent(config.appPath.lastPathComponent)
            try fm.copyItem(at: config.appPath, to: appDest)

            // 5. Create Applications symlink
            let appsLink = volumeURL.appendingPathComponent("Applications")
            try fm.createSymbolicLink(atPath: appsLink.path,
                                       withDestinationPath: "/Applications")

            // 6. Copy background image
            var bgFileName: String?
            if let bgPath = config.backgroundImagePath {
                let bgDir = volumeURL.appendingPathComponent(".background")
                try fm.createDirectory(at: bgDir, withIntermediateDirectories: true)
                bgFileName = bgPath.lastPathComponent
                let bgDest = bgDir.appendingPathComponent(bgFileName!)
                try fm.copyItem(at: bgPath, to: bgDest)
            }

            onProgress?("Configuring Finder window...")

            // 7. Use AppleScript to configure Finder (creates proper Alias records)
            try configureWithFinder(
                volumeName: config.volumeName,
                appName: config.appPath.lastPathComponent,
                windowSize: config.windowSize,
                iconPositions: config.iconPositions,
                iconSize: config.iconSize,
                bgFileName: bgFileName
            )

            // 8. Clean up system files
            let fseventsd = volumeURL.appendingPathComponent(".fseventsd")
            if fm.fileExists(atPath: fseventsd.path) {
                try? fm.removeItem(at: fseventsd)
            }

            onProgress?("Detaching...")

            // 9. Detach
            try run("hdiutil", "detach", volumePath)

            onProgress?("Compressing...")

            // 9. Convert to read-only compressed
            try run("hdiutil", "convert", tempDMG.path,
                     "-format", "UDZO",
                     "-o", config.outputPath.path)

            onProgress?("Done!")

        } catch {
            do { try run("hdiutil", "detach", "/Volumes/\(config.volumeName)", "-quiet") } catch {}
            throw error
        }
    }

    // MARK: - Finder Configuration

    private func configureWithFinder(
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

        let bgLine: String
        if let bg = bgFileName {
            bgLine = "set background picture of viewOptions to file \".background:\(bg)\""
        } else {
            bgLine = "-- no background"
        }

        let script = """
        tell application "Finder"
            tell disk "\(volumeName)"
                open
                delay 2
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {100, 100, \(100 + w), \(100 + h)}
                set viewOptions to the icon view options of container window
                set icon size of viewOptions to \(Int(iconSize))
                set text size of viewOptions to 12
                set arrangement of viewOptions to not arranged
                \(bgLine)
                delay 1
                set position of item "\(appName)" of container window to {\(appX), \(appY)}
                set position of item "Applications" of container window to {\(appsX), \(appsY)}
                delay 3
                close
                delay 2
            end tell
        end tell
        """

        // Write script to temp file to avoid shell escaping issues
        let scriptFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapdmg-\(UUID().uuidString).scpt")
        try script.write(to: scriptFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptFile) }

        let result = try run("osascript", scriptFile.path)
        if result.lowercased().contains("error") {
            throw DMGBuilderError.finderSetupFailed(result)
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
