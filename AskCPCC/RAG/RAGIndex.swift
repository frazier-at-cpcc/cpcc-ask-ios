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

        // Over-fetch so we can drop archived-catalog chunks and still return k results.
        let overFetch = max(k * 4, 24)
        let hits = store.withEmbeddingsBuffer { ptr, count in
            VectorStore.topK(query: queryVec, ptr, count: count, dim: CorpusStore.dimension, k: overFetch)
        }
        let ids = hits.map { Int64($0.id + 1) }
        var chunks = store.chunks(for: ids)
        for i in chunks.indices {
            if i < hits.count { chunks[i].score = hits[i].score }
        }
        let filtered = chunks.filter { !Self.isArchivedSource($0.sourceURL) }
        return Array(filtered.prefix(k))
    }

    // Year-stamped catalog filenames are inherently archival, e.g.
    //   /archives/2006-07.pdf, /archives/2014-15.pdf, /pdf/2013-14.pdf, /catalog/2018.pdf
    private static let archivedFilenameRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(?:^|/)(?:19|20)\d{2}(?:[-_]\d{2,4})?\.pdf$"#,
                                 options: [.caseInsensitive])
    }()

    private static func isArchivedSource(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        if path.contains("/archives/") || path.contains("/archive/") {
            return true
        }
        if let rx = archivedFilenameRegex {
            let range = NSRange(path.startIndex..<path.endIndex, in: path)
            if rx.firstMatch(in: path, range: range) != nil { return true }
        }
        return false
    }

    func currentManifest() -> CorpusStore.Manifest? {
        store?.manifest
    }
}
