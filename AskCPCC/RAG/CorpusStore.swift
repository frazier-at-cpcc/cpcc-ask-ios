import Foundation
import SQLite3

enum CorpusError: Error {
    case missingFiles
    case openFailed(String)
    case statementFailed(String)
    case manifestMalformed
}

final class CorpusStore {

    let chunkCount: Int
    let manifest: Manifest

    private let db: OpaquePointer
    private let embeddingsHandle: FileHandle
    private let embeddingsData: Data

    static let dimension = 384

    struct Manifest: Decodable {
        let version: String
        let totalChunks: Int
        let embeddingDim: Int
        let buildTimestamp: String
    }

    init(directory: URL) throws {
        let dbURL = directory.appendingPathComponent("corpus.sqlite")
        let embURL = directory.appendingPathComponent("embeddings.bin")
        let manifestURL = directory.appendingPathComponent("manifest.json")

        guard FileManager.default.fileExists(atPath: dbURL.path),
              FileManager.default.fileExists(atPath: embURL.path),
              FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw CorpusError.missingFiles
        }

        self.manifest = try JSONDecoder().decode(Manifest.self, from: try Data(contentsOf: manifestURL))
        guard manifest.embeddingDim == Self.dimension else { throw CorpusError.manifestMalformed }
        self.chunkCount = manifest.totalChunks

        var handle: OpaquePointer?
        let status = sqlite3_open_v2(dbURL.path, &handle, SQLITE_OPEN_READONLY, nil)
        guard status == SQLITE_OK, let db = handle else {
            throw CorpusError.openFailed("sqlite3_open_v2 \(status)")
        }
        self.db = db

        self.embeddingsHandle = try FileHandle(forReadingFrom: embURL)
        self.embeddingsData = try Data(contentsOf: embURL, options: .alwaysMapped)
    }

    deinit {
        sqlite3_close(db)
    }

    func embedding(forChunkId id: Int64) -> [Float] {
        let zeroIndex = Int(id - 1)
        let offset = zeroIndex * Self.dimension * MemoryLayout<Float>.size
        var out = [Float](repeating: 0, count: Self.dimension)
        embeddingsData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let base = ptr.baseAddress!.advanced(by: offset).assumingMemoryBound(to: Float.self)
            for i in 0..<Self.dimension { out[i] = base[i] }
        }
        return out
    }

    func withEmbeddingsBuffer<T>(_ body: (UnsafePointer<Float>, Int) throws -> T) rethrows -> T {
        try embeddingsData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let base = ptr.baseAddress!.assumingMemoryBound(to: Float.self)
            return try body(base, chunkCount)
        }
    }

    func chunks(for ids: [Int64]) -> [Chunk] {
        guard !ids.isEmpty else { return [] }
        var statement: OpaquePointer?
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT id, source_url, title, text FROM chunks WHERE id IN (\(placeholders))"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        for (i, id) in ids.enumerated() {
            sqlite3_bind_int64(statement, Int32(i + 1), id)
        }

        var byId: [Int64: Chunk] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let cid = sqlite3_column_int64(statement, 0)
            let url = URL(string: String(cString: sqlite3_column_text(statement, 1))) ?? URL(string: "https://cpcc.edu/")!
            let title = String(cString: sqlite3_column_text(statement, 2))
            let text = String(cString: sqlite3_column_text(statement, 3))
            byId[cid] = Chunk(id: cid, sourceURL: url, title: title, text: text)
        }
        return ids.compactMap { byId[$0] }
    }
}
