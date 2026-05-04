import Foundation

struct QueryResult {
    let chunks: [Chunk]
    let sections: [Section]
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

        var sections: [Section] = []
        if allowSchedule, case let .needsSchedule(code, subject) = intent {
            do {
                sections = try await schedule.searchSections(
                    courseCode: code, subject: subject)
            } catch {
                sections = []
            }
        }

        let today = dateFormatter.string(from: Date())
        let messages = PromptBuilder.build(question: question,
                                           chunks: chunks,
                                           sections: sections,
                                           history: history,
                                           today: today)
        let stream = await llm.stream(messages: messages, modelId: modelId, apiKey: apiKey)
        return QueryResult(chunks: chunks, sections: sections, stream: stream)
    }
}
