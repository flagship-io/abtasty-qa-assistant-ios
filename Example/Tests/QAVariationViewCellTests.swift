//
//  QAVariationViewCellTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
@testable import ABTastyQAssistant

final class QAVariationViewCellTests: XCTestCase {

    private var sut: QAVariationViewCell!

    override func setUp() {
        super.setUp()
        sut = QAVariationViewCell(style: .default, reuseIdentifier: nil)
        // Wire outlets manually — awakeFromNib is not called in programmatic init
        sut.keyFlag = UILabel()
        sut.valueFlag = PaddedLabel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - configure(with:)

    func testConfigureSetsKeyText() {
        sut.configure(with: (key: "isVIP", value: "true"))
        XCTAssertEqual(sut.keyFlag?.text, "isVIP")
    }

    func testConfigureSetsValueText() {
        sut.configure(with: (key: "isVIP", value: "true"))
        XCTAssertEqual(sut.valueFlag?.text, "true")
    }

    func testConfigureWithEmptyKeyAndValue() {
        sut.configure(with: (key: "", value: ""))
        XCTAssertEqual(sut.keyFlag?.text, "")
        XCTAssertEqual(sut.valueFlag?.text, "")
    }

    func testConfigureWithSpecialCharacters() {
        sut.configure(with: (key: "user.name", value: "Alice & Bob"))
        XCTAssertEqual(sut.keyFlag?.text, "user.name")
        XCTAssertEqual(sut.valueFlag?.text, "Alice & Bob")
    }

    func testReconfigureUpdatesLabels() {
        sut.configure(with: (key: "old_key", value: "old_value"))
        sut.configure(with: (key: "new_key", value: "new_value"))
        XCTAssertEqual(sut.keyFlag?.text, "new_key")
        XCTAssertEqual(sut.valueFlag?.text, "new_value")
    }

    // MARK: - PaddedLabel intrinsicContentSize

    func testPaddedLabelAddsInsets() {
        let label = PaddedLabel()
        label.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        label.text = "Test"
        let baseSize = UILabel().intrinsicContentSize  // without insets
        let paddedSize = label.intrinsicContentSize
        XCTAssertGreaterThan(paddedSize.width, baseSize.width)
        XCTAssertGreaterThan(paddedSize.height, baseSize.height)
    }

    func testPaddedLabelZeroInsets() {
        let label = PaddedLabel()
        label.contentInsets = .zero
        label.text = "Test"
        let plain = UILabel()
        plain.text = "Test"
        XCTAssertEqual(label.intrinsicContentSize.width, plain.intrinsicContentSize.width)
        XCTAssertEqual(label.intrinsicContentSize.height, plain.intrinsicContentSize.height)
    }
}
