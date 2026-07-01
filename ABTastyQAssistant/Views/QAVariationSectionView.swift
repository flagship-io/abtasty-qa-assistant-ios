//
//  QAVariationSectionView.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 01/06/2026.
//

import UIKit

/// View representing a variation with its name as a header and its flags as expandable rows.
class QAVariationSectionView: UIView {

    // MARK: - IBOutlets

    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var chevronImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var assignedBadge: UILabel!
    @IBOutlet private weak var contentStackView: UIStackView!

    // MARK: - State

    private var isExpanded = false
    private var contentHeightConstraint: NSLayoutConstraint?   // height=0 constraint used to collapse the section

    // MARK: - XIB Loading

    static func instantiate() -> QAVariationSectionView {
        let nib = UINib(nibName: "QAVariationSectionView", bundle: .qaAssistant)
        guard let view = nib.instantiate(withOwner: nil, options: nil).first as? QAVariationSectionView else {
            assertionFailure("QAVariationSectionView: failed to load QAVariationSectionView.xib from bundle \(Bundle.qaAssistant.bundlePath)")
            return QAVariationSectionView(frame: .zero)
        }
        return view
    }

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        let tap = UITapGestureRecognizer(target: self, action: #selector(headerTapped))
        headerView.addGestureRecognizer(tap)
        headerView.isUserInteractionEnabled = true
        contentStackView.clipsToBounds = true

        // Active by default so the section starts collapsed with no empty space
        contentHeightConstraint = contentStackView.heightAnchor.constraint(equalToConstant: 0)
        contentHeightConstraint?.isActive = true
    }

    // MARK: - Configure

    func configure(with variation: Variation) {
        nameLabel.text = variation.name ?? variation.id
        assignedBadge.isHidden = !variation.isAssigned

        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let mods = variation.modifications?.value, !mods.isEmpty {
            for (key, value) in mods.sorted(by: { $0.key < $1.key }) {
                contentStackView.addArrangedSubview(makeFlagRow(key: key, value: value.description))
            }
        } else {
            contentStackView.addArrangedSubview(makeEmptyLabel("No flags defined"))
        }

        setExpanded(false, animated: false)
    }

    // MARK: - Expand / Collapse

    @objc private func headerTapped() {
        setExpanded(!isExpanded, animated: true)
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        let angle: CGFloat = expanded ? .pi / 2 : 0

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
                self.contentHeightConstraint?.isActive = !expanded
                self.superview?.layoutIfNeeded()
            }
        } else {
            chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
            contentHeightConstraint?.isActive = !expanded
        }
    }

    // MARK: - Row Builders

    private func makeFlagRow(key: String, value: String) -> UIView {
        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        keyLabel.textColor = .secondaryLabel
        keyLabel.numberOfLines = 1

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = UIColor(red: 0.192, green: 0.0, blue: 0.749, alpha: 1)
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 1
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [keyLabel, valueLabel])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.layoutMargins = UIEdgeInsets(top: 10, left: 40, bottom: 10, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = UIColor(red: 243/255, green: 243/255, blue: 247/255, alpha: 1)

        // Fine separator at row bottom
        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        sep.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 40),
            sep.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        return row
    }

    private func makeEmptyLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 13)
        lbl.textColor = .tertiaryLabel
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lbl.heightAnchor.constraint(equalToConstant: 44)
        ])
        return lbl
    }
}
