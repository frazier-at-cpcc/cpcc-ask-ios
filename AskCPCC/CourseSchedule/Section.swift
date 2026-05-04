import Foundation

struct Section: Codable, Hashable, Identifiable {
    let id: String
    let courseCode: String
    let title: String
    let sectionNumber: String
    let term: String
    let days: String
    let time: String
    let location: String
    let instructor: String
    let seatsOpen: Int
    let credits: Double
}
