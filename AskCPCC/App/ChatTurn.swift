import Foundation

enum ChatRole: String, Codable, Hashable {
    case system, user, assistant
}

struct ChatTurn: Identifiable, Hashable {
    let id: UUID
    let role: ChatRole
    var text: String
    var sources: [URL]
    var scheduleHits: [Section]
    var isStreaming: Bool

    init(id: UUID = UUID(), role: ChatRole, text: String,
         sources: [URL] = [], scheduleHits: [Section] = [], isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.sources = sources
        self.scheduleHits = scheduleHits
        self.isStreaming = isStreaming
    }
}
