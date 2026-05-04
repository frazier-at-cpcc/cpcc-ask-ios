import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {

    var turns: [ChatTurn]
    var inputText: String = ""
    var isStreaming: Bool = false
    var lastError: String?

    private let introTurn: ChatTurn

    init() {
        self.introTurn = ChatTurn(
            role: .system,
            text: "Hi! Ask about CPCC programs, courses, deadlines, anything.")
        self.turns = [introTurn]
    }

    func newChat() {
        turns = [introTurn]
        lastError = nil
    }

    func recentHistory() -> [ChatMessage] {
        let exchange = turns.filter { $0.role != .system }
        let pairs = stride(from: 0, to: exchange.count, by: 2).map {
            Array(exchange[$0..<min($0 + 2, exchange.count)])
        }
        let lastFour = pairs.suffix(4)
        return lastFour.flatMap { pair in
            pair.map { ChatMessage(role: $0.role.rawValue, content: $0.text) }
        }
    }

    func send(orchestrator: QueryOrchestrator,
              modelId: String,
              apiKey: String,
              allowSchedule: Bool) async {

        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        inputText = ""

        let userTurn = ChatTurn(role: .user, text: question)
        let assistantTurn = ChatTurn(role: .assistant, text: "", isStreaming: true)
        turns.append(userTurn)
        turns.append(assistantTurn)
        let assistantId = assistantTurn.id
        isStreaming = true
        lastError = nil

        let history = recentHistory().dropLast(2)

        do {
            let result = try await orchestrator.answer(
                question: question,
                history: Array(history),
                modelId: modelId,
                apiKey: apiKey,
                allowSchedule: allowSchedule)

            for try await token in result.stream {
                if let idx = turns.firstIndex(where: { $0.id == assistantId }) {
                    turns[idx].text += token
                }
            }

            if let idx = turns.firstIndex(where: { $0.id == assistantId }) {
                turns[idx].isStreaming = false
                var seen = Set<URL>()
                turns[idx].sources = result.chunks.map(\.sourceURL).filter { seen.insert($0).inserted }
                turns[idx].scheduleHits = result.sections
            }
            switch result.scheduleStatus {
            case .error(let detail):
                lastError = "Live schedule unreachable: \(detail)"
            case .noResults(let q):
                lastError = "Live schedule returned no sections for \"\(q)\"."
            case .ok, .skipped:
                break
            }
        } catch let err {
            if let idx = turns.firstIndex(where: { $0.id == assistantId }) {
                turns[idx].isStreaming = false
                turns[idx].text = "Sorry — \(friendlyError(err))"
            }
            lastError = friendlyError(err)
        }
        isStreaming = false
    }

    private func friendlyError(_ err: Error) -> String {
        if let e = err as? OpenRouterError {
            switch e {
            case .invalidKey: return "your API key seems wrong. Update in Settings."
            case .rateLimited: return "rate limited by OpenRouter. Try again in a moment."
            case .server: return "OpenRouter is having trouble. Try again."
            case .network: return "no connection — check Wi-Fi."
            case .missingKey: return "no API key set. Add one in Settings."
            case .malformedResponse: return "OpenRouter returned an unexpected response."
            }
        }
        return "something went wrong: \(err)"
    }
}
