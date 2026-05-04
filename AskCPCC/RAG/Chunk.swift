import Foundation

struct Chunk: Hashable {
    let id: Int64
    let sourceURL: URL
    let title: String
    let text: String
    var score: Float = 0
}
