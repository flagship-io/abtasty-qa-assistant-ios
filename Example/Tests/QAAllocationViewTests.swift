//
//  QAAllocationViewTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
@testable import ABTastyQAssistant

final class QAAllocationViewTests: XCTestCase {

    private var sut: QAAllocationView!

    override func setUp() {
        super.setUp()
        sut = QAAllocationView(frame: .zero)
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

    /// Builds a Campaign with the given type, runtime flags, and group count.
    /// `groupNames` sets optional names for groups in order; remaining groups get nil names.
    private func makeCampaign(type: String = "ab",
                               isActive: Bool = false,
                               isForced: Bool = false,
                               groupCount: Int = 1,
                               groupNames: [String?] = []) -> Campaign {
        let names = groupNames + Array(repeating: nil as String?, count: max(0, groupCount - groupNames.count))
        let groupsJSON = (0..<groupCount).map { i in
            let nameJSON = names[i].map { "\"\($0)\"" } ?? "null"
            return """
            {"id":"vg\(i)","name":\(nameJSON),"variations":[{"id":"v\(i)","name":"Variation \(i)","allocation":100}]}
            """
        }.joined(separator: ",")

        let json = """
        {"campaigns":[{"id":"c1","type":"\(type)","variationGroups":[\(groupsJSON)]}]}
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

    func testConfigureWithNilShowsEmptyLabel() {
        sut.configure(with: nil)
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UILabel)
    }

    func testConfigureWithNilLabelText() {
        sut.configure(with: nil)
        let lbl = contentStack?.arrangedSubviews.first as? UILabel
        XCTAssertEqual(lbl?.text, "No allocation data available")
    }

    // MARK: - Empty variation groups

    func testConfigureWithNoGroupsShowsEmptyLabel() {
        sut.configure(with: makeCampaign(groupCount: 0))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UILabel)
    }

    // MARK: - Active campaign (no warning banner)

    func testActiveCampaignOneGroupAddsOneGroupRow() {
        sut.configure(with: makeCampaign(isActive: true, groupCount: 1))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UIStackView)
    }

    func testActiveCampaignTwoGroupsAddsTwoRows() {
        sut.configure(with: makeCampaign(isActive: true, groupCount: 2))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
    }

    // MARK: - Inactive campaign (warning banner added per group)

    func testInactiveNonForcedAddsGroupRowAndWarningBanner() {
        // isActive=false, isForced=false → 1 group row + 1 warning banner
        sut.configure(with: makeCampaign(groupCount: 1))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
    }

    func testInactiveForcedAddsGroupRowAndWarningBanner() {
        sut.configure(with: makeCampaign(isForced: true, groupCount: 1))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
    }

    func testInactiveNonForcedWarningMessageMentionsUntrackedTraffic() {
        sut.configure(with: makeCampaign(groupCount: 1))
        // Warning structure: stack[1] = wrapper UIView → banner UIView → UILabel
        let wrapper = contentStack?.arrangedSubviews[1]
        let banner = wrapper?.subviews.first
        let lbl = banner?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertTrue(lbl?.text?.contains("untracked") ?? false, "Expected 'untracked' in warning text")
    }

    func testInactiveForcedWarningMessageMentionsBypassed() {
        sut.configure(with: makeCampaign(isForced: true, groupCount: 1))
        let wrapper = contentStack?.arrangedSubviews[1]
        let banner = wrapper?.subviews.first
        let lbl = banner?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertTrue(lbl?.text?.contains("bypassed") ?? false, "Expected 'bypassed' in warning text")
    }

    func testInactiveTwoGroupsAddsRowAndBannerForEachGroup() {
        // 2 groups × (row + banner) = 4 items
        sut.configure(with: makeCampaign(groupCount: 2))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 4)
    }

    // MARK: - Perso campaign (group headers)

    func testPersoCampaignWithNamedGroupAddsHeaderAndRow() {
        sut.configure(with: makeCampaign(type: "perso", isActive: true, groupCount: 1, groupNames: ["Alpha Group"]))
        // header wrapper + group row = 2
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)
    }

    func testPersoCampaignGroupHeaderTextMatchesGroupName() {
        sut.configure(with: makeCampaign(type: "perso", isActive: true, groupCount: 1, groupNames: ["My Group"]))
        // Header: stack[0] = wrapper UIView → UILabel
        let headerWrapper = contentStack?.arrangedSubviews[0]
        let headerLabel = headerWrapper?.subviews.first(where: { $0 is UILabel }) as? UILabel
        XCTAssertEqual(headerLabel?.text, "My Group")
    }

    func testPersoCampaignWithNilGroupNameSkipsHeader() {
        // group name is nil → no header added
        sut.configure(with: makeCampaign(type: "perso", isActive: true, groupCount: 1, groupNames: [nil]))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
    }

    // MARK: - Reconfigure

    func testReconfigureReplacesContent() {
        sut.configure(with: makeCampaign(isActive: true, groupCount: 2))
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 2)

        sut.configure(with: nil)
        XCTAssertEqual(contentStack?.arrangedSubviews.count, 1)
        XCTAssertTrue(contentStack?.arrangedSubviews.first is UILabel)
    }
}
