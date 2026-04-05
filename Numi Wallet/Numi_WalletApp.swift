import SwiftUI

@main
struct Numi_WalletApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bootstrap = WalletBootstrapper()

    var body: some Scene {
        WindowGroup {
            WalletBootstrapRootView(bootstrap: bootstrap)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1480, height: 960)
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, bootstrap.supportsBackgroundRefresh {
                BackgroundRefreshCoordinator.shared.scheduleNextRefresh()
            }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefreshCoordinator.taskIdentifier)) {
            let supportsBackgroundRefresh = await MainActor.run { bootstrap.supportsBackgroundRefresh }
            guard supportsBackgroundRefresh else { return }
            await bootstrap.performBackgroundRefresh()
            BackgroundRefreshCoordinator.shared.scheduleNextRefresh()
        }
        #endif
    }
}
