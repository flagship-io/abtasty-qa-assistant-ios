//
//  QACampaignDetailsViewCtrl.swift
//  ABTastyQAssistant
//
//  Created by Adel Ferguen on 26/05/2026.
//

#if canImport(FlagShip)
import FlagShip
#else
import Flagship
#endif
import UIKit

class QACampaignDetailsViewCtrl: UIViewController {
    var campItem: Campaign?
    var onTakeAction: ((Campaign, String) -> Void)?

    @IBOutlet var campNameLabel: UILabel?
    @IBOutlet var assignedVariationNameLabel: UILabel?
    @IBOutlet var tabContainerView: UIView?
    @IBOutlet private var badgeButton: UIButton?
    @IBOutlet private var actionButton: UIButton?

    @IBOutlet private var tabStackView: UIStackView?
    @IBOutlet private var tabContentContainer: UIView?
    @IBOutlet private var bannerHeightConstraint: NSLayoutConstraint?
    @IBOutlet private var tabTopConstraint: NSLayoutConstraint?
    private var selectedTabIndex = 0
    private let tabTitles = ["Variations", "Targeting", "Allocation"]
    private weak var variationVC: QAVariationViewCtrl?
    private weak var allocationView: QAAllocationView?
    private weak var targetingView: QATargetingView?
    private var userContext: [String: Any] = [:]
    private var contextToken: NSObjectProtocol?

