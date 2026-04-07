import Foundation

#if os(iOS)
import BackgroundTasks
#endif

actor TachyonProofContinuationCoordinator {
    static let shared = TachyonProofContinuationCoordinator()

    typealias WorkHandler = @Sendable (
        _ taskIdentifier: String,
        _ progressSink: @escaping @Sendable (TachyonProofProgress) async -> Void
    ) async throws -> TachyonProofArtifact

    private static let fallbackBundleIdentifier = "numi.Numi-Wallet"
    private var workHandler: WorkHandler?
    private var installed = false
    private var waiters: [String: [CheckedContinuation<TachyonProofArtifact, Error>]] = [:]
    private var completedResults: [String: Result<TachyonProofArtifact, Error>] = [:]

    static var wildcardIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier).tachyon-proof.*"
    }

    static func taskIdentifier(for jobID: UUID) -> String {
        "\(Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier).tachyon-proof.\(jobID.uuidString.lowercased())"
    }

    func installHandler(_ handler: @escaping WorkHandler) {
        workHandler = handler

        #if os(iOS)
        guard !installed else { return }
        guard #available(iOS 26.0, *) else { return }

        installed = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.wildcardIdentifier, using: nil) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await self.handle(continuedTask)
            }
        }
        #else
        installed = true
        #endif
    }

    func submit(
        taskIdentifier: String,
        title: String,
        subtitle: String,
        executionGrant: TachyonProofExecutionGrant
    ) async -> Bool {
        #if os(iOS)
        guard executionGrant.requiresContinuedProcessingTask else { return false }
        guard installed else { return false }
        guard #available(iOS 26.0, *) else { return false }

        let request = BGContinuedProcessingTaskRequest(
            identifier: taskIdentifier,
            title: title,
            subtitle: subtitle
        )
        request.strategy = .fail
        if executionGrant.permitsGPU, BGTaskScheduler.supportedResources.contains(.gpu) {
            request.requiredResources = .gpu
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            return true
        } catch {
            return false
        }
        #else
        _ = (taskIdentifier, title, subtitle, executionGrant)
        return false
        #endif
    }

    func awaitResult(for taskIdentifier: String) async throws -> TachyonProofArtifact {
        if let result = completedResults.removeValue(forKey: taskIdentifier) {
            return try result.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            waiters[taskIdentifier, default: []].append(continuation)
        }
    }

    private func finish(taskIdentifier: String, result: Result<TachyonProofArtifact, Error>) {
        if let continuations = waiters.removeValue(forKey: taskIdentifier), !continuations.isEmpty {
            for continuation in continuations {
                continuation.resume(with: result)
            }
            return
        }

        completedResults[taskIdentifier] = result
    }

    #if os(iOS)
    @available(iOS 26.0, *)
    private func handle(_ task: BGContinuedProcessingTask) async {
        guard let workHandler else {
            task.setTaskCompleted(success: false)
            finish(
                taskIdentifier: task.identifier,
                result: .failure(WalletError.resumableProofPending("No continued-processing proof handler is registered."))
            )
            return
        }

        task.progress.totalUnitCount = 1_000
        task.progress.completedUnitCount = 0

        let worker = Task {
            try await workHandler(task.identifier) { progress in
                Self.publish(progress, into: task)
            }
        }

        task.expirationHandler = {
            worker.cancel()
        }

        do {
            let artifact = try await worker.value
            task.setTaskCompleted(success: true)
            finish(taskIdentifier: task.identifier, result: .success(artifact))
        } catch {
            task.setTaskCompleted(success: false)
            finish(taskIdentifier: task.identifier, result: .failure(error))
        }
    }

    @available(iOS 26.0, *)
    private nonisolated static func publish(_ progress: TachyonProofProgress, into task: BGContinuedProcessingTask) {
        let clamped = max(0, min(progress.fractionCompleted, 1))
        task.progress.totalUnitCount = 1_000
        task.progress.completedUnitCount = Int64((clamped * 1_000).rounded())
        if let detail = progress.detail, !detail.isEmpty {
            task.updateTitle(task.title, subtitle: detail)
        }
    }
    #endif
}
