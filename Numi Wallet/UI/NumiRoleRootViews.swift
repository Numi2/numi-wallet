import SwiftUI

struct NumiRootExperienceView: View {
    @ObservedObject var model: WalletAppModel

    var body: some View {
        switch model.role {
        case .authorityPhone:
            NumiAuthorityPhoneRootView(model: model)
        case .recoveryPad:
            NumiRecoveryPeerRootView(model: model)
        case .recoveryMac:
            NumiMacPeerConsoleView(model: model)
        }
    }
}

struct NumiAuthorityPhoneRootView: View {
    @ObservedObject var model: WalletAppModel

    var body: some View {
        WalletDashboardView(model: model, initialDeck: .wallet)
    }
}

struct NumiRecoveryPeerRootView: View {
    @ObservedObject var model: WalletAppModel

    var body: some View {
        WalletDashboardView(model: model, initialDeck: .custody)
    }
}

struct NumiMacPeerConsoleView: View {
    @ObservedObject var model: WalletAppModel

    var body: some View {
        NumiMacConsoleView(model: model)
    }
}
