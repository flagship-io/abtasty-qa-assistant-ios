import FlagShip
import UIKit
public class ABTastyQAAssistant: NSObject {
    public let envId: String
    public let apiKey: String
    private let onClose: (() -> Void)?

    private let service: QAssistantService

    // MARK: - Bucketing state

    public private(set) var cachedBucketingResponse: BucketingResponse?
    public private(set) var isBucketingLoading = false
    public private(set) var bucketingError: String?
    public private(set) var hasBeenModified = false

    public var isBucketingReady: Bool { cachedBucketingResponse != nil }

    // MARK: - Live SDK state

    public private(set) var hitEvents: [QAHitEvent] = []
    public private(set) var userContext: [String: Any] = [:]
    public private(set) var latestFetchedCampaigns: Set<String> = []
    public private(set) var latestFetchedCampaignIds: [String: Any] = [:]

    private var observerTokens: [NSObjectProtocol] = []

    private var overlayButton: UIButton?
    private var overlayRestoreDelegate: OverlayRestoreDelegate?
    private weak var presentingViewController: UIViewController?

    private weak var qaAssistantHomeCtrl: QAssistantHomeViewController?

    public var isOverlayVisible: Bool {
        return overlayButton?.superview != nil
    }

    public init(_ envId: String, _ apiKey: String, onClose: (() -> Void)? = nil) {
        self.envId = envId
        self.apiKey = apiKey
        self.onClose = onClose
        self.service = QAssistantService(envId: envId, apiKey: apiKey)
        super.init()
        Bundle.registerLatoFonts()
        preloadBucketingConfig()
        subscribeToMessages()
    }

    // MARK: - Bucketing

