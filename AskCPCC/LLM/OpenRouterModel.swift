import Foundation

struct OpenRouterModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let promptCostPerMTok: Double
    let completionCostPerMTok: Double

    static let all: [OpenRouterModel] = [
        OpenRouterModel(id: "anthropic/claude-haiku-4-5",
                        displayName: "Claude Haiku 4.5",
                        promptCostPerMTok: 1.00, completionCostPerMTok: 5.00),
        OpenRouterModel(id: "openai/gpt-4o-mini",
                        displayName: "GPT-4o mini",
                        promptCostPerMTok: 0.15, completionCostPerMTok: 0.60),
        OpenRouterModel(id: "google/gemini-2.5-flash",
                        displayName: "Gemini 2.5 Flash",
                        promptCostPerMTok: 0.30, completionCostPerMTok: 2.50),
        OpenRouterModel(id: "anthropic/claude-sonnet-4-6",
                        displayName: "Claude Sonnet 4.6",
                        promptCostPerMTok: 3.00, completionCostPerMTok: 15.00),
    ]

    static func find(id: String) -> OpenRouterModel? {
        all.first { $0.id == id }
    }
}
