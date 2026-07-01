import UIKit
import FlagShip
import ABTastyQAssistant

class ViewController: UIViewController {

    // MARK: - State

    private var qaAssistant: ABTastyQAAssistant?
    private var isVIPMode = false

    private var btnTitleValue  = "Loading..."
    private var btnColorValue  = "Loading..."
    private var flag1Value     = "Loading..."
    private var flag2Value     = 0
    private var key1Value      = "Loading..."
    private var vipValue       = "Loading..."

    // MARK: - UI Components

    private let scrollView   = UIScrollView()
    private let contentView  = UIView()

    private lazy var btnTitleValueLabel = makeValueBadge()
    private lazy var btnColorValueLabel = makeValueBadge()
    private lazy var flag1ValueLabel    = makeValueBadge()
    private lazy var flag2ValueLabel    = makeValueBadge()
    private lazy var key1ValueLabel     = makeValueBadge()
    private lazy var vipValueLabel      = makeValueBadge()

    private let vipSwitch = UISwitch()
    private let vipStatusLabel: UILabel = {
        let l = UILabel()
        l.text = "Disabled"
        l.textColor = .systemGray
        l.font = .systemFont(ofSize: 13, weight: .medium)
        return l
    }()

    private let syncBanner: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()
    private let syncBannerLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .systemGreen
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let syncActivityIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(activityIndicatorStyle: .medium)
        a.color = .systemBlue
        a.translatesAutoresizingMaskIntoConstraints = false
        a.hidesWhenStopped = true
        return a
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1)
        setupNavigationBar()
        setupUI()
        initFlagship()
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        title = "ABTasty QA Demo"

        let qaButton = UIBarButtonItem(
            image: UIImage(systemName: "ladybug"),
            style: .plain,
            target: self,
            action: #selector(toggleQAAssistant)
        )
        navigationItem.leftBarButtonItem = qaButton

        let syncButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.triangle.2.circlepath"),
            style: .plain,
            target: self,
            action: #selector(syncFlags)
        )
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshFlagsUI)
        )
        navigationItem.rightBarButtonItems = [refreshButton, syncButton]
    }

    // MARK: - Flagship SDK

    private func initFlagship() {
        Flagship.sharedInstance.start(
            envId: "bkk9glocmjcg0vtmdlng",
            apiKey: "DxAcxlnRB9yFBZYtLDue1q01dcXZCw6aM49CQB23"
        )

        _ = Flagship.sharedInstance.newVisitor(visitorId: "qaUser", hasConsented: true)
            .withContext(context: [
                "isQA": true,
                "country": "FR",
                "customer": "customer",
                "accountID": "1234",
                "isVip": isVIPMode
            ])
            .build()

        print("Flagship SDK initialized successfully")

        // Live flag updates from QA Assistant
        Flagship.sharedInstance.sharedVisitor?.onFlagUpdate = { [weak self] changedFlagKeys in
            DispatchQueue.main.async {
                self?.updateFlagValues()
                self?.showSyncBanner("Live update: \(changedFlagKeys.joined(separator: ", "))", color: .systemOrange)
            }
        }

        Flagship.sharedInstance.sharedVisitor?.fetchFlags { [weak self] in
            DispatchQueue.main.async {
                self?.updateFlagValues()
            }
        }
    }

    private func updateFlagValues() {
        guard let visitor = Flagship.sharedInstance.sharedVisitor else { return }

        btnTitleValue = visitor.getFlag(key: "btnTitle").value(defaultValue: "Default Button") ?? "Default Button"
        btnColorValue = visitor.getFlag(key: "btnColor").value(defaultValue: "Default Color") ?? "Default Color"
        flag1Value    = visitor.getFlag(key: "payKey1").value(defaultValue: "Default Flag1") ?? "Default Flag1"
        flag2Value    = visitor.getFlag(key: "payKey2").value(defaultValue: 0) ?? 0
        key1Value     = visitor.getFlag(key: "rejectedKey").value(defaultValue: "Rejected Key") ?? "Rejected Key"
        vipValue      = visitor.getFlag(key: "Delivery cost").value(defaultValue: "25 €") ?? "25 €"

        updateFlagLabels()
    }

    private func updateFlagLabels() {
        btnTitleValueLabel.setTitle(btnTitleValue, for: .normal)
        btnColorValueLabel.setTitle(btnColorValue, for: .normal)
        flag1ValueLabel.setTitle(flag1Value, for: .normal)
        flag2ValueLabel.setTitle("\(flag2Value)", for: .normal)
        key1ValueLabel.setTitle(key1Value, for: .normal)
        vipValueLabel.setTitle(vipValue, for: .normal)
    }

    // MARK: - QA Assistant

    @objc private func toggleQAAssistant() {
        if qaAssistant?.isOverlayVisible == true {
            destroyQAAssistant()
        } else {
            initializeQAAssistant()
            qaAssistant?.showOverlayButton(in: self)
        }
        updateQABarButton()
    }

    private func initializeQAAssistant() {
        guard qaAssistant == nil else { return }
        qaAssistant = ABTastyQAAssistant(
            "bkk9glocmjcg0vtmdlng",
            "DxAcxlnRB9yFBZYtLDue1q01dcXZCw6aM49CQB23",
            onClose: { [weak self] in
                print("QA Assistant closed, fetching updated flags...")
                self?.fetchFlagsFromSDK()
            }
        )
        print("QA Assistant initialized")
    }

    private func destroyQAAssistant() {
        qaAssistant?.dispose()
        qaAssistant = nil
        print("QA Assistant destroyed")
    }

    private func updateQABarButton() {
        let imageName = qaAssistant?.isOverlayVisible == true ? "eye.slash" : "ladybug"
        navigationItem.leftBarButtonItem?.image = UIImage(systemName: imageName)
    }

    // MARK: - Actions

    @objc private func syncFlags() {
        syncActivityIndicator.startAnimating()
        showSyncBanner("Syncing flags…", color: .systemBlue)
        Flagship.sharedInstance.sharedVisitor?.fetchFlags { [weak self] in
            DispatchQueue.main.async {
                self?.updateFlagValues()
                self?.syncActivityIndicator.stopAnimating()
                self?.showSyncBanner("✓  Flags synced", color: .systemGreen)
            }
        }
    }

    @objc private func refreshFlagsUI() {
        updateFlagValues()
        showSyncBanner("✓  UI refreshed", color: .systemIndigo)
    }

    private func fetchFlagsFromSDK() {
        Flagship.sharedInstance.sharedVisitor?.fetchFlags { [weak self] in
            DispatchQueue.main.async {
                self?.updateFlagValues()
                self?.showSyncBanner("✓  Flags auto-refreshed", color: .systemGreen)
                print("Flags fetched from SDK successfully")
            }
        }
    }

    @objc private func sendEvents() {
        guard let visitor = Flagship.sharedInstance.sharedVisitor else {
            showSyncBanner("⚠  Visitor not initialized", color: .systemRed)
            return
        }
        visitor.sendHit(FSScreen("HomeScreen"))
        visitor.sendHit(FSEvent(eventCategory: .Action_Tracking, eventAction: "eventQA"))
        visitor.sendHit(FSEvent(eventCategory: .User_Engagement, eventAction: "eventQA"))
        visitor.sendHit(FSTransaction(transactionId: "transactionId", affiliation: "affiliationQA"))
        showSyncBanner("✓  Events sent", color: .systemGreen)
        print("Events sent successfully!")
    }

    @objc private func vipSwitchChanged(_ sender: UISwitch) {
        isVIPMode = sender.isOn
        vipStatusLabel.text  = isVIPMode ? "Enabled" : "Disabled"
        vipStatusLabel.textColor = isVIPMode ? .systemGreen : .systemGray

        Flagship.sharedInstance.sharedVisitor?.updateContext("isVip", isVIPMode)
        Flagship.sharedInstance.sharedVisitor?.fetchFlags { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateFlagValues()
                let message = self.isVIPMode ? "🌟  VIP Mode enabled" : "VIP Mode disabled"
                let color: UIColor = self.isVIPMode ? .systemGreen : .systemOrange
                self.showSyncBanner(message, color: color)
            }
        }
    }

    // MARK: - Sync Banner

    private func showSyncBanner(_ message: String, color: UIColor, duration: TimeInterval = 2.5) {
        syncBannerLabel.text = message
        syncBannerLabel.textColor = color
        syncBanner.backgroundColor = color.withAlphaComponent(0.1)
        syncBanner.layer.borderColor = color.withAlphaComponent(0.3).cgColor
        syncBanner.layer.borderWidth = 1

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideSyncBanner), object: nil)
        UIView.animate(withDuration: 0.25) { self.syncBanner.alpha = 1 }
        perform(#selector(hideSyncBanner), with: nil, afterDelay: duration)
    }

    @objc private func hideSyncBanner() {
        UIView.animate(withDuration: 0.4) { self.syncBanner.alpha = 0 }
    }

    // MARK: - UI Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Subviews
        syncBanner.addSubview(syncBannerLabel)
        NSLayoutConstraint.activate([
            syncBannerLabel.topAnchor.constraint(equalTo: syncBanner.topAnchor, constant: 8),
            syncBannerLabel.leadingAnchor.constraint(equalTo: syncBanner.leadingAnchor, constant: 12),
            syncBannerLabel.trailingAnchor.constraint(equalTo: syncBanner.trailingAnchor, constant: -12),
            syncBannerLabel.bottomAnchor.constraint(equalTo: syncBanner.bottomAnchor, constant: -8)
        ])

        let heroCard      = buildHeroCard()
        let flagsCard     = buildFlagsCard()
        let eventsButton  = buildSendEventsButton()
        let vipCard       = buildVIPCard()

        [heroCard, flagsCard, syncBanner, eventsButton, vipCard].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            heroCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            heroCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            flagsCard.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 14),
            flagsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            flagsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            syncBanner.topAnchor.constraint(equalTo: flagsCard.bottomAnchor, constant: 10),
            syncBanner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            syncBanner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            eventsButton.topAnchor.constraint(equalTo: syncBanner.bottomAnchor, constant: 10),
            eventsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            eventsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            eventsButton.heightAnchor.constraint(equalToConstant: 54),

            vipCard.topAnchor.constraint(equalTo: eventsButton.bottomAnchor, constant: 14),
            vipCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            vipCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            vipCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }

    // MARK: - Hero Card (env info)

    private func buildHeroCard() -> UIView {
        let card = makeCard(gradient: true)

        let iconView = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right"))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Flagship"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white

        let subtitleLabel = UILabel()
        subtitleLabel.text = "ENV: bkk9glocmjcg0vtmdlng"
        subtitleLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        syncActivityIndicator.color = .white
        let mainRow = UIStackView(arrangedSubviews: [iconView, textStack, syncActivityIndicator])
        mainRow.axis = .horizontal
        mainRow.spacing = 12
        mainRow.alignment = .center
        mainRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(mainRow)
        NSLayoutConstraint.activate([
            mainRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            mainRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            mainRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            mainRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        return card
    }

    // MARK: - Flags Card

    private func buildFlagsCard() -> UIView {
        let card = makeCard()

        // Header
        let flagIcon = UIImageView(image: UIImage(systemName: "flag.2.crossed.fill"))
        flagIcon.tintColor = .systemBlue
        flagIcon.setContentHuggingPriority(.required, for: .horizontal)
        flagIcon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        flagIcon.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let headerLabel = UILabel()
        headerLabel.text = "Feature Flags"
        headerLabel.font = .systemFont(ofSize: 17, weight: .bold)

        let countBadge = makePillLabel(text: "6", color: .systemBlue)

        let headerSpacer = UIView()
        let headerRow = UIStackView(arrangedSubviews: [flagIcon, headerLabel, headerSpacer, countBadge])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        let dividerTop = makeDivider()

        let flags: [(icon: String, color: UIColor, name: String, desc: String, badge: UIButton)] = [
            ("textformat.abc",      .systemPurple,  "btnTitle",      "Login A/B",    btnTitleValueLabel),
            ("paintpalette.fill",   .systemPink,    "btnColor",      "Login A/B",    btnColorValueLabel),
            ("creditcard.fill",     .systemGreen,   "payKey1",       "Payment",      flag1ValueLabel),
            ("number.circle.fill",  .systemOrange,  "payKey2",       "Payment",      flag2ValueLabel),
            ("xmark.seal.fill",     .systemRed,     "rejectedKey",   "—",            key1ValueLabel),
            ("shippingbox.fill",    .systemTeal,    "Delivery cost", "VIP Mode",     vipValueLabel),
        ]

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        mainStack.addArrangedSubview(headerRow)
        mainStack.setCustomSpacing(14, after: headerRow)
        mainStack.addArrangedSubview(dividerTop)
        mainStack.setCustomSpacing(0, after: dividerTop)

        for (i, flag) in flags.enumerated() {
            mainStack.addArrangedSubview(buildFlagRow(icon: flag.icon, iconColor: flag.color,
                                                      name: flag.name, desc: flag.desc,
                                                      badge: flag.badge))
            if i < flags.count - 1 {
                mainStack.addArrangedSubview(makeDivider())
            }
        }

        card.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func buildFlagRow(icon: String, iconColor: UIColor, name: String, desc: String, badge: UIButton) -> UIView {
        // Icon circle
        let iconBg = UIView()
        iconBg.backgroundColor = iconColor.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 10
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let iconImage = UIImageView(image: UIImage(systemName: icon))
        iconImage.tintColor = iconColor
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconImage)
        NSLayoutConstraint.activate([
            iconImage.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 18),
            iconImage.heightAnchor.constraint(equalToConstant: 18)
        ])

        // Text
        let keyLabel = UILabel()
        keyLabel.text = name
        keyLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        keyLabel.textColor = .label

        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = .systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [keyLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let spacer = UIView()

        let rowStack = UIStackView(arrangedSubviews: [iconBg, textStack, spacer, badge])
        rowStack.axis = .horizontal
        rowStack.spacing = 10
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        return container
    }

    // MARK: - Send Events Button

    private func buildSendEventsButton() -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("  Send Events", for: .normal)
        button.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 14
        button.layer.shadowColor = UIColor.systemBlue.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(sendEvents), for: .touchUpInside)
        return button
    }

    // MARK: - VIP Card

    private func buildVIPCard() -> UIView {
        let card = makeCard()

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 12
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let starIcon = UIImageView(image: UIImage(systemName: "star.fill"))
        starIcon.tintColor = .systemYellow
        starIcon.contentMode = .scaleAspectFit
        starIcon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(starIcon)
        NSLayoutConstraint.activate([
            starIcon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            starIcon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            starIcon.widthAnchor.constraint(equalToConstant: 22),
            starIcon.heightAnchor.constraint(equalToConstant: 22)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "VIP Mode"
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, vipStatusLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 3

        vipSwitch.onTintColor = .systemGreen
        vipSwitch.addTarget(self, action: #selector(vipSwitchChanged(_:)), for: .valueChanged)

        let spacer = UIView()
        let rowStack = UIStackView(arrangedSubviews: [iconBg, labelStack, spacer, vipSwitch])
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    // MARK: - Helpers

    private func makeCard(gradient: Bool = false) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = gradient ? nil : .systemBackground
        card.layer.cornerRadius = 16
        card.clipsToBounds = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8

        if gradient {
            let gradLayer = CAGradientLayer()
            gradLayer.colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemIndigo.cgColor
            ]
            gradLayer.startPoint = CGPoint(x: 0, y: 0)
            gradLayer.endPoint   = CGPoint(x: 1, y: 1)
            gradLayer.cornerRadius = 16
            // Insert behind content
            card.layer.insertSublayer(gradLayer, at: 0)
            card.translatesAutoresizingMaskIntoConstraints = false
            // Resize gradient layer on layout
            DispatchQueue.main.async {
                gradLayer.frame = card.bounds
            }
        }

        return card
    }

    /// A pill-shaped UIButton used as a read-only value badge.
    private func makeValueBadge() -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "—"
        config.baseForegroundColor = .systemBlue
        config.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return a
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.cornerStyle = .fixed
        let btn = UIButton(configuration: config)
        btn.layer.cornerRadius = 10
        btn.isUserInteractionEnabled = false
        return btn
    }

    private func makePillLabel(text: String, color: UIColor) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        let bg = UIView()
        bg.backgroundColor = color
        bg.layer.cornerRadius = 9
        bg.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            bg.widthAnchor.constraint(equalToConstant: 22),
            bg.heightAnchor.constraint(equalToConstant: 18),
            label.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: bg.centerYAnchor)
        ])
        return bg
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }
}
