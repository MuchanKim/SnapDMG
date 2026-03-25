import SwiftUI

struct InspectorView: View {
    @Binding var project: SnapDMGProject
    @State private var selectedPreset: Preset? = .classic
    @State private var selectedWindowPreset: WindowSizePreset? = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Layout
            layoutSection

            Divider().overlay(Theme.border)

            // Icon Size
            iconSizeSection

            Divider().overlay(Theme.border)

            // Window Size
            windowSizeSection

            Spacer()
        }
        .padding(12)
        .frame(width: 180)
        .background(Theme.sidebarBackground)
    }

    // MARK: - Layout

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAYOUT").font(.caption).foregroundStyle(Theme.textSecondary)

            VStack(spacing: 4) {
                ForEach(Preset.allCases) { preset in
                    Button {
                        selectedPreset = preset
                        project.iconPositions = preset.iconPositions(for: project.windowSize)
                    } label: {
                        Text(preset.displayName)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedPreset == preset ? Theme.accent : nil)
                }
            }
        }
    }

    // MARK: - Icon Size

    private var iconSizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ICON SIZE").font(.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(project.iconSize))px")
                    .font(.caption2).monospacedDigit()
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
        VStack(alignment: .leading, spacing: 6) {
            Text("WINDOW SIZE").font(.caption).foregroundStyle(Theme.textSecondary)

            HStack(spacing: 3) {
                ForEach(landscapePresets) { preset in
                    windowPresetButton(preset)
                }
            }

            HStack(spacing: 3) {
                ForEach(portraitPresets) { preset in
                    windowPresetButton(preset)
                }
            }

            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Text("W").font(.caption2).foregroundStyle(Theme.textSecondary)
                    TextField("", value: widthBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                }
                HStack(spacing: 3) {
                    Text("H").font(.caption2).foregroundStyle(Theme.textSecondary)
                    TextField("", value: heightBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
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
                    .font(.system(size: 9))
                    .fontWeight(.medium)
                Text(preset.dimensionLabel)
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
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
