//
//  QAVariationsView.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 01/06/2026.
//

import UIKit

/// Scrollable view listing a campaign's variations as expandable sections.
class QAVariationsView: UIView {

    // MARK: - IBOutlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var sectionsStackView: UIStackView!

    // MARK: - XIB Loading

    static func instantiate() -> QAVariationsView {
        let nib = UINib(nibName: "QAVariationsView", bundle: .qaAssistant)
        guard let view = nib.instantiate(withOwner: nil, options: nil).first as? QAVariationsView else {
            assertionFailure("QAVariationsView: failed to load QAVariationsView.xib from bundle \(Bundle.qaAssistant.bundlePath)")
            return QAVariationsView(frame: .zero)
        }
        return view
    }

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        sectionsStackView.spacing = 0
        sectionsStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
    }

    // MARK: - Configure

    func configure(with campaign: Campaign?) {
        sectionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let allVariations = campaign?.variationGroups.flatMap { $0.variations } ?? []

        guard !allVariations.isEmpty else {
            sectionsStackView.addArrangedSubview(makeEmptyLabel("No variations"))
            return
        }

        for variation in allVariations {
            let section = QAVariationSectionView.instantiate()
            section.configure(with: variation)
            sectionsStackView.addArrangedSubview(section)
        }
    }

    // MARK: - Helpers

    private func makeEmptyLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lbl.heightAnchor.constraint(equalToConstant: 80)
        ])
        return lbl
    }
}
