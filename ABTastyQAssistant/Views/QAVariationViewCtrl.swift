//
//  QAVariationViewCtrl.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 02/06/2026.
//

import UIKit

class QAVariationViewCtrl: UIViewController {
    @IBOutlet var tableView: UITableView?

    var campaign: Campaign?
    /// Called whenever the user selects a different variation.
    var onVariationChanged: ((Campaign) -> Void)?
    /// Controls whether "View" / "Reset" buttons appear.
    /// `onVariationSelected != null` guard.
    var canChangeVariation: Bool = true

    /// The variation that was originally assigned when this screen first loaded.
    /// `initialVariationId` / SharedPreferences logic.
    private var initialVariationId: String?

    private var variations: [Variation] {
        guard let campaign = campaign else { return [] }

        // _initializeVariations():
        // - ab / toggle → flat list of variations as-is
        // - perso       → variation name prefixed with its group name ("GroupName - VariationName")
        if campaign.type == "perso" {
            return campaign.variationGroups.flatMap { group in
                group.variations.map { variation in
                    var v = variation
                    let groupName = group.name ?? group.id
                    v.name = "\(groupName) - \(variation.name ?? variation.id)"
                    return v
                }
            }
        } else {
            return campaign.variationGroups.flatMap { $0.variations }
        }
    }

    private var expandedSections = Set<Int>()

    override func viewDidLoad() {
        super.viewDidLoad()
        loadInitialVariation()
        tableView?.reloadData()
    }

    // MARK: - Initial variation

    private func loadInitialVariation() {
        guard let campaignId = campaign?.id else { return }
        let initialKey = "initial_variation_\(campaignId)"
        if let saved = UserDefaults.standard.string(forKey: initialKey), !saved.isEmpty {
            initialVariationId = saved
        } else {
            // First visit: persist the currently-assigned variation
            let assignedId = variations.first { $0.isAssigned }?.id
            initialVariationId = assignedId
            if let id = assignedId {
                UserDefaults.standard.set(id, forKey: initialKey)
            }
        }

        // Restore the variation the user last selected (may differ from the initial SDK assignment)
        let selectedKey = "selected_variation_\(campaignId)"
        if let savedSelected = UserDefaults.standard.string(forKey: selectedKey), !savedSelected.isEmpty {
            if variations.contains(where: { $0.id == savedSelected }) {
                applyVariationInMemory(id: savedSelected)
            } else {
                // Stale selection: keep the current assignment and drop the persisted value.
                UserDefaults.standard.removeObject(forKey: selectedKey)
            }
        }
    }

    // MARK: - Variation selection

    private func selectVariation(id: String) {
        applyVariationInMemory(id: id)
        saveSelectedVariation(id: id)
        tableView?.reloadData()
        if let updated = campaign {
            onVariationChanged?(updated)
        }
    }

    /// Updates `isAssigned` in `campaign.variationGroups` without side-effects (no save, no callback).
    private func applyVariationInMemory(id: String) {
        guard campaign != nil else { return }
        for i in campaign!.variationGroups.indices {
            for j in campaign!.variationGroups[i].variations.indices {
                campaign!.variationGroups[i].variations[j].isAssigned =
                    campaign!.variationGroups[i].variations[j].id == id
            }
        }
    }

    private func saveSelectedVariation(id: String) {
        guard let campaignId = campaign?.id else { return }
        UserDefaults.standard.set(id, forKey: "selected_variation_\(campaignId)")
    }
}

// MARK: - UITableViewDataSource

