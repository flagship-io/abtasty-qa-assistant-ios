//
//  QACampaignsTableViewCtrlTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
import FlagShip
@testable import ABTastyQAssistant

final class QACampaignsTableViewCtrlTests: XCTestCase {

    private var assistant: ABTastyQAAssistant!
    private var sut: QACampaignsTableViewCtrl!
    private let dummyTable = UITableView()

    override func setUp() {
        super.setUp()
        assistant = ABTastyQAAssistant("env_test", "key_test")

        // Campaigns: two with names for name-search, one for ID-search
        let json = """
        { "campaigns": [
            { "id": "camp_alpha", "name": "Alpha Campaign" },
            { "id": "camp_beta",  "name": "Beta Campaign" },
            { "id": "camp_gamma", "name": "Gamma Feature" }
        ]}
        """
        let response = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
        assistant.updateCachedBucketingResponse(response)
        // latestFetchedCampaigns is empty → all campaigns land in the rejected (section 1) bucket

        sut = QACampaignsTableViewCtrl()
        sut.qaAssistant = assistant
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        sut = nil
        assistant.dispose()
        assistant = nil
        super.tearDown()
    }

    // MARK: - numberOfSections

    func testAlwaysHasTwoSections() {
        XCTAssertEqual(sut.numberOfSections(in: dummyTable), 2)
    }

    // MARK: - Initial data load

