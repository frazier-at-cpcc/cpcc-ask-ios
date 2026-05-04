import Foundation

enum ScheduleStatus {
    case skipped
    case ok([Section])
    case noResults(query: String)
    case error(String)
}

struct QueryResult {
    let chunks: [Chunk]
    let sections: [Section]
    let scheduleStatus: ScheduleStatus
    let stream: AsyncThrowingStream<String, Error>
}

actor QueryOrchestrator {

    private let rag: RAGIndex
    private let schedule: CourseScheduleClient
    private let llm: OpenRouterClient
    private let dateFormatter: DateFormatter

    init(rag: RAGIndex, schedule: CourseScheduleClient, llm: OpenRouterClient) {
        self.rag = rag
        self.schedule = schedule
        self.llm = llm
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        self.dateFormatter = f
    }

    func answer(question: String,
                history: [ChatMessage],
                modelId: String,
                apiKey: String,
                allowSchedule: Bool) async throws -> QueryResult {

        let intent = IntentClassifier.classify(question)
        let chunks = await rag.search(question, k: 6)

        var status: ScheduleStatus = .skipped
        if allowSchedule, case let .needsSchedule(code, subject) = intent {
            let label = code ?? subject ?? question
            do {
                let found = try await schedule.searchSections(
                    courseCode: code, subject: subject)
                status = found.isEmpty ? .noResults(query: label) : .ok(found)
            } catch {
                status = .error(String(describing: error))
            }
        }

        let sections: [Section]
        if case let .ok(s) = status { sections = s } else { sections = [] }

        let today = dateFormatter.string(from: Date())
        let messages = PromptBuilder.build(question: question,
                                           chunks: chunks,
                                           scheduleStatus: status,
                                           history: history,
                                           today: today)
        let stream = await llm.stream(messages: messages, modelId: modelId, apiKey: apiKey)
        return QueryResult(chunks: chunks, sections: sections,
                           scheduleStatus: status, stream: stream)
    }
}
