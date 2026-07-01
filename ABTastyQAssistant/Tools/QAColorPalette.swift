//
//  QAColorPalette.swift
//  ABTastyQAssistant
//

import UIKit

enum QAColorPalette {
    // Green (match / accepted)
    static let greenBg  = UIColor(red: 240/255, green: 255/255, blue: 253/255, alpha: 1)
    static let greenBdr = UIColor(red: 199/255, green: 244/255, blue: 238/255, alpha: 1)

    // Red (rejected)
    static let redBg    = UIColor(red: 255/255, green: 240/255, blue: 240/255, alpha: 1)
    static let redBdr   = UIColor(red: 255/255, green: 205/255, blue: 210/255, alpha: 1)

    // Amber (forced / warning)
    static let amberBg  = UIColor(red: 255/255, green: 250/255, blue: 240/255, alpha: 1)
    static let amberBdr = UIColor(red: 255/255, green: 214/255, blue: 102/255, alpha: 1)

    // Icon tints
    static let checkGreen = UIColor(red:   0/255, green: 128/255, blue: 108/255, alpha: 1)
    static let checkAmber = UIColor(red: 161/255, green: 108/255, blue:  12/255, alpha: 1)

    // Allocation-specific
    static let pillBlue = UIColor(red: 219/255, green: 229/255, blue: 255/255, alpha: 1)
    static let warnBg   = UIColor(red: 255/255, green: 236/255, blue: 189/255, alpha: 1)
    static let warnBdr  = UIColor(red: 255/255, green: 214/255, blue: 102/255, alpha: 1)
    static let warnFg   = UIColor(red:  77/255, green:  55/255, blue:   0/255, alpha: 1)

    // Targeting-specific
    static let tagBg    = UIColor(red: 237/255, green: 237/255, blue: 242/255, alpha: 1)
    static let tagBdr   = UIColor(red: 216/255, green: 216/255, blue: 226/255, alpha: 1)
    static let purple   = UIColor(red:  49/255, green:   0/255, blue: 191/255, alpha: 1)
    static let pillGray = UIColor(red: 240/255, green: 240/255, blue: 247/255, alpha: 1)
    static let opBg     = UIColor(red: 0.989,   green: 0.989,   blue: 0.991,   alpha: 1)
}
