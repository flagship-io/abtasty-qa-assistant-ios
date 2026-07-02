//
//  ABTastyQAssistantTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
#if canImport(FlagShip)
import FlagShip
#else
import Flagship
#endif
@testable import ABTastyQAssistant

final class ABTastyQAssistantTests: XCTestCase {

    private var assistant: ABTastyQAAssistant!

    override func setUp() {
        super.setUp()
        assistant = ABTastyQAAssistant("env_test", "key_test")
    }

    override func tearDown() {
        assistant.dispose()
        assistant = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeResponse(campaignIds: [String] = ["camp_1"]) -> BucketingResponse {
        let json = """
        { "campaigns": [\(campaignIds.map { "{\"id\":\"\($0)\"}" }.joined(separator: ","))] }
        """
        return try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8))
    }

    /// Waits two main-queue cycles so NotificationCenter + DispatchQueue.main.async handlers settle.
    private func drainMain(timeout: TimeInterval = 0.2) {
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { exp.fulfill() }
        wait(for: [exp], timeout: timeout + 1)
    }

    // MARK: - isBucketingReady

    func testIsBucketingReadyFalseInitially() {
        XCTAssertFalse(assistant.isBucketingReady)
    }

    func testIsBucketingReadyTrueAfterUpdate() {
        assistant.updateCachedBucketingResponse(makeResponse())
        XCTAssertTrue(assistant.isBucketingReady)
    }

    func testIsBucketingReadyFalseAfterClear() {
        assistant.updateCachedBucketingResponse(makeResponse())
        assistant.clearModifications()
        XCTAssertFalse(assistant.isBucketingReady)
    }

    // MARK: - updateCachedBucketingResponse

    func testUpdateStoresCampaigns() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["c1", "c2"]))
        XCTAssertEqual(assistant.cachedBucketingResponse?.campaigns.count, 2)
    }

    func testUpdateSetsHasBeenModified() {
        XCTAssertFalse(assistant.hasBeenModified)
        assistant.updateCachedBucketingResponse(makeResponse())
        XCTAssertTrue(assistant.hasBeenModified)
    }

    func testUpdatePreservesResponseContent() {
        let response = makeResponse(campaignIds: ["camp_abc"])
        assistant.updateCachedBucketingResponse(response)
        XCTAssertEqual(assistant.cachedBucketingResponse?.campaigns.first?.id, "camp_abc")
    }

    // MARK: - clearModifications

    func testClearModificationsClearsResponse() {
        assistant.updateCachedBucketingResponse(makeResponse())
        assistant.clearModifications()
        XCTAssertNil(assistant.cachedBucketingResponse)
    }

    func testClearModificationsResetsHasBeenModified() {
        assistant.updateCachedBucketingResponse(makeResponse())
        assistant.clearModifications()
        XCTAssertFalse(assistant.hasBeenModified)
    }

    // MARK: - clearHitEvents

    func testClearHitEventsEmptiesArray() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "pageview"])
        drainMain()
        assistant.clearHitEvents()
        XCTAssertTrue(assistant.hitEvents.isEmpty)
    }

    // MARK: - getBucketingConfig (cached path)

    func testGetBucketingConfigReturnsCachedImmediately() {
        assistant.updateCachedBucketingResponse(makeResponse(campaignIds: ["cached_camp"]))

        var received: BucketingResponse?
        assistant.getBucketingConfig { result in
            if case .success(let r) = result { received = r }
        }
        XCTAssertEqual(received?.campaigns.first?.id, "cached_camp")
    }

    func testGetBucketingConfigCompletionCalledSynchronouslyWhenCached() {
        assistant.updateCachedBucketingResponse(makeResponse())
        var called = false
        assistant.getBucketingConfig { _ in called = true }
        XCTAssertTrue(called)
    }

    // MARK: - Hit event notification

    func testHitEventNotificationAppendsEvent() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "click"])
        drainMain()
        XCTAssertFalse(assistant.hitEvents.isEmpty)
        XCTAssertEqual(assistant.hitEvents.last?.hitType, "click")
    }

    func testHitEventWithoutTypeDefaultsToUnknown() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["x": "y"])
        drainMain()
        XCTAssertEqual(assistant.hitEvents.last?.hitType, "Unknown")
    }

    func testMultipleHitEventsAreAllAppended() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "a"])
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "b"])
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "c"])
        drainMain()
        let types = assistant.hitEvents.map(\.hitType)
        XCTAssertTrue(types.contains("a"))
        XCTAssertTrue(types.contains("b"))
        XCTAssertTrue(types.contains("c"))
    }

    func testHitEventPayloadIsPreserved() {
        FSQAMessageService.shared.broadcastHitEvent(payload: ["t": "ev", "custom": "value"])
        drainMain()
        XCTAssertEqual(assistant.hitEvents.last?.payload["custom"] as? String, "value")
    }

    // MARK: - Fetched flags notification

    func testFetchedFlagsUpdateLatestFetchedCampaigns() {
        let variations: [[String: String]] = [
            ["campaignId": "camp_a", "variationId": "var_1"],
            ["campaignId": "camp_b", "variationId": "var_2"]
        ]
        FSQAMessageService.shared.broadcastFetchedFlagIds(variations)
        drainMain()

        XCTAssertTrue(assistant.latestFetchedCampaigns.contains("camp_a"))
        XCTAssertTrue(assistant.latestFetchedCampaigns.contains("camp_b"))
    }

    func testFetchedFlagsReplacesPreviousCampaigns() {
        FSQAMessageService.shared.broadcastFetchedFlagIds([["campaignId": "old", "variationId": "v"]])
        drainMain()

        FSQAMessageService.shared.broadcastFetchedFlagIds([["campaignId": "new", "variationId": "v"]])
        drainMain()

        XCTAssertTrue(assistant.latestFetchedCampaigns.contains("new"))
        XCTAssertFalse(assistant.latestFetchedCampaigns.contains("old"))
    }
}
