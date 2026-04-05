//
//  ContentView.swift
//  Numi Wallet
//
//  Created by T on 4/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bootstrap = WalletBootstrapper()

    var body: some View {
        WalletBootstrapRootView(bootstrap: bootstrap)
    }
}

#Preview {
    NumiRootExperienceView(model: WalletAppModel.preview())
}
