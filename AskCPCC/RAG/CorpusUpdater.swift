import CryptoKit
import Foundation
import ZIPFoundation

struct LatestPointer: Decodable {
    let version: String
    let url: String
    let size: Int64
    let sha256: String
}

enum CorpusUpdaterError: Error {
    case fetchFailed
    case shaMismatch
    case unzipFailed
}

actor CorpusUpdater {

    static let pointerURL = URL(string:
        "https://raw.githubusercontent.com/Frazier-at-CPCC/cpcc-ask-ios/main/latest.json")!

    func updateIfNewer(localManifest: CorpusStore.Manifest?,
                       installInto directory: URL) async throws -> Bool {
        let pointer = try await fetchPointer()
        if pointer.version.isEmpty || pointer.url.isEmpty { return false }
        if let local = localManifest, local.version == pointer.version { return false }

        let zipURL = try await downloadZip(from: pointer)
        try verifySha(zipURL: zipURL, expected: pointer.sha256)
        try unzip(zipURL: zipURL, into: directory)
        try? FileManager.default.removeItem(at: zipURL)
        return true
    }

    private func fetchPointer() async throws -> LatestPointer {
        var req = URLRequest(url: Self.pointerURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw CorpusUpdaterError.fetchFailed
        }
        return try JSONDecoder().decode(LatestPointer.self, from: data)
    }

    private func downloadZip(from pointer: LatestPointer) async throws -> URL {
        guard let url = URL(string: pointer.url) else { throw CorpusUpdaterError.fetchFailed }
        let (downloaded, resp) = try await URLSession.shared.download(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw CorpusUpdaterError.fetchFailed
        }
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("corpus-\(pointer.version).zip")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: downloaded, to: dest)
        return dest
    }

    private func verifySha(zipURL: URL, expected: String) throws {
        let data = try Data(contentsOf: zipURL)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual.lowercased() == expected.lowercased() else {
            throw CorpusUpdaterError.shaMismatch
        }
    }

    private func unzip(zipURL: URL, into target: URL) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("corpus-staging-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipURL, to: tmp)

        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: tmp, to: target)
    }
}
