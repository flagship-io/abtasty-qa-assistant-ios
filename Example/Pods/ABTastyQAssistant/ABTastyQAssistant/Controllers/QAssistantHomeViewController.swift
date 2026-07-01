//
//  QAssistantHomeViewController.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 11/05/2026.
//

import FlagShip
import UIKit

class QAssistantHomeViewController: UIViewController {
    @IBOutlet var searchField: UITextField?
    @IBOutlet var tabStackView: UIStackView?
    @IBOutlet var resetButton: UIButton?
    @IBOutlet var containerView: UIView?
    @IBOutlet var liveCampaignLabel: UILabel?
    @IBOutlet var closeBtn: UIButton?

    weak var qaAssistant: ABTastyQAAssistant?

    enum Tab { case campaigns, events, context }
    private var selectedTab: Tab = .campaigns

    private var resetBarHeightConstraint: NSLayoutConstraint?

    // MARK: - Live observer token

    private var fetchedFlagsToken: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        styleSearchField()
        setupTabIndicators()
        cacheResetBarHeightConstraint()
        selectTab(at: 0)
        showTabContent(for: 0)
        updateLiveCount()
        searchField?.addTarget(self, action: #selector(searchChanged(_:)), for: .editingChanged)
        closeBtn?.addTarget(self, action: #selector(closeBtnTapped), for: .touchUpInside)
        subscribeLiveFetchedFlags()
        downloadBucketingResponse()
    }

    private func cacheResetBarHeightConstraint() {
        resetBarHeightConstraint = resetButton?.superview?.constraints
            .first { $0.firstAttribute == .height && $0.secondItem == nil }
    }

    private func setResetBarVisible(_ visible: Bool) {
        let bar = resetButton?.superview
        bar?.isHidden = !visible
        resetBarHeightConstraint?.constant = visible ? 56 : 0
    }

    deinit {
        if let token = fetchedFlagsToken {
            FSQAMessageService.shared.remove(token)
        }
    }

    // MARK: - Live stream

    private func subscribeLiveFetchedFlags() {
        fetchedFlagsToken = FSQAMessageService.shared.observe(.fsQABroadcastFetchedFlags) { [weak self] notification in
            guard let self, let qaAssistant = self.qaAssistant else { return }
            guard let variations = notification.userInfo?[FSQANotificationKey.variations] as? [[String: String]] else { return }

            let fetchedVariationIds = Set(variations.compactMap { $0["variationId"] })
            let fetchedCampaignIds = Set(variations.compactMap { $0["campaignId"] })

            guard var cached = qaAssistant.cachedBucketingResponse else { return }

            let updated = cached.campaigns.map { campaign -> Campaign in
                var c = campaign
                c.isActive = fetchedCampaignIds.contains(c.id)
                return c
            }
            let newResponse = BucketingResponse(
                campaigns: updated,
                panic: cached.panic,
                accountSettings: cached.accountSettings,
                cdnSettings: cached.cdnSettings,
                hasConsented: cached.hasConsented
            )
            DispatchQueue.main.async {
                qaAssistant.updateCachedBucketingResponse(newResponse)
                (self.children.first as? QACampaignsTableViewCtrl)?.reloadData()
                self.updateLiveCount()
                print("✅ HomeVC: Live update — \(fetchedCampaignIds.count) active campaign(s)")
            }
        }
    }

    // MARK: - Download & decorate

    private func downloadBucketingResponse() {
        guard let qaAssistant else { return }
        let isFirstLoad = !qaAssistant.hasBeenModified
        let fetchedIds = qaAssistant.latestFetchedCampaignIds["variations"] as? [[String: String]] ?? []

        qaAssistant.getBucketingConfig { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let response):
                    let decorated = self.decorateWithFetchedIds(response, fetchedIds: fetchedIds, isFirstLoad: isFirstLoad)
                    qaAssistant.updateCachedBucketingResponse(decorated)
                    self.showTabContent(for: 0)
                    self.updateLiveCount()
                    print("✅ HomeVC: Bucketing loaded — \(decorated.campaigns.count) campaign(s)")
                case .failure(let error):
                    print("❌ HomeVC: Failed to load bucketing: \(error.localizedDescription)")
                    // Still show tab with cached data if available
                    self.showTabContent(for: 0)
                }
            }
        }
    }

    /// Decoration logic:
    /// - Detects manual changes (preserve user selection)
    /// - Assigns fetched variation for active campaigns
    /// - Assigns reference (or first) variation for inactive campaigns
    /// - Resets isHidden/isForced only on first load
    private func decorateWithFetchedIds(_ response: BucketingResponse,
                                        fetchedIds: [[String: String]],
                                        isFirstLoad: Bool) -> BucketingResponse
    {
        let freshCampaigns: [Campaign] = response.campaigns.map { campaign in
            var updated = campaign

            // Find fetchedVariationId for this campaign
            var campaignFound = false
            var fetchedVariationId: String?
            for v in fetchedIds where v["campaignId"] == campaign.id {
                campaignFound = true
                fetchedVariationId = v["variationId"]
                break
            }

            // Detect manual changes: if user already selected a different variation, preserve it
            let currentAssignedId = campaign.variationGroups
                .flatMap { $0.variations }
                .first { $0.isAssigned }?.id

            let hasManualChanges = currentAssignedId != nil
                && fetchedVariationId != nil
                && currentAssignedId != fetchedVariationId

            if hasManualChanges {
                print("🔒 Preserving manual variation for campaign: \(campaign.name ?? campaign.id)")
            } else {
                // Reset all variations
                for i in updated.variationGroups.indices {
                    for j in updated.variationGroups[i].variations.indices {
                        updated.variationGroups[i].variations[j].isAssigned = false
                    }
                }

                if campaignFound, let vid = fetchedVariationId {
                    // Assign variation from SDK
                    outer: for i in updated.variationGroups.indices {
                        for j in updated.variationGroups[i].variations.indices {
                            if updated.variationGroups[i].variations[j].id == vid {
                                updated.variationGroups[i].variations[j].isAssigned = true
                                print("✅ Assigned fetched variation \(vid) for \(campaign.name ?? campaign.id)")
                                break outer
                            }
                        }
                    }
                } else {
                    // Inactive campaign: assign reference variation (or first)
                    var assigned = false
                    outer: for i in updated.variationGroups.indices {
                        for j in updated.variationGroups[i].variations.indices {
                            if updated.variationGroups[i].variations[j].reference == true {
                                updated.variationGroups[i].variations[j].isAssigned = true
                                print("📌 Assigned reference variation for \(campaign.name ?? campaign.id)")
                                assigned = true
                                break outer
                            }
                        }
                    }
                    if !assigned,
                       !updated.variationGroups.isEmpty,
                       !updated.variationGroups[0].variations.isEmpty
                    {
                        updated.variationGroups[0].variations[0].isAssigned = true
                        print("📌 Assigned first variation for \(campaign.name ?? campaign.id)")
                    }
                }
            }

            updated.isActive = campaignFound
            if isFirstLoad {
                updated.isHidden = false
                updated.isForced = false
            }
            return updated
        }

        return BucketingResponse(
            campaigns: freshCampaigns,
            panic: response.panic,
            accountSettings: response.accountSettings,
            cdnSettings: response.cdnSettings,
            hasConsented: response.hasConsented
        )
    }

    // MARK: - Reset

    @objc private func closeBtnTapped() {
        navigationController?.dismiss(animated: true) { [weak self] in
            self?.qaAssistant?.restoreOverlayButton()
        }
    }

    @IBAction private func resetTapped(_ sender: UIButton) {
        resetToInitialState()
    }

    private func resetToInitialState() {
        print("🔄 Reset button clicked - Clearing all QA modifications")

        guard let cached = qaAssistant?.cachedBucketingResponse else {
            print("❌ Reset failed: cachedBucketingResponse is nil")
            return
        }

        // Step 1: Unhide all hidden campaigns
        for campaign in cached.campaigns where campaign.isHidden {
            FSQAMessageService.shared.unhideCampaign(campaign.id)
            print("  📡 Unhiding campaign: \(campaign.name ?? campaign.id)")
        }

        // Step 2: Clear persisted variation selections for all campaigns
        // `selectedVariations.clear()` — removes both the user-selected
        // variation and the cached initial variation so the fresh SDK data takes over.
        for campaign in cached.campaigns {
            UserDefaults.standard.removeObject(forKey: "selected_variation_\(campaign.id)")
            UserDefaults.standard.removeObject(forKey: "initial_variation_\(campaign.id)")
            print("  🗑️ Cleared variation keys for: \(campaign.name ?? campaign.id)")
        }

        // Step 3: Clear all modifications and cached state
        qaAssistant?.clearModifications()

        // Step 4: Re-download fresh bucketing config
        downloadBucketingResponse()

        print("✅ Reset completed - All QA modifications cleared")
    }

    @objc private func searchChanged(_ field: UITextField) {
        let query = field.text?.lowercased() ?? ""
        if let vc = children.first as? QACampaignsTableViewCtrl {
            vc.filter(by: query)
        } else if let vc = children.first as? QAEventsViewController {
            vc.filter(by: query)
        } else if let vc = children.first as? QAContextViewController {
            vc.filter(by: query)
        }
    }

    @IBAction private func tabButtonTapped(_ sender: UIButton) {
        selectTab(at: sender.tag)
        showTabContent(for: sender.tag)
    }

    // MARK: - Tab content (child VC embedding)

    private func showTabContent(for index: Int) {
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        setResetBarVisible(index == 0)

        guard let container = containerView else { return }

        let storyboard = UIStoryboard(name: "QAAssistant", bundle: .qaAssistant)
        let vc: UIViewController
        switch index {
        case 0:
            let campaignsVC = storyboard.instantiateViewController(withIdentifier: "QACampaigns") as! QACampaignsTableViewCtrl
            campaignsVC.qaAssistant = qaAssistant
            vc = campaignsVC
        case 1:
            let eventsVC = QAEventsViewController()
            eventsVC.qaAssistant = qaAssistant
            vc = eventsVC
        case 2:
            let contextVC = QAContextViewController()
            contextVC.qaAssistant = qaAssistant
            vc = contextVC
        default: return
        }

        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: container.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        vc.didMove(toParent: self)
    }

    private func updateLiveCount() {
        let count = qaAssistant?.cachedBucketingResponse?.campaigns.count ?? 0
        liveCampaignLabel?.text = "\(count) live campaign\(count == 1 ? "" : "s")"
    }

    // MARK: - Tab indicators

    private func selectTab(at index: Int) {
        switch index {
        case 0: selectedTab = .campaigns
        case 1: selectedTab = .events
        case 2: selectedTab = .context
        default: return
        }
        tabStackView?.arrangedSubviews.compactMap { $0 as? UIButton }.enumerated().forEach { i, btn in
            let selected = i == index
            btn.setTitleColor(selected ? UIColor(red: 0.192, green: 0.0, blue: 0.749, alpha: 1) : .label, for: .normal)
            btn.viewWithTag(99)?.isHidden = !selected
        }
    }

    private func setupTabIndicators() {
        tabStackView?.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
            let indicator = UIView()
            indicator.tag = 99
            indicator.backgroundColor = UIColor(red: 0.192, green: 0.0, blue: 0.749, alpha: 1)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.isHidden = true
            btn.addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
                indicator.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
                indicator.bottomAnchor.constraint(equalTo: btn.bottomAnchor),
                indicator.heightAnchor.constraint(equalToConstant: 2)
            ])
        }
    }

    // MARK: - Search field

    private func styleSearchField() {
        guard let field = searchField else { return }
        field.layer.borderColor = UIColor.separator.cgColor
        field.layer.borderWidth = 1
        field.layer.cornerRadius = 4
        field.clipsToBounds = true

        let placeholderColor = UIColor(red: 120 / 255, green: 120 / 255, blue: 136 / 255, alpha: 1)
        field.attributedPlaceholder = NSAttributedString(
            string: field.placeholder ?? "",
            attributes: [.foregroundColor: placeholderColor]
        )

        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftView = leftPadding
        field.leftViewMode = .always

        let rightContainer = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 20))

        let loopImageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        loopImageView.tintColor = .secondaryLabel
        loopImageView.contentMode = .scaleAspectFit
        loopImageView.frame = CGRect(
            x: (rightContainer.frame.width - 20) / 2,
            y: (rightContainer.frame.height - 20) / 2,
            width: 20,
            height: 20
        )
        rightContainer.addSubview(loopImageView)
        field.rightView = rightContainer
        field.rightViewMode = .always
    }
}
