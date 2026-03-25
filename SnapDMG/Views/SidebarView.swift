import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var project: SnapDMGProject
    @Binding var appURL: URL?
    @Binding var backgroundURL: URL?
    var onBuild: () -> Void
    var onSave: () -> Void
    var onOpen: () -> Void

    @State private var isAppTargeted = false
    @State private var isBgTargeted = false
    @State private var selectedWindowPreset: WindowSizePreset? = .standard
    @State private var selectedPreset: Preset? = .classic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appDropZone
            backgroundSection
            presetSection
            windowSizeSection

            Spacer()

            // Project save/open
            HStack(spacing: 8) {
                Button(action: onOpen) {
                    Label("Open", systemImage: "folder")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(appURL == nil)
            }

            Button(action: onBuild) {
                Text("Build DMG")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(appURL == nil)

            Text("© 2026 moolab")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 220)
    }

    // MARK: - Sections

    private var appDropZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APP").font(.caption).foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isAppTargeted ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isAppTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                if let url = appURL {
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent).font(.callout).fontWeight(.semibold)
                            Text(fileSizeString(url)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "app.dashed")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Drop .app here")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                }
            }
            .frame(height: 64)
            .onDrop(of: [.fileURL], isTargeted: $isAppTargeted) { providers in
                handleAppDrop(providers)
            }
        }
    }

    private var widthBinding: Binding<Double> {
        Binding(
            get: { Double(project.windowSize.width) },
            set: { newValue in
                project.windowSize.width = CGFloat(newValue)
                selectedWindowPreset = WindowSizePreset.matching(project.windowSize)
                clampIconPositions()
            }
        )
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { Double(project.windowSize.height) },
            set: { newValue in
                project.windowSize.height = CGFloat(newValue)
                selectedWindowPreset = WindowSizePreset.matching(project.windowSize)
                clampIconPositions()
            }
        )
    }

    private var landscapePresets: [WindowSizePreset] {
        WindowSizePreset.allCases.filter(\.isLandscape)
    }

    private var portraitPresets: [WindowSizePreset] {
        WindowSizePreset.allCases.filter { !$0.isLandscape }
    }

    private var windowSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WINDOW SIZE").font(.caption).foregroundStyle(.secondary)

            // Landscape presets
            HStack(spacing: 4) {
                ForEach(landscapePresets) { preset in
                    windowPresetButton(preset)
                }
            }

            // Portrait presets
            HStack(spacing: 4) {
                ForEach(portraitPresets) { preset in
                    windowPresetButton(preset)
                }
            }

            // Direct input
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("W").font(.caption2).foregroundStyle(.secondary)
                    TextField("", value: widthBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                }
                HStack(spacing: 4) {
                    Text("H").font(.caption2).foregroundStyle(.secondary)
                    TextField("", value: heightBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                }
            }
        }
    }

    private func windowPresetButton(_ preset: WindowSizePreset) -> some View {
        Button {
            selectedWindowPreset = preset
            project.windowSize = preset.size
            if let selectedPreset {
                project.iconPositions = selectedPreset.iconPositions(for: project.windowSize)
            }
            clampIconPositions()
        } label: {
            VStack(spacing: 1) {
                Text(preset.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text(preset.dimensionLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(selectedWindowPreset == preset ? .accentColor : nil)
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BACKGROUND").font(.caption).foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(isBgTargeted ? Color.accentColor : .secondary.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isBgTargeted ? Color.accentColor.opacity(0.1) : .clear)
                    )

                if let url = backgroundURL {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .foregroundStyle(.green)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .padding(8)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Drop image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(project.windowSize.width)) × \(Int(project.windowSize.height)) recommended")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                }
            }
            .frame(height: 70)
            .onDrop(of: [.fileURL], isTargeted: $isBgTargeted) { providers in
                handleBackgroundDrop(providers)
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYOUT").font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(Preset.allCases) { preset in
                    Button {
                        selectedPreset = preset
                        project.iconPositions = preset.iconPositions(for: project.windowSize)
                    } label: {
                        Text(preset.displayName)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedPreset == preset ? .accentColor : nil)
                }
            }
        }
    }

    // MARK: - Helpers

    private func clampIconPositions() {
        let w = project.windowSize.width
        let h = project.windowSize.height
        let margin: CGFloat = 32

        project.iconPositions.app = CGPoint(
            x: max(margin, min(w - margin, project.iconPositions.app.x)),
            y: max(margin, min(h - margin, project.iconPositions.app.y))
        )
        project.iconPositions.applications = CGPoint(
            x: max(margin, min(w - margin, project.iconPositions.applications.x)),
            y: max(margin, min(h - margin, project.iconPositions.applications.y))
        )
    }

    private func handleAppDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension == "app" else { return }
            DispatchQueue.main.async {
                appURL = url
                project.appName = url.deletingPathExtension().lastPathComponent
            }
        }
        return true
    }

    private func handleBackgroundDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let imageExts = ["png", "jpg", "jpeg", "tiff", "tif"]
            guard imageExts.contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                backgroundURL = url
                project.backgroundImagePath = url.path
            }
        }
        return true
    }

    private func fileSizeString(_ url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
