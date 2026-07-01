//
//  QAModelsTests.swift
//  ABTastyQAssistant_Tests
//

import XCTest
import UIKit
@testable import ABTastyQAssistant

final class QAHitEventTests: XCTestCase {

    func testInitStoresHitType() {
        let event = QAHitEvent(hitType: "pageview", payload: [:])
        XCTAssertEqual(event.hitType, "pageview")
    }

    func testInitStoresPayload() {
        let payload: [String: Any] = ["key": "value", "count": 42]
        let event = QAHitEvent(hitType: "event", payload: payload)
        XCTAssertEqual(event.payload["key"] as? String, "value")
        XCTAssertEqual(event.payload["count"] as? Int, 42)
    }

    func testInitStoresExplicitTimestamp() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let event = QAHitEvent(hitType: "event", payload: [:], timestamp: date)
        XCTAssertEqual(event.timestamp, date)
    }

    func testDefaultTimestampIsNow() {
        let before = Date()
        let event = QAHitEvent(hitType: "event", payload: [:])
        let after = Date()
        XCTAssertGreaterThanOrEqual(event.timestamp, before)
        XCTAssertLessThanOrEqual(event.timestamp, after)
    }

    func testEmptyPayload() {
        let event = QAHitEvent(hitType: "hit", payload: [:])
        XCTAssertTrue(event.payload.isEmpty)
    }

    func testPayloadWithMultipleTypes() {
        let payload: [String: Any] = [
            "string": "hello",
            "int": 1,
            "bool": true,
            "double": 3.14
        ]
        let event = QAHitEvent(hitType: "hit", payload: payload)
        XCTAssertEqual(event.payload.count, 4)
        XCTAssertEqual(event.payload["string"] as? String, "hello")
        XCTAssertEqual(event.payload["int"] as? Int, 1)
        XCTAssertEqual(event.payload["bool"] as? Bool, true)
        XCTAssertEqual(event.payload["double"] as? Double, 3.14)
    }
}

final class OverlayRestoreDelegateTests: XCTestCase {

    func testOnDismissIsCalledWhenDelegateMethodFires() {
        var wasCalled = false
        let delegate = OverlayRestoreDelegate { wasCalled = true }

        let presented = UIViewController()
        let presenting = UIViewController()
        let controller = UIPresentationController(presentedViewController: presented,
                                                  presenting: presenting)
        delegate.presentationControllerDidDismiss(controller)

        XCTAssertTrue(wasCalled)
    }

    func testOnDismissIsCalledExactlyOnce() {
        var callCount = 0
        let delegate = OverlayRestoreDelegate { callCount += 1 }

        let presented = UIViewController()
        let presenting = UIViewController()
        let controller = UIPresentationController(presentedViewController: presented,
                                                  presenting: presenting)
        delegate.presentationControllerDidDismiss(controller)

        XCTAssertEqual(callCount, 1)
    }

    func testMultipleDismissCallsEachFireClosure() {
        var callCount = 0
        let delegate = OverlayRestoreDelegate { callCount += 1 }

        let presented = UIViewController()
        let presenting = UIViewController()
        let controller = UIPresentationController(presentedViewController: presented,
                                                  presenting: presenting)
        delegate.presentationControllerDidDismiss(controller)
        delegate.presentationControllerDidDismiss(controller)

        XCTAssertEqual(callCount, 2)
    }
}
