import Combine
import Foundation

@MainActor
final class WalletBootstrapper: ObservableObject {
    enum State {
        case ready(WalletAppModel)
        case failed(WalletBootstrapFault)
    }

    @Published private(set) var state: State

    init(bundle: Bundle = .main, manifestLoader: CoinManifestLoader = CoinManifestLoader()) {
        do {
            let manifest = try manifestLoader.load(from: bundle)
            self.state = .ready(WalletAppModel(configuration: manifest.configuration))
        } catch {
            self.state = .failed(WalletBootstrapFault(error: error))
        }
    }

    var activeModel: WalletAppModel? {
        guard case let .ready(model) = state else {
            return nil
        }
        return model
    }

    var supportsBackgroundRefresh: Bool {
        activeModel?.supportsBackgroundRefresh ?? false
    }

    func performBackgroundRefresh() async {
        guard let model = activeModel else {
            return
        }
        await model.performBackgroundRefresh()
    }
}

struct WalletBootstrapFault: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
    let recoverySuggestion: String

    init(error: Error) {
        if let manifestError = error as? CoinManifestError {
            self.title = "Signed Coin Manifest Failed Verification"
            self.detail = manifestError.errorDescription ?? "Bundled manifest verification failed."
        } else {
            self.title = "Wallet Bootstrap Failed"
            self.detail = error.localizedDescription
        }
        self.recoverySuggestion = "Install a signed build with a valid bundled coin manifest before using Numi."
    }
}
