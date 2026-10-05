import SwiftUI

@main
struct SnapDMGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appUpdater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            let layout = EditorWindowLayout.fitting(screenSize: NSScreen.main?.visibleFrame.size ?? .zero)
            ContentView(layout: layout)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: appUpdater.checkForUpdates)
                    .disabled(!appUpdater.canCheckForUpdates)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppKit 파일 선택 패널도 SwiftUI 화면과 같은 라이트 모드를 사용한다.
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.activate(ignoringOtherApps: true)
    }
}
