import CryptoKit
import Foundation
import Metal

private actor TachyonProofProgressBuffer {
    private var entries: [TachyonProofProgress] = []

    func append(
        _ progress: TachyonProofProgress,
        sink: (@Sendable (TachyonProofProgress) async -> Void)?
    ) async {
        entries.append(progress)
        if let sink {
            await sink(progress)
        }
    }

    func snapshot() -> [TachyonProofProgress] {
        entries
    }
}

actor LocalProver {
    private let device: MTLDevice?
    private let pipelineState: MTLComputePipelineState?
    private let compatibilityAdapter = RaguTachyonProofAdapter()

    init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.device = device
        self.pipelineState = LocalProver.makePipelineState(device: device)
    }

    func prove(
        job: TachyonProofJob,
        policy: ProofPolicy,
        pairedMacAvailable: Bool,
        progressSink: (@Sendable (TachyonProofProgress) async -> Void)? = nil
    ) async throws -> TachyonProofArtifact {
        let start = Date()
        let progressBuffer = TachyonProofProgressBuffer()

        @Sendable func emit(
            phase: TachyonProofProgressPhase,
            fractionCompleted: Double,
            detail: String,
            at timestamp: Date = Date()
        ) async {
            let progress = TachyonProofProgress(
                phase: phase,
                fractionCompleted: fractionCompleted,
                updatedAt: timestamp,
                detail: detail
            )
            await progressBuffer.append(progress, sink: progressSink)
        }

        await emit(
            phase: .prepared,
            fractionCompleted: 0.05,
            detail: "Proof job sealed for the iPhone lane.",
            at: start
        )
        await emit(
            phase: .witnessBound,
            fractionCompleted: 0.18,
            detail: "Witness digests bound to the Tachyon transcript."
        )

        let seed = TachyonSupport.digest(
            job.jobDigest,
            job.transcriptDigest,
            job.witnessDigest,
            job.quoteBindingDigest ?? Data()
        )
        let venue: String
        let backend: TachyonProofBackendKind
        let proofSeed: Data
        let usedGPU: Bool

        if let device,
           let pipelineState,
           let metalDigest = try metalDigest(
               seed: seed,
               rounds: job.rounds,
               device: device,
               pipelineState: pipelineState
           )
        {
            proofSeed = metalDigest
            usedGPU = true
            backend = .metalFallback
            if pairedMacAvailable && policy == .pairedMacPreferred {
                venue = "Metal fallback; paired Mac policy ignored for the iPhone-only proof lane"
            } else {
                venue = "Metal fallback"
            }
            await emit(
                phase: .accumulated,
                fractionCompleted: job.compressionMode == .compressed ? 0.86 : 1.0,
                detail: "Recursive work completed on \(venue)."
            )
        } else {
            proofSeed = try await cpuDigest(seed: seed, rounds: job.rounds) { fractionCompleted in
                await emit(
                    phase: .accumulated,
                    fractionCompleted: 0.18 + (fractionCompleted * 0.64),
                    detail: "Recursive work \(Int((fractionCompleted * 100).rounded()))% complete on CPU fallback."
                )
            }
            usedGPU = false
            backend = .cpuFallback
            venue = "CPU fallback"
            await emit(
                phase: .accumulated,
                fractionCompleted: job.compressionMode == .compressed ? 0.86 : 1.0,
                detail: "Recursive work completed on \(venue)."
            )
        }

        let proofLength = job.compressionMode == .compressed ? 96 : 768
        let proofData = TachyonSupport.syntheticProofData(seed: proofSeed, length: proofLength)
        let proofDigest = TachyonSupport.digest(proofData)
        let artifactDigest = TachyonSupport.artifactDigest(
            jobDigest: job.jobDigest,
            proofDigest: proofDigest,
            transcriptDigest: job.transcriptDigest,
            backend: backend,
            compressionMode: job.compressionMode
        )
        let completedAt = Date()
        if job.compressionMode == .compressed {
            await emit(
                phase: .compressed,
                fractionCompleted: 1.0,
                detail: "Compressed at the relay boundary for transmission.",
                at: completedAt
            )
        }
        let progressTimeline = await progressBuffer.snapshot()

        return TachyonProofArtifact(
            jobID: job.id,
            requestedJobDigest: job.jobDigest,
            backend: backend,
            lane: job.lane,
            compressionMode: job.compressionMode,
            compressionBoundary: job.compressionBoundary,
            walletStateDigest: job.walletStateDigest,
            transactionDraftDigest: job.transactionDraftDigest,
            witnessDigest: job.witnessDigest,
            quoteBindingDigest: job.quoteBindingDigest,
            transcriptDigest: job.transcriptDigest,
            proofDigest: proofDigest,
            artifactDigest: artifactDigest,
            proofData: proofData,
            progress: progressTimeline,
            metrics: TachyonProofMetrics(
                rounds: job.rounds,
                witnessBytes: job.witnessRequirements.count * 96,
                proofBytes: proofData.count,
                compressedProofBytes: job.compressionMode == .compressed ? proofData.count : nil,
                usedGPU: usedGPU
            ),
            verificationStatus: .unverified,
            completedAt: completedAt
        )
    }

    func prove(job: LocalProofJob, policy: ProofPolicy, pairedMacAvailable: Bool) async throws -> LocalProofArtifact {
        let tachyonJob = try compatibilityAdapter.makeCompatibilityJob(from: job)
        let artifact = try await prove(job: tachyonJob, policy: policy, pairedMacAvailable: pairedMacAvailable)
        let verified = try compatibilityAdapter.verify(artifact, for: tachyonJob)
        return compatibilityAdapter.localArtifact(from: verified)
    }

    private func cpuDigest(
        seed: Data,
        rounds: Int,
        progressSink: @escaping @Sendable (Double) async -> Void
    ) async throws -> Data {
        var accumulator = seed
        let progressInterval = max(1, rounds / 12)
        for round in 0..<rounds {
            try Task.checkCancellation()
            accumulator = Data(SHA256.hash(data: accumulator + withUnsafeBytes(of: UInt32(round).littleEndian, Array.init)))
            let completedRounds = round + 1
            if completedRounds == rounds || completedRounds.isMultiple(of: progressInterval) {
                await progressSink(Double(completedRounds) / Double(max(rounds, 1)))
            }
        }
        return Data(SHA256.hash(data: accumulator))
    }

    private func metalDigest(
        seed: Data,
        rounds: Int,
        device: MTLDevice,
        pipelineState: MTLComputePipelineState
    ) throws -> Data? {
        var words = seed.withUnsafeBytes { rawBuffer -> [UInt32] in
            let byteCount = rawBuffer.count
            let paddedCount = ((byteCount + 3) / 4) * 4
            var buffer = Data(count: paddedCount)
            buffer.replaceSubrange(0..<byteCount, with: rawBuffer)
            return buffer.withUnsafeBytes { alignedBuffer in
                Array(alignedBuffer.bindMemory(to: UInt32.self))
            }
        }
        if words.isEmpty {
            words = [0]
        }

        guard
            let commandQueue = device.makeCommandQueue(),
            let inputBuffer = device.makeBuffer(bytes: words, length: words.count * MemoryLayout<UInt32>.stride),
            let outputBuffer = device.makeBuffer(length: words.count * MemoryLayout<UInt32>.stride)
        else {
            return nil
        }

        var rounds = UInt32(rounds)
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBytes(&rounds, length: MemoryLayout<UInt32>.stride, index: 2)

        let width = pipelineState.threadExecutionWidth
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (words.count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let output = Data(bytes: outputBuffer.contents(), count: words.count * MemoryLayout<UInt32>.stride)
        return Data(SHA256.hash(data: output))
    }

    private static func makePipelineState(device: MTLDevice?) -> MTLComputePipelineState? {
        guard let device else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void numi_mix(
            device const uint *input [[buffer(0)]],
            device uint *output [[buffer(1)]],
            constant uint &rounds [[buffer(2)]],
            uint gid [[thread_position_in_grid]]
        ) {
            uint value = input[gid];
            for (uint round = 0; round < rounds; ++round) {
                value = (value << 5) ^ (value >> 3) ^ (0x9e3779b9u + round);
            }
            output[gid] = value;
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let function = library.makeFunction(name: "numi_mix") else { return nil }
            return try device.makeComputePipelineState(function: function)
        } catch {
            return nil
        }
    }
}
