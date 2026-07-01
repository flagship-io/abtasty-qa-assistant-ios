//
//  QAAllocationView.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 01/06/2026.
//

import UIKit

class QAAllocationView: UIView {

    // MARK: - Layout
    private let scrollView = UIScrollView()
    private let stack      = UIStackView()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildLayout()
    }

    private func buildLayout() {
        backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        stack.axis    = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    // MARK: - Configure
    func configure(with campaign: Campaign?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let campaign else {
            stack.addArrangedSubview(makeEmptyLabel("No allocation data available"))
            return
        }

        let isActive = campaign.isActive
        let isForced = campaign.isForced
        let isPerso  = campaign.type?.lowercased() == "perso"

        guard !campaign.variationGroups.isEmpty else {
            stack.addArrangedSubview(makeEmptyLabel("No allocation data available"))
            return
        }

        for group in campaign.variationGroups {
            if isPerso, let name = group.name {
                stack.addArrangedSubview(makeGroupHeader(name))
            }
            stack.addArrangedSubview(makeGroupRow(group, isActive: isActive, isForced: isForced))
            if !isActive {
                let msg = isForced
                    ? " ⚠️ Allocation has been bypassed"
                    : " ⚠️ You are part of the untracked traffic"
                stack.addArrangedSubview(makeWarningBanner(msg))
            }
        }
    }

    // MARK: - Group header (perso)
    private func makeGroupHeader(_ name: String) -> UIView {
        let lbl       = UILabel()
        lbl.text      = name
        lbl.font      = UIFont.latoBold(size: 18)
        lbl.textColor = .label

        let wrapper = UIView()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: wrapper.topAnchor),
            lbl.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            lbl.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24),
            lbl.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        ])
        return wrapper
    }

    // MARK: - Group row (status icon + card)
    private func makeGroupRow(_ group: VariationGroup, isActive: Bool, isForced: Bool) -> UIView {
        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        if isActive || isForced {
            icon.image     = UIImage(named: "check", in: .qaAssistant, compatibleWith: nil)
            icon.tintColor = isForced ? QAColorPalette.checkAmber : QAColorPalette.checkGreen
        } else {
            icon.image     = UIImage(named: "close", in: .qaAssistant, compatibleWith: nil)
            icon.tintColor = .systemRed
        }

        let (bg, bdr): (UIColor, UIColor) = isForced
            ? (QAColorPalette.amberBg, QAColorPalette.amberBdr)
            : (!isActive ? (QAColorPalette.redBg, QAColorPalette.redBdr) : (QAColorPalette.greenBg, QAColorPalette.greenBdr))

        let card = UIView()
        card.backgroundColor    = bg
        card.layer.cornerRadius = 8
        card.layer.borderWidth  = 1
        card.layer.borderColor  = bdr.cgColor

        let cardStack = UIStackView()
        cardStack.axis    = .vertical
        cardStack.spacing = 0
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        if group.variations.isEmpty {
            cardStack.addArrangedSubview(makeEmptyLabel("No variations"))
        } else {
            for (i, variation) in group.variations.enumerated() {
                if i > 0 {
                    cardStack.setCustomSpacing(12, after: cardStack.arrangedSubviews.last!)
                }
                cardStack.addArrangedSubview(makeVariationBlock(variation))
            }
        }

        let row = UIStackView(arrangedSubviews: [icon, card])
        row.axis      = .horizontal
        row.spacing   = 8
        row.alignment = .center
        return row
    }

    // MARK: - Variation row ("Name :   [26%]")
    private func makeVariationBlock(_ variation: Variation) -> UIView {
        let name = variation.name ?? "Variation \(variation.id)"

        let nameLbl       = UILabel()
        nameLbl.text      = "\(name) :"
        nameLbl.font      = UIFont.latoBold(size: 16)
        nameLbl.textColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1)
        nameLbl.numberOfLines = 1
        nameLbl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        nameLbl.setContentCompressionResistancePriority(.required, for: .horizontal)

        let pill = makeAllocationPill("\(variation.allocation ?? 0)%")

        let row       = UIStackView(arrangedSubviews: [nameLbl, pill])
        row.axis      = .horizontal
        row.spacing   = 12
        row.alignment = .center
        return row
    }

    // MARK: - Allocation % pill
    private func makeAllocationPill(_ text: String) -> UILabel {
        let lbl = PillLabel()
        lbl.text               = text
        lbl.font               = UIFont.latoBold(size: 13)
        lbl.textColor          = .black
        lbl.backgroundColor    = QAColorPalette.pillBlue
        lbl.layer.cornerRadius = 12
        lbl.clipsToBounds      = true
        lbl.textAlignment      = .center

        NSLayoutConstraint.activate([
            lbl.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.setContentHuggingPriority(.required, for: .vertical)
        lbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        return lbl
    }

    // UILabel subclass that adds horizontal/vertical insets so the pill
    // reports a correct intrinsicContentSize inside UIStackView.
    private class PillLabel: UILabel {
        private let insets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)

        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.inset(by: insets))
        }

        override var intrinsicContentSize: CGSize {
            let s = super.intrinsicContentSize
            return CGSize(width: s.width + insets.left + insets.right,
                          height: s.height + insets.top + insets.bottom)
        }
    }

    // MARK: - Warning banner
    private func makeWarningBanner(_ text: String) -> UIView {
        let lbl           = UILabel()
        lbl.text          = text
        lbl.font          = UIFont.lato(size: 14)
        lbl.textColor     = QAColorPalette.warnFg
        lbl.numberOfLines = 0

        let banner = UIView()
        banner.backgroundColor    = QAColorPalette.warnBg
        banner.layer.cornerRadius = 4
        banner.layer.borderWidth  = 1
        banner.layer.borderColor  = QAColorPalette.warnBdr.cgColor

        lbl.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
            lbl.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8),
            lbl.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            lbl.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12)
        ])

        // 24 = icon (16) + spacing (8): aligns banner under the card
        let wrapper = UIView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: wrapper.topAnchor),
            banner.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            banner.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24),
            banner.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        ])
        return wrapper
    }

    // MARK: - Empty state
    private func makeEmptyLabel(_ text: String) -> UILabel {
        let lbl           = UILabel()
        lbl.text          = text
        lbl.font          = UIFont.lato(size: 16)
        lbl.textColor     = .secondaryLabel
        lbl.textAlignment = .center
        return lbl
    }
}
