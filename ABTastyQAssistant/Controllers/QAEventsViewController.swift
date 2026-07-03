//
//  QAEventsViewController.swift
//  ABTastyQAssistant
//

#if canImport(FlagShip)
import FlagShip
#else
import Flagship
#endif
import UIKit

class QAEventsViewController: UIViewController {
    weak var qaAssistant: ABTastyQAAssistant?

    private var allEvents: [QAHitEvent] = []
    private var filteredEvents: [QAHitEvent] = []
    private var expandedIndices = Set<Int>()
    private var searchQuery = ""

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerView = UIView()
    private let countLabel = UILabel()
    private let clearButton = UIButton(type: .system)
    private let emptyStateView = UIView()

    private var hitEventToken: NSObjectProtocol?
    private var headerHeightConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupHeader()
        setupTableView()
        setupEmptyState()
        loadData()
        subscribeToHitEvents()
    }


    deinit {
        if let token = hitEventToken {
            FSQAMessageService.shared.remove(token)
        }
    }

    // MARK: - Public API

    func reload() {
        loadData()
    }

    func filter(by query: String) {
        searchQuery = query
        applyFilter()
    }

    // MARK: - Notifications

    private func subscribeToHitEvents() {
        hitEventToken = FSQAMessageService.shared.observe(.fsQABroadcastHitEvent) { [weak self] _ in
            DispatchQueue.main.async { self?.loadData() }
        }
    }

    // MARK: - Data

    private func loadData() {
        allEvents = (qaAssistant?.hitEvents ?? []).reversed()
        applyFilter()
    }

    private func applyFilter() {
        if searchQuery.isEmpty {
            filteredEvents = allEvents
        } else {
            let q = searchQuery.lowercased()
            filteredEvents = allEvents.filter { event in
                if event.hitType.lowercased().contains(q) { return true }
                for (key, value) in event.payload {
                    if key.lowercased().contains(q) { return true }
                    if "\(value)".lowercased().contains(q) { return true }
                }
                return false
            }
        }
        expandedIndices.removeAll()
        updateCountLabel()
        updateEmptyState()
        tableView.reloadData()
    }

    private func updateCountLabel() {
        let count = filteredEvents.count
        countLabel.text = "\(count) event\(count == 1 ? "" : "s") recorded"
    }

    private func updateEmptyState() {
        let isEmpty = filteredEvents.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        headerView.isHidden = isEmpty
        headerHeightConstraint?.constant = isEmpty ? 0 : 48
        updateClearButtonState()
    }

    private func updateClearButtonState() {
        let hasEvents = !(qaAssistant?.hitEvents.isEmpty ?? true)
        let color: UIColor = hasEvents ? .systemRed : .secondaryLabel
        clearButton.configuration?.baseForegroundColor = color
        clearButton.isEnabled = hasEvents
    }

    // MARK: - Actions

    @objc private func clearAllTapped() {
        qaAssistant?.clearHitEvents()
        loadData()
    }

    // MARK: - Setup

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        countLabel.font = UIFont.lato(size: 14)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(countLabel)

        var config = UIButton.Configuration.plain()
        let trashSize = CGSize(width: 16, height: 16)
        let trashIcon = UIGraphicsImageRenderer(size: trashSize).image { _ in
            UIImage(named: "trash", in: .qaAssistant, compatibleWith: nil)?
                .withRenderingMode(.alwaysTemplate)
                .draw(in: CGRect(origin: .zero, size: trashSize))
        }.withRenderingMode(.alwaysTemplate)
        config.image = trashIcon
        config.imagePadding = 4
        config.imagePlacement = .leading
        config.baseForegroundColor = .secondaryLabel
        var titleAttr = AttributedString("Clear all")
        titleAttr.font = UIFont.lato(size: 14)
        config.attributedTitle = titleAttr
        clearButton.configuration = config
        clearButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(clearButton)

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(separator)

        let heightConstraint = headerView.heightAnchor.constraint(equalToConstant: 48)
        headerHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,

            countLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            countLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            clearButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(QAEventCell.self, forCellReuseIdentifier: QAEventCell.reuseID)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        let imageView = UIImageView(image: UIImage(named: "noEvent", in: .qaAssistant, compatibleWith: nil))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

let titleLabel = UILabel()
titleLabel.text = "No events to display for the moment"
titleLabel.font = UIFont.latoBold(size: 18)
titleLabel.textAlignment = .center
titleLabel.numberOfLines = 0
titleLabel.translatesAutoresizingMaskIntoConstraints = false

