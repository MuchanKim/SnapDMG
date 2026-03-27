import SwiftUI

struct SidebarView: View {
    @Binding var project: SnapDMGProject
    @Binding var appURL: URL?
    var onBuild: () -> Void
    var onSave: () -> Void
    var onOpen: () -> Void

    @State private var selectedPreset: Preset? = .classic
    @State private var selectedWindowPreset: WindowSizePreset? = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Layout
            sectionLabel("LAYOUT")
            HStack(spacing: 3) {
                ForEach(Preset.allCases) { preset in
                    presetButton(
                        title: preset.displayName,
                        isSelected: selectedPreset == preset
                    ) {
                        selectedPreset = preset
                        project.iconPositions = preset.iconPositions(for: project.windowSize)
                    }
                }
            }

            Divider().overlay(Theme.border)

            // Icon Size
            HStack {
                sectionLabel("ICON SIZE")
                Spacer()
                Text("\(Int(project.iconSize)) px")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(Theme.textAccent)
            }
            Slider(value: $project.iconSize, in: 48...256, step: 8)
                .tint(Theme.accent)
                .controlSize(.small)

            Divider().overlay(Theme.border)

            // Window Size
            sectionLabel("WINDOW")
            HStack(spacing: 4) {
                Text("W").font(.caption2).foregroundStyle(Theme.textSecondary)
                TextField("", value: widthBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .controlSize(.small)
                Text("H").font(.caption2).foregroundStyle(Theme.textSecondary)
                TextField("", value: heightBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .controlSize(.small)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 3) {
                ForEach(WindowSizePreset.allCases) { preset in
                    presetButton(
                        title: preset.displayName,
                        subtitle: preset.dimensionLabel,
                        isSelected: selectedWindowPreset == preset
                    ) {
                        selectedWindowPreset = preset
                        project.windowSize = preset.size
                        if let selectedPreset {
                            project.iconPositions = selectedPreset.iconPositions(for: project.windowSize)
                        }
                        clampIconPositions()
                    }
                }
            }

            Spacer()

            // Save / Open
            HStack(spacing: 4) {
                Button(action: onOpen) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Project")

                Button(action: onSave) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appURL == nil)
                .help("Save Project")
            }

            // Build
            Button(action: onBuild) {
                Text("Build DMG")
                    .font(.caption).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(appURL == nil)

            Text("snapDMG 1.0.0 · © 2026 moolab")
                .font(.system(size: 9))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
                .frame(maxWidth: .infinity)
        }
        .padding(10)
        .frame(width: 160)
        .background(Theme.sidebarBackground)
    }

    // MARK: - Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.caption).fontWeight(.medium).foregroundStyle(Theme.textSecondary)
    }

    private func presetButton(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 8))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : Theme.textSecondary.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Theme.accent : Theme.controlBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bindings

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
}
