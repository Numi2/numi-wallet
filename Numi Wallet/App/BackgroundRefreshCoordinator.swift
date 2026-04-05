import Foundation

#if os(iOS)
import BackgroundTasks
#endif

final class BackgroundRefreshCoordinator {
    static let shared = BackgroundRefreshCoordinator()
    static var taskIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "numi.Numi-Wallet").pir-refresh"
    }

    private init() {}

    func scheduleNextRefresh(after interval: TimeInterval = 15 * 60) {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
}
