import Foundation

final class BertWordPieceTokenizer {

    private let vocab: [String: Int32]
    private let unkId: Int32
    private let clsId: Int32
    private let sepId: Int32
    private let padId: Int32
    private let maxLen: Int

    init(vocabURL: URL, maxLen: Int = 256) throws {
        let raw = try String(contentsOf: vocabURL, encoding: .utf8)
        var dict: [String: Int32] = [:]
        for (i, line) in raw.split(separator: "\n").enumerated() {
            dict[String(line)] = Int32(i)
        }
        self.vocab = dict
        self.unkId = dict["[UNK]"] ?? 100
        self.clsId = dict["[CLS]"] ?? 101
        self.sepId = dict["[SEP]"] ?? 102
        self.padId = dict["[PAD]"] ?? 0
        self.maxLen = maxLen
    }

    func encode(_ text: String) -> (ids: [Int32], mask: [Int32]) {
        let lowered = text.lowercased()
        let tokens = basicTokenize(lowered).flatMap { wordPiece($0) }
        var ids: [Int32] = [clsId]
        for token in tokens {
            if ids.count >= maxLen - 1 { break }
            ids.append(vocab[token] ?? unkId)
        }
        ids.append(sepId)
        let attention = ids.count
        while ids.count < maxLen { ids.append(padId) }
        var mask = [Int32](repeating: 0, count: maxLen)
        for i in 0..<attention { mask[i] = 1 }
        return (ids, mask)
    }

    private func basicTokenize(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in text {
            if ch.isWhitespace {
                if !current.isEmpty { out.append(current); current = "" }
            } else if ch.isPunctuation {
                if !current.isEmpty { out.append(current); current = "" }
                out.append(String(ch))
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private func wordPiece(_ word: String) -> [String] {
        if vocab[word] != nil { return [word] }
        var subTokens: [String] = []
        var start = word.startIndex
        while start < word.endIndex {
            var end = word.endIndex
            var cur: String?
            while start < end {
                var sub = String(word[start..<end])
                if start != word.startIndex { sub = "##" + sub }
                if vocab[sub] != nil { cur = sub; break }
                end = word.index(before: end)
            }
            guard let token = cur else { return ["[UNK]"] }
            subTokens.append(token)
            start = end
        }
        return subTokens
    }
}
