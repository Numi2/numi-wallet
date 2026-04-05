import SwiftUI

struct WalletBootstrapRootView: View {
    @ObservedObject var bootstrap: WalletBootstrapper

    var body: some View {
        switch bootstrap.state {
        case .ready(let model):
            NumiRootExperienceView(model: model)
        case .failed(let fault):
            WalletBootstrapFailureView(fault: fault)
        }
    }
}

struct WalletBootstrapFailureView: View {
    let fault: WalletBootstrapFault

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.16, green: 0.09, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                Label("Sovereign Bootstrap Halted", systemImage: "exclamationmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))

                Text(fault.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(fault.detail)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.84))

                Divider()
                    .overlay(Color.white.opacity(0.14))

                Text(fault.recoverySuggestion)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(28)
            .frame(maxWidth: 620, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .padding(24)
        }
    }
}
