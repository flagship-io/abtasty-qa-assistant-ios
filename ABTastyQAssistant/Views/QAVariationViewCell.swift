//
//  QAVariationViewCell.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 03/06/2026.
//

import UIKit

class PaddedLabel: UILabel {
    var contentInsets = UIEdgeInsets.zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + contentInsets.left + contentInsets.right,
                      height: size.height + contentInsets.top + contentInsets.bottom)
    }
}

class QAVariationViewCell: UITableViewCell {
    @IBOutlet var keyFlag: UILabel?
    @IBOutlet var valueFlag: PaddedLabel?
    @IBOutlet var containerView: UIView?
    @IBOutlet var operatorFlag: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView?.layer.cornerRadius = 4
        containerView?.layer.masksToBounds = true
        operatorFlag?.layer.borderWidth = 1
        operatorFlag?.layer.masksToBounds = true
        operatorFlag?.layer.borderColor = UIColor(red: 0xD8/255, green: 0xD8/255, blue: 0xE2/255, alpha: 1).cgColor
        valueFlag?.layer.masksToBounds = true
        valueFlag?.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let label = operatorFlag {
            label.layer.cornerRadius = label.bounds.height / 2
        }
        if let label = valueFlag {
            label.layer.cornerRadius = label.bounds.height / 2
        }
    }

    func configure(with flag: (key: String, value: String)) {
        keyFlag?.text = flag.key
        valueFlag?.text = flag.value
    }


}
