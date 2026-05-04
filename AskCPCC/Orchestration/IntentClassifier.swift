import Foundation

enum Intent {
    case ragOnly
    case needsSchedule(courseCode: String?, subject: String?)
}

enum IntentClassifier {

    private static let scheduleKeywords: [String] = [
        "section", "sections", "meets", "meeting time", "schedule",
        "seats", "open seats", "register for", "available", "who teaches",
        "instructor for",
    ]

    static func classify(_ question: String) -> Intent {
        let q = question.lowercased()

        if let code = extractCourseCode(question) {
            return .needsSchedule(courseCode: code, subject: nil)
        }
        for kw in scheduleKeywords {
            if q.contains(kw) {
                return .needsSchedule(courseCode: nil, subject: nil)
            }
        }
        return .ragOnly
    }

    private static func extractCourseCode(_ s: String) -> String? {
        let pattern = #"\b([A-Z]{2,4})[\s\-]?(\d{2,3})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nss = s as NSString
        let range = NSRange(location: 0, length: nss.length)
        guard let m = regex.firstMatch(in: s, range: range), m.numberOfRanges == 3 else { return nil }
        let prefix = nss.substring(with: m.range(at: 1))
        let number = nss.substring(with: m.range(at: 2))
        return "\(prefix)-\(number)"
    }
}
