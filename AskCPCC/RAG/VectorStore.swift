import Accelerate
import Foundation

enum VectorStore {

    struct Hit {
        let id: Int
        let score: Float
    }

    static func topK(query: [Float],
                     _ embeddings: UnsafePointer<Float>,
                     count: Int,
                     dim: Int,
                     k: Int) -> [Hit] {
        guard count > 0, k > 0, dim > 0 else { return [] }
        guard query.count == dim else { return [] }

        var scores = [Float](repeating: 0, count: count)
        query.withUnsafeBufferPointer { qPtr in
            for i in 0..<count {
                let row = embeddings.advanced(by: i * dim)
                var s: Float = 0
                vDSP_dotpr(qPtr.baseAddress!, 1, row, 1, &s, vDSP_Length(dim))
                scores[i] = s
            }
        }

        let kEff = min(k, count)
        let indexed = scores.enumerated().map { (id: $0.offset, score: $0.element) }
        let sorted = indexed.sorted { $0.score > $1.score }
        return sorted.prefix(kEff).map { Hit(id: $0.id, score: $0.score) }
    }
}
