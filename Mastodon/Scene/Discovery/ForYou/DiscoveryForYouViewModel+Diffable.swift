//
//  DiscoveryForYouViewModel+Diffable.swift
//  Mastodon
//
//  Created by MainasuK on 2022-4-14.
//

import UIKit
import Combine
import MastodonUI

extension DiscoveryForYouViewModel {
    
    func setupDiffableDataSource(
        tableView: UITableView,
        profileCardTableViewCellDelegate: ProfileCardTableViewCellDelegate
    ) {
        diffableDataSource = DiscoverySection.diffableDataSource(
            tableView: tableView,
            configuration: DiscoverySection.Configuration(
                authenticationBox: authenticationBox,
                profileCardTableViewCellDelegate: profileCardTableViewCellDelegate,
                familiarFollowers: $familiarFollowers
            )
        )
        
        Task {
            try await fetch()
        }
    }
}
