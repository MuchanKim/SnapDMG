import Foundation

enum DMGBuilderError: LocalizedError {
    case appNotFound(String)
    case backgroundImageNotFound(String)
    case createDmgNotFound
    case buildFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let path):
            "App not found: \(path)"
        case .backgroundImageNotFound(let path):
            "Background image not found: \(path)"
        case .createDmgNotFound:
            "create-dmg not found. Install with: brew install create-dmg"
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

        // create-dmg 찾기
        let createDmgPath = findCreateDmg()
        guard let createDmg = createDmgPath else {
            throw DMGBuilderError.createDmgNotFound
        }

        // 기존 출력 파일 삭제
        if fm.fileExists(atPath: config.outputPath.path) {
            try fm.removeItem(at: config.outputPath)
        }

        onProgress?("Building DMG...")

        // create-dmg 명령어 조립
        var args = [
            createDmg,
            "--volname", config.volumeName,
            "--window-pos", "100", "100",
            "--window-size", "\(Int(config.windowSize.width))", "\(Int(config.windowSize.height))",
            "--icon-size", "\(Int(config.iconSize))",
            "--icon", config.appPath.lastPathComponent,
                "\(Int(config.iconPositions.app.x))", "\(Int(config.iconPositions.app.y))",
            "--icon", "Applications",
                "\(Int(config.iconPositions.applications.x))", "\(Int(config.iconPositions.applications.y))",
            "--app-drop-link",
                "\(Int(config.iconPositions.applications.x))", "\(Int(config.iconPositions.applications.y))",
            "--no-internet-enable",
            "--hide-extension", config.appPath.lastPathComponent,
        ]

        if let bgPath = config.backgroundImagePath {
            args += ["--background", bgPath.path]
        }

        args += [config.outputPath.path, config.appPath.path]

        onProgress?("Creating DMG...")

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
            throw DMGBuilderError.buildFailed(output)
        }

        onProgress?("Done!")
    }

    // MARK: - Private

    private func findCreateDmg() -> String? {
        let paths = [
            "/opt/homebrew/bin/create-dmg",
            "/usr/local/bin/create-dmg",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}
