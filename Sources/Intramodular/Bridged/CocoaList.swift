//
// Copyright (c) Vatsal Manot
//

import Swift
import SwiftUI

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

public struct CocoaList<SectionModel: Identifiable, Item: Identifiable, Data: RandomAccessCollection, SectionHeader: View, SectionFooter: View, RowContent: View>: UIViewControllerRepresentable where Data.Element == ListSection<SectionModel, Item> {
    public typealias Offset = ScrollView<AnyView>.Offset
    public typealias UIViewControllerType = UIHostingTableViewController<SectionModel, Item, Data, SectionHeader, SectionFooter, RowContent>
    
    private let data: Data
    private let sectionHeader: (SectionModel) -> SectionHeader
    private let sectionFooter: (SectionModel) -> SectionFooter
    private let rowContent: (Item) -> RowContent
    
    private var style: UITableView.Style = .plain
    private var separatorStyle: UITableViewCell.SeparatorStyle = .singleLine
    private var scrollViewConfiguration = CocoaScrollViewConfiguration<AnyView>()
    
    @Environment(\.initialContentAlignment) var initialContentAlignment
    @Environment(\.isScrollEnabled) var isScrollEnabled
    
    public init(
        _ data: Data,
        sectionHeader: @escaping (SectionModel) -> SectionHeader,
        sectionFooter: @escaping (SectionModel) -> SectionFooter,
        rowContent: @escaping (Item) -> RowContent
    ) {
        self.data = data
        self.sectionHeader = sectionHeader
        self.sectionFooter = sectionFooter
        self.rowContent = rowContent
    }
    
    public func makeUIViewController(context: Context) -> UIViewControllerType {
        .init(
            data,
            style: style,
            sectionHeader: sectionHeader,
            sectionFooter: sectionFooter,
            rowContent: rowContent
        )
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        let oldContentSize = uiViewController.tableView.contentSize
        let isDirty = uiViewController.data.isIdentical(to: data)
        
        uiViewController.data = data
        uiViewController.sectionHeader = sectionHeader
        uiViewController.sectionFooter = sectionFooter
        uiViewController.rowContent = rowContent
        uiViewController.scrollViewConfiguration = scrollViewConfiguration
        
        uiViewController.tableView.isScrollEnabled = isScrollEnabled
        uiViewController.tableView.separatorStyle = separatorStyle
        
        uiViewController.tableView.reloadData()
        
        if isDirty {
            if !uiViewController.isInitialContentAlignmentSet {
                uiViewController.tableView.invalidateIntrinsicContentSize()
                uiViewController.tableView.setNeedsLayout()
                uiViewController.tableView.layoutIfNeeded()
                
                if uiViewController.tableView.contentSize.minimumDimensionLength != .zero && uiViewController.tableView.frame.minimumDimensionLength != .zero  {
                    uiViewController.tableView.setContentAlignment(initialContentAlignment, animated: false)
                    
                    uiViewController.isInitialContentAlignmentSet = true
                }
            } else if oldContentSize.minimumDimensionLength != 0 {
                guard initialContentAlignment.horizontal == .trailing || initialContentAlignment.vertical == .bottom else {
                    return
                }
                
                uiViewController.tableView.invalidateIntrinsicContentSize()
                uiViewController.tableView.setNeedsLayout()
                uiViewController.tableView.layoutIfNeeded()
                
                let contentSize = uiViewController.tableView.contentSize
                
                if contentSize != oldContentSize {
                    var newContentOffset = uiViewController.tableView.contentOffset
                    
                    if initialContentAlignment.horizontal == .trailing {
                        newContentOffset.x += contentSize.width - oldContentSize.width
                    }
                    
                    if initialContentAlignment.vertical == .bottom {
                        newContentOffset.y += contentSize.height - oldContentSize.height
                    }
                    
                    if newContentOffset != uiViewController.tableView.contentOffset {
                        uiViewController.tableView.setContentOffset(newContentOffset, animated: false)
                    }
                }
            }
        }
    }
}

