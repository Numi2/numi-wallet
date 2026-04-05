import Foundation

extension Data {
    mutating func zeroize() {
        guard !isEmpty else { return }
        resetBytes(in: startIndex..<endIndex)
    }
}