extension QAVariationViewCtrl: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        variations.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard expandedSections.contains(section) else { return 0 }
        let mods = variations[section].modifications?.value ?? [:]
        return mods.isEmpty ? 1 : mods.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "VariationCell", for: indexPath) as? QAVariationViewCell else {
            return UITableViewCell()
        }
        let mods = variations[indexPath.section].modifications?.value ?? [:]
        if mods.isEmpty {
            cell.configure(with: (key: "No flags defined", value: ""))
        } else {
            let entry = mods.sorted(by: { $0.key < $1.key })[indexPath.row]
            cell.configure(with: (key: entry.key, value: entry.value.description))
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension QAVariationViewCtrl: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let variation = variations[section]
        let isExpanded = expandedSections.contains(section)

        let header = UIView()
        header.backgroundColor = .systemBackground

        let chevron = UIImageView(image: UIImage(systemName: isExpanded ? "chevron.up" : "chevron.down"))
        chevron.tintColor = .label
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = variation.name ?? variation.id
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(chevron)
        header.addSubview(titleLabel)
        header.addSubview(separator)

        var constraints: [NSLayoutConstraint] = [
            chevron.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            chevron.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 20),
            chevron.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: chevron.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ]

        // Only add the action badge (Your version / View / Reset) when one exists.
        // When nil (non-assigned variation with canChangeVariation=false), the title
        // simply stretches to the right edge — the header row stays fully visible.
        if let actionView = makeActionBadge(for: variation, section: section) {
            header.addSubview(actionView)
            constraints += [
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionView.leadingAnchor, constant: -8),
                actionView.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
                actionView.centerYAnchor.constraint(equalTo: header.centerYAnchor),
                actionView.heightAnchor.constraint(equalToConstant: 28)
            ]
        } else {
            constraints.append(
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -16)
            )
        }

        NSLayoutConstraint.activate(constraints)

        let tap = UITapGestureRecognizer(target: self, action: #selector(headerTapped(_:)))
        header.tag = section
        header.addGestureRecognizer(tap)
        header.isUserInteractionEnabled = true

        return header
    }

    /// Pushes a new interactivity state to the already-displayed table.
    /// Called by the parent detail VC after a dashboard action (hide/show/force/reset).
    func updateInteractivity(_ canChange: Bool) {
        canChangeVariation = canChange
        tableView?.reloadData()
    }

    // MARK: - Action badge factory

    /// Returns the right-hand badge/button for a variation header row, or `nil` when nothing
    /// should appear (non-assigned variation with interaction disabled).
    ///
    /// - Always returns "Your version" pill for the assigned variation.
    /// - Returns "View" / "Reset" button only when `canChangeVariation` is true.
    /// - Returns `nil` for non-assigned rows when `canChangeVariation` is false, so
    ///   the caller can keep the title stretching to the right edge without any layout gap.
    private func makeActionBadge(for variation: Variation, section: Int) -> UIView? {
        // All right-side labels/buttons are hidden when the campaign doesn't allow
        // variation changes
        if !canChangeVariation { return nil }

        let isAssigned = variation.isAssigned
        let isInitial = variation.id == initialVariationId

        // "Your version" — shown for the currently selected variation (when interactive)
        if isAssigned {
            let badge = PaddedLabel()
            badge.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
            badge.text = "Your version"
            badge.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            badge.textColor = .black
            badge.textAlignment = .center
            badge.backgroundColor = UIColor(red: 0.780, green: 0.957, blue: 0.933, alpha: 1)
            badge.layer.cornerRadius = 14
            badge.layer.masksToBounds = true
            badge.layer.borderWidth = 1
            badge.layer.borderColor = UIColor(red: 0.847, green: 0.847, blue: 0.886, alpha: 1).cgColor
            badge.translatesAutoresizingMaskIntoConstraints = false
            return badge
        }

        // "View" / "Reset" for non-assigned variations
        let title = isInitial ? "Reset" : "View"
        var config = UIButton.Configuration.bordered()
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.black
            ])
        )
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .white
        config.baseForegroundColor = .black
        config.background.cornerRadius = 4
        config.background.strokeColor = UIColor(red: 0.847, green: 0.847, blue: 0.886, alpha: 1)
        config.background.strokeWidth = 1
        let btn = UIButton(configuration: config)
        btn.tag = section
        btn.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    // MARK: - Header / button actions

    @objc private func headerTapped(_ gesture: UITapGestureRecognizer) {
        guard let section = gesture.view?.tag else { return }
        toggleSection(section)
    }

    /// Handles "View" (select this variation) and "Reset" (select the initial variation).
    @objc private func actionButtonTapped(_ sender: UIButton) {
        let section = sender.tag
        guard section < variations.count else { return }
        let variation = variations[section]

        // "Reset" → go back to the originally assigned variation
        // "View"  → select this variation
        // In both cases we select variation.id (for "Reset" the button belongs to the
        // initial variation row, so variation.id == initialVariationId).
        selectVariation(id: variation.id)
    }

    // MARK: - Sizes

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        48
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        36
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = UIView()
        footer.backgroundColor = .white
        return footer
    }

    // MARK: - Private helpers

    private func toggleSection(_ section: Int) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
        tableView?.reloadSections(IndexSet(integer: section), with: .automatic)
    }
}
