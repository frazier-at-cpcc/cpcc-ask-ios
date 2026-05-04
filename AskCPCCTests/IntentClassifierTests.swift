@testable import AskCPCC
import XCTest

final class IntentClassifierTests: XCTestCase {

    func testCourseCodeTriggersScheduleIntent() {
        let r = IntentClassifier.classify("When does ENG 111 meet?")
        if case .needsSchedule(let code, _) = r {
            XCTAssertEqual(code, "ENG-111")
        } else {
            XCTFail("expected .needsSchedule")
        }
    }

    func testCourseCodeWithDashIsNormalized() {
        let r = IntentClassifier.classify("Who teaches MAT-271?")
        if case .needsSchedule(let code, _) = r {
            XCTAssertEqual(code, "MAT-271")
        } else { XCTFail() }
    }

    func testCourseCodeNoSpaceIsNormalized() {
        let r = IntentClassifier.classify("Show me CSC214 sections")
        if case .needsSchedule(let code, _) = r {
            XCTAssertEqual(code, "CSC-214")
        } else { XCTFail() }
    }

    func testKeywordTriggersScheduleIntent() {
        let r = IntentClassifier.classify("Are there any open sections this fall?")
        guard case .needsSchedule(_, _) = r else { XCTFail("expected .needsSchedule"); return }
    }

    func testPolicyQuestionStaysRagOnly() {
        let r = IntentClassifier.classify("What is CPCC's transfer policy?")
        guard case .ragOnly = r else { XCTFail("expected .ragOnly"); return }
    }

    func testGreetingStaysRagOnly() {
        let r = IntentClassifier.classify("Hi")
        guard case .ragOnly = r else { XCTFail("expected .ragOnly"); return }
    }
}
