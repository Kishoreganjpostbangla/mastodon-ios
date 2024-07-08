// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonLocalization

enum NotificationFilterSection: Hashable {
    case main
}

enum NotificationFilterItem: Hashable,  CaseIterable {
    case notFollowing
    case noFollower
    case newAccount
    case privateMentions

    var title: String {
        switch self {
        case .notFollowing:
            return "People you don't follow"
        case .noFollower:
            return "People not following you"
        case .newAccount:
            return "New accounts"
        case .privateMentions:
            return "Unsolicited private mentions"
        }
    }

    var subtitle: String {
        switch self {
        case .notFollowing:
            return "Until you manually approve them"
        case .noFollower:
            return "Including people who have been following you fewer than 3 days"
        case .newAccount:
            return "Created within the past 30 days"
        case .privateMentions:
            return "Filtered unless it’s in reply to your own mention or if you follow the sender"
        }
    }
}

struct NotificationFilterViewModel {
    var notFollowing: Bool
    var noFollower: Bool
    var newAccount: Bool
    var privateMentions: Bool

    init(notFollowing: Bool, noFollower: Bool, newAccount: Bool, privateMentions: Bool) {
        self.notFollowing = notFollowing
        self.noFollower = noFollower
        self.newAccount = newAccount
        self.privateMentions = privateMentions
    }
}

class NotificationPolicyViewController: UIViewController {

    //TODO: DataSource, Source, Items
    let tableView: UITableView
    var dataSource: UITableViewDiffableDataSource<NotificationFilterSection, NotificationFilterItem>?
    let items: [NotificationFilterItem]
    let viewModel: NotificationFilterViewModel


    init() {
        //TODO: Dependency Inject Policy ViewModel
        viewModel = NotificationFilterViewModel(notFollowing: false, noFollower: false, newAccount: false, privateMentions: false)
        items = NotificationFilterItem.allCases

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(NotificationPolicyFilterTableViewCell.self, forCellReuseIdentifier: NotificationPolicyFilterTableViewCell.reuseIdentifier)

        super.init(nibName: nil, bundle: nil)

        let dataSource = UITableViewDiffableDataSource<NotificationFilterSection, NotificationFilterItem>(tableView: tableView) { [weak self] tableView, indexPath, itemIdentifier in
            guard let self, let cell = tableView.dequeueReusableCell(withIdentifier: NotificationPolicyFilterTableViewCell.reuseIdentifier, for: indexPath) as? NotificationPolicyFilterTableViewCell else {
                fatalError("No NotificationPolicyFilterTableViewCell")
            }

            //TODO: Configuration

            let item = items[indexPath.row]
            cell.configure(with: item, viewModel: self.viewModel)
            cell.delegate = self

            return cell
        }

        tableView.dataSource = dataSource
        tableView.delegate = self

        self.dataSource = dataSource
        view.addSubview(tableView)
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Common.Controls.Actions.save, style: .done, target: self, action: #selector(NotificationPolicyViewController.save(_:)))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Common.Controls.Actions.cancel, style: .done, target: self, action: #selector(NotificationPolicyViewController.cancel(_:)))

        setupConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var snapshot = NSDiffableDataSourceSnapshot<NotificationFilterSection, NotificationFilterItem>()

        snapshot.appendSections([.main])
        snapshot.appendItems(items)

        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Action

    @objc private func save(_ sender: UIBarButtonItem) {
        //TODO: Save
    }

    @objc private func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
}

extension NotificationPolicyViewController: UITableViewDelegate {

}

extension NotificationPolicyViewController: NotificationPolicyFilterTableViewCellDelegate {
    func toggleValueChanged(_ tableViewCell: NotificationPolicyFilterTableViewCell, filterItem: NotificationFilterItem, newValue: Bool) {
        //TODO: Update ViewModel
    }
}
