import SwiftUI

@MainActor
struct WindowSizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: SnapDMGProject
    @State private var widthText: String
    @State private var heightText: String
    @State private var validationError: String?

    init(project: Binding<SnapDMGProject>) {
        _project = project
        _widthText = State(initialValue: String(Int(project.wrappedValue.windowSize.width)))
        _heightText = State(initialValue: String(Int(project.wrappedValue.windowSize.height)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Window Size").font(.headline)
                Text("Set the window size used when the DMG opens.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                dimensionField("Width (px)", text: $widthText)
                dimensionField("Height (px)", text: $heightText)
            }
            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("window-size-error")
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Cancel").foregroundStyle(.primary)
                    }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                    Button("Apply", action: applySize)
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(width: 340)
        .onSubmit(applySize)
    }

    private func dimensionField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text)
                .labelsHidden()
                .accessibilityLabel(title)
        }
    }

    private func applySize() {
        guard let width = Double(widthText), let height = Double(heightText) else {
            validationError = "Enter numeric values for width and height."
            return
        }
        let size = CGSize(width: width.rounded(.down), height: height.rounded(.down))
        guard project.previewLayout.containsWindowSize(size) else {
            let minimum = project.previewLayout.minimumWindowSize
            validationError = "Use at least \(Int(minimum.width)) × \(Int(minimum.height)) px to fit the icons and labels."
            return
        }
        project.windowSize = size
        project.clampIconPositions()
        dismiss()
    }
}
