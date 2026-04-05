import SwiftUI

@main
struct Numi_WalletApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = WalletAppModel()

    var body: some Scene {
        WindowGroup {
            NumiRootExperienceView(model: model)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1480, height: 960)
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, model.supportsBackgroundRefresh {
                BackgroundRefreshCoordinator.shared.scheduleNextRefresh()
            }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefreshCoordinator.taskIdentifier)) {
            let supportsBackgroundRefresh = await MainActor.run { model.supportsBackgroundRefresh }
            guard supportsBackgroundRefresh else { return }
            await model.performBackgroundRefresh()
            BackgroundRefreshCoordinator.shared.scheduleNextRefresh()
        }
        #endif
    }
}
