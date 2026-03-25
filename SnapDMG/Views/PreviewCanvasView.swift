import SwiftUI

struct PreviewCanvasView: View {
    @Binding var project: SnapDMGProject
    let appURL: URL?
    let backgroundURL: URL?

    private var scale: CGFloat {
        let maxWidth: CGFloat = 500
        let maxHeight: CGFloat = 400
        let scaleX = maxWidth / project.windowSize.width
        let scaleY = maxHeight / project.windowSize.height
        return min(scaleX, scaleY, 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Drag icons to reposition")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            GeometryReader { _ in
                let scaledW = project.windowSize.width * scale
                let scaledH = project.windowSize.height * scale

                ZStack {
                    Color(nsColor: .windowBackgroundColor)

                    ZStack {
                        backgroundView

                        iconView(
                            position: project.iconPositions.app,
                            label: project.appName.isEmpty ? "App" : project.appName,
                            icon: appIcon,
                            onDrag: { newPos in
                                project.iconPositions.app = clampPosition(newPos)
                            }
                        )

                        iconView(
                            position: project.iconPositions.applications,
                            label: "Applications",
                            icon: applicationsIcon,
                            onDrag: { newPos in
                                project.iconPositions.applications = clampPosition(newPos)
                            }
                        )
                    }
                    .frame(width: scaledW, height: scaledH)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 8)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var backgroundView: some View {
        if let url = backgroundURL, let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func iconView(
        position: CGPoint,
        label: String,
        icon: some View,
        onDrag: @escaping (CGPoint) -> Void
    ) -> some View {
        let scaledPos = CGPoint(x: position.x * scale, y: position.y * scale)
        let iconSize: CGFloat = 64 * scale

        return VStack(spacing: 4) {
            icon
                .frame(width: iconSize, height: iconSize)
            Text(label)
                .font(.system(size: 11 * scale))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .position(x: scaledPos.x, y: scaledPos.y)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newX = value.location.x / scale
                    let newY = value.location.y / scale
                    onDrag(CGPoint(x: newX, y: newY))
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
                    .fill(.blue.opacity(0.3))
                    .overlay(
                        Image(systemName: "app.fill")
                            .foregroundStyle(.blue)
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
}
