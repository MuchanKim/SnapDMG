import SwiftUI

@MainActor
struct SidebarView: View {
    @Binding var project: SnapDMGProject
    @Binding var appURL: URL?
    var onBuild: () -> Void
    var onSave: () -> Void
    var onOpen: () -> Void

    @State private var widthText = ""
    @State private var heightText = ""
    @State private var windowSizeError: String?
    @FocusState private var focusedDimension: Dimension?

    @State private var selectedPreset: Preset? = .classic
    @State private var selectedWindowPreset: WindowSizePreset? = .standard

    private enum Dimension { case width, height }

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
                        project.clampIconPositions()
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
            Slider(value: iconSizeBinding, in: 48...maximumIconSize, step: 8)
                .tint(Theme.accent)
                .controlSize(.small)

            Divider().overlay(Theme.border)

            // Window Size
            sectionLabel("WINDOW")
            HStack(spacing: 4) {
                Text("W").font(.caption2).foregroundStyle(Theme.textSecondary)
                TextField("", text: $widthText)
                    .focused($focusedDimension, equals: .width)
                    .accessibilityLabel("Window width")
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .controlSize(.small)
                Text("H").font(.caption2).foregroundStyle(Theme.textSecondary)
                TextField("", text: $heightText)
                    .focused($focusedDimension, equals: .height)
                    .accessibilityLabel("Window height")
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .controlSize(.small)
            }

            if let windowSizeError {
                Text(windowSizeError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
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
                        syncWindowFields()
                        project.clampIconPositions()
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

                Button {
                    if commitWindowSize() { onSave() }
                } label: {
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
            Button {
                if commitWindowSize() { onBuild() }
            } label: {
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
        .onAppear { syncWindowFields() }
        .onChange(of: project.windowSize) { _, _ in syncWindowFields() }
        .onChange(of: focusedDimension) { oldValue, _ in
            if oldValue != nil { commitWindowSize() }
        }
        .onSubmit { commitWindowSize() }
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

    private var maximumIconSize: Double {
        let layout = project.previewLayout
        let available = min(project.windowSize.width,
                            project.windowSize.height - layout.captionHeight) - PreviewLayout.edgePadding * 2
        return max(48, min(256, floor(available / 8) * 8))
    }

    private var iconSizeBinding: Binding<Double> {
        Binding(
            get: { project.iconSize },
            set: {
                project.iconSize = $0
                project.clampIconPositions()
            }
        )
    }

    private func syncWindowFields() {
        widthText = String(Int(project.windowSize.width))
        heightText = String(Int(project.windowSize.height))
        windowSizeError = nil
    }

    @discardableResult
    private func commitWindowSize() -> Bool {
        guard let width = Double(widthText), let height = Double(heightText) else {
            windowSizeError = "Enter a number for W and H."
            return false
        }
        return updateWindowSize(CGSize(width: width, height: height))
    }

    private func updateWindowSize(_ size: CGSize) -> Bool {
        let size = CGSize(width: size.width.rounded(.down), height: size.height.rounded(.down))
        guard project.previewLayout.containsWindowSize(size) else {
            let minimum = project.previewLayout.minimumWindowSize
            windowSizeError = "Enter a valid size of at least \(Int(minimum.width)) × \(Int(minimum.height))."
            return false
        }
        windowSizeError = nil
        project.windowSize = size
        selectedWindowPreset = WindowSizePreset.matching(size)
        project.clampIconPositions()
        syncWindowFields()
        return true
    }
}