let subtitleLabel = UILabel()
subtitleLabel.text = "Events will appear here as soon as they are recorded in the QA Assistant"
subtitleLabel.font = UIFont.lato(size: 12)
subtitleLabel.textColor = .secondaryLabel
subtitleLabel.textAlignment = .center
subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.addSubview(imageView)
        emptyStateView.addSubview(titleLabel)
        emptyStateView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -60),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -32)
        ])
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension QAEventsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredEvents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: QAEventCell.reuseID, for: indexPath) as! QAEventCell
        let event = filteredEvents[indexPath.row]
        cell.configure(with: event, expanded: expandedIndices.contains(indexPath.row))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if expandedIndices.contains(indexPath.row) {
            expandedIndices.remove(indexPath.row)
        } else {
            expandedIndices.insert(indexPath.row)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - QAEventCell

final class QAEventCell: UITableViewCell {
    static let reuseID = "QAEventCell"

    private let pillLabel = PaddedLabel()
    private let timestampLabel = UILabel()
    private let chevronImageView = UIImageView()
    private let payloadContainer = UIView()
    private let payloadStack = UIStackView()
    private let rowSeparator = UIView()

    // Separator is anchored to rowStack (collapsed) or payloadContainer (expanded).
    // Only one of these is active at a time.
    private var separatorCollapsed: NSLayoutConstraint!
    private var separatorExpanded: NSLayoutConstraint!
    // payloadContainer.top is only active when expanded to avoid phantom height
    private var payloadContainerTop: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        applyCollapsedLayout()
        payloadStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chevronImageView.image = UIImage(systemName: "chevron.down")
    }

    func configure(with event: QAHitEvent, expanded: Bool) {
        pillLabel.text = event.hitType
        let ago = Self.minutesAgo(from: event.timestamp)
        timestampLabel.text = ago
        timestampLabel.textColor = ago == "Just now"
            ? UIColor(red: 0, green: 0.502, blue: 0.424, alpha: 1)
            : .secondaryLabel
        chevronImageView.image = UIImage(systemName: expanded ? "chevron.up" : "chevron.down")

        if expanded {
            payloadStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            event.payload
                .filter { $0.key != "qt" }
                .sorted { $0.key < $1.key }
                .forEach { payloadStack.addArrangedSubview(makePayloadRow(key: $0.key, value: $0.value)) }
            applyExpandedLayout()
        } else {
            applyCollapsedLayout()
        }
    }

    private func applyCollapsedLayout() {
        separatorExpanded.isActive = false
        payloadContainerTop.isActive = false
        payloadContainer.isHidden = true
        separatorCollapsed.isActive = true
    }

    private func applyExpandedLayout() {
        separatorCollapsed.isActive = false
        payloadContainer.isHidden = false
        payloadContainerTop.isActive = true
        separatorExpanded.isActive = true
    }

    private func makePayloadRow(key: String, value: Any) -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        let text = NSMutableAttributedString(
            string: "\"\(key)\": ",
            attributes: [.font: UIFont.lato(size: 14)]
        )
        let valueStr = value is String ? "\"\(value)\"" : "\(value)"
        text.append(NSAttributedString(string: valueStr, attributes: [.font: UIFont.lato(size: 14)]))
        label.attributedText = text
        return label
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground

        pillLabel.font = UIFont.latoBold(size: 15)
        pillLabel.backgroundColor = UIColor(red: 0.859, green: 0.898, blue: 1.0, alpha: 1)
        pillLabel.layer.cornerRadius = 12
        pillLabel.clipsToBounds = true
        pillLabel.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        pillLabel.translatesAutoresizingMaskIntoConstraints = false

        timestampLabel.font = UIFont.lato(size: 12)
        timestampLabel.setContentHuggingPriority(.required, for: .horizontal)
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false

        chevronImageView.tintColor = .secondaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [pillLabel, spacer, timestampLabel, chevronImageView])
        rowStack.axis = .horizontal
        rowStack.spacing = 8
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        payloadContainer.backgroundColor = UIColor(red: 0.953, green: 0.953, blue: 0.969, alpha: 1)
        payloadContainer.layer.cornerRadius = 4
        payloadContainer.isHidden = true
        payloadContainer.translatesAutoresizingMaskIntoConstraints = false

        payloadStack.axis = .vertical
        payloadStack.spacing = 4
        payloadStack.translatesAutoresizingMaskIntoConstraints = false
        payloadContainer.addSubview(payloadStack)

        rowSeparator.backgroundColor = .separator
        rowSeparator.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rowStack)
        contentView.addSubview(payloadContainer)
        contentView.addSubview(rowSeparator)

        // Build the two mutually-exclusive separator-top constraints
        separatorCollapsed = rowSeparator.topAnchor.constraint(equalTo: rowStack.bottomAnchor, constant: 12)
        separatorExpanded  = rowSeparator.topAnchor.constraint(equalTo: payloadContainer.bottomAnchor, constant: 12)
        payloadContainerTop = payloadContainer.topAnchor.constraint(equalTo: rowStack.bottomAnchor, constant: 8)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16),

            payloadContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            payloadContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            payloadStack.topAnchor.constraint(equalTo: payloadContainer.topAnchor, constant: 12),
            payloadStack.leadingAnchor.constraint(equalTo: payloadContainer.leadingAnchor, constant: 12),
            payloadStack.trailingAnchor.constraint(equalTo: payloadContainer.trailingAnchor, constant: -12),
            payloadStack.bottomAnchor.constraint(equalTo: payloadContainer.bottomAnchor, constant: -12),

            rowSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rowSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rowSeparator.heightAnchor.constraint(equalToConstant: 1),
            rowSeparator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            separatorCollapsed  // start collapsed
        ])
    }

    private static func minutesAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
