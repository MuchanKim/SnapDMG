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
    @State private var backgroundURL: URL?
    @State private var isBuilding = false
    @State private var buildError: String?
    @State private var showAlert = false
    @State private var projectFileURL: URL?

    var body: some View {
        HSplitView {
            SidebarView(
                project: $project,
                appURL: $appURL,
                backgroundURL: $backgroundURL,
                onBuild: buildDMG
            )

            PreviewCanvasView(
                project: $project,
                appURL: appURL,
                backgroundURL: backgroundURL
            )
        }
        .frame(minWidth: 760, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    openProject()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Open Project")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    saveProject()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save Project")
                .disabled(appURL == nil)
            }
        }
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

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            return
        }

        isBuilding = true
        Task {
            do {
                let builder = DMGBuilder()
                try await builder.build(config: .init(
                    appPath: appURL,
                    outputPath: outputURL,
                    volumeName: project.appName,
                    windowSize: project.windowSize,
                    backgroundImagePath: backgroundURL,
                    iconPositions: project.iconPositions,
                    iconSize: 128
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
            project = try JSONDecoder().decode(SnapDMGProject.self, from: data)
            projectFileURL = url

            if let bgPath = project.backgroundImagePath {
                let bgURL = URL(fileURLWithPath: bgPath)
                if FileManager.default.fileExists(atPath: bgURL.path) {
                    backgroundURL = bgURL
                }
            }
        } catch {
            buildError = "Failed to open: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
