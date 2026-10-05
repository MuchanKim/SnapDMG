import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let layout: EditorWindowLayout

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
    @State private var isSidebarCollapsed = false

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                SidebarView(
                    project: $project,
                    appURL: appURL,
                    layout: layout,
                    isCollapsed: isSidebarCollapsed,
                    isBuilding: isBuilding,
                    onSelectApp: selectApp,
                    onBuild: buildDMG,
                    onSave: saveProject,
                    onOpen: openProject
                )
                .frame(width: isSidebarCollapsed ? layout.collapsedSidebarWidth : layout.sidebarWidth)
                .disabled(isBuilding)

                PreviewCanvasView(project: $project, appURL: $appURL, onSelectApp: selectApp)
                    .disabled(isBuilding)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: layout.windowSize.width, height: layout.windowSize.height)
        .background(.windowBackground)
        .navigationTitle("SnapDMG")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                        isSidebarCollapsed.toggle()
                    }
                } label: {
                    Label("Settings", systemImage: "sidebar.left")
                }
                .help(isSidebarCollapsed ? "Show Sidebar" : "Hide Sidebar")
                .accessibilityLabel(isSidebarCollapsed ? "Show Sidebar" : "Hide Sidebar")
                .accessibilityIdentifier("sidebar-toggle")
            }
        }
        .alert("Build Error", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(buildError ?? "Unknown error")
        }
    }

    private func buildDMG() {
        guard !isBuilding, let appURL else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "dmg")!]
        panel.nameFieldStringValue = "\(project.appName).dmg"

        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        let config = DMGBuilder.BuildConfig(
            appPath: appURL,
            outputPath: outputURL,
            volumeName: project.appName,
            windowSize: project.windowSize,
            backgroundImagePath: nil,
            iconPositions: project.iconPositions,
            iconSize: project.iconSize
        )
        isBuilding = true
        Task {
            do {
                let builder = DMGBuilder()
                try await builder.build(config: config)
            } catch {
                buildError = error.localizedDescription
                showAlert = true
            }
            isBuilding = false
        }
    }

    private func selectApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              url.pathExtension == "app" else { return }
        appURL = url
        project.appName = url.deletingPathExtension().lastPathComponent
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
