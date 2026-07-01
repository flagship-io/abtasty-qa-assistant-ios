//
//  BucketingResponseTests.swift
//  ABTastyQAssistant_Tests
//
//  Unit tests for defensive Codable decoding and runtime model logic.
//

import XCTest
@testable import ABTastyQAssistant

final class BucketingResponseTests: XCTestCase {

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private let fullJSON = """
    {
      "panic": null,
      "hasConsented": true,
      "campaigns": [
        {
          "id": "camp_1",
          "name": "Homepage CTA",
          "type": "ab",
          "slug": "homepage-cta",
          "variationGroups": [
            {
              "id": "vg_1",
              "name": "Default group",
              "variations": [
                { "id": "v_ref", "name": "Original", "reference": true, "allocation": 50 },
                { "id": "v_test", "name": "Variant", "reference": false, "allocation": 50,
                  "modifications": { "type": "FLAG", "value": { "btnColor": "green", "count": 3 } } }
              ],
              "targeting": {
                "targetingGroups": [
                  { "targetings": [ { "operator": "EQUALS", "key": "country", "value": "FR" } ] }
                ]
              }
            }
          ]
        }
      ]
    }
    """

    // MARK: - Full decode

    func testDecodesFullResponse() throws {
        let response = try decode(BucketingResponse.self, from: fullJSON)

        XCTAssertEqual(response.campaigns.count, 1)
        XCTAssertEqual(response.hasConsented, true)
        XCTAssertNil(response.panic)

        let campaign = response.campaigns[0]
        XCTAssertEqual(campaign.id, "camp_1")
        XCTAssertEqual(campaign.name, "Homepage CTA")
        XCTAssertEqual(campaign.variationGroups.count, 1)

        let group = campaign.variationGroups[0]
        XCTAssertEqual(group.variations.count, 2)
        XCTAssertEqual(group.targeting?.targetingGroups.first?.targetings.first?.key, "country")

        let variant = group.variations[1]
        XCTAssertEqual(variant.id, "v_test")
        XCTAssertEqual(variant.allocation, 50)
        XCTAssertEqual(variant.modifications?.type, "FLAG")
        if case .string(let color)? = variant.modifications?.value["btnColor"] {
            XCTAssertEqual(color, "green")
        } else {
            XCTFail("Expected btnColor string modification")
        }
    }

    // MARK: - Runtime defaults

    func testRuntimeFlagsDefaultToFalse() throws {
        let campaign = try decode(BucketingResponse.self, from: fullJSON).campaigns[0]
        XCTAssertFalse(campaign.isActive)
        XCTAssertFalse(campaign.isHidden)
        XCTAssertFalse(campaign.isForced)
        XCTAssertNil(campaign.isTargetingRespected)
        XCTAssertFalse(campaign.variationGroups[0].variations[0].isAssigned)
    }

    // MARK: - Defensive decoding

    func testMissingCampaignsDefaultsToEmpty() throws {
        let response = try decode(BucketingResponse.self, from: "{}")
        XCTAssertTrue(response.campaigns.isEmpty)
        XCTAssertNil(response.hasConsented)
    }

    func testCampaignWithMissingFieldsUsesDefaults() throws {
        let json = """
        { "campaigns": [ { "name": "no id here" } ] }
        """
        let campaign = try decode(BucketingResponse.self, from: json).campaigns[0]
        XCTAssertEqual(campaign.id, "")               // missing id -> ""
        XCTAssertTrue(campaign.variationGroups.isEmpty)
        XCTAssertNil(campaign.traffic)
    }

    func testMalformedVariationsDoNotCrashDecoding() throws {
        // `variations` is the wrong type -> defensive decoder yields [].
        let json = """
        { "campaigns": [ { "id": "c", "variationGroups": [ { "id": "g", "variations": "oops" } ] } ] }
        """
        let campaign = try decode(BucketingResponse.self, from: json).campaigns[0]
        XCTAssertEqual(campaign.variationGroups.count, 1)
        XCTAssertTrue(campaign.variationGroups[0].variations.isEmpty)
    }

    // MARK: - assignFetchedVariation

    func testAssignFetchedVariationByID() throws {
        var campaign = try decode(BucketingResponse.self, from: fullJSON).campaigns[0]
        campaign.assignFetchedVariation(id: "v_test")

        let vars = campaign.variationGroups[0].variations
        XCTAssertFalse(vars[0].isAssigned)            // v_ref
        XCTAssertTrue(vars[1].isAssigned)             // v_test
    }

    func testAssignFetchedVariationFallsBackToReference() throws {
        var campaign = try decode(BucketingResponse.self, from: fullJSON).campaigns[0]
        campaign.assignFetchedVariation(id: nil)

        let vars = campaign.variationGroups[0].variations
        XCTAssertTrue(vars[0].isAssigned)             // reference == true
        XCTAssertFalse(vars[1].isAssigned)
    }

    func testAssignUnknownFetchedIDAssignsNothing() throws {
        var campaign = try decode(BucketingResponse.self, from: fullJSON).campaigns[0]
        campaign.assignFetchedVariation(id: "does_not_exist")

        let assigned = campaign.variationGroups[0].variations.filter(\.isAssigned)
        XCTAssertTrue(assigned.isEmpty)
    }

    // MARK: - JSONValue

    func testJSONValueDecodesEachType() throws {
        let json = """
        { "s": "txt", "i": 42, "d": 3.14, "b": true, "n": null,
          "arr": [1, "two"], "obj": { "k": "v" } }
        """
        let dict = try decode([String: JSONValue].self, from: json)

        guard case .string(let s) = dict["s"] else { return XCTFail("s") }
        XCTAssertEqual(s, "txt")
        guard case .int(let i) = dict["i"] else { return XCTFail("i") }
        XCTAssertEqual(i, 42)
        guard case .double(let d) = dict["d"] else { return XCTFail("d") }
        XCTAssertEqual(d, 3.14, accuracy: 0.0001)
        guard case .bool(let b) = dict["b"] else { return XCTFail("b") }
        XCTAssertTrue(b)
        guard case .null = dict["n"] else { return XCTFail("n") }
        guard case .array = dict["arr"] else { return XCTFail("arr") }
        guard case .object = dict["obj"] else { return XCTFail("obj") }
    }

    func testJSONValueDescription() {
        XCTAssertEqual(JSONValue.string("hi").description, "hi")
        XCTAssertEqual(JSONValue.int(7).description, "7")
        XCTAssertEqual(JSONValue.bool(true).description, "true")
        XCTAssertEqual(JSONValue.null.description, "null")
        XCTAssertEqual(JSONValue.array([.int(1), .int(2)]).description, "[1, 2]")
    }

    func testJSONValueRoundTripsThroughEncoding() throws {
        let original: JSONValue = .object(["a": .int(1), "b": .array([.string("x"), .bool(false)])])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        guard case .object(let obj) = decoded else { return XCTFail("expected object") }
        guard case .int(let a) = obj["a"] else { return XCTFail("a") }
        XCTAssertEqual(a, 1)
    }
}
