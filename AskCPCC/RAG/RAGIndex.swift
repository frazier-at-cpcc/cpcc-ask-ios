import Foundation

actor RAGIndex {

    enum State {
        case unloaded
        case ready
        case unavailable(reason: String)
    }

    private(set) var state: State = .unloaded
    private var store: CorpusStore?
    private let embedder: EmbeddingModel?

    init() {
        self.embedder = try? EmbeddingModel()
    }

    func load(from directory: URL) async {
        guard embedder != nil else {
            state = .unavailable(reason: "Embedding model failed to load")
            return
        }
        do {
            self.store = try CorpusStore(directory: directory)
            self.state = .ready
        } catch {
            self.state = .unavailable(reason: "\(error)")
        }
    }

    func search(_ query: String, k: Int = 6) async -> [Chunk] {
        guard let store, let embedder, case .ready = state else { return [] }
        let queryVec: [Float]
        do { queryVec = try embedder.encode(query) } catch { return [] }

        let hits = store.withEmbeddingsBuffer { ptr, count in
            VectorStore.topK(query: queryVec, ptr, count: count, dim: CorpusStore.dimension, k: k)
        }
        let ids = hits.map { Int64($0.id + 1) }
        var chunks = store.chunks(for: ids)
        for i in chunks.indices {
            if i < hits.count { chunks[i].score = hits[i].score }
        }
        return chunks
    }

    func currentManifest() -> CorpusStore.Manifest? {
        store?.manifest
    }
}