extension CocoaList {
    public init<_Item: Hashable>(
        _ data: Data,
        sectionHeader: @escaping (SectionModel) -> SectionHeader,
        sectionFooter: @escaping (SectionModel) -> SectionFooter,
        rowContent: @escaping (_Item) -> RowContent
    ) where Item == HashIdentifiableValue<_Item> {
        self.data = data
        self.sectionHeader = sectionHeader
        self.sectionFooter = sectionFooter
        self.rowContent = { rowContent($0.value) }
    }
    
    public init<_SectionModel: Hashable, _Item: Hashable>(
        _ data: Data,
        sectionHeader: @escaping (_SectionModel) -> SectionHeader,
        sectionFooter: @escaping (_SectionModel) -> SectionFooter,
        rowContent: @escaping (_Item) -> RowContent
    ) where SectionModel == HashIdentifiableValue<_SectionModel>, Item == HashIdentifiableValue<_Item> {
        self.data = data
        self.sectionHeader = { sectionHeader($0.value) }
        self.sectionFooter = { sectionFooter($0.value) }
        self.rowContent = { rowContent($0.value) }
    }
    
    public init<_SectionModel: Hashable, _Item: Hashable>(
        _ data: [ListSection<_SectionModel, _Item>],
        sectionHeader: @escaping (_SectionModel) -> SectionHeader,
        sectionFooter: @escaping (_SectionModel) -> SectionFooter,
        rowContent: @escaping (_Item) -> RowContent
    ) where Data == Array<ListSection<SectionModel, Item>>, SectionModel == HashIdentifiableValue<_SectionModel>, Item == HashIdentifiableValue<_Item> {
        self.data = data.map({ .init(model: .init($0.model), items: $0.items.map(HashIdentifiableValue.init)) })
        self.sectionHeader = { sectionHeader($0.value) }
        self.sectionFooter = { sectionFooter($0.value) }
        self.rowContent = { rowContent($0.value) }
    }
}

extension CocoaList where Data: RangeReplaceableCollection, SectionModel == Never, SectionHeader == Never, SectionFooter == Never {
    public init<Items: RandomAccessCollection>(
        _ items: Items,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) where Items.Element == Item {
        var data = Data.init()
        
        data.append(.init(items: items))
        
        self.init(
            data,
            sectionHeader: Never.produce,
            sectionFooter: Never.produce,
            rowContent: rowContent
        )
    }
}

extension CocoaList where Data == Array<ListSection<SectionModel, Item>>, SectionModel == Never, SectionHeader == Never, SectionFooter == Never {
    public init<Items: RandomAccessCollection>(
        _ items: Items,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) where Items.Element == Item {
        self.init(
            [.init(items: items)],
            sectionHeader: Never.produce,
            sectionFooter: Never.produce,
            rowContent: rowContent
        )
    }
}

// MARK: - API -

extension CocoaList {
    public func listStyle(_ style: UITableView.Style) -> Self {
        then({ $0.style = style })
    }
    
    public func listSeparatorStyle(_ separatorStyle: UITableViewCell.SeparatorStyle) -> Self {
        then({ $0.separatorStyle = separatorStyle })
    }
}

extension CocoaList {
    public func onOffsetChange(_ body: @escaping (Offset) -> ()) -> Self {
        then({ $0.scrollViewConfiguration.onOffsetChange = body })
    }
}

@available(tvOS, unavailable)
extension CocoaList {
    public func onRefresh(_ body: @escaping () -> Void) -> Self {
        then({ $0.scrollViewConfiguration.onRefresh = body })
    }
    
    public func isRefreshing(_ isRefreshing: Bool) -> Self {
        then({ $0.scrollViewConfiguration.isRefreshing = isRefreshing })
    }
}

#endif
