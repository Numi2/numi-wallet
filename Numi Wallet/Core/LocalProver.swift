import CryptoKit
import Foundation
import Metal

actor LocalProver {
    private let device: MTLDevice?
    private let pipelineState: MTLComputePipelineState?

    init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.device = device
        self.pipelineState = LocalProver.makePipelineState(device: device)
    }

    func prove(job: LocalProofJob, policy: ProofPolicy, pairedMacAvailable: Bool) async throws -> LocalProofArtifact {
        let start = Date()
        let venue: String
        let digest: Data

        if let device, let pipelineState, let metalDigest = try metalDigest(for: job, device: device, pipelineState: pipelineState) {
            digest = metalDigest
            if pairedMacAvailable && policy == .pairedMacPreferred {
                venue = "Metal local path; paired Mac lane armed"
            } else {
                venue = "Metal local path"
            }
        } else {
            digest = cpuDigest(for: job)
            venue = "CPU fallback"
        }

        return LocalProofArtifact(
            jobID: job.id,
            venue: venue,
            duration: Date().timeIntervalSince(start),
            digest: digest,
            completedAt: Date()
        )
    }

    private func cpuDigest(for job: LocalProofJob) -> Data {
        var accumulator = job.witness
        for round in 0..<job.rounds {
            accumulator = Data(SHA256.hash(data: accumulator + withUnsafeBytes(of: UInt32(round).littleEndian, Array.init)))
        }
        return Data(SHA256.hash(data: accumulator))
    }

    private func metalDigest(
        for job: LocalProofJob,
        device: MTLDevice,
        pipelineState: MTLComputePipelineState
    ) throws -> Data? {
        var words = job.witness.withUnsafeBytes { rawBuffer -> [UInt32] in
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

        var rounds = UInt32(job.rounds)
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
