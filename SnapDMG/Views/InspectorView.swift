import SwiftUI

struct InspectorView: View {
    @Binding var project: SnapDMGProject
    @State private var selectedPreset: Preset? = .classic
    @State private var selectedWindowPreset: WindowSizePreset? = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            layoutSection

            Divider().overlay(Theme.border)

            iconSizeSection

            Divider().overlay(Theme.border)

            windowSizeSection

            Spacer()

            Text("snapDMG 1.0.0 · © 2026 moolab")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 220)
        .background(Theme.sidebarBackground)
    }

    // MARK: - Layout

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAYOUT").font(.callout).fontWeight(.medium).foregroundStyle(Theme.textSecondary)

            VStack(spacing: 6) {
                ForEach(Preset.allCases) { preset in
                    Button {
                        selectedPreset = preset
                        project.iconPositions = preset.iconPositions(for: project.windowSize)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.displayName)
                                .font(.callout).fontWeight(.medium)
                            Text(preset.description)
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedPreset == preset ? Theme.accent : nil)
                }
            }
        }
    }

    // MARK: - Icon Size

    private var iconSizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ICON SIZE").font(.callout).fontWeight(.medium).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(project.iconSize)) px")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(Theme.textAccent)
            }

            Slider(value: $project.iconSize, in: 48...256, step: 8)
                .tint(Theme.accent)
        }
    }

    // MARK: - Window Size

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
        VStack(alignment: .leading, spacing: 10) {
            Text("WINDOW SIZE").font(.callout).fontWeight(.medium).foregroundStyle(Theme.textSecondary)

            // Landscape
            HStack(spacing: 4) {
                ForEach(landscapePresets) { preset in
                    windowPresetButton(preset)
                }
            }

            // Portrait
            HStack(spacing: 4) {
                ForEach(portraitPresets) { preset in
                    windowPresetButton(preset)
                }
            }

            // Direct input
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("W").font(.caption).foregroundStyle(Theme.textSecondary)
                    TextField("", value: widthBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                HStack(spacing: 4) {
                    Text("H").font(.caption).foregroundStyle(Theme.textSecondary)
                    TextField("", value: heightBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
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
            VStack(spacing: 2) {
                Text(preset.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(preset.dimensionLabel)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .buttonStyle(.bordered)
        .tint(selectedWindowPreset == preset ? Theme.accent : nil)
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
}
