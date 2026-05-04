@testable import AskCPCC
import XCTest

final class KeychainStoreTests: XCTestCase {

    private let testService = "edu.cpcc.AskCPCC.test.openrouter"

    override func setUp() {
        super.setUp()
        try? KeychainStore.delete(service: testService, account: "key")
    }

    override func tearDown() {
        try? KeychainStore.delete(service: testService, account: "key")
        super.tearDown()
    }

    func testReadReturnsNilWhenEmpty() throws {
        XCTAssertNil(try KeychainStore.read(service: testService, account: "key"))
    }

    func testWriteThenRead() throws {
        try KeychainStore.write("sk-or-test-123", service: testService, account: "key")
        XCTAssertEqual(try KeychainStore.read(service: testService, account: "key"), "sk-or-test-123")
    }

    func testWriteOverwrites() throws {
        try KeychainStore.write("first", service: testService, account: "key")
        try KeychainStore.write("second", service: testService, account: "key")
        XCTAssertEqual(try KeychainStore.read(service: testService, account: "key"), "second")
    }

    func testDeleteRemoves() throws {
        try KeychainStore.write("x", service: testService, account: "key")
        try KeychainStore.delete(service: testService, account: "key")
        XCTAssertNil(try KeychainStore.read(service: testService, account: "key"))
    }
}
