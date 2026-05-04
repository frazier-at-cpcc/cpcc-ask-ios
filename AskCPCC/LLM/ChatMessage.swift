import Foundation

struct ChatMessage: Codable, Equatable {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}
