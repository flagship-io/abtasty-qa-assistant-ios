//
//  QATargetingEvaluatorTests.swift
//  ABTastyQAssistant_Tests
//
//  Unit tests for the pure targeting-condition logic.
//

import XCTest
@testable import ABTastyQAssistant

final class QATargetingEvaluatorTests: XCTestCase {

    // MARK: - Helpers

    /// Builds an `ItemTarget` by decoding JSON (the struct only exposes `init(from:)`).
    private func makeTarget(operator op: String, key: String, value: Any) -> ItemTarget {
        let json: [String: Any] = ["operator": op, "key": key, "value": value]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(ItemTarget.self, from: data)
    }

    private func eval(_ op: String, key: String = "k", value: Any, context: [String: Any]) -> Bool {
        QATargetingEvaluator.isConditionMet(makeTarget(operator: op, key: key, value: value), in: context)
    }

    // MARK: - fs_all_users

    func testAllUsersAlwaysMatches() {
        let target = makeTarget(operator: "EQUALS", key: "fs_all_users", value: true)
        XCTAssertTrue(QATargetingEvaluator.isConditionMet(target, in: [:]))
        XCTAssertTrue(QATargetingEvaluator.isConditionMet(target, in: ["k": "v"]))
    }

    // MARK: - Missing context / key

    func testEmptyContextFails() {
        XCTAssertFalse(eval("EQUALS", value: "v", context: [:]))
    }

    func testMissingKeyFails() {
        XCTAssertFalse(eval("EQUALS", key: "missing", value: "v", context: ["other": "v"]))
    }

    // MARK: - EQUALS / NOT_EQUALS

    func testEqualsString() {
        XCTAssertTrue(eval("EQUALS", value: "fr", context: ["k": "fr"]))
        XCTAssertFalse(eval("EQUALS", value: "fr", context: ["k": "en"]))
    }

    func testEqualsInt() {
        XCTAssertTrue(eval("EQUALS", value: 25, context: ["k": 25]))
        XCTAssertFalse(eval("EQUALS", value: 25, context: ["k": 30]))
    }

    func testEqualsBool() {
        XCTAssertTrue(eval("EQUALS", value: true, context: ["k": true]))
        XCTAssertFalse(eval("EQUALS", value: true, context: ["k": false]))
    }

    func testEqualsWithArrayMatchesAnyMember() {
        XCTAssertTrue(eval("EQUALS", value: ["fr", "en", "de"], context: ["k": "en"]))
        XCTAssertFalse(eval("EQUALS", value: ["fr", "en", "de"], context: ["k": "es"]))
    }

    func testNotEquals() {
        XCTAssertTrue(eval("NOT_EQUALS", value: "fr", context: ["k": "en"]))
        XCTAssertFalse(eval("NOT_EQUALS", value: "fr", context: ["k": "fr"]))
    }

    func testNotEqualsWithArray() {
        XCTAssertFalse(eval("NOT_EQUALS", value: ["fr", "en"], context: ["k": "en"]))
        XCTAssertTrue(eval("NOT_EQUALS", value: ["fr", "en"], context: ["k": "es"]))
    }

    // MARK: - CONTAINS / NOT_CONTAINS

    func testContains() {
        XCTAssertTrue(eval("CONTAINS", value: "ell", context: ["k": "hello"]))
        XCTAssertFalse(eval("CONTAINS", value: "xyz", context: ["k": "hello"]))
    }

    func testContainsNonStringContextFails() {
        XCTAssertFalse(eval("CONTAINS", value: "1", context: ["k": 123]))
    }

    func testNotContains() {
        XCTAssertTrue(eval("NOT_CONTAINS", value: "xyz", context: ["k": "hello"]))
        XCTAssertFalse(eval("NOT_CONTAINS", value: "ell", context: ["k": "hello"]))
    }

    func testContainsWithArray() {
        XCTAssertTrue(eval("CONTAINS", value: ["zzz", "ell"], context: ["k": "hello"]))
        XCTAssertFalse(eval("CONTAINS", value: ["zzz", "yyy"], context: ["k": "hello"]))
    }

    // MARK: - Numeric comparisons

    func testGreaterThan() {
        XCTAssertTrue(eval("GREATER_THAN", value: 18, context: ["k": 25]))
        XCTAssertFalse(eval("GREATER_THAN", value: 18, context: ["k": 18]))
        XCTAssertFalse(eval("GREATER_THAN", value: 18, context: ["k": 10]))
    }

    func testLowerThan() {
        XCTAssertTrue(eval("LOWER_THAN", value: 18, context: ["k": 10]))
        XCTAssertFalse(eval("LOWER_THAN", value: 18, context: ["k": 18]))
    }

    func testGreaterThanOrEquals() {
        XCTAssertTrue(eval("GREATER_THAN_OR_EQUALS", value: 18, context: ["k": 18]))
        XCTAssertTrue(eval("GREATER_THAN_OR_EQUALS", value: 18, context: ["k": 19]))
        XCTAssertFalse(eval("GREATER_THAN_OR_EQUALS", value: 18, context: ["k": 17]))
    }

    func testLowerThanOrEquals() {
        XCTAssertTrue(eval("LOWER_THAN_OR_EQUALS", value: 18, context: ["k": 18]))
        XCTAssertFalse(eval("LOWER_THAN_OR_EQUALS", value: 18, context: ["k": 19]))
    }

    func testNumericComparisonMixesIntAndDouble() {
        XCTAssertTrue(eval("GREATER_THAN", value: 18.5, context: ["k": 19]))
        XCTAssertTrue(eval("LOWER_THAN", value: 18, context: ["k": 17.9]))
    }

    func testNumericComparisonWithNonNumericFails() {
        XCTAssertFalse(eval("GREATER_THAN", value: 18, context: ["k": "abc"]))
    }

    // MARK: - STARTS_WITH / ENDS_WITH

    func testStartsWith() {
        XCTAssertTrue(eval("STARTS_WITH", value: "he", context: ["k": "hello"]))
        XCTAssertFalse(eval("STARTS_WITH", value: "lo", context: ["k": "hello"]))
    }

    func testEndsWith() {
        XCTAssertTrue(eval("ENDS_WITH", value: "lo", context: ["k": "hello"]))
        XCTAssertFalse(eval("ENDS_WITH", value: "he", context: ["k": "hello"]))
    }

    func testStartsWithArray() {
        XCTAssertTrue(eval("STARTS_WITH", value: ["foo", "he"], context: ["k": "hello"]))
        XCTAssertFalse(eval("STARTS_WITH", value: ["foo", "bar"], context: ["k": "hello"]))
    }

    // MARK: - Operator casing & unknown operators

    func testOperatorIsCaseInsensitive() {
        XCTAssertTrue(eval("equals", value: "fr", context: ["k": "fr"]))
    }

    func testUnknownOperatorFails() {
        XCTAssertFalse(eval("REGEX_MATCH", value: "fr", context: ["k": "fr"]))
    }
}
