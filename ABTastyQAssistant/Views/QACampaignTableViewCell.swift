//
//  QACampaignTableViewCell.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 19/05/2026.
//

import UIKit

private extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16)/255
        let g = CGFloat((rgb & 0x00FF00) >> 8)/255
        let b = CGFloat(rgb & 0x0000FF)/255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

class QACampaignTableViewCell: UITableViewCell {
    @IBOutlet var titleCampaign: UILabel?
    @IBOutlet var typeCampaign: UILabel?
    @IBOutlet var status: UIButton?

    override func awakeFromNib() {
        super.awakeFromNib()
        tintColor = UIColor(red: 42/255, green: 42/255, blue: 60/255, alpha: 1)

        // Configure title label for long text
        titleCampaign?.lineBreakMode = .byTruncatingTail
        titleCampaign?.numberOfLines = 2
    }

    func configure(with campaign: Campaign) {
        titleCampaign?.text = campaign.name ?? "-"
        typeCampaign?.text = campaignType(from: campaign.type ?? "")
        tintColor = UIColor(red: 42/255, green: 42/255, blue: 60/255, alpha: 1)

        status?.isUserInteractionEnabled = false
        status?.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 2, trailing: 12)
        status?.titleLabel?.font = UIFont.latoBold(size: 15)

        let title: String
        let bgColor: UIColor
        let textColor: UIColor

        if campaign.isActive {
            if !campaign.isHidden {
                title = "Accepted"
                bgColor = UIColor(hex: "c7f4ee")
                textColor = UIColor(hex: "00332b")
            } else {
                title = "Hidden"
                bgColor = UIColor(hex: "ffecbd")
                textColor = UIColor(hex: "332600")
            }
        } else {
            if campaign.isForced {
                title = "Forced"
                bgColor = UIColor(hex: "ffecbd")
                textColor = UIColor(hex: "332600")
            } else {
                title = "Rejected"
                bgColor = UIColor(hex: "fed1cd")
                textColor = UIColor(hex: "310502")
            }
        }

        status?.setTitle(title, for: .normal)
        status?.setTitleColor(textColor, for: .normal)
        status?.backgroundColor = bgColor
    }

    private func campaignType(from type: String) -> String {
        switch type {
        case "ab": return "A/B Test"
        case "toggle": return "Feature Toggle"
        case "perso": return "Personalization"
        default: return type
        }
    }
}
