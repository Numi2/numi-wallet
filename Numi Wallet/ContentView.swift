//
//  ContentView.swift
//  Numi Wallet
//
//  Created by T on 4/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = WalletAppModel()

    var body: some View {
        NumiRootExperienceView(model: model)
    }
}

#Preview {
    ContentView()
}
