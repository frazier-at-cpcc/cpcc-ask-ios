@testable import AskCPCC
import XCTest

final class PromptBuilderTests: XCTestCase {

    func testNoChunksOrSchedule_emitsSystemAndUserOnly() {
        let result = PromptBuilder.build(question: "Hi", chunks: [], sections: [], history: [],
                                         today: "2026-05-03")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].role, "system")
        XCTAssertTrue(result[0].content.contains("Today's date is 2026-05-03"))
        XCTAssertEqual(result[1].role, "user")
        XCTAssertEqual(result[1].content, "Hi")
    }

    func testChunksAreNumberedInContext() {
        let chunks = [
            Chunk(id: 1, sourceURL: URL(string: "https://cpcc.edu/a")!, title: "A", text: "alpha"),
            Chunk(id: 2, sourceURL: URL(string: "https://cpcc.edu/b")!, title: "B", text: "beta"),
        ]
        let result = PromptBuilder.build(question: "Q", chunks: chunks, sections: [], history: [],
                                         today: "2026-05-03")
        XCTAssertTrue(result[0].content.contains("[1]"))
        XCTAssertTrue(result[0].content.contains("[2]"))
        XCTAssertTrue(result[0].content.contains("alpha"))
        XCTAssertTrue(result[0].content.contains("beta"))
    }

    func testSectionsRenderInScheduleBlock() {
        let s = Section(id: "12345", courseCode: "ENG-111", title: "College Composition",
                        sectionNumber: "12345", term: "FALL2026", days: "MWF",
                        time: "9:00 AM - 9:50 AM", location: "Central, RM-204",
                        instructor: "Smith, J.", seatsOpen: 4, credits: 3.0)
        let result = PromptBuilder.build(question: "Q", chunks: [], sections: [s], history: [],
                                         today: "2026-05-03")
        XCTAssertTrue(result[0].content.contains("LIVE COURSE SCHEDULE"))
        XCTAssertTrue(result[0].content.contains("ENG-111"))
        XCTAssertTrue(result[0].content.contains("MWF"))
        XCTAssertTrue(result[0].content.contains("4 seats"))
    }

    func testHistoryAppearsBeforeCurrentQuestion() {
        let history: [ChatMessage] = [
            ChatMessage(role: "user", content: "earlier user"),
            ChatMessage(role: "assistant", content: "earlier reply"),
        ]
        let result = PromptBuilder.build(question: "now", chunks: [], sections: [], history: history,
                                         today: "2026-05-03")
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[1].role, "user")
        XCTAssertEqual(result[1].content, "earlier user")
        XCTAssertEqual(result[3].role, "user")
        XCTAssertEqual(result[3].content, "now")
    }
}