    deinit {
        contextToken.map { FSQAMessageService.shared.remove($0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        campNameLabel?.text = campItem?.name
        actionButton?.layer.borderWidth = 1
        actionButton?.layer.borderColor = UIColor(red: 216/255, green: 216/255, blue: 226/255, alpha: 1).cgColor
        actionButton?.layer.cornerRadius = 0.5
        actionButton?.layer.masksToBounds = true
        subscribeToUserContext()
        FSQAMessageService.shared.broadcastUserContextRequest()
        updateDashboardState()
        updateBannerVisibility()
        setupVariationLabel()
        setupTabs()
        showTab(at: 0)
    }

    // MARK: - Variation label

    private func setupVariationLabel() {
        let assignedVariation = campItem?.variationGroups
            .flatMap { $0.variations }
            .first { $0.isAssigned }
        let variationName = "You are viewing: " + (assignedVariation?.name ?? assignedVariation?.id ?? "-")

        let attachment = NSTextAttachment()
        let checkImage = UIImage(systemName: "checkmark.square.fill")?
            .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        attachment.image = checkImage
        attachment.bounds = CGRect(x: 0, y: -2, width: 16, height: 16)

        let attributed = NSMutableAttributedString(attachment: attachment)
        attributed.append(NSAttributedString(string: "  \(variationName)"))
        assignedVariationNameLabel?.attributedText = attributed
    }

    // MARK: - Tabs

    private func setupTabs() {
        // Stack, separator, and content container are defined in the storyboard.
        // We only add the selection indicators (purple bar) on each button here.
        tabStackView?.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)

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

    @objc private func tabTapped(_ sender: UIButton) {
        showTab(at: sender.tag)
    }

    private func showTab(at index: Int) {
        selectedTabIndex = index

        // Update indicators & colors
        tabStackView?.arrangedSubviews.compactMap { $0 as? UIButton }.enumerated().forEach { i, btn in
            let selected = i == index
            btn.setTitleColor(selected ? UIColor(red: 0.192, green: 0.0, blue: 0.749, alpha: 1) : .secondaryLabel, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: selected ? .bold : .medium)
            btn.viewWithTag(99)?.isHidden = !selected
        }

        // Clear content
        tabContentContainer?.subviews.forEach { $0.removeFromSuperview() }

        guard let container = tabContentContainer else { return }

        switch index {
        case 0: buildVariationsContent(in: container)
        case 1: buildTargetingContent(in: container)
        case 2: buildAllocationContent(in: container)
        default: break
        }
    }

    // MARK: - Tab contents

    private func buildVariationsContent(in container: UIView) {
        let storyboard = UIStoryboard(name: "QAAssistant", bundle: .qaAssistant)
        let vc = storyboard.instantiateViewController(withIdentifier: "QAVariationViewCtrl") as! QAVariationViewCtrl
        vc.campaign = campItem
        vc.canChangeVariation = canChangeVariation
        vc.onVariationChanged = { [weak self] updatedCampaign in
            self?.campItem = updatedCampaign
            self?.setupVariationLabel()
            self?.sendModificationForSelectedVariation()
            
            // Reconfigure allocation and targeting views with updated campaign
            self?.allocationView?.configure(with: updatedCampaign)
            self?.targetingView?.configure(with: updatedCampaign)
            
            // Propagate the updated campaign (new isAssigned flags) back to the campaigns list
            self?.onTakeAction?(updatedCampaign, "variation")
        }
        variationVC = vc
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

    private func buildTargetingContent(in container: UIView) {
        let view = QATargetingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        view.configure(with: campItem)
        targetingView = view
    }

    private func buildAllocationContent(in container: UIView) {
        let view = QAAllocationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        view.configure(with: campItem)
        allocationView = view
    }

    // MARK: - Dashboard State

    private func updateDashboardState() {
        guard let camp = campItem else { return }

        let badgeTitle: String
        let badgeColor: UIColor
        let actionTitle: String
        let actionImage: String

        if camp.isActive {
            if !camp.isHidden {
                badgeTitle = "Accepted"
                badgeColor = UIColor(red: 199/255, green: 244/255, blue: 238/255, alpha: 1)
                actionTitle = "Hide"
                actionImage = "eye.slash"
            } else {
                badgeTitle = "Hidden"
                badgeColor = UIColor(red: 255/255, green: 236/255, blue: 189/255, alpha: 1)
                actionTitle = "Initial state"
                actionImage = "arrow.clockwise"
            }
        } else {
            if camp.isForced {
                badgeTitle = "Forced"
                badgeColor = UIColor(red: 255/255, green: 236/255, blue: 189/255, alpha: 1)
                actionTitle = "Initial state"
                actionImage = "arrow.clockwise"
            } else {
                if let targeting = camp.isTargetingRespected {
                    badgeTitle = targeting ? "Allocation rejected" : "Targeting rejected"
                } else {
                    badgeTitle = "Rejected"
                }
                badgeColor = UIColor(red: 254/255, green: 209/255, blue: 205/255, alpha: 1)
                actionTitle = "Force display"
                actionImage = "eye"
            }
        }

        if #available(iOS 15.0, *) {
            var badgeCfg = badgeButton?.configuration ?? .plain()
            var badgeAttr = AttributedString(badgeTitle)
            badgeAttr.font = UIFont(name: "Lato-Bold", size: 15)
            badgeCfg.attributedTitle = badgeAttr
            badgeCfg.background.backgroundColor = badgeColor
            badgeButton?.configuration = badgeCfg

            var actionCfg = actionButton?.configuration ?? .plain()
            var actionAttr = AttributedString(actionTitle)
            actionAttr.font = UIFont(name: "Lato-Bold", size: 14)
            actionCfg.attributedTitle = actionAttr
            actionCfg.image = UIImage(systemName: actionImage)
            actionButton?.configuration = actionCfg
        } else {
            badgeButton?.setTitle(badgeTitle, for: .normal)
            badgeButton?.backgroundColor = badgeColor
            actionButton?.setTitle(actionTitle, for: .normal)
            actionButton?.setImage(UIImage(systemName: actionImage), for: .normal)
        }
    }

    /// Condition for enabling variation selection:
    /// `(isHidden == false && isActive == true) || (isForced == true && isActive == false)`
    private var canChangeVariation: Bool {
        guard let camp = campItem else { return false }
        return (camp.isActive && !camp.isHidden) || (!camp.isActive && camp.isForced)
    }

    @IBAction private func actionButtonTapped(_ sender: UIButton) {
        guard var camp = campItem else { return }
        let action: String

        if camp.isActive {
            if !camp.isHidden {
                camp.isHidden = true
                action = "hide"
            } else {
                camp.isHidden = false
                action = "show"
            }
        } else {
            if !camp.isForced {
                camp.isForced = true
                action = "force"
            } else {
                camp.isForced = false
                action = "reset"
            }
        }

        campItem = camp
        updateDashboardState()
        updateBannerVisibility()
        variationVC?.updateInteractivity(canChangeVariation)
        
        // Reconfigure allocation and targeting views with updated campaign state
        allocationView?.configure(with: campItem)
        targetingView?.configure(with: campItem)
        
        forwardActionToSDK(action: action)
        onTakeAction?(camp, action)
    }

    // MARK: - SDK forwarding

    private func forwardActionToSDK(action: String) {
        guard let camp = campItem else { return }
        switch action {
        case "hide":
            FSQAMessageService.shared.hideCampaign(camp.id)
        case "show":
            FSQAMessageService.shared.unhideCampaign(camp.id)
        case "force":
            sendModificationForSelectedVariation()
        case "reset":
            resetToReferenceVariation()
        default:
            break
        }
    }

    private func sendModificationForSelectedVariation() {
        guard let camp = campItem else { return }
        let assigned = camp.variationGroups.flatMap { $0.variations }.first { $0.isAssigned }
        guard let variation = assigned else { return }
        guard let vg = camp.variationGroups.first(where: { $0.variations.contains { $0.id == variation.id } }) else { return }

        let rawMods: [String: Any]
        if let mods = variation.modifications {
            rawMods = ["type": mods.type, "value": mods.value.mapValues { jsonValueToAny($0) }]
        } else {
            rawMods = [:]
        }

        let msg = FSQAModificationMessage(
            campaignId: camp.id,
            campaignName: camp.name ?? "Campaign \(camp.id)",
            campaignType: camp.type ?? "",
            campaignSlug: camp.slug ?? "",
            variationGroupId: vg.id,
            variationGroupName: vg.name ?? "Group \(vg.id)",
            variation: FSQAVariation(
                id: variation.id,
                name: variation.name ?? "Variation \(variation.id)",
                reference: variation.reference ?? false,
                modifications: rawMods
            )
        )
        FSQAMessageService.shared.sendModification(msg)
    }

    private func resetToReferenceVariation() {
        guard let camp = campItem else { return }

        if !camp.isActive {
            // Rejected campaign: hide then unhide to clear the forced SDK modification
            FSQAMessageService.shared.hideCampaign(camp.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                FSQAMessageService.shared.unhideCampaign(camp.id)
            }
            return
        }

        // Active campaign: restore the reference variation
        var referenceVariation: Variation?
        var referenceGroup: VariationGroup?
        outer: for vg in camp.variationGroups {
            for v in vg.variations where v.reference == true {
                referenceVariation = v; referenceGroup = vg; break outer
            }
        }
        if referenceVariation == nil, let first = camp.variationGroups.first, let v = first.variations.first {
            referenceVariation = v; referenceGroup = first
        }
        guard let variation = referenceVariation, let vg = referenceGroup else { return }

        let rawMods: [String: Any]
        if let mods = variation.modifications {
            rawMods = ["type": mods.type, "value": mods.value.mapValues { jsonValueToAny($0) }]
        } else {
            rawMods = [:]
        }

        let msg = FSQAModificationMessage(
            campaignId: camp.id,
            campaignName: camp.name ?? "Campaign \(camp.id)",
            campaignType: camp.type ?? "",
            campaignSlug: camp.slug ?? "",
            variationGroupId: vg.id,
            variationGroupName: vg.name ?? "Group \(vg.id)",
            variation: FSQAVariation(
                id: variation.id,
                name: variation.name ?? "Variation \(variation.id)",
                reference: variation.reference ?? false,
                modifications: rawMods
            )
        )
        FSQAMessageService.shared.sendModification(msg)
    }

    // MARK: - Banner visibility

    private func updateBannerVisibility() {
        guard let camp = campItem else {
            assignedVariationNameLabel?.isHidden = true
            bannerHeightConstraint?.constant = 0
            tabTopConstraint?.constant = 0
            return
        }
        let isToggle = camp.type == "toggle"
        let visible: Bool
        if camp.isActive {
            visible = !isToggle && !camp.isHidden
        } else {
            visible = !isToggle && camp.isForced
        }
        assignedVariationNameLabel?.isHidden = !visible
        bannerHeightConstraint?.constant = visible ? 36 : 0
        tabTopConstraint?.constant = visible ? 6 : 0
    }

    // MARK: - Helpers

    private func jsonValueToAny(_ value: JSONValue) -> Any {
        switch value {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .array(let v): return v.map { jsonValueToAny($0) }
        case .object(let v): return v.mapValues { jsonValueToAny($0) }
        case .null: return NSNull()
        }
    }

    // MARK: - Actions

    @IBAction private func backButtonTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - User context

    private func subscribeToUserContext() {
        guard contextToken == nil else { return }
        contextToken = FSQAMessageService.shared.observe(.fsQABroadcastUserContext) { [weak self] note in
            guard let ctx = note.userInfo?[FSQANotificationKey.context] as? [String: Any] else { return }
            self?.userContext = ctx
            DispatchQueue.main.async { self?.evaluateTargeting() }
        }
    }

    private func evaluateTargeting() {
        guard var camp = campItem, !camp.isActive, !camp.isForced else { return }
        let groups = camp.variationGroups
            .compactMap { $0.targeting?.targetingGroups }
            .flatMap { $0 }
        if groups.isEmpty {
            camp.isTargetingRespected = true
        } else {
            camp.isTargetingRespected = groups.contains { group in
                group.targetings.allSatisfy { QATargetingEvaluator.isConditionMet($0, in: userContext) }
            }
        }
        campItem = camp
        updateDashboardState()
    }

}
