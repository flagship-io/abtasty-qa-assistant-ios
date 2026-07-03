//
//  QACampaignDetailsViewCtrlTests.swift
//  ABTastyQAssistant_Tests
//
//  Tests for QACampaignDetailsViewCtrl.
//
//  NOTE – canChangeVariation, updateBannerVisibility, and updateDashboardState are all
//  private. To unit-test them directly, change their access to `internal`. Until then,
//  this file tests the externally observable effects of the logic that depends on them:
//
//    • campItem and onTakeAction are both internal — readable/writable in tests.
//    • evaluateTargeting is triggered indirectly via the fsQABroadcastUserContext
//      notification, and its result is readable through campItem.isTargetingRespected.
//

import XCTest
#if canImport(FlagShip)
import FlagShip
#else
import Flagship
#endif
@testable import ABTastyQAssistant

final class QACampaignDetailsViewCtrlTests: XCTestCase {

    private var sut: QACampaignDetailsViewCtrl!

    override func setUp() {
        super.setUp()
        sut = QACampaignDetailsViewCtrl()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeCampaign(id: String = "c1",
                              isActive: Bool = false,
                              isHidden: Bool = false,
                              isForced: Bool = false,
                              targetingJSON: String? = nil) -> Campaign {
        var json: [String: Any] = ["id": id]
        if let t = targetingJSON {
            json["variationGroups"] = [
                [
                    "id": "vg1",
                    "variations": [["id": "v1", "reference": true]],
                    "targeting": try! JSONSerialization.jsonObject(with: Data(t.utf8))
                ]
            ]
        }
        let data = try! JSONSerialization.data(withJSONObject: ["campaigns": [json]])
        var campaign = try! JSONDecoder().decode(BucketingResponse.self, from: data).campaigns[0]
        campaign.isActive = isActive
        campaign.isHidden = isHidden
        campaign.isForced = isForced
        return campaign
    }

    private func drainMain(timeout: TimeInterval = 0.2) {
        let exp = expectation(description: "drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { exp.fulfill() }
        wait(for: [exp], timeout: timeout + 1)
    }

    // MARK: - campItem & onTakeAction wiring

    func testCampItemIsSetBeforeViewLoads() {
        let camp = makeCampaign(id: "x42")
        sut.campItem = camp
        XCTAssertEqual(sut.campItem?.id, "x42")
    }

    func testOnTakeActionCallbackIsStored() {
        var received: (Campaign, String)?
        sut.onTakeAction = { camp, action in received = (camp, action) }
        let cb = sut.onTakeAction
        XCTAssertNotNil(cb)
        _ = received // silence unused warning
    }

    // MARK: - evaluateTargeting (indirect via notification)
    //
    // evaluateTargeting runs only when:  !camp.isActive && !camp.isForced
    // It sets campItem.isTargetingRespected based on QATargetingEvaluator.

    func testEvaluateTargetingSetsTrueWhenNoTargetingGroups() {
        sut.campItem = makeCampaign(isActive: false, isForced: false)
        sut.loadViewIfNeeded()

        FSQAMessageService.shared.broadcastUserContextUpdate(["country": "FR"])
        drainMain()

        XCTAssertEqual(sut.campItem?.isTargetingRespected, true)
    }

    func testEvaluateTargetingSetsTrueWhenContextMatchesTargeting() {
        let targeting = """
        { "targetingGroups": [
            { "targetings": [{ "operator": "EQUALS", "key": "country", "value": "FR" }] }
        ]}
        """
        sut.campItem = makeCampaign(isActive: false, isForced: false, targetingJSON: targeting)
        sut.loadViewIfNeeded()

        FSQAMessageService.shared.broadcastUserContextUpdate(["country": "FR"])
        drainMain()

        XCTAssertEqual(sut.campItem?.isTargetingRespected, true)
    }

    func testEvaluateTargetingSetsFalseWhenContextDoesNotMatch() {
        let targeting = """
        { "targetingGroups": [
            { "targetings": [{ "operator": "EQUALS", "key": "country", "value": "FR" }] }
        ]}
        """
        sut.campItem = makeCampaign(isActive: false, isForced: false, targetingJSON: targeting)
        sut.loadViewIfNeeded()

        FSQAMessageService.shared.broadcastUserContextUpdate(["country": "DE"])
        drainMain()

        XCTAssertEqual(sut.campItem?.isTargetingRespected, false)
    }

    func testEvaluateTargetingSkippedForActiveCampaign() {
        sut.campItem = makeCampaign(isActive: true, isForced: false)
        sut.loadViewIfNeeded()

        FSQAMessageService.shared.broadcastUserContextUpdate(["country": "FR"])
        drainMain()

        // evaluateTargeting returns early when isActive == true
        XCTAssertNil(sut.campItem?.isTargetingRespected)
    }

    func testEvaluateTargetingSkippedForForcedCampaign() {
        sut.campItem = makeCampaign(isActive: false, isForced: true)
        sut.loadViewIfNeeded()

        FSQAMessageService.shared.broadcastUserContextUpdate(["country": "FR"])
        drainMain()

        // evaluateTargeting returns early when isForced == true
        XCTAssertNil(sut.campItem?.isTargetingRespected)
    }
}

// MARK: - canChangeVariation
//
// canChangeVariation is private. To enable direct testing, change it to `internal`:
//
//   var canChangeVariation: Bool { ... }
//
// Then add tests here:
//
// func testCanChangeVariationTrueWhenActiveAndNotHidden() {
//     sut.campItem = makeCampaign(isActive: true, isHidden: false)
//     XCTAssertTrue(sut.canChangeVariation)
// }
// func testCanChangeVariationFalseWhenActiveButHidden() {
//     sut.campItem = makeCampaign(isActive: true, isHidden: true)
//     XCTAssertFalse(sut.canChangeVariation)
// }
// func testCanChangeVariationTrueWhenForcedAndInactive() {
//     sut.campItem = makeCampaign(isActive: false, isForced: true)
//     XCTAssertTrue(sut.canChangeVariation)
// }
// func testCanChangeVariationFalseWhenInactiveAndNotForced() {
//     sut.campItem = makeCampaign(isActive: false, isForced: false)
//     XCTAssertFalse(sut.canChangeVariation)
// }
// func testCanChangeVariationFalseWhenNoCampItem() {
//     sut.campItem = nil
//     XCTAssertFalse(sut.canChangeVariation)
// }
