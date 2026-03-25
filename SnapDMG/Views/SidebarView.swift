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
        VStack(spacing: 14) {
            // Open / Save — 세로, 중앙정렬
            VStack(spacing: 8) {
                Button(action: onOpen) {
                    Label("Open Project", systemImage: "folder")
                        .font(.callout)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    Label("Save Project", systemImage: "square.and.arrow.down")
                        .font(.callout)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(appURL == nil)
            }

            Divider().overlay(Theme.border)

            appDropZone
            backgroundSection

            Spacer()

            // Build — 작게
            Button(action: onBuild) {
                Text("Build DMG")
                    .font(.callout).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentGreen)
            .disabled(appURL == nil)
        }
        .padding(14)
        .frame(width: 230)
        .background(Theme.sidebarBackground)
    }

    // MARK: - Sections

    private var appDropZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APP").font(.callout).fontWeight(.medium).foregroundStyle(Theme.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isAppTargeted ? Theme.accent.opacity(0.15) : Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isAppTargeted ? Theme.accent : Theme.border, lineWidth: 1)
                    )

                appDropContent
            }
            .frame(height: 80)
            .onDrop(of: [.fileURL], isTargeted: $isAppTargeted) { providers in
                handleAppDrop(providers)
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BACKGROUND").font(.callout).fontWeight(.medium).foregroundStyle(Theme.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(isBgTargeted ? Theme.accent : Theme.borderSubtle)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isBgTargeted ? Theme.accent.opacity(0.1) : Theme.cardBackground)
                    )

                if let url = backgroundURL {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(Theme.accentGreen)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Button {
                            self.backgroundURL = nil
                            project.backgroundImagePath = nil
                        } label: {
                            Text("Remove")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Drop image")
                            .font(.callout)
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(Int(project.windowSize.width)) × \(Int(project.windowSize.height)) recommended")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 80)
            .onDrop(of: [.fileURL], isTargeted: $isBgTargeted) { providers in
                handleBackgroundDrop(providers)
            }
        }
    }

    @ViewBuilder
    private var appDropContent: some View {
        if let url = appURL {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.callout).fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(fileSizeString(url))
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "app.dashed")
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Drop .app here")
                    .font(.callout)
                    .foregroundStyle(Theme.textAccent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
