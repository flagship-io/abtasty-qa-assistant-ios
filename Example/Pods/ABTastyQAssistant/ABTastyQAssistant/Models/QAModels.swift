//
//  QAModels.swift
//  ABTastyQAssistant
//

import Foundation
import UIKit

// MARK: - QAHitEvent

public struct QAHitEvent {
    public let hitType: String
    public let payload: [String: Any]
    public let timestamp: Date

    public init(hitType: String, payload: [String: Any], timestamp: Date = Date()) {
        self.hitType   = hitType
        self.payload   = payload
        self.timestamp = timestamp
    }
}

// MARK: - OverlayRestoreDelegate

/// Calls `onDismiss` when the presented sheet is dismissed (interactive swipe-down).
final class OverlayRestoreDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void
    init(_ onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
