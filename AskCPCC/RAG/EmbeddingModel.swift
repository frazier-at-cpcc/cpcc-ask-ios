import CoreML
import Foundation

enum EmbeddingError: Error {
    case modelLoadFailed
    case tokenizerLoadFailed
    case predictionFailed
}

final class EmbeddingModel {

    static let dimension = 384
    private let model: MLModel
    private let tokenizer: BertWordPieceTokenizer
    private let maxLen = 256

    init() throws {
        guard let modelURL = Bundle.main.url(forResource: "BGEEmbedder", withExtension: "mlpackage") else {
            throw EmbeddingError.modelLoadFailed
        }
        let compiled = try MLModel.compileModel(at: modelURL)
        self.model = try MLModel(contentsOf: compiled)

        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt") else {
            throw EmbeddingError.tokenizerLoadFailed
        }
        self.tokenizer = try BertWordPieceTokenizer(vocabURL: vocabURL, maxLen: maxLen)
    }

    func encode(_ text: String) throws -> [Float] {
        let (ids, mask) = tokenizer.encode(text)
        let idsArray = try MLMultiArray(shape: [1, NSNumber(value: maxLen)], dataType: .int32)
        let maskArray = try MLMultiArray(shape: [1, NSNumber(value: maxLen)], dataType: .int32)
        for i in 0..<maxLen {
            idsArray[i] = NSNumber(value: ids[i])
            maskArray[i] = NSNumber(value: mask[i])
        }

        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": idsArray,
            "attention_mask": maskArray,
        ])
        let result = try model.prediction(from: input)
        guard let arr = result.featureValue(for: "sentence_embedding")?.multiArrayValue else {
            throw EmbeddingError.predictionFailed
        }
        var out = [Float](repeating: 0, count: Self.dimension)
        for i in 0..<Self.dimension {
            out[i] = arr[i].floatValue
        }
        return out
    }
}
