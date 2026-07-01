//
//  QATargetingView.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 01/06/2026.
//

import FlagShip
import UIKit

class QATargetingView: UIView {
    // MARK: - State

    private var campaign: Campaign?
    private var userContext: [String: Any] = [:]
    private var contextToken: NSObjectProtocol?

    // MARK: - Layout

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildLayout()
    }

    deinit {
        contextToken.map { FSQAMessageService.shared.remove($0) }
    }

    // MARK: - Layout setup

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

        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    // MARK: - Configure

    func configure(with campaign: Campaign?) {
        self.campaign = campaign
        subscribeToUserContext()
        FSQAMessageService.shared.broadcastUserContextRequest()
        reload()
    }

    private func subscribeToUserContext() {
        guard contextToken == nil else { return }
        contextToken = FSQAMessageService.shared.observe(.fsQABroadcastUserContext) { [weak self] note in
            guard let ctx = note.userInfo?[FSQANotificationKey.context] as? [String: Any] else { return }
            self?.userContext = ctx
            DispatchQueue.main.async { self?.reload() }
        }
    }

    // MARK: - Reload

    private func reload() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let campaign else {
            stack.addArrangedSubview(makeEmptyLabel("No targeting rules defined"))
            return
        }
        if campaign.isForced {
            stack.addArrangedSubview(makeBanner("Targeting has been bypassed", isForced: true))
        } else if !campaign.isActive {
            stack.addArrangedSubview(makeBanner("Targeting does not match your current values", isForced: false))
        }

        let groups = campaign.variationGroups.compactMap { $0.targeting?.targetingGroups }.flatMap { $0 }
        guard !groups.isEmpty else {
            stack.addArrangedSubview(makeEmptyLabel("No targeting rules defined"))
            return
        }

        for (i, group) in groups.enumerated() {
            if i > 0 { stack.addArrangedSubview(makeOrRow()) }
            stack.addArrangedSubview(makeGroupRow(group, bypassed: campaign.isForced))
        }
    }

    // MARK: - Banner

    private func makeBanner(_ text: String, isForced: Bool) -> UIView {
        let bg = isForced ? UIColor(red: 1, green: 0.925, blue: 0.741, alpha: 1)
            : UIColor(red: 1, green: 0.820, blue: 0.804, alpha: 1)
        let bdr = isForced ? QAColorPalette.amberBdr : QAColorPalette.redBdr
        let fg = isForced ? UIColor(red: 0.302, green: 0.216, blue: 0, alpha: 1)
            : UIColor(red: 0.302, green: 0, blue: 0, alpha: 1)

        let v = UIView()
        v.backgroundColor = bg
        v.layer.cornerRadius = 8
        v.layer.borderWidth = 1
        v.layer.borderColor = bdr.cgColor

        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.lato(size: 14)
        lbl.textColor = fg
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            lbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            lbl.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -8)
        ])
        return v
    }

    // MARK: - OR separator

    private func makeOrRow() -> UIView {
        let badge = makeLogicBadge("OR")
        badge.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = UIView()
        wrapper.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            badge.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
            badge.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 32)
        ])
        return wrapper
    }

    // MARK: - Group row

    private func makeGroupRow(_ group: TargetingGroup, bypassed: Bool) -> UIView {
        let allPassed = group.targetings.allSatisfy { QATargetingEvaluator.isConditionMet($0, in: userContext) }
        let iconPassed = bypassed || allPassed

        let iconImg = UIImage(named: iconPassed ? "check" : "close", in: .qaAssistant, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        let icon = UIImageView(image: iconImg)
        icon.contentMode = .scaleAspectFit
        icon.tintColor = iconPassed
            ? (bypassed ? QAColorPalette.checkAmber : QAColorPalette.checkGreen)
            : .systemRed
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let (bg, bdr): (UIColor, UIColor) = bypassed
            ? (QAColorPalette.amberBg, QAColorPalette.amberBdr)
            : allPassed
            ? (QAColorPalette.greenBg, QAColorPalette.greenBdr)
            : (QAColorPalette.redBg, QAColorPalette.redBdr)

        let card = UIView()
        card.backgroundColor = bg
        card.layer.cornerRadius = 8
        card.layer.borderWidth = 1
        card.layer.borderColor = bdr.cgColor

        let innerStack = UIStackView()
        innerStack.axis = .vertical
        innerStack.spacing = 0
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        for (j, target) in group.targetings.enumerated() {
            if j > 0 { innerStack.addArrangedSubview(makeAndRow()) }
            innerStack.addArrangedSubview(makeConditionRow(target))
        }

        let row = UIStackView(arrangedSubviews: [icon, card])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    // MARK: - AND separator

    private func makeAndRow() -> UIView {
        let badge = makeLogicBadge("AND")
        badge.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = UIView()
        wrapper.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 6),
            badge.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
            badge.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor)
        ])
        return wrapper
    }

    // MARK: - Condition row

    private func makeConditionRow(_ target: ItemTarget) -> UIView {
        if target.key == "fs_all_users" {
            let lbl = UILabel()
            lbl.text = "ALL USERS"
            lbl.font = UIFont.latoBold(size: 14)
            lbl.textColor = .label

            let wrapper = UIView()
            lbl.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
                lbl.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
                lbl.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                lbl.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor)
            ])
            return wrapper
        }

        let keyLbl = UILabel()
        keyLbl.text = target.key
        keyLbl.font = UIFont.latoBold(size: 14)
        keyLbl.textColor = .label
        keyLbl.setContentHuggingPriority(.required, for: .horizontal)
        keyLbl.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let opPill = OperatorPill(
            text: formatOperator(target.operator),
            font: UIFont.latoBold(size: 13)
        )

        let valView = makeValueWidget(for: target)

        let hStack = UIStackView(arrangedSubviews: [keyLbl, opPill, valView])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = UIView()
        wrapper.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            hStack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
            hStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        ])
        return wrapper
    }

    // MARK: - Value widget

    private func makeValueWidget(for target: ItemTarget) -> UIView {
        if case .array(let arr) = target.value, !arr.isEmpty {
            return makeArrayPillsView(arr, userValue: userContext[target.key])
        }
        let isMatch = QATargetingEvaluator.isConditionMet(target, in: userContext)
        let bg = isMatch ? QAColorPalette.greenBdr : UIColor.clear
        let v = makePill(target.value.description, bg: bg, border: .clear, fg: .label,
                         corner: 12, hPad: 12, vPad: 4)
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return v
    }

    private func makeArrayPillsView(_ items: [JSONValue], userValue: Any?) -> UIView {
        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 6

        var rowItems: [UIView] = []
        for (i, item) in items.enumerated() {
            let isMatch = userValue.map { QATargetingEvaluator.valEquals($0, item) } ?? false
            let p = makePill(item.description,
                             bg: isMatch ? QAColorPalette.greenBdr : QAColorPalette.pillGray,
                             border: QAColorPalette.tagBdr, fg: .label,
                             corner: 12, hPad: 8, vPad: 4)
            p.setContentHuggingPriority(.required, for: .horizontal)
            rowItems.append(p)

            if rowItems.count == 3 || i == items.count - 1 {
                let row = UIStackView(arrangedSubviews: rowItems)
                row.axis = .horizontal
                row.spacing = 6
                row.alignment = .center
                let spacer = UIView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                row.addArrangedSubview(spacer)
                vStack.addArrangedSubview(row)
                rowItems = []
            }
        }
        return vStack
    }

    // MARK: - Logic badge (OR / AND)

    private func makeLogicBadge(_ text: String) -> UIView {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.latoBold(size: 13)
        lbl.textColor = .label

        let v = UIView()
        v.backgroundColor = QAColorPalette.tagBg
        v.layer.cornerRadius = 6
        v.layer.borderWidth = 1
        v.layer.borderColor = QAColorPalette.tagBdr.cgColor
        v.setContentHuggingPriority(.required, for: .horizontal)
        v.setContentCompressionResistancePriority(.required, for: .horizontal)

        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: v.topAnchor, constant: 4),
            lbl.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -4),
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
            lbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6)
        ])
        return v
    }

    // MARK: - Pill

    private func makePill(_ text: String,
                          bg: UIColor, border: UIColor, fg: UIColor,
                          corner: CGFloat, hPad: CGFloat, vPad: CGFloat) -> UIView {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.latoBold(size: 13)
        lbl.textColor = fg
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.setContentCompressionResistancePriority(.required, for: .horizontal)

        let v = UIView()
        v.backgroundColor = bg
        v.layer.cornerRadius = corner
        v.layer.borderWidth = (border == .clear) ? 0 : 1
        v.layer.borderColor = border.cgColor
        v.setContentHuggingPriority(.required, for: .horizontal)
        v.setContentCompressionResistancePriority(.required, for: .horizontal)

        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: v.topAnchor, constant: vPad),
            lbl.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -vPad),
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: hPad),
            lbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -hPad)
        ])
        return v
    }

    // MARK: - Empty state

    private func makeEmptyLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.lato(size: 16)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        return lbl
    }

    // MARK: - Operator label

    private func formatOperator(_ op: String) -> String {
        switch op.uppercased() {
        case "EQUALS": return "IS"
        case "NOT_EQUALS": return "IS NOT"
        case "CONTAINS": return "Contains"
        case "NOT_CONTAINS": return "Not Contains"
        case "GREATER_THAN": return ">"
        case "LOWER_THAN": return "<"
        case "GREATER_THAN_OR_EQUALS": return "≥"
        case "LOWER_THAN_OR_EQUALS": return "≤"
        case "STARTS_WITH": return "Starts with"
        case "ENDS_WITH": return "Ends with"
        default: return op
        }
    }

    // Operator badge pill — white bg, rgba(42,42,60) text, 8pt h-padding, 24pt fixed height, 12pt radius, 1px border.
    private class OperatorPill: UIView {
        private let lbl = UILabel()

        init(text: String, font: UIFont) {
            super.init(frame: .zero)
            lbl.text = text
            lbl.font = font
            lbl.textColor = UIColor(red: 42/255, green: 42/255, blue: 60/255, alpha: 1)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerYAnchor.constraint(equalTo: centerYAnchor),
                lbl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                lbl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                heightAnchor.constraint(equalToConstant: 24)
            ])
            backgroundColor = .white
            layer.cornerRadius = 12
            layer.borderWidth = 1
            layer.borderColor = UIColor(red: 216/255, green: 216/255, blue: 226/255, alpha: 1).cgColor
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override var intrinsicContentSize: CGSize {
            CGSize(width: lbl.intrinsicContentSize.width + 16, height: 24)
        }
    }
}
