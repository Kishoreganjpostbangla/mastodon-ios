//
//  MastodonPickServerViewController+Diffable.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021/3/5.
//

import UIKit
import Combine
import MastodonSDK

extension MastodonPickServerViewModel {
    
    func setupDiffableDataSource(
        for tableView: UITableView,
        dependency: UIViewController,
        pickServerServerSectionTableHeaderViewDelegate: PickServerServerSectionTableHeaderViewDelegate
    ) {
        // set section header
        serverSectionHeaderView.diffableDataSource = CategoryPickerSection.collectionViewDiffableDataSource(
            for: serverSectionHeaderView.collectionView,
            dependency: dependency,
            viewModel: self
        )
        var sectionHeaderSnapshot = NSDiffableDataSourceSnapshot<CategoryPickerSection, CategoryPickerItem>()
        sectionHeaderSnapshot.appendSections([.main])
        sectionHeaderSnapshot.appendItems(categoryPickerItems, toSection: .main)
        serverSectionHeaderView.delegate = pickServerServerSectionTableHeaderViewDelegate
        serverSectionHeaderView.diffableDataSource?.apply(sectionHeaderSnapshot, animatingDifferences: false) { [weak self] in
            guard let self = self else { return }
            guard let indexPath = self.serverSectionHeaderView.diffableDataSource?.indexPath(for: .category(category: .init(category: Mastodon.Entity.Category.Kind.general.rawValue, serversCount: 0))) else { return }

            self.serverSectionHeaderView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .right)

            let firstIndex = IndexPath(item: 0, section: 0)
            self.serverSectionHeaderView.collectionView.scrollToItem(at: firstIndex, at: .left, animated: false)
        }
        
        // set tableView
        diffableDataSource = PickServerSection.tableViewDiffableDataSource(
            for: tableView,
            dependency: dependency
        )
        
        var snapshot = NSDiffableDataSourceSnapshot<PickServerSection, PickServerItem>()
        snapshot.appendSections([.header, .servers])
        diffableDataSource?.apply(snapshot, animatingDifferences: false, completion: nil)
        
        loadIndexedServerStateMachine.enter(LoadIndexedServerState.Loading.self)
        
        Publishers.CombineLatest(
            filteredIndexedServers,
            unindexedServers
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] indexedServers, unindexedServers in
            guard let self = self else { return }
            guard let diffableDataSource = self.diffableDataSource else { return }
            
            let oldSnapshot = diffableDataSource.snapshot()
            var oldSnapshotServerItemAttributeDict: [String : PickServerItem.ServerItemAttribute] = [:]
            for item in oldSnapshot.itemIdentifiers {
                guard case let .server(server, attribute) = item else { continue }
                oldSnapshotServerItemAttributeDict[server.domain] = attribute
            }
            
            var snapshot = NSDiffableDataSourceSnapshot<PickServerSection, PickServerItem>()
            snapshot.appendSections([.header, .servers])

            // TODO: handle filter
            var serverItems: [PickServerItem] = []
            for server in indexedServers {
                let attribute = oldSnapshotServerItemAttributeDict[server.domain] ?? PickServerItem.ServerItemAttribute(isLast: false, isExpand: false)
                attribute.isLast.value = false
                let item = PickServerItem.server(server: server, attribute: attribute)
                guard !serverItems.contains(item) else { continue }
                serverItems.append(item)
            }
            
            if let unindexedServers = unindexedServers {
                if !unindexedServers.isEmpty {
                    for server in unindexedServers {
                        let attribute = oldSnapshotServerItemAttributeDict[server.domain] ?? PickServerItem.ServerItemAttribute(isLast: false, isExpand: false)
                        attribute.isLast.value = false
                        let item = PickServerItem.server(server: server, attribute: attribute)
                        guard !serverItems.contains(item) else { continue }
                        serverItems.append(item)
                    }
                } else {
                    if indexedServers.isEmpty && !self.isLoadingIndexedServers.value {
                        serverItems.append(.loader(attribute: PickServerItem.LoaderItemAttribute(isLast: false, isEmptyResult: true)))
                    }
                }
            } else {
                serverItems.append(.loader(attribute: PickServerItem.LoaderItemAttribute(isLast: false, isEmptyResult: false)))
            }
            
            if case let .server(_, attribute) = serverItems.last {
                attribute.isLast.value = true
            }
            if case let .loader(attribute) = serverItems.last {
                attribute.isLast = true
            }
            snapshot.appendItems(serverItems, toSection: .servers)
            
            diffableDataSource.defaultRowAnimation = .fade
            diffableDataSource.apply(snapshot, animatingDifferences: true, completion: nil)
        })
        .store(in: &disposeBag)
    }
    
}


