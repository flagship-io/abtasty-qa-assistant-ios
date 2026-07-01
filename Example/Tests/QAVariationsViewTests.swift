//
//  QAVariationsViewTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
@testable import ABTastyQAssistant

// MARK: - QAVariationsViewTests

final class QAVariationsViewTests: XCTestCase {

    private var sut: QAVariationsView!

    override func setUp() {
        super.setUp()
        sut = QAVariationsView.instantiate()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var sectionsStack: UIStackView? {
        guard let scroll = sut.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView
        else { return nil }
        return scroll.subviews.first(where: { $0 is UIStackView }) as? UIStackView
    }

    private func makeCampaign(id: String = "c1",
                              type: String = "ab",
                              variations: [(id: String, name: String)] = []) -> Campaign {
        let variationsJSON = variations.map { "{ \"id\": \"\($0.id)\", \"name\": \"\($0.name)\" }" }.joined(separator: ",")
        let json = """
        { "campaigns": [{
            "id": "\(id)",
            "type": "\(type)",
            "variationGroups": [{
                "id": "vg1",
                "name": "Group One",
                "variations": [\(variationsJSON)]
            }]
        }]}
        """
        return try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8)).campaigns[0]
    }

    // MARK: - Instantiate

    func testInstantiateReturnsView() {
        XCTAssertNotNil(sut)
    }

    func testSectionsStackViewExistsAfterInstantiate() {
        XCTAssertNotNil(sectionsStack)
    }

    // MARK: - configure(with:) — nil / empty

    func testConfigureWithNilCampaignShowsEmptyLabel() {
        sut.configure(with: nil)
        XCTAssertEqual(sectionsStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(sectionsStack?.arrangedSubviews.first is UILabel)
    }

    func testConfigureWithNilCampaignLabelTextIsNoVariations() {
        sut.configure(with: nil)
        let label = sectionsStack?.arrangedSubviews.first as? UILabel
        XCTAssertEqual(label?.text, "No variations")
    }

    func testConfigureWithNoVariationsShowsEmptyLabel() {
        let campaign = makeCampaign(variations: [])
        sut.configure(with: campaign)
        XCTAssertEqual(sectionsStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(sectionsStack?.arrangedSubviews.first is UILabel)
    }

    // MARK: - configure(with:) — with variations

    func testConfigureWithOneVariationAddsOneSectionView() {
        let campaign = makeCampaign(variations: [("v1", "Original")])
        sut.configure(with: campaign)
        XCTAssertEqual(sectionsStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(sectionsStack?.arrangedSubviews.first is QAVariationSectionView)
    }

    func testConfigureWithThreeVariationsAddsThreeSectionViews() {
        let campaign = makeCampaign(variations: [("v1", "A"), ("v2", "B"), ("v3", "C")])
        sut.configure(with: campaign)
        let arranged = sectionsStack?.arrangedSubviews ?? []
        XCTAssertEqual(arranged.count, 3)
        XCTAssertTrue(arranged.allSatisfy { $0 is QAVariationSectionView })
    }

    func testConfigureReplacesContentOnReconfigure() {
        let first = makeCampaign(variations: [("v1", "A"), ("v2", "B")])
        sut.configure(with: first)
        XCTAssertEqual(sectionsStack?.arrangedSubviews.count, 2)

        let second = makeCampaign(variations: [("v3", "C")])
        sut.configure(with: second)
        XCTAssertEqual(sectionsStack?.arrangedSubviews.count, 1)
    }

    func testReconfigureWithNilAfterDataShowsEmptyLabel() {
        sut.configure(with: makeCampaign(variations: [("v1", "A")]))
        sut.configure(with: nil)
        XCTAssertEqual(sectionsStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(sectionsStack?.arrangedSubviews.first is UILabel)
    }
}

// MARK: - QAVariationViewCtrlTests

final class QAVariationViewCtrlTests: XCTestCase {

    private var sut: QAVariationViewCtrl!
    private let dummyTable = UITableView()
    private let testCampaignId = "test_camp_unit"

    override func setUp() {
        super.setUp()
        sut = QAVariationViewCtrl()
        // Clean UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "initial_variation_\(testCampaignId)")
        UserDefaults.standard.removeObject(forKey: "selected_variation_\(testCampaignId)")
    }

    override func tearDown() {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "initial_variation_\(testCampaignId)")
        UserDefaults.standard.removeObject(forKey: "selected_variation_\(testCampaignId)")
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeCampaign(id: String? = nil,
                              type: String = "ab",
                              groups: [( groupId: String, groupName: String, variations: [(id: String, name: String, isAssigned: Bool)] )] = []) -> Campaign {
        let campaignId = id ?? testCampaignId
        let groupsJSON = groups.map { group in
            let varsJSON = group.variations.map { v in
                "{ \"id\": \"\(v.id)\", \"name\": \"\(v.name)\" }"
            }.joined(separator: ",")
            return "{ \"id\": \"\(group.groupId)\", \"name\": \"\(group.groupName)\", \"variations\": [\(varsJSON)] }"
        }.joined(separator: ",")

        let json = """
        { "campaigns": [{
            "id": "\(campaignId)",
            "type": "\(type)",
            "variationGroups": [\(groupsJSON)]
        }]}
        """
        var campaign = try! JSONDecoder().decode(BucketingResponse.self, from: Data(json.utf8)).campaigns[0]

        // Apply isAssigned runtime flags
        for (gi, group) in groups.enumerated() {
            for (vi, v) in group.variations.enumerated() {
                campaign.variationGroups[gi].variations[vi].isAssigned = v.isAssigned
            }
        }
        return campaign
    }

    // MARK: - canChangeVariation default

    func testCanChangeVariationDefaultIsTrue() {
        XCTAssertTrue(sut.canChangeVariation)
    }

    // MARK: - updateInteractivity

    func testUpdateInteractivityToFalseSetsFlag() {
        sut.updateInteractivity(false)
        XCTAssertFalse(sut.canChangeVariation)
    }

    func testUpdateInteractivityToTrueSetsFlag() {
        sut.updateInteractivity(false)
        sut.updateInteractivity(true)
        XCTAssertTrue(sut.canChangeVariation)
    }

    // MARK: - numberOfSections (via variations computed property)

    func testNumberOfSectionsZeroWithNilCampaign() {
        sut.campaign = nil
        XCTAssertEqual(sut.numberOfSections(in: dummyTable), 0)
    }

    func testNumberOfSectionsMatchesVariationCount() {
        sut.campaign = makeCampaign(groups: [
            ("vg1", "Group", [("v1", "Ref", false), ("v2", "Var", false)])
        ])
        XCTAssertEqual(sut.numberOfSections(in: dummyTable), 2)
    }

    func testNumberOfSectionsAcrossMultipleGroups() {
        sut.campaign = makeCampaign(groups: [
            ("vg1", "G1", [("v1", "A", false), ("v2", "B", false)]),
            ("vg2", "G2", [("v3", "C", false)])
        ])
        XCTAssertEqual(sut.numberOfSections(in: dummyTable), 3)
    }

    // MARK: - numberOfRowsInSection — collapsed by default

    func testNumberOfRowsIsZeroWhenSectionCollapsed() {
        sut.campaign = makeCampaign(groups: [("vg1", "G", [("v1", "A", false)])])
        XCTAssertEqual(sut.tableView(dummyTable, numberOfRowsInSection: 0), 0)
    }

    // MARK: - ab vs perso variation names (verified via section header title label)

    func testAbCampaignDoesNotPrefixVariationName() {
        sut.campaign = makeCampaign(type: "ab", groups: [
            ("vg1", "Group", [("v1", "Original", false)])
        ])
        let header = sut.tableView(dummyTable, viewForHeaderInSection: 0)
        let label = header?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertEqual(label?.text, "Original")
    }

    func testPersoCampaignPrefixesVariationNameWithGroupName() {
        sut.campaign = makeCampaign(type: "perso", groups: [
            ("vg1", "My Group", [("v1", "Variant A", false)])
        ])
        let header = sut.tableView(dummyTable, viewForHeaderInSection: 0)
        let label = header?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertEqual(label?.text, "My Group - Variant A")
    }

    // MARK: - UserDefaults — loadInitialVariation

    func testFirstViewSavesAssignedVariationToUserDefaults() {
        sut.campaign = makeCampaign(groups: [
            ("vg1", "G", [("v1", "Ref", true), ("v2", "Var", false)])
        ])
        sut.loadViewIfNeeded()

        let saved = UserDefaults.standard.string(forKey: "initial_variation_\(testCampaignId)")
        XCTAssertEqual(saved, "v1")
    }

    func testSubsequentViewReadsExistingInitialVariation() {
        // Pre-seed a saved initial variation
        UserDefaults.standard.set("v2", forKey: "initial_variation_\(testCampaignId)")

        sut.campaign = makeCampaign(groups: [
            ("vg1", "G", [("v1", "Ref", true), ("v2", "Var", false)])
        ])
        sut.loadViewIfNeeded()

        // The pre-seeded value must not be overwritten
        let saved = UserDefaults.standard.string(forKey: "initial_variation_\(testCampaignId)")
        XCTAssertEqual(saved, "v2")
    }

    func testSavedSelectedVariationIsRestoredOnLoad() {
        UserDefaults.standard.set("v2", forKey: "selected_variation_\(testCampaignId)")

        sut.campaign = makeCampaign(groups: [
            ("vg1", "G", [("v1", "Ref", true), ("v2", "Var", false)])
        ])
        sut.loadViewIfNeeded()

        // v2 should now be assigned, v1 should not
        let assigned = sut.campaign?.variationGroups.flatMap { $0.variations }.filter { $0.isAssigned }.map { $0.id }
        XCTAssertEqual(assigned, ["v2"])
    }

    func testStaleSavedSelectionIsRemovedFromUserDefaults() {
        // "v99" doesn't exist in the campaign → stale, should be removed
        UserDefaults.standard.set("v99", forKey: "selected_variation_\(testCampaignId)")

        sut.campaign = makeCampaign(groups: [
            ("vg1", "G", [("v1", "Ref", true), ("v2", "Var", false)])
        ])
        sut.loadViewIfNeeded()

        let saved = UserDefaults.standard.string(forKey: "selected_variation_\(testCampaignId)")
        XCTAssertNil(saved)
    }
}
