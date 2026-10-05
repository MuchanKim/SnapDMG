import SwiftUI

@MainActor
struct SidebarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var project: SnapDMGProject
    let appURL: URL?
    let layout: EditorWindowLayout
    let isCollapsed: Bool
    let isBuilding: Bool
    var onSelectApp: () -> Void
    var onSelectBackground: () -> Void
    var onRemoveBackground: () -> Void
    var onBuild: () -> Void
    var onSave: () -> Void
    var onOpen: () -> Void

    @State private var isWindowSizePresented = false

    private var maximumIconSize: Double {
        let available = min(project.windowSize.width,
                            project.windowSize.height - project.previewLayout.captionHeight) - PreviewLayout.edgePadding * 2
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

    private var windowSizeLabel: String {
        let name = WindowSizePreset.matching(project.windowSize)?.displayName ?? "Custom"
        return "\(name) · \(Int(project.windowSize.width)) × \(Int(project.windowSize.height))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if isCollapsed {
                    collapsedControls
                } else {
                    expandedControls
                }
            }
            .frame(maxHeight: .infinity)
            .modifier(EditorControlPanel())

            VStack(spacing: 6) {
                buildButton
                if !isCollapsed {
                    HStack(spacing: 6) {
                        Text("© moolab")
                        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                            Text("· v\(version)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .sheet(isPresented: $isWindowSizePresented) {
            WindowSizeSheet(project: $project)
        }
    }

    private var expandedControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.contentSpacing) {
                appSelectionButton

                backgroundControls

                Divider()

                VStack(alignment: .leading, spacing: layout.contentSpacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Icon Layout")
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                layoutButton("Horizontal", preset: .classic)
                                layoutButton("Vertical", preset: .topBottom)
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        HStack {
                            sectionLabel("Icon Size")
                            Spacer()
                            Text("\(Int(project.iconSize)) px")
                                .font(.callout).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: iconSizeBinding, in: 48...maximumIconSize, step: 8)
                            .accessibilityLabel("Icon Size")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Window Size")
                        Menu {
                            ForEach(WindowSizePreset.allCases) { preset in
                                Button("\(preset.displayName) · \(preset.dimensionLabel)") {
                                    project.windowSize = preset.size
                                    project.clampIconPositions()
                                }
                            }
                            Divider()
                            Button("Custom…") { isWindowSizePresented = true }
                        } label: {
                            HStack(spacing: 6) {
                                Text(windowSizeLabel)
                                    .font(.callout).monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Theme.cardBackground.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(.rect(cornerRadius: 10))
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                        .menuIndicator(.hidden)
                        .accessibilityLabel("Window Size")
                        .accessibilityValue(windowSizeLabel)
                        .accessibilityIdentifier("window-size-menu")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    HStack(spacing: 8) {
                        Button(action: onOpen) {
                            Label("Open", systemImage: "folder")
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                        }
                        .help("Open a .snapdmg project")
                        .accessibilityIdentifier("open-project")
                        .accessibilityLabel("Open Project")
                        Button(action: onSave) {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                        }
                        .help("Save a .snapdmg project")
                        .accessibilityIdentifier("save-project")
                        .accessibilityLabel("Save Project")
                    }
                    .font(.callout)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(height: 32)
                }
            }
            .padding(layout.contentPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var appSelectionButton: some View {
        Button(action: onSelectApp) {
            HStack(spacing: 10) {
                Group {
                    if let appURL {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appURL?.deletingPathExtension().lastPathComponent ?? "Select App…")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(appURL == nil ? "Application (.app)" : "Change App…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(appURL?.path ?? "Select an app to include in the DMG")
        .accessibilityIdentifier("select-app")
    }

    private var collapsedControls: some View {
        VStack(spacing: 12) {
            railButton("Change App", symbol: "app", action: onSelectApp)
            railButton("Choose Background", symbol: "photo", action: onSelectBackground)
            railButton("Open Project", symbol: "folder", action: onOpen)
            railButton("Save Project", symbol: "square.and.arrow.down", action: onSave)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
    }

    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Background")
            HStack(spacing: 6) {
                Button(action: onSelectBackground) {
                    Label(project.backgroundImagePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Choose Image…", systemImage: "photo")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .help(project.backgroundImagePath ?? "Choose a PNG or JPEG background image")
                .accessibilityLabel("Choose Background Image")
                .accessibilityValue(project.backgroundImagePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "None")
                .accessibilityIdentifier("choose-background")
                if project.backgroundImagePath != nil {
                    Button(action: onRemoveBackground) {
                        Image(systemName: "xmark").foregroundStyle(.primary)
                    }
                    .help("Remove Background")
                    .accessibilityLabel("Remove Background")
                    .accessibilityIdentifier("remove-background")
                }
            }
            .font(.callout)
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(height: 30)
        }
    }

    private var buildButton: some View {
        Button(action: onBuild) {
            Group {
                if isCollapsed {
                    Image(systemName: "shippingbox")
                } else {
                    Label(isBuilding ? "Building…" : "Build DMG…", systemImage: "shippingbox")
                }
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(appURL == nil || isBuilding)
        .help(isBuilding ? "Building DMG" : "Build DMG")
        .accessibilityLabel(isBuilding ? "Building DMG" : "Build DMG")
        .accessibilityIdentifier("build-dmg")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.callout.weight(.medium))
    }

    private func layoutButton(_ title: String, preset: Preset) -> some View {
        var expected = project
        expected.iconPositions = preset.iconPositions(for: project.windowSize)
        expected.clampIconPositions()
        let isSelected = project.iconPositions == expected.iconPositions
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                project.iconPositions = expected.iconPositions
            }
        } label: {
            HStack(spacing: 6) {
                Group {
                    if preset == .classic {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).frame(width: 10, height: 14)
                            RoundedRectangle(cornerRadius: 2).frame(width: 10, height: 14)
                        }
                    } else {
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2).frame(width: 14, height: 6)
                            RoundedRectangle(cornerRadius: 2).frame(width: 14, height: 6)
                        }
                    }
                }
                .frame(height: 16)
                .foregroundStyle(isSelected ? Theme.accent : .secondary)
                .accessibilityHidden(true)
                Text(title).font(.callout.weight(isSelected ? .medium : .regular))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .foregroundStyle(isSelected ? Theme.accent : .primary)
            .contentShape(.rect(cornerRadius: 10))
            .glassEffect(.regular.tint(isSelected ? Theme.accent.opacity(0.16) : .clear).interactive(), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func railButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body)
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}
