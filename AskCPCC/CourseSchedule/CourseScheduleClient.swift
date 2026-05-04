import Foundation

enum CourseScheduleError: Error {
    case requestFailed
    case malformedResponse
}

actor CourseScheduleClient {

    static let endpoint = URL(string:
        "https://mycollegess.cpcc.edu/Student/Student/Courses/PostSearchCriteria")!

    private let auth: CourseScheduleAuth
    private let session: URLSession

    init(auth: CourseScheduleAuth = CourseScheduleAuth(), session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    func searchSections(courseCode: String? = nil,
                        subject: String? = nil,
                        keyword: String? = nil,
                        termId: String? = nil) async throws -> [Section] {
        var token = try await auth.ensureToken()

        var attempt = 0
        while attempt < 2 {
            attempt += 1
            var req = URLRequest(url: Self.endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(token, forHTTPHeaderField: "__RequestVerificationToken")

            var body: [String: Any] = [:]
            if let courseCode { body["keyword"] = courseCode }
            if let subject { body["subjectCode"] = subject }
            if let keyword { body["keyword"] = keyword }
            if let termId { body["termId"] = termId }
            body["openSectionsOnly"] = false
            body["pageSize"] = 25
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw CourseScheduleError.requestFailed }
            if http.statusCode == 401 || http.statusCode == 302 {
                await auth.invalidate()
                token = try await auth.ensureToken()
                continue
            }
            guard http.statusCode == 200 else { throw CourseScheduleError.requestFailed }
            return try parse(data)
        }
        throw CourseScheduleError.requestFailed
    }

    private func parse(_ data: Data) throws -> [Section] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CourseScheduleError.malformedResponse
        }
        let listings = (obj["SectionListings"] as? [[String: Any]])
            ?? (obj["sectionListings"] as? [[String: Any]])
            ?? (obj["sections"] as? [[String: Any]])
            ?? []

        var out: [Section] = []
        for raw in listings {
            let id = (raw["Id"] as? String) ?? (raw["id"] as? String) ?? UUID().uuidString
            let courseCode = (raw["CourseDisplayName"] as? String)
                ?? (raw["courseCode"] as? String)
                ?? "?"
            let title = (raw["CourseTitle"] as? String)
                ?? (raw["title"] as? String) ?? ""
            let sectionNumber = (raw["Number"] as? String)
                ?? (raw["sectionNumber"] as? String) ?? ""
            let term = (raw["TermId"] as? String) ?? (raw["term"] as? String) ?? ""
            let days = (raw["Days"] as? String) ?? ""
            let time = (raw["Time"] as? String) ?? "TBA"
            let location = (raw["Location"] as? String) ?? ""
            let instructor = (raw["Instructor"] as? String) ?? ""
            let seats = (raw["AvailableSeats"] as? Int) ?? -1
            let credits = (raw["Credits"] as? Double) ?? 0

            out.append(Section(id: id, courseCode: courseCode, title: title,
                               sectionNumber: sectionNumber, term: term, days: days,
                               time: time, location: location, instructor: instructor,
                               seatsOpen: seats, credits: credits))
        }
        return out
    }
}
