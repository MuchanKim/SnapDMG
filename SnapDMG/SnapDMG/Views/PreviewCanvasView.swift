import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PreviewCanvasView: View {
    @Binding var project: SnapDMGProject
    @Binding var appURL: URL?
    var onSelectApp: () -> Void
    @State private var isTargeted = false
    @State private var dragStart: CGPoint?

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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - 드롭존 (앱 없을 때)

    private var dropZoneContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Theme.accent : .secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Add an App")
                    .font(.title3.weight(.semibold))
                Text("Drop an app here or choose one below")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button(action: onSelectApp) {
                Text("Select App…").foregroundStyle(.primary)
            }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .foregroundStyle(isTargeted ? Theme.accent : Theme.border)
        }
    }

    // MARK: - 프리뷰 (앱 있을 때)

    private var previewContent: some View {
        GeometryReader { geometry in
            let scale = project.previewLayout.scale(in: geometry.size)

            ZStack {
                Theme.cardBackground

                iconView(
                    position: project.iconPositions.app,
                    label: project.previewAppName,
                    icon: appIcon,
                    onDrag: { project.iconPositions.app = project.previewLayout.clampedPosition($0, label: project.previewAppName) }
                )

                iconView(
                    position: project.iconPositions.applications,
                    label: "Applications",
                    icon: applicationsIcon,
                    onDrag: { project.iconPositions.applications = project.previewLayout.clampedPosition($0, label: "Applications") }
                )
            }
            .frame(width: project.windowSize.width, height: project.windowSize.height)
            .coordinateSpace(name: "previewCanvas")
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .scaleEffect(scale)
            .frame(width: project.windowSize.width * scale, height: project.windowSize.height * scale)
            .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Icons

    private func iconView(
        position: CGPoint,
        label: String,
        icon: some View,
        onDrag: @escaping (CGPoint) -> Void
    ) -> some View {
        VStack(spacing: PreviewLayout.labelSpacing) {
            icon
                .frame(width: project.iconSize, height: project.iconSize)
            Text(label)
                .font(.system(size: PreviewLayout.textSize))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .frame(width: project.previewLayout.labelWidth(for: label), height: PreviewLayout.labelHeight)
        }
        .position(x: position.x, y: position.y + project.previewLayout.captionHeight / 2)
        .gesture(
            DragGesture(coordinateSpace: .named("previewCanvas"))
                .onChanged { value in
                    let start = dragStart ?? position
                    dragStart = start
                    onDrag(CGPoint(
                        x: start.x + value.translation.width,
                        y: start.y + value.translation.height
                    ))
                }
                .onEnded { _ in
                    dragStart = nil
                }
        )
    }

    private var appIcon: some View {
        Group {
            if let url = appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
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
            .scaledToFit()
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

}
