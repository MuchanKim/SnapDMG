import SwiftUI
import UniformTypeIdentifiers

struct PreviewCanvasView: View {
    @Binding var project: SnapDMGProject
    @Binding var appURL: URL?
    @State private var isTargeted = false

    private var scale: CGFloat {
        let maxWidth: CGFloat = 500
        let maxHeight: CGFloat = 400
        let scaleX = maxWidth / project.windowSize.width
        let scaleY = maxHeight / project.windowSize.height
        return min(scaleX, scaleY, 1.0)
    }

    var body: some View {
        ZStack {
            Theme.canvasBackground

            if appURL != nil {
                // 프리뷰 모드
                previewContent
            } else {
                // 드롭존 모드
                dropZoneContent
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - 드롭존 (앱 없을 때)

    private var dropZoneContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.textSecondary.opacity(0.5))

            Text("Drop .app here")
                .font(.title3)
                .foregroundStyle(isTargeted ? Theme.accent : Theme.textAccent)

            Text("or click to browse")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.border)
                .padding(24)
        )
        .onTapGesture {
            browseForApp()
        }
    }

    // MARK: - 프리뷰 (앱 있을 때)

    private var previewContent: some View {
        GeometryReader { _ in
            let scaledW = project.windowSize.width * scale
            let scaledH = project.windowSize.height * scale

            ZStack {
                Theme.canvasBackground

                ZStack {
                    Theme.cardBackground

                    iconView(
                        position: project.iconPositions.app,
                        label: project.appName.isEmpty ? "App" : project.appName,
                        icon: appIcon,
                        onDrag: { project.iconPositions.app = clampPosition($0) }
                    )

                    iconView(
                        position: project.iconPositions.applications,
                        label: "Applications",
                        icon: applicationsIcon,
                        onDrag: { project.iconPositions.applications = clampPosition($0) }
                    )
                }
                .frame(width: scaledW, height: scaledH)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12)
            }
        }
    }

    // MARK: - Icons

    private func iconView(
        position: CGPoint,
        label: String,
        icon: some View,
        onDrag: @escaping (CGPoint) -> Void
    ) -> some View {
        let scaledPos = CGPoint(x: position.x * scale, y: position.y * scale)
        let scaledIconSize = CGFloat(project.iconSize) * scale

        return VStack(spacing: 4) {
            icon
                .frame(width: scaledIconSize, height: scaledIconSize)
            Text(label)
                .font(.system(size: max(9, 12 * scale)))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .position(x: scaledPos.x, y: scaledPos.y)
        .gesture(
            DragGesture()
                .onChanged { value in
                    onDrag(CGPoint(x: value.location.x / scale, y: value.location.y / scale))
                }
        )
    }

    private var appIcon: some View {
        Group {
            if let url = appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.accent.opacity(0.3))
                    .overlay(
                        Image(systemName: "app.fill")
                            .foregroundStyle(Theme.textAccent)
                    )
            }
        }
    }

    private var applicationsIcon: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: "/Applications"))
            .resizable()
    }

    private func clampPosition(_ pos: CGPoint) -> CGPoint {
        CGPoint(
            x: max(32, min(project.windowSize.width - 32, pos.x)),
            y: max(32, min(project.windowSize.height - 32, pos.y))
        )
    }

    // MARK: - Drop / Browse

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
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

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "app")!]
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url,
              url.pathExtension == "app" else { return }
        appURL = url
        project.appName = url.deletingPathExtension().lastPathComponent
    }
}
