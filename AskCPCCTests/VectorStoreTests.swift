@testable import AskCPCC
import XCTest

final class VectorStoreTests: XCTestCase {

    func testTopKReturnsHighestSimilarities() {
        let dim = 4
        let v1: [Float] = [1, 0, 0, 0]
        let v2: [Float] = [0, 1, 0, 0]
        let v3: [Float] = [0.7071, 0.7071, 0, 0]
        let raw: [Float] = v1 + v2 + v3

        let query: [Float] = [1, 0, 0, 0]
        let result = VectorStore.topK(query: query, raw.withUnsafeBufferPointer { $0.baseAddress! }, count: 3, dim: dim, k: 2)
        XCTAssertEqual(result.map(\.id), [0, 2])
        XCTAssertEqual(result[0].score, 1.0, accuracy: 0.01)
    }

    func testKLargerThanCountClampsToCount() {
        let v: [Float] = [1, 0]
        let result = VectorStore.topK(query: [1, 0], v.withUnsafeBufferPointer { $0.baseAddress! }, count: 1, dim: 2, k: 5)
        XCTAssertEqual(result.count, 1)
    }

    func testEmptyCorpusReturnsEmpty() {
        var dummy: Float = 0
        let result = withUnsafePointer(to: &dummy) { ptr in
            VectorStore.topK(query: [1, 0], ptr, count: 0, dim: 2, k: 5)
        }
        XCTAssertTrue(result.isEmpty)
    }
}
