//
//  QACampaignsTableViewCtrl.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 18/05/2026.
//

import UIKit

class QACampaignsTableViewCtrl: UITableViewController {
    weak var qaAssistant: ABTastyQAAssistant?

    private var allAccepted: [Campaign] = []
    private var allRejected: [Campaign] = []
    private var acceptedCampaigns: [Campaign] = []
    private var rejectedCampaigns: [Campaign] = []

    private var isAcceptedExpanded = true
    private var isRejectedExpanded = true

    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }

    private func loadData() {
        guard let response = qaAssistant?.cachedBucketingResponse else { return }
        let liveIds = qaAssistant?.latestFetchedCampaigns ?? []
        allAccepted = response.campaigns.filter { liveIds.contains($0.id) }
        allRejected = response.campaigns.filter { !liveIds.contains($0.id) }
        acceptedCampaigns = allAccepted
        rejectedCampaigns = allRejected
        tableView.reloadData()
    }

    func reloadData() {
        loadData()
    }

    func filter(by query: String) {
        if query.isEmpty {
            acceptedCampaigns = allAccepted
            rejectedCampaigns = allRejected
        } else {
            acceptedCampaigns = allAccepted.filter { matches($0, query: query) }
            rejectedCampaigns = allRejected.filter { matches($0, query: query) }
        }
        tableView.reloadData()
    }

    private func matches(_ campaign: Campaign, query: String) -> Bool {
        (campaign.name ?? "").lowercased().contains(query) || campaign.id.lowercased().contains(query)
    }

    @objc private func headerTapped(_ gesture: UITapGestureRecognizer) {
        guard let section = gesture.view?.tag else { return }
        if section == 0 {
            isAcceptedExpanded.toggle()
        } else {
            isRejectedExpanded.toggle()
        }
        tableView.reloadSections(IndexSet(integer: section), with: .automatic)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return isAcceptedExpanded ? acceptedCampaigns.count : 0 }
        return isRejectedExpanded ? rejectedCampaigns.count : 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isAccepted = section == 0
        let isExpanded = isAccepted ? isAcceptedExpanded : isRejectedExpanded
        let count = isAccepted ? acceptedCampaigns.count : rejectedCampaigns.count

        let header = UIView()
        header.backgroundColor = tableView.backgroundColor
        header.tag = section

        let tap = UITapGestureRecognizer(target: self, action: #selector(headerTapped(_:)))
        header.addGestureRecognizer(tap)

        // Badge
        var badgeConfig = UIButton.Configuration.plain()
        badgeConfig.baseForegroundColor = UIColor(red: 0, green: 51/255, blue: 43/255, alpha: 1)
        badgeConfig.background.backgroundColor = isAccepted
            ? UIColor(red: 199/255, green: 244/255, blue: 238/255, alpha: 1)
            : UIColor(red: 254/255, green: 209/255, blue: 205/255, alpha: 1)
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        var titleAttr = AttributedString(isAccepted ? "Accepted" : "Rejected")
        titleAttr.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        badgeConfig.attributedTitle = titleAttr
        let badge = UIButton(configuration: badgeConfig)
        badge.isUserInteractionEnabled = false
        badge.translatesAutoresizingMaskIntoConstraints = false

        // Count label
        let countLabel = UILabel()
        countLabel.text = "\(count) campaign\(count == 1 ? "" : "s")"
        countLabel.font = UIFont.lato(size: 14)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        // Chevron
        let chevronImage = isExpanded
            ? UIImage(named: "Vector", in: .qaAssistant, compatibleWith: nil)
            : UIImage(named: "I.Caret", in: .qaAssistant, compatibleWith: nil)
        let chevron = UIImageView(image: chevronImage)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        // Bottom separator
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(badge)
        header.addSubview(countLabel)
        header.addSubview(chevron)
        header.addSubview(separator)

        var constraints = [
            chevron.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            chevron.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 10),
            badge.leadingAnchor.constraint(equalTo: chevron.trailingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            countLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8),
            countLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ]

        if section > 0 {
            let topSeparator = UIView()
            topSeparator.backgroundColor = .separator
            topSeparator.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(topSeparator)
            constraints += [
                topSeparator.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                topSeparator.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                topSeparator.topAnchor.constraint(equalTo: header.topAnchor),
                topSeparator.heightAnchor.constraint(equalToConstant: 1)
            ]
        }

        NSLayoutConstraint.activate(constraints)

        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 56 }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QACampaignCell", for: indexPath) as! QACampaignTableViewCell
        let campaign = indexPath.section == 0 ? acceptedCampaigns[indexPath.row] : rejectedCampaigns[indexPath.row]
        cell.configure(with: campaign)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let campaign = indexPath.section == 0 ? acceptedCampaigns[indexPath.row] : rejectedCampaigns[indexPath.row]
        performSegue(withIdentifier: "onClickCampaign", sender: campaign)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "onClickCampaign", let campaign = sender as? Campaign {
            if let detailsVC = segue.destination as? QACampaignDetailsViewCtrl {
                detailsVC.campItem = campaign
                detailsVC.onTakeAction = { [weak self] updatedCampaign, _ in
                    self?.updateCampaign(updatedCampaign)
                }
            }
        }
    }

    private func updateCampaign(_ updated: Campaign) {
        if let i = allAccepted.firstIndex(where: { $0.id == updated.id }) {
            allAccepted[i] = updated
            if let j = acceptedCampaigns.firstIndex(where: { $0.id == updated.id }) {
                acceptedCampaigns[j] = updated
                tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .none)
            }
        } else if let i = allRejected.firstIndex(where: { $0.id == updated.id }) {
            allRejected[i] = updated
            if let j = rejectedCampaigns.firstIndex(where: { $0.id == updated.id }) {
                rejectedCampaigns[j] = updated
                tableView.reloadRows(at: [IndexPath(row: j, section: 1)], with: .none)
            }
        }

        guard let current = qaAssistant?.cachedBucketingResponse else { return }
        let newCampaigns = current.campaigns.map { $0.id == updated.id ? updated : $0 }
        let newResponse = BucketingResponse(
            campaigns: newCampaigns,
            panic: current.panic,
            accountSettings: current.accountSettings,
            cdnSettings: current.cdnSettings,
            hasConsented: current.hasConsented
        )
        qaAssistant?.updateCachedBucketingResponse(newResponse)
    }
}
