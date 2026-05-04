@testable import AskCPCC
import XCTest

@MainActor
final class ChatViewModelTests: XCTestCase {

    func testInitialStateHasIntroTurn() {
        let vm = ChatViewModel()
        XCTAssertEqual(vm.turns.count, 1)
        XCTAssertEqual(vm.turns[0].role, .system)
    }

    func testNewChatResetsTurns() {
        let vm = ChatViewModel()
        vm.turns.append(ChatTurn(role: .user, text: "Hi"))
        vm.newChat()
        XCTAssertEqual(vm.turns.count, 1)
        XCTAssertEqual(vm.turns[0].role, .system)
    }

    func testHistoryReturnsLastFourPairs() {
        let vm = ChatViewModel()
        for i in 0..<10 {
            vm.turns.append(ChatTurn(role: .user, text: "u\(i)"))
            vm.turns.append(ChatTurn(role: .assistant, text: "a\(i)"))
        }
        let h = vm.recentHistory()
        XCTAssertEqual(h.count, 8)
        XCTAssertEqual(h.first?.content, "u6")
        XCTAssertEqual(h.last?.content, "a9")
    }
}
