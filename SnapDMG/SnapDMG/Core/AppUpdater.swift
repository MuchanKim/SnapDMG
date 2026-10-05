import Combine
import Observation
import OSLog
import Sparkle

@MainActor
@Observable
final class AppUpdater {
    private(set) var canCheckForUpdates = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var updateAvailability: AnyCancellable?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updateAvailability = controller.updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] canCheckForUpdates in
                self?.canCheckForUpdates = canCheckForUpdates
            }

        // 배포 주소와 공개 키를 준비하기 전에는 업데이트 확인을 시작하지 않는다.
        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feedURL.isEmpty,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !publicKey.isEmpty else {
            Logger(subsystem: "com.moolab.SnapDMG", category: "Updates")
                .notice("Updates are inactive: configure SUFeedURL and SUPublicEDKey before distribution.")
            return
        }

        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
