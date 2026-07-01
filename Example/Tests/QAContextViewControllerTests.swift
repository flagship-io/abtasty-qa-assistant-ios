//
//  QAContextViewControllerTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
import FlagShip
@testable import ABTastyQAssistant

final class QAContextViewControllerTests: XCTestCase {

    private var sut: QAContextViewController!

    override func setUp() {
        super.setUp()
        sut = QAContextViewController()
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - View hierarchy helpers

    private var scrollView: UIScrollView? {
        sut.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView
    }

    private var cardStack: UIStackView? {
        guard let scroll = scrollView,
              let contentStack = scroll.subviews.first(where: { $0 is UIStackView }) as? UIStackView,
              let cardView = contentStack.arrangedSubviews.first,
              let stack = cardView.subviews.first(where: { $0 is UIStackView }) as? UIStackView
        else { return nil }
        return stack
    }

    private var rowCount: Int { cardStack?.arrangedSubviews.count ?? 0 }

    private func rowText(at index: Int) -> String? {
        (cardStack?.arrangedSubviews[index] as? UILabel)?.text
    }

    /// Posts a user context notification and drains the main queue so the handler settles.
    private func postContext(_ context: [String: Any], timeout: TimeInterval = 0.2) {
        FSQAMessageService.shared.broadcastUserContextUpdate(context)
        let exp = expectation(description: "context delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { exp.fulfill() }
        wait(for: [exp], timeout: timeout + 1)
    }

    // MARK: - Initial state

    func testScrollViewExistsAfterLoad() {
        XCTAssertNotNil(scrollView)
    }

    func testCardStackExistsAfterLoad() {
        XCTAssertNotNil(cardStack)
    }

    func testInitiallyHasNoRows() {
        XCTAssertEqual(rowCount, 0)
    }

    // scrollView starts visible (UIView default); updateEmptyState() only runs after the first notification.
    func testScrollViewVisibleInitially() {
        XCTAssertFalse(scrollView?.isHidden ?? true)
    }

    // MARK: - Context notification

    func testContextNotificationAddsRows() {
        postContext(["country": "FR", "age": 30, "premium": true])
        XCTAssertEqual(rowCount, 3)
    }

    func testContextNotificationShowsScrollView() {
        postContext(["key": "value"])
        XCTAssertFalse(scrollView?.isHidden ?? true)
    }

    func testContextIsSortedAlphabeticallyByKey() {
        postContext(["zzz": "last", "aaa": "first", "mmm": "middle"])
        XCTAssertTrue(rowText(at: 0)?.hasPrefix("aaa") ?? false)
        XCTAssertTrue(rowText(at: 1)?.hasPrefix("mmm") ?? false)
        XCTAssertTrue(rowText(at: 2)?.hasPrefix("zzz") ?? false)
    }

    func testNewContextReplacesOldContext() {
        postContext(["a": 1, "b": 2, "c": 3])
        XCTAssertEqual(rowCount, 3)

        postContext(["x": 9])
        XCTAssertEqual(rowCount, 1)
    }

    // MARK: - filter(by:) — query is lowercased internally

    func testEmptyQueryShowsAllRows() {
        postContext(["country": "FR", "city": "Paris"])
        sut.filter(by: "country")
        sut.filter(by: "")
        XCTAssertEqual(rowCount, 2)
    }

    func testFilterByKeySubstringMatches() {
        postContext(["country": "FR", "city": "Paris", "age": 25])
        sut.filter(by: "co")
        XCTAssertEqual(rowCount, 1)
    }

    func testFilterByValueSubstringMatches() {
        postContext(["country": "FR", "city": "Paris"])
        sut.filter(by: "paris")
        XCTAssertEqual(rowCount, 1)
    }

    func testFilterIsCaseInsensitive() {
        postContext(["country": "FR", "city": "Paris"])
        sut.filter(by: "COUNTRY")
        XCTAssertEqual(rowCount, 1)
    }

    func testFilterByValueIsCaseInsensitive() {
        postContext(["city": "Paris"])
        sut.filter(by: "PARIS")
        XCTAssertEqual(rowCount, 1)
    }

    func testFilterWithNoMatchReturnsZeroRows() {
        postContext(["country": "FR", "city": "Paris"])
        sut.filter(by: "zzz_no_match")
        XCTAssertEqual(rowCount, 0)
    }

    func testFilterWithNoMatchHidesScrollView() {
        postContext(["country": "FR"])
        sut.filter(by: "zzz_no_match")
        XCTAssertTrue(scrollView?.isHidden ?? true)
    }

    func testFilterMatchShowsScrollView() {
        postContext(["country": "FR"])
        sut.filter(by: "country")
        XCTAssertFalse(scrollView?.isHidden ?? true)
    }

    func testFilterBySharedSubstringMatchesMultiple() {
        postContext(["username": "alice", "user_id": "123", "age": 30])
        sut.filter(by: "user")
        XCTAssertEqual(rowCount, 2)
    }

    func testFilterPreservesAlphabeticalOrder() {
        postContext(["zebra": "z", "apple": "a", "mango": "m"])
        sut.filter(by: "")
        XCTAssertTrue(rowText(at: 0)?.hasPrefix("apple") ?? false)
        XCTAssertTrue(rowText(at: 1)?.hasPrefix("mango") ?? false)
        XCTAssertTrue(rowText(at: 2)?.hasPrefix("zebra") ?? false)
    }
}
