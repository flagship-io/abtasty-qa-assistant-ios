//
//  QAssistantHomeViewControllerTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
import FlagShip
@testable import ABTastyQAssistant

final class QAssistantHomeViewControllerTests: XCTestCase {

    private var sut: QAssistantHomeViewController!
    private var assistant: ABTastyQAAssistant!
    private var liveCampaignLabel: UILabel!

    override func setUp() {
        super.setUp()
        assistant = ABTastyQAAssistant("env_test", "key_home_test")
        sut = QAssistantHomeViewController()
        liveCampaignLabel = UILabel()
        // Wire outlet before loadViewIfNeeded so viewDidLoad's updateLiveCount() sees it.
        // qaAssistant is intentionally left nil at this point so downloadBucketingResponse()
        // returns early without making a network call.
        sut.liveCampaignLabel = liveCampaignLabel
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        sut = nil
        assistant.dispose()
        assistant = nil
        liveCampaignLabel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func drainMain(timeout: TimeInterval = 0.3) {
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { exp.fulfill() }
        wait(for: [exp], timeout: timeout + 1)
    }

    private func makeResponse(campaignIds: [String]) -> BucketingResponse {
        let campaigns = campaignIds.map { "{ \"id\": \"\($0)\", \"variationGroups\": [] }" }
            .joined(separator: ",")
        let json = "{ \"campaigns\": [\(campaigns)] }"
        return try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
    }

    // MARK: - Live campaign label initial state

    func testLiveLabelShowsZeroWhenNoAssistantAtLoad() {
        // qaAssistant was nil at viewDidLoad → updateLiveCount gives 0
        XCTAssertEqual(liveCampaignLabel.text, "0 live campaigns")
    }

    // MARK: - Live campaign label via fsQABroadcastFetchedFlags notification

    func testLiveLabelUsesPluralsForMultipleCampaigns() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["c1", "c2", "c3"]))
        sut.qaAssistant = assistant

        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "c1", "variationId": "v1"]
        ])
        drainMain()

        // updateLiveCount counts ALL campaigns in the cached response (3 total)
        XCTAssertEqual(liveCampaignLabel.text, "3 live campaigns")
    }

    func testLiveLabelUsesSingularForOneCampaign() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["c1"]))
        sut.qaAssistant = assistant

        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "c1", "variationId": "v1"]
        ])
        drainMain()

        XCTAssertEqual(liveCampaignLabel.text, "1 live campaign")
    }

    func testLiveLabelShowsZeroWhenNoCampaignsInResponse() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: []))
        sut.qaAssistant = assistant

        FSQAMessageService.shared.broadcastFetchedFlagIds([])
        drainMain()

        XCTAssertEqual(liveCampaignLabel.text, "0 live campaigns")
    }

    // MARK: - decorateWithFetchedIds logic (tested indirectly via the notification handler)

    func testFetchedFlagsMarkMatchingCampaignAsActive() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["c1", "c2"]))
        sut.qaAssistant = assistant

        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "c1", "variationId": "v1"]
        ])
        drainMain()

        let campaigns = assistant.cachedBucketingResponse?.campaigns ?? []
        XCTAssertTrue(campaigns.first { $0.id == "c1" }?.isActive ?? false)
        XCTAssertFalse(campaigns.first { $0.id == "c2" }?.isActive ?? true)
    }

    func testFetchedFlagsWithNoCampaignIdsMarkAllAsInactive() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["c1", "c2"]))
        sut.qaAssistant = assistant

        FSQAMessageService.shared.broadcastFetchedFlagIds([])
        drainMain()

        let allInactive = assistant.cachedBucketingResponse?.campaigns.allSatisfy { !$0.isActive } ?? false
        XCTAssertTrue(allInactive)
    }

    func testFetchedFlagsWithAllCampaignIdsMarkAllAsActive() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["c1", "c2"]))
        sut.qaAssistant = assistant

        FSQAMessageService.shared.broadcastFetchedFlagIds([
            ["campaignId": "c1", "variationId": "v1"],
            ["campaignId": "c2", "variationId": "v2"]
        ])
        drainMain()

        let allActive = assistant.cachedBucketingResponse?.campaigns.allSatisfy { $0.isActive } ?? false
        XCTAssertTrue(allActive)
    }
}
