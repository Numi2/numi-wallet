import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ScreenPrivacyMonitor {
    struct Event {
        var isCaptured: Bool
        var screenshotDetected: Bool
        var protectedDataWillBecomeUnavailable: Bool
    }

    private var observers: [NSObjectProtocol] = []
    private let onEvent: (Event) -> Void

    init(onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        #if canImport(UIKit)
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.emitCaptureState(screenshotDetected: false)
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.emitCaptureState(screenshotDetected: true)
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.emitCaptureState(
                        screenshotDetected: false,
                        protectedDataWillBecomeUnavailable: true
                    )
                }
            }
        )

        emitCaptureState(screenshotDetected: false, protectedDataWillBecomeUnavailable: false)
        #endif
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func emitCaptureState(screenshotDetected: Bool, protectedDataWillBecomeUnavailable: Bool = false) {
        #if canImport(UIKit)
        let captureState = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.screen.isCaptured }
        onEvent(
            Event(
                isCaptured: captureState,
                screenshotDetected: screenshotDetected,
                protectedDataWillBecomeUnavailable: protectedDataWillBecomeUnavailable
            )
        )
        #endif
    }
}
