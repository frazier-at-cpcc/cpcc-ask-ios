import Foundation

struct SectionResult: Codable, Hashable {
    let courseCode: String
    let title: String
    let credits: Double
    let sections: [Section]
}
