import Foundation

enum PromptBuilder {

    static let systemPrompt = """
    You are Ask CPCC, an assistant that answers questions about Central Piedmont Community College using only the provided context. Cite sources at the end of each claim using [n] markers matching the context entries below. If the answer isn't in the context, say so — don't fabricate. Keep answers concise (under 200 words unless the question demands detail).
    """

    static func build(question: String,
                      chunks: [Chunk],
                      scheduleStatus: ScheduleStatus,
                      history: [ChatMessage],
                      today: String) -> [ChatMessage] {

        var system = "\(systemPrompt) Today's date is \(today)."

        if !chunks.isEmpty {
            system += "\n\nCONTEXT:\n"
            for (i, c) in chunks.enumerated() {
                system += "[\(i + 1)] \(c.text)\n    Source: \(c.sourceURL.absoluteString)\n"
            }
        }

        switch scheduleStatus {
        case .skipped:
            break
        case .ok(let sections):
            system += "\n\nLIVE COURSE SCHEDULE:\n"
            for (i, s) in sections.enumerated() {
                let seats = s.seatsOpen >= 0 ? "\(s.seatsOpen) seats" : "FULL"
                system += "[s\(i + 1)] \(s.courseCode) — \(s.title) (\(s.credits) credits)\n"
                system += "    Section \(s.sectionNumber): \(s.days) \(s.time), \(s.location), \(s.instructor), \(seats)\n"
            }
        case .noResults(let query):
            system += "\n\nLIVE COURSE SCHEDULE: attempted lookup for \"\(query)\" but the live schedule returned no current sections. Tell the user the live schedule had no matching sections right now and suggest they check the official schedule directly. Do not fabricate sections, seats, or times."
        case .error(let detail):
            system += "\n\nLIVE COURSE SCHEDULE: live lookup failed (\(detail)). Tell the user the live schedule is temporarily unreachable and suggest they check the official schedule directly. Do not fabricate sections, seats, or times."
        }

        var msgs: [ChatMessage] = [ChatMessage(role: "system", content: system)]
        msgs.append(contentsOf: history)
        msgs.append(ChatMessage(role: "user", content: question))
        return msgs
    }
}
