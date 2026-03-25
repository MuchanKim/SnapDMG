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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Open / Save
            HStack(spacing: 6) {
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

            Divider().overlay(Theme.border)

            // App drop
            appDropZone

            // Background drop
            backgroundSection

            Spacer()

            // Build
            Button(action: onBuild) {
                Text("Build DMG")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentGreen)
            .disabled(appURL == nil)

            Text("snapDMG 1.0.0 · © 2026 moolab")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(width: 190)
        .background(Theme.sidebarBackground)
    }

    // MARK: - Sections

    private var appDropZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("APP").font(.caption).foregroundStyle(Theme.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isAppTargeted ? Theme.accent.opacity(0.15) : Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isAppTargeted ? Theme.accent : Theme.border, lineWidth: 1)
                    )

                if let url = appURL {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(url.lastPathComponent)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(fileSizeString(url))
                                .font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(10)
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: "app.dashed")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Drop .app here")
                            .font(.caption2)
                            .foregroundStyle(Theme.textAccent)
                    }
                    .padding(10)
                }
            }
            .frame(height: 56)
            .onDrop(of: [.fileURL], isTargeted: $isAppTargeted) { providers in
                handleAppDrop(providers)
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BACKGROUND").font(.caption).foregroundStyle(Theme.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(isBgTargeted ? Theme.accent : Theme.borderSubtle)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isBgTargeted ? Theme.accent.opacity(0.1) : Theme.cardBackground)
                    )

                if let url = backgroundURL {
                    VStack(spacing: 3) {
                        Image(systemName: "photo")
                            .foregroundStyle(Theme.accentGreen)
                        Text(url.lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(8)
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: "photo.badge.plus")
                            .foregroundStyle(Theme.textSecondary)
                        Text("Drop image")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(Int(project.windowSize.width))×\(Int(project.windowSize.height))")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    }
                    .padding(8)
                }
            }
            .frame(height: 60)
            .onDrop(of: [.fileURL], isTargeted: $isBgTargeted) { providers in
                handleBackgroundDrop(providers)
            }
        }
    }

    // MARK: - Helpers

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