    func testAllCampaignsStartInRejectedSection() {
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 0) // accepted
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 3) // rejected
    }

    // MARK: - filter(by:)

    func testEmptyQueryRestoresAllCampaigns() {
        sut.filter(by: "alpha")
        sut.filter(by: "")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 3)
    }

    func testFilterByNameMatchesSingleCampaign() {
        sut.filter(by: "beta")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 1)
    }

    func testFilterByCampaignId() {
        sut.filter(by: "gamma")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 1)
    }

    // filter(by:) expects a pre-lowercased query — the caller (searchChanged) lowercases first.
    func testFilterRequiresLowercasedQuery() {
        sut.filter(by: "alpha")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 1)

        sut.filter(by: "ALPHA")          // uppercase → no match, by design
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0)
    }

    func testFilterWithNoMatchReturnsZeroRows() {
        sut.filter(by: "zzz_no_match")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0)
    }

    func testFilterBySharedSubstringMatchesMultiple() {
        // "camp" appears in all three IDs
        sut.filter(by: "camp")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 3)
    }

    // MARK: - Accepted / rejected split

    private func drainMain(timeout: TimeInterval = 0.2) {
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { exp.fulfill() }
        wait(for: [exp], timeout: timeout + 1)
    }

    func testCampaignInLatestFetchedGoesToAcceptedSection() {
        // Broadcast that camp_alpha was fetched — ABTastyQAAssistant updates latestFetchedCampaigns
        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "camp_alpha", "variationId": "v1"]
        ])
        drainMain()
        sut.reloadData()

        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 1) // accepted: camp_alpha
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 2) // rejected: camp_beta, camp_gamma
    }

    func testAllCampaignsFetchedAllGoToAcceptedSection() {
        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "camp_alpha", "variationId": "v1"],
            ["campaignId": "camp_beta",  "variationId": "v2"],
            ["campaignId": "camp_gamma", "variationId": "v3"]
        ])
        drainMain()
        sut.reloadData()

        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 3) // all accepted
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0) // none rejected
    }

    func testReloadDataReflectsUpdatedCachedResponse() {
        // Replace the cached response with fewer campaigns
        let newJson = """
        { "campaigns": [{ "id": "camp_alpha", "name": "Alpha Campaign" }] }
        """
        let newResponse = try! JSONDecoder().decode(BucketingResponse.self, from: Data(newJson.utf8))
        assistant.updateCachedBucketingResponse(newResponse)
        sut.reloadData()

        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 1)
    }

    func testFilterAppliedAfterReloadPreservesResults() {
        // Reload with a different response, then filter
        let newJson = """
        { "campaigns": [
            { "id": "c1", "name": "Foo Campaign" },
            { "id": "c2", "name": "Bar Campaign" }
        ]}
        """
        let newResponse = try! JSONDecoder().decode(BucketingResponse.self, from: Data(newJson.utf8))
        assistant.updateCachedBucketingResponse(newResponse)
        sut.reloadData()

        sut.filter(by: "foo")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 1)
    }

    func testFilterOnAcceptedSection() {
        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "camp_alpha", "variationId": "v1"],
            ["campaignId": "camp_beta",  "variationId": "v2"]
        ])
        drainMain()
        sut.reloadData()

        sut.filter(by: "alpha")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0) // gamma not matching
    }

    // MARK: - nil assistant

    func testReloadWithNilAssistantPreservesLastKnownData() {
        // loadData() guards on cachedBucketingResponse and returns early when qaAssistant is nil.
        // The existing arrays are NOT cleared, so the last-loaded state is preserved.
        sut.qaAssistant = nil
        sut.reloadData()
        // 3 campaigns were loaded before qaAssistant was cleared — they remain visible.
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 3)
    }

    // MARK: - matches: nil-name campaign

    func testFilterMatchesNilNameCampaignByIdSubstring() {
        let json = "{ \"campaigns\": [{ \"id\": \"unique_xyz_id\" }] }"
        let resp = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
        assistant.updateCachedBucketingResponse(resp)
        sut.reloadData()

        sut.filter(by: "xyz")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 1)
    }

    func testFilterDoesNotMatchNilNameByArbitraryString() {
        let json = "{ \"campaigns\": [{ \"id\": \"unique_xyz_id\" }] }"
        let resp = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
        assistant.updateCachedBucketingResponse(resp)
        sut.reloadData()

        sut.filter(by: "nonexistent_name")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0)
    }

    // MARK: - viewForHeaderInSection

    func testSection0HeaderBadgeTitleIsAccepted() {
        let header = sut.tableView(dummyTable, viewForHeaderInSection: 0)
        let badge = header?.subviews.compactMap { $0 as? UIButton }.first
        let attrTitle = badge?.configuration?.attributedTitle
        let text = attrTitle.map { String($0.characters) } ?? ""
        XCTAssertEqual(text, "Accepted")
    }

    func testSection1HeaderBadgeTitleIsRejected() {
        let header = sut.tableView(dummyTable, viewForHeaderInSection: 1)
        let badge = header?.subviews.compactMap { $0 as? UIButton }.first
        let attrTitle = badge?.configuration?.attributedTitle
        let text = attrTitle.map { String($0.characters) } ?? ""
        XCTAssertEqual(text, "Rejected")
    }

    func testHeaderCountLabelPluralText() {
        let header = sut.tableView(dummyTable, viewForHeaderInSection: 1)
        let label = header?.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertEqual(label?.text, "3 campaigns")
    }

    func testHeaderCountLabelSingularForOneCampaign() {
        let json = "{ \"campaigns\": [{ \"id\": \"c1\", \"name\": \"Solo\" }] }"
        let resp = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
        assistant.updateCachedBucketingResponse(resp)
        sut.reloadData()

        let header = sut.tableView(dummyTable, viewForHeaderInSection: 1)
        let label = header?.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertEqual(label?.text, "1 campaign")
    }

    func testHeaderHasExactlyOneTapGestureRecognizer() {
        let header = sut.tableView(dummyTable, viewForHeaderInSection: 0)
        XCTAssertEqual(header?.gestureRecognizers?.count, 1)
        XCTAssertTrue(header?.gestureRecognizers?.first is UITapGestureRecognizer)
    }

    func testHeaderTagMatchesSectionIndex() {
        XCTAssertEqual(sut.tableView(dummyTable, viewForHeaderInSection: 0)?.tag, 0)
        XCTAssertEqual(sut.tableView(dummyTable, viewForHeaderInSection: 1)?.tag, 1)
    }

    func testSection1HeaderHasMoreSubviewsThanSection0() {
        // Section 1 gets an extra top-separator UIView
        let count0 = sut.tableView(dummyTable, viewForHeaderInSection: 0)?.subviews.count ?? 0
        let count1 = sut.tableView(dummyTable, viewForHeaderInSection: 1)?.subviews.count ?? 0
        XCTAssertEqual(count1, count0 + 1)
    }

    // MARK: - heightForHeaderInSection / footer

    func testHeaderHeightIs56() {
        XCTAssertEqual(sut.tableView(dummyTable, heightForHeaderInSection: 0), 56)
        XCTAssertEqual(sut.tableView(dummyTable, heightForHeaderInSection: 1), 56)
    }

    func testFooterHeightIsLeastNormalMagnitude() {
        XCTAssertEqual(sut.tableView(dummyTable, heightForFooterInSection: 0), .leastNormalMagnitude)
        XCTAssertEqual(sut.tableView(dummyTable, heightForFooterInSection: 1), .leastNormalMagnitude)
    }

    func testFooterViewIsNil() {
        XCTAssertNil(sut.tableView(dummyTable, viewForFooterInSection: 0))
        XCTAssertNil(sut.tableView(dummyTable, viewForFooterInSection: 1))
    }

    // MARK: - headerTapped collapse / expand

    /// Calls sut.headerTapped(_:) via Objective-C runtime — the method is @objc private.
    private func tapHeader(section: Int) {
        let header = sut.tableView(dummyTable, viewForHeaderInSection: section)!
        let tap = header.gestureRecognizers!.first as! UITapGestureRecognizer
        sut.perform(Selector(("headerTapped:")), with: tap)
    }

    func testTappingAcceptedHeaderCollapsesThenRestores() {
        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "camp_alpha", "variationId": "v1"]
        ])
        drainMain()
        sut.reloadData()
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 1, "pre-condition")

        tapHeader(section: 0)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 0, "after collapse")

        tapHeader(section: 0)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 1, "after re-expand")
    }

    func testTappingRejectedHeaderCollapsesThenRestores() {
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 3, "pre-condition")

        tapHeader(section: 1)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0, "after collapse")

        tapHeader(section: 1)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 3, "after re-expand")
    }

    func testCollapsingAcceptedDoesNotAffectRejectedSection() {
        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "camp_alpha", "variationId": "v1"]
        ])
        drainMain()
        sut.reloadData()

        tapHeader(section: 0)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 2) // unchanged
    }

    func testFilterWithCollapsedSectionYieldsZeroRows() {
        // Collapse rejected section first
        tapHeader(section: 1)
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0)

        // Filter still returns 0 even though there would be a match, because section is collapsed
        sut.filter(by: "alpha")
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 1), 0)
    }

    // MARK: - updateCampaign (via prepare + onTakeAction callback)

    func testUpdateRejectedCampaignPropagatesChangeToAssistantCache() {
        let detailsVC = QACampaignDetailsViewCtrl()
        let segue = UIStoryboardSegue(identifier: "onClickCampaign", source: sut, destination: detailsVC)

        let original = assistant.cachedBucketingResponse!.campaigns.first { $0.id == "camp_alpha" }!
        sut.prepare(for: segue, sender: original)

        var updated = original
        updated.isHidden = true
        detailsVC.onTakeAction?(updated, "hide")

        let cached = assistant.cachedBucketingResponse?.campaigns.first { $0.id == "camp_alpha" }
        XCTAssertTrue(cached?.isHidden ?? false)
    }

    func testUpdateAcceptedCampaignPropagatesChangeToAssistantCache() {
        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "camp_alpha", "variationId": "v1"]
        ])
        drainMain()
        sut.reloadData()

        let detailsVC = QACampaignDetailsViewCtrl()
        let segue = UIStoryboardSegue(identifier: "onClickCampaign", source: sut, destination: detailsVC)

        let original = assistant.cachedBucketingResponse!.campaigns.first { $0.id == "camp_alpha" }!
        sut.prepare(for: segue, sender: original)

        var updated = original
        updated.isForced = true
        detailsVC.onTakeAction?(updated, "hide")

        let cached = assistant.cachedBucketingResponse?.campaigns.first { $0.id == "camp_alpha" }
        XCTAssertTrue(cached?.isForced ?? false)
    }

    func testUpdateCampaignNotInListIsNoOp() {
        let detailsVC = QACampaignDetailsViewCtrl()
        let segue = UIStoryboardSegue(identifier: "onClickCampaign", source: sut, destination: detailsVC)
        let ghost = assistant.cachedBucketingResponse!.campaigns.first { $0.id == "camp_alpha" }!
        sut.prepare(for: segue, sender: ghost)

        // Trigger with a campaign ID that doesn't exist in the controller's lists
        var unknown = ghost
        // Override the id to a non-existent one by decoding a fresh campaign
        let fakeJson = "{\"campaigns\":[{\"id\":\"ghost_id\",\"name\":\"Ghost\"}]}"
        let fakeCampaign = try! JSONDecoder().decode(BucketingResponse.self, from: Data(fakeJson.utf8)).campaigns[0]

        let countBefore = assistant.cachedBucketingResponse?.campaigns.count
        detailsVC.onTakeAction?(fakeCampaign, "noop")
        // Assistant cache should be unchanged since "ghost_id" isn't in the response
        XCTAssertEqual(assistant.cachedBucketingResponse?.campaigns.count, countBefore)
    }
}
