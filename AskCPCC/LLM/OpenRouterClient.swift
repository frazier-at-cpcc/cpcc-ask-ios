import Foundation

enum OpenRouterError: Error, Equatable {
    case missingKey
    case invalidKey
    case rateLimited
    case server
    case network
    case malformedResponse
}

actor OpenRouterClient {

    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private let referer = "https://github.com/Frazier-at-CPCC/cpcc-ask-ios"
    private let title = "Ask CPCC"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(messages: [ChatMessage], modelId: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = URLRequest(url: endpoint)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
                    req.setValue(title, forHTTPHeaderField: "X-Title")

                    let body: [String: Any] = [
                        "model": modelId,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true,
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, resp) = try await session.bytes(for: req)
                    guard let http = resp as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenRouterError.network); return
                    }
                    if http.statusCode == 401 {
                        continuation.finish(throwing: OpenRouterError.invalidKey); return
                    }
                    if http.statusCode == 429 {
                        continuation.finish(throwing: OpenRouterError.rateLimited); return
                    }
                    if http.statusCode >= 500 {
                        continuation.finish(throwing: OpenRouterError.server); return
                    }
                    guard http.statusCode == 200 else {
                        continuation.finish(throwing: OpenRouterError.malformedResponse); return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8) else { continue }
                        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: OpenRouterError.network)
                }
            }
        }
    }
}
