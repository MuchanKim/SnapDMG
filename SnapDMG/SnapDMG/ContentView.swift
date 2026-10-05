import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var project = SnapDMGProject(
        appName: "",
        windowSize: CGSize(width: 540, height: 380),
        backgroundImagePath: nil,
        iconPositions: Preset.classic.iconPositions(for: CGSize(width: 540, height: 380))
    )
    @State private var appURL: URL?
    @State private var isBuilding = false
    @State private var buildError: String?
    @State private var showAlert = false
    @State private var projectFileURL: URL?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                project: $project,
                appURL: $appURL,
                onBuild: buildDMG,
                onSave: saveProject,
                onOpen: openProject
            )

            Divider().overlay(Theme.border)

            PreviewCanvasView(
                project: $project,
                appURL: $appURL
            )
        }
        .frame(minWidth: 480, minHeight: 320)
        .background(Theme.canvasBackground)
        .alert("Build Error", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(buildError ?? "Unknown error")
        }
    }

    private func buildDMG() {
        guard let appURL else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "dmg")!]
        panel.nameFieldStringValue = "\(project.appName).dmg"

        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        isBuilding = true
        Task {
            do {
                let builder = DMGBuilder()
                try await builder.build(config: .init(
                    appPath: appURL,
                    outputPath: outputURL,
                    volumeName: project.appName,
                    windowSize: project.windowSize,
                    backgroundImagePath: nil,
                    iconPositions: project.iconPositions,
                    iconSize: project.iconSize
                ))
            } catch {
                buildError = error.localizedDescription
                showAlert = true
            }
            isBuilding = false
        }
    }

    private func saveProject() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "snapdmg")!]
        panel.nameFieldStringValue = "\(project.appName).snapdmg"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(project)
            try data.write(to: url)
            projectFileURL = url
        } catch {
            buildError = "Failed to save: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "snapdmg")!]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let loadedProject = try JSONDecoder().decode(SnapDMGProject.self, from: data)
            project = loadedProject
            appURL = nil
            projectFileURL = url
        } catch DecodingError.dataCorrupted(let context) {
            buildError = "Failed to open: \(context.debugDescription)"
            showAlert = true
        } catch {
            buildError = "Failed to open: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