    private func preloadBucketingConfig() {
        guard !isBucketingLoading, cachedBucketingResponse == nil else { return }
        isBucketingLoading = true
        print("🔄 QA Assistant: Preloading bucketing configuration...")
        service.downloadBucketingConfig { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBucketingLoading = false
                switch result {
                case .success(let response):
                    self.cachedBucketingResponse = response
                    self.bucketingError = nil
                    print("✅ QA Assistant: Bucketing configuration loaded successfully")
                    FSQAMessageService.shared.broadcastStartQAAssistant()
                case .failure(let error):
                    self.bucketingError = error.localizedDescription
                    print("❌ QA Assistant: Failed to preload bucketing configuration: \(error)")
                }
            }
        }
    }

    /// Returns cached config immediately, polls if still loading, or downloads fresh.
    func getBucketingConfig(completion: @escaping (Result<BucketingResponse, Error>) -> Void) {
        if let cached = cachedBucketingResponse {
            completion(.success(cached))
            return
        }
        if isBucketingLoading {
            pollUntilLoaded(deadline: .now() + 30, completion: completion)
            return
        }
        service.downloadBucketingConfig { [weak self] result in
            if case .success(let response) = result {
                self?.cachedBucketingResponse = response
            }
            completion(result)
        }
    }

    private func pollUntilLoaded(deadline: DispatchTime,
                                 completion: @escaping (Result<BucketingResponse, Error>) -> Void)
    {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
            guard let self else { return }
            if let cached = self.cachedBucketingResponse {
                completion(.success(cached))
            } else if self.isBucketingLoading && DispatchTime.now() < deadline {
                self.pollUntilLoaded(deadline: deadline, completion: completion)
            } else {
                completion(.failure(QAServiceError.timeout))
            }
        }
    }

    public func updateCachedBucketingResponse(_ response: BucketingResponse) {
        cachedBucketingResponse = response
        hasBeenModified = true
        print("✅ QA Assistant: Updated cached bucketing response")
    }

    public func clearModifications() {
        cachedBucketingResponse = nil
        hasBeenModified = false
        print("🔄 QA Assistant: Cleared all modifications")
    }

    public func clearHitEvents() {
        hitEvents.removeAll()
        print("🧹 QA Assistant: Hit events cleared")
    }

    public func getContext() -> [String: Any] {
        FSQAMessageService.shared.broadcastUserContextRequest()
        return userContext
    }

    // MARK: - Message subscriptions

    private func subscribeToMessages() {
        _listenToFetchedCampIds()
        _listenToHitEvents()
    }

    private func _listenToHitEvents() {
        let token = FSQAMessageService.shared.observe(.fsQABroadcastHitEvent) { [weak self] notification in
            guard let self else { return }
            guard let payload = notification.userInfo?[FSQANotificationKey.payload] as? [String: Any] else { return }
            let hitType = (payload["t"] as? String) ?? "Unknown"
            let event = QAHitEvent(hitType: hitType, payload: payload)
            DispatchQueue.main.async {
                self.hitEvents.append(event)
                if self.hitEvents.count > 500 { self.hitEvents.removeFirst(self.hitEvents.count - 500) }
            }
        }
        observerTokens.append(token)
    }

    /// `_listenToFetchedCampIds()`.
    /// Listens for the SDK broadcast of fetched variation IDs and updates
    /// `latestFetchedCampaigns` (Set of campaignIds) and `latestFetchedCampaignIds`
    /// (raw dict) so the QA tools know which variations are currently live.
    private func _listenToFetchedCampIds() {
        let token = FSQAMessageService.shared.observe(.fsQABroadcastFetchedFlags) { [weak self] notification in
            guard let self else { return }

            // Raw userInfo dict `_latestFetchedCampaignIds.addAll(data)`
            if let userInfo = notification.userInfo as? [String: Any] {
                self.latestFetchedCampaignIds.merge(userInfo) { _, new in new }
            }

            // Extract the `variations` array `data['variations']` check
            if let variations = notification.userInfo?[FSQANotificationKey.variations] as? [[String: String]] {
                let campaignIds = Set(variations.compactMap { $0["campaignId"] })
                self.latestFetchedCampaigns = campaignIds
                print("✅ QA Assistant: Updated latest fetched variations (\(campaignIds.count) items)")
            }
        }
        observerTokens.append(token)
    }

    public func showOverlayButton(in viewController: UIViewController) {
        guard overlayButton == nil else { return }
        presentingViewController = viewController

        let size: CGFloat = 56
        let view = viewController.view!
        let safeBottom = view.safeAreaInsets.bottom
        let initialX = view.bounds.width - size - 20
        let initialY = view.bounds.height - safeBottom - size - 80

        let button = UIButton(type: .custom)
        button.frame = CGRect(x: initialX, y: initialY, width: size, height: size)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        button.layer.cornerRadius = size / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 6
        button.setImage(UIImage(systemName: "ladybug.fill"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(overlayButtonTapped), for: .touchUpInside)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        button.addGestureRecognizer(panGesture)

        view.addSubview(button)
        overlayButton = button

        button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            button.transform = .identity
        }
    }

    func restoreOverlayButton() {
        guard let button = overlayButton else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIView.animate(withDuration: 0.2) { button.alpha = 1 }
        }
        overlayRestoreDelegate = nil
    }

    public func hideOverlayButton() {
        guard let button = overlayButton else { return }
        UIView.animate(withDuration: 0.2, animations: {
            button.alpha = 0
            button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }, completion: { _ in
            button.removeFromSuperview()
        })
        overlayButton = nil
        FSQAMessageService.shared.broadcastStopQAAssistant()
        onClose?()
        print("✅ QA Assistant: onClose callback triggered")
    }

    public func dispose() {
        hideOverlayButton()
        observerTokens.forEach { FSQAMessageService.shared.remove($0) }
        observerTokens.removeAll()
        latestFetchedCampaigns.removeAll()
        cachedBucketingResponse = nil
        presentingViewController = nil
        print("🧹 QA Assistant: Resources cleaned up")
    }

    /// `_defaultOverlayAction`:
    /// 1. Hides the overlay button while the panel is open.
    /// 2. Presents QAPanelViewController as a bottom sheet (transparent, scroll-controlled).
    /// 3. Restores the overlay button after the sheet is dismissed.
    @objc private func overlayButtonTapped() {
        guard let vc = presentingViewController else { return }

        // 1. Hide overlay while panel is open
        if let button = overlayButton {
            UIView.animate(withDuration: 0.2) { button.alpha = 0 }
        }

        // 2. Build panel wrapped in a navigation controller so each tab can push its VC
        let storyboard = UIStoryboard(name: "QAAssistant", bundle: .qaAssistant)
        let panel = storyboard.instantiateViewController(withIdentifier: "QAssistantHome") as! QAssistantHomeViewController
        panel.qaAssistant = self
        let nav = UINavigationController(rootViewController: panel)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.selectedDetentIdentifier = .large
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
        }

        // 3. Restore overlay when sheet is dismissed.
        // The delegate must be held strongly — UIAdaptivePresentationControllerDelegate is weak.
        let restoreDelegate = OverlayRestoreDelegate { [weak self] in
            guard let self, let button = self.overlayButton else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIView.animate(withDuration: 0.2) { button.alpha = 1 }
            }
            self.overlayRestoreDelegate = nil
        }
        overlayRestoreDelegate = restoreDelegate
        nav.presentationController?.delegate = restoreDelegate

        vc.present(nav, animated: true)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let button = overlayButton, let superview = button.superview else { return }
        let translation = gesture.translation(in: superview)
        button.center = CGPoint(
            x: button.center.x + translation.x,
            y: button.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: superview)

        if gesture.state == .ended {
            let margin: CGFloat = 28
            var finalX = button.center.x
            let finalY = min(max(button.center.y, margin), superview.bounds.height - margin)
            finalX = button.center.x < superview.bounds.width / 2
                ? margin
                : superview.bounds.width - margin
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: []) {
                button.center = CGPoint(x: finalX, y: finalY)
            }
        }
    }
}
