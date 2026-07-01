//
//  QAContextViewController.swift
//  ABTastyQAssistant
//

import FlagShip
import UIKit

class QAContextViewController: UIViewController {
    weak var qaAssistant: ABTastyQAAssistant?

    private var contextData: [(key: String, value: Any)] = []
    private var filteredData: [(key: String, value: Any)] = []
    private var searchQuery = ""

    private var contextToken: NSObjectProtocol?

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let cardView = UIView()
    private let cardStack = UIStackView()
    private let emptyStateView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        subscribeToContext()
        FSQAMessageService.shared.broadcastUserContextRequest()
    }

    deinit {
        if let token = contextToken {
            FSQAMessageService.shared.remove(token)
        }
    }

    // MARK: - Public API

    func filter(by query: String) {
        searchQuery = query
        applyFilter()
    }

    // MARK: - Notifications

    private func subscribeToContext() {
        contextToken = FSQAMessageService.shared.observe(.fsQABroadcastUserContext) { [weak self] note in
            guard let self else { return }
            guard let ctx = note.userInfo?[FSQANotificationKey.context] as? [String: Any] else { return }
            DispatchQueue.main.async {
                self.contextData = ctx.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
                self.applyFilter()
            }
        }
    }

    // MARK: - Data

    private func applyFilter() {
        if searchQuery.isEmpty {
            filteredData = contextData
        } else {
            let q = searchQuery.lowercased()
            filteredData = contextData.filter {
                $0.key.lowercased().contains(q) || "\($0.value)".lowercased().contains(q)
            }
        }
        rebuildRows()
        updateEmptyState()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        cardView.backgroundColor = UIColor(red: 0.953, green: 0.953, blue: 0.969, alpha: 1)
        cardView.layer.cornerRadius = 4
        cardView.translatesAutoresizingMaskIntoConstraints = false

        cardStack.axis = .vertical
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardStack)

        contentStack.addArrangedSubview(cardView)

        setupEmptyState()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        let titleLabel = UILabel()
        titleLabel.text = "No context available"
        titleLabel.font = UIFont.latoBold(size: 18)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Context values will appear here once the SDK sends them"
        subtitleLabel.font = UIFont.lato(size: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.addSubview(titleLabel)
        emptyStateView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -16),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -32)
        ])
    }

    private func rebuildRows() {
        cardStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for item in filteredData {
            let label = UILabel()
            label.text = "\(item.key): \(item.value)"
            label.font = UIFont.lato(size: 16)
            label.textColor = UIColor(red: 0.165, green: 0.165, blue: 0.235, alpha: 1)
            label.numberOfLines = 0
            cardStack.addArrangedSubview(label)
        }
    }

    private func updateEmptyState() {
        let isEmpty = filteredData.isEmpty
        emptyStateView.isHidden = !isEmpty
        scrollView.isHidden = isEmpty
    }
}
