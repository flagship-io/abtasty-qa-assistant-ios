//
//  QATargetingViewTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
import FlagShip
@testable import ABTastyQAssistant

final class QATargetingViewTests: XCTestCase {

    private var sut: QATargetingView!

    override func setUp() {
        super.setUp()
        sut = QATargetingView(frame: .zero)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var contentStack: UIStackView? {
        guard let scroll = sut.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView
        else { return nil }
        return scroll.subviews.first(where: { $0 is UIStackView }) as? UIStackView
    }

    private func drainMain(timeout: TimeInterval = 0.2) {
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { exp.fulfill() }
        wait(for: [exp], timeout: timeout + 1)
    }

    /// Builds a Campaign with optional targeting groups.
    /// `targetingGroupCount` sets how many TargetingGroups the first VariationGroup has.
    /// Uses `fs_all_users` key so conditions always evaluate without user context.
    private func makeCampaign(id: String = "c1",
                               isActive: Bool = true,
                               isForced: Bool = false,
                               targetingGroupCount: Int = 0) -> Campaign {
        let targetingJSON: String
        if targetingGroupCount > 0 {
            let groups = (0..<targetingGroupCount).map { _ in
                """
                {"targetings":[{"operator":"EQUALS","key":"fs_all_users","value":true}]}
                """
            }.joined(separator: ",")
            targetingJSON = "{\"targetingGroups\":[\(groups)]}"
        } else {
            targetingJSON = "null"
        }

        let json = """
        {"campaigns":[{"id":"\(id)","type":"ab","variationGroups":[
            {"id":"vg1","targeting":\(targetingJSON),"variations":[]}
        ]}]}
        """
        var c = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8)).campaigns[0]
        c.isActive = isActive
        c.isForced = isForced
        return c
    }

    // MARK: - Instantiate

    func testInstantiateReturnsView() {
        XCTAssertNotNil(sut)
    }

    func testScrollViewAndStackExistInHierarchy() {
        XCTAssertNotNil(contentStack)
    }

    // MARK: - Nil campaign

    func testConfigureWithNilCampaignShowsEmptyLabel() {
        sut.configure(with: nil)
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UILabel)
    }

    func testConfigureWithNilCampaignLabelText() {
        sut.configure(with: nil)
        let lbl = contentStack?.arrangedSubviews.first as? UILabel
        XCTAssertEqual(lbl?.text, "No targeting rules defined")
    }

    // MARK: - Active campaign, no targeting groups

    func testActiveCampaignWithNoGroupsShowsEmptyLabel() {
        sut.configure(with: makeCampaign(isActive: true, targetingGroupCount: 0))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UILabel)
    }

    // MARK: - Active campaign with targeting groups

    func testActiveCampaignOneGroupAddsOneRow() {
        sut.configure(with: makeCampaign(isActive: true, targetingGroupCount: 1))
        // 1 group row (UIStackView: icon + card)
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UIStackView)
    }

    func testActiveCampaignTwoGroupsAddsOrSeparatorBetweenRows() {
        sut.configure(with: makeCampaign(isActive: true, targetingGroupCount: 2))
        // [group row, OR separator, group row] = 3
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 3)
    }

    func testActiveCampaignThreeGroupsAddsTwoOrSeparators() {
        sut.configure(with: makeCampaign(isActive: true, targetingGroupCount: 3))
        // [row, OR, row, OR, row] = 5
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 5)
    }

    // MARK: - Forced campaign (bypass banner)

    func testForcedCampaignAddsBypassBannerBeforeGroupRows() {
        sut.configure(with: makeCampaign(isForced: true, targetingGroupCount: 1))
        // [banner, group row] = 2
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
        // First item should be a UIView (the banner), not a UIStackView (group row)
        XCTAssertFalse(contentStack?.arrangedSubviews.first is UIStackView)
    }

    func testForcedCampaignBannerContainsBypassMessage() {
        sut.configure(with: makeCampaign(isForced: true, targetingGroupCount: 1))
        let banner = contentStack?.arrangedSubviews.first
        let lbl = banner?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertTrue(lbl?.text?.contains("bypassed") ?? false)
    }

    func testForcedCampaignWithNoGroupsAddsBannerAndEmptyLabel() {
        sut.configure(with: makeCampaign(isForced: true, targetingGroupCount: 0))
        // [banner, empty label] = 2
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
    }

    // MARK: - Inactive non-forced campaign (not-matching banner)

    func testInactiveCampaignAddsNotMatchingBannerBeforeGroupRows() {
        sut.configure(with: makeCampaign(isActive: false, isForced: false, targetingGroupCount: 1))
        // [banner, group row] = 2
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
    }

    func testInactiveCampaignBannerContainsNotMatchingMessage() {
        sut.configure(with: makeCampaign(isActive: false, isForced: false, targetingGroupCount: 1))
        let banner = contentStack?.arrangedSubviews.first
        let lbl = banner?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertTrue(lbl?.text?.contains("does not match") ?? false)
    }

    // MARK: - User context subscription

    func testContextNotificationTriggersReloadWithoutCrashing() {
        sut.configure(with: makeCampaign(isActive: true, targetingGroupCount: 1))
        let countBefore = contentStack?.arrangedSubviews.count

        FSQAMessageService.shared.broadcastUserContextUpdate(["age": 30, "country": "FR"])
        drainMain()

        // Stack is rebuilt — count should remain consistent
        XCTAssertEqual(contentStack?.arrangedSubviews.count, countBefore)
    }

    // MARK: - Reconfigure

    func testReconfigureReplacesContent() {
        sut.configure(with: makeCampaign(isActive: true, targetingGroupCount: 2))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 3)  // row + OR + row

        sut.configure(with: nil)
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UILabel)
    }
}
