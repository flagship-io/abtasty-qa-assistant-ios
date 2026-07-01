//
//  QACampaignTableViewCellTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
@testable import ABTastyQAssistant

final class QACampaignTableViewCellTests: XCTestCase {

    private var sut: QACampaignTableViewCell!

    override func setUp() {
        super.setUp()
        sut = QACampaignTableViewCell(style: .default, reuseIdentifier: nil)
        // Wire outlets manually — awakeFromNib is not called in programmatic init
        sut.titleCampaign = UILabel()
        sut.typeCampaign = UILabel()
        sut.status = UIButton(type: .custom)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Campaign factory

    private func makeCampaign(id: String = "c1",
                               name: String? = "Test Campaign",
                               type: String = "ab",
                               isActive: Bool = false,
                               isHidden: Bool = false,
                               isForced: Bool = false) -> Campaign {
        let nameJSON = name.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"campaigns":[{"id":"\(id)","name":\(nameJSON),"type":"\(type)","variationGroups":[]}]}
        """
        var campaign = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8)).campaigns[0]
        campaign.isActive = isActive
        campaign.isHidden = isHidden
        campaign.isForced = isForced
        return campaign
    }

    // MARK: - titleCampaign

    func testTitleShowsCampaignName() {
        sut.configure(with: makeCampaign(name: "My Campaign"))
        XCTAssertEqual(sut.titleCampaign?.text, "My Campaign")
    }

    func testTitleWithNilNameShowsDash() {
        sut.configure(with: makeCampaign(name: nil))
        XCTAssertEqual(sut.titleCampaign?.text, "-")
    }

    func testTitleUpdatesOnReconfigure() {
        sut.configure(with: makeCampaign(name: "First"))
        sut.configure(with: makeCampaign(name: "Second"))
        XCTAssertEqual(sut.titleCampaign?.text, "Second")
    }

    // MARK: - typeCampaign (campaignType mapping)

    func testTypeABMapsToABTest() {
        sut.configure(with: makeCampaign(type: "ab"))
        XCTAssertEqual(sut.typeCampaign?.text, "A/B Test")
    }

    func testTypeToggleMapsToFeatureToggle() {
        sut.configure(with: makeCampaign(type: "toggle"))
        XCTAssertEqual(sut.typeCampaign?.text, "Feature Toggle")
    }

    func testTypePersoMapsToPersonalization() {
        sut.configure(with: makeCampaign(type: "perso"))
        XCTAssertEqual(sut.typeCampaign?.text, "Personalization")
    }

    func testUnknownTypePassesThroughUnchanged() {
        sut.configure(with: makeCampaign(type: "experiment"))
        XCTAssertEqual(sut.typeCampaign?.text, "experiment")
    }

    func testEmptyTypePassesThroughUnchanged() {
        sut.configure(with: makeCampaign(type: ""))
        XCTAssertEqual(sut.typeCampaign?.text, "")
    }

    // MARK: - status button title

    func testStatusIsAcceptedWhenActiveAndNotHidden() {
        sut.configure(with: makeCampaign(isActive: true, isHidden: false))
        XCTAssertEqual(sut.status?.title(for: .normal), "Accepted")
    }

    func testStatusIsHiddenWhenActiveAndHidden() {
        sut.configure(with: makeCampaign(isActive: true, isHidden: true))
        XCTAssertEqual(sut.status?.title(for: .normal), "Hidden")
    }

    func testStatusIsForcedWhenNotActiveButForced() {
        sut.configure(with: makeCampaign(isActive: false, isForced: true))
        XCTAssertEqual(sut.status?.title(for: .normal), "Forced")
    }

    func testStatusIsRejectedWhenNotActiveAndNotForced() {
        sut.configure(with: makeCampaign(isActive: false, isForced: false))
        XCTAssertEqual(sut.status?.title(for: .normal), "Rejected")
    }

    // isActive takes priority — isForced is irrelevant when campaign is active
    func testActiveCampaignWithForcedFlagIsAccepted() {
        sut.configure(with: makeCampaign(isActive: true, isHidden: false, isForced: true))
        XCTAssertEqual(sut.status?.title(for: .normal), "Accepted")
    }

    // MARK: - status button interaction

    func testStatusButtonIsNotUserInteractable() {
        sut.configure(with: makeCampaign())
        XCTAssertFalse(sut.status?.isUserInteractionEnabled ?? true)
    }

    // MARK: - status button background color differs per state

    func testAcceptedAndRejectedHaveDifferentBackgroundColors() {
        sut.configure(with: makeCampaign(isActive: true, isHidden: false))
        let acceptedColor = sut.status?.backgroundColor

        sut.configure(with: makeCampaign(isActive: false, isForced: false))
        let rejectedColor = sut.status?.backgroundColor

        XCTAssertNotNil(acceptedColor)
        XCTAssertNotNil(rejectedColor)
        XCTAssertNotEqual(acceptedColor, rejectedColor)
    }

    func testHiddenAndForcedHaveSameBackgroundColor() {
        sut.configure(with: makeCampaign(isActive: true, isHidden: true))
        let hiddenColor = sut.status?.backgroundColor

        sut.configure(with: makeCampaign(isActive: false, isForced: true))
        let forcedColor = sut.status?.backgroundColor

        XCTAssertNotNil(hiddenColor)
        XCTAssertEqual(hiddenColor, forcedColor)
    }
}
