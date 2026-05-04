import Foundation

enum CourseScheduleAuthError: Error {
    case landingPageFailed
    case tokenNotFound
}

actor CourseScheduleAuth {

    static let landingURL = URL(string:
        "https://mycollegess.cpcc.edu/Student/Student/Courses")!

    private var cachedToken: String?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func ensureToken() async throws -> String {
        if let t = cachedToken { return t }
        let (data, resp) = try await session.data(from: Self.landingURL)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw CourseScheduleAuthError.landingPageFailed
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw CourseScheduleAuthError.landingPageFailed
        }
        let needle = "name=\"__RequestVerificationToken\""
        guard let nameRange = html.range(of: needle) else { throw CourseScheduleAuthError.tokenNotFound }
        let after = html[nameRange.upperBound...]
        guard let valueRange = after.range(of: "value=\"") else { throw CourseScheduleAuthError.tokenNotFound }
        let valueStart = valueRange.upperBound
        guard let valueEnd = after[valueStart...].firstIndex(of: "\"") else {
            throw CourseScheduleAuthError.tokenNotFound
        }
        let token = String(after[valueStart..<valueEnd])
        cachedToken = token
        return token
    }

    func invalidate() {
        cachedToken = nil
    }
}
