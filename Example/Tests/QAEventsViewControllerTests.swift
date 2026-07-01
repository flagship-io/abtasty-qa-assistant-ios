//
//  QAEventsViewControllerTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
import FlagShip
@testable import ABTastyQAssistant

final class QAEventsViewControllerTests: XCTestCase {

    private var assistant: ABTastyQAAssistant!
    private var sut: QAEventsViewController!
    private let dummyTable = UITableView()

    override func setUp() {
        super.setUp()
        assistant = ABTastyQAAssistant("env_test", "key_test")
        addEvents()

        sut = QAEventsViewController()
        sut.qaAssistant = assistant
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        sut = nil
        assistant.dispose()
        assistant = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Posts hit events synchronously and drains the main queue so they land in assistant.hitEvents.
    private func addEvents() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "pageview", "url": "home"])
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "click",    "btn": "buy"])
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "screen",   "url": "cart"])

        let exp = expectation(description: "events delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
    }

    private func rowCount() -> Int {
        sut.tableView(dummyTable, numberOfRowsInSection: 0)
    }

    // MARK: - Initial load

    func testAllEventsVisibleAfterLoad() {
        XCTAssertEqual(rowCount(), 3)
    }

    // MARK: - filter(by:)

    func testEmptyQueryShowsAllEvents() {
        sut.filter(by: "pageview")
        sut.filter(by: "")
        XCTAssertEqual(rowCount(), 3)
    }

    func testFilterByHitTypeMatchesSingleEvent() {
        sut.filter(by: "click")
        XCTAssertEqual(rowCount(), 1)
    }

    func testFilterByPayloadValueMatches() {
        sut.filter(by: "cart")
        XCTAssertEqual(rowCount(), 1)
    }

    func testFilterIsCaseInsensitive() {
        sut.filter(by: "PAGEVIEW")
        XCTAssertEqual(rowCount(), 1)
    }

    func testFilterWithNoMatchReturnsZeroRows() {
        sut.filter(by: "zzz_no_match")
        XCTAssertEqual(rowCount(), 0)
    }

    func testFilterByPayloadKeyMatches() {
        // "btn" is a payload key only in the click event
        sut.filter(by: "btn")
        XCTAssertEqual(rowCount(), 1)
    }

    func testReloadShowsLatestEvents() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "transaction"])
        let exp = expectation(description: "event delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        sut.reload()
        XCTAssertEqual(rowCount(), 4)
    }
}

// MARK: - QAEventCell.minutesAgo
//
// minutesAgo(from:) is a private static method on QAEventCell.
// To make it directly testable, change its access to `internal`:
//
//   static func minutesAgo(from date: Date) -> String { ... }
//
// Then add tests here:
//
// func testMinutesAgoJustNow() {
//     XCTAssertEqual(QAEventCell.minutesAgo(from: Date()), "Just now")
// }
// func testMinutesAgoMinutes() {
//     XCTAssertEqual(QAEventCell.minutesAgo(from: Date(timeIntervalSinceNow: -120)), "2m ago")
// }
// func testMinutesAgoHours() {
//     XCTAssertEqual(QAEventCell.minutesAgo(from: Date(timeIntervalSinceNow: -7200)), "2h ago")
// }
// func testMinutesAgoDays() {
//     XCTAssertEqual(QAEventCell.minutesAgo(from: Date(timeIntervalSinceNow: -172800)), "2d ago")
// }
