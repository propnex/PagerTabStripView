//
//  ScrollableNavBarView.swift
//  PagerTabStripView
//
//  Created by Cecilia Pirotto on 23/8/21.
//

import Foundation
import SwiftUI

internal struct ScrollableNavBarView: View {
    @Binding private var selection: Int
    @State private var switchAppeared: Bool = false

    @EnvironmentObject private var dataStore: DataStore

    public init(selection: Binding<Int>) {
        self._selection = selection
    }
    
    var body: some View {
        ScrollViewReader { value in
            VStack(spacing: -(style.indicatorBarHeight / 2)) {
                
                // Horizontal ScrollView containing the Navigation Items and the Indicator
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack {
                        
                        // List of Navigation Items
                        HStack(spacing: style.tabItemSpacing) {
                            if dataStore.itemsCount > 0 {
                                ForEach(0..<dataStore.itemsCount, id: \.self) { idx in
                                    NavBarItem(id: idx, selection: $selection)
                                }
                            }
                        }
                        
                        // Indicator Bar View
                        IndicatorScrollableBarView(selection: $selection)
                            .frame(height: style.indicatorBarHeight)
                        
                    }
                }
                .padding(self.style.padding)
                
                // Handler to reposition scroll when `switchAppeared` changes
                .onChange(of: switchAppeared) { _ in
                    // This is necessary because anchor: .center is not working correctly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        adjustScrollPosition(value)
                    }
                }
                
                // Handler to reposition scroll when `selection` changes
                .onChange(of: self.selection) { newSelection in
                    withAnimation {
                        value.scrollTo(newSelection, anchor: .center)
                    }
                }
                
                // Optional Bottom Divider based on style configuration
                if style.showBottomDivider {
                    Divider()
                }
                
            }
            .frame(height: self.style.tabItemHeight)
        }
        .onAppear {
            switchAppeared.toggle()
        }
    }

    // Helper function to adjust the scroll position based on the item selected and its position
    private func adjustScrollPosition(_ value: ScrollViewProxy) {
        var remainingItemsWidth = (dataStore.items[selection]?.itemWidth ?? 0) / 2
        let itemsAfterSelection = dataStore.items.filter { index, _ in
            index > selection
        }
        remainingItemsWidth += itemsAfterSelection.map { $0.value.itemWidth ?? 0 }.reduce(0, +)
        remainingItemsWidth += CGFloat(dataStore.items.count - 1 - selection) * style.tabItemSpacing
        let shouldCenterSelectedItem = remainingItemsWidth > settings.width / 2
        if shouldCenterSelectedItem {
            value.scrollTo(selection, anchor: .center)
        } else {
            value.scrollTo(dataStore.items.count - 1)
        }
    }


    @Environment(\.pagerStyle) var style: PagerStyle
    @EnvironmentObject private var settings: PagerSettings
}

internal struct IndicatorScrollableBarView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Binding private var selection: Int
    @State private var position: Double = 0
    @State private var selectedItemWidth: Double = 0
    @State private var appeared: Bool = false

    public init(selection: Binding<Int>) {
        self._selection = selection
    }

    var body: some View {
        Rectangle()
            .fill(style.indicatorBarColor)
            .animation(.default, value: appeared)
            .frame(width: selectedItemWidth, height: style.indicatorBarHeight)
            .position(x: position)
            .onAppear {
                appeared = true
            }
            .onChange(of: dataStore.widthUpdated) { updated in
                if updated {
                    let items = dataStore.items.filter { index, _ in
                        index < selection
                    }
                    selectedItemWidth = dataStore.items[selection]?.itemWidth ?? 0
                    var newPosition = items.map({return $0.value.itemWidth ?? 0}).reduce(0, +)
                    newPosition += (style.tabItemSpacing * CGFloat(selection)) + selectedItemWidth/2
                    position = newPosition
                }
            }
            .onChange(of: settings.contentOffset) { newValue in
                let offset = newValue + (settings.width * CGFloat(selection))
                let percentage = offset / settings.width
                let items = dataStore.items.filter { index, _ in
                    index < selection
                }

                let spaces = style.tabItemSpacing * CGFloat(selection-1)
                let actualWidth = dataStore.items[selection]?.itemWidth ?? 0
                var lastPosition = items.map({return $0.value.itemWidth ?? 0}).reduce(0, +)
                lastPosition += spaces + actualWidth/2
                var nextPosition = items.map({return $0.value.itemWidth ?? 0}).reduce(0, +)
                if percentage == 0 {
                    selectedItemWidth = dataStore.items[selection]?.itemWidth ?? 0
                    var newPosition = items.map({return $0.value.itemWidth ?? 0}).reduce(0, +)
                    newPosition += style.tabItemSpacing * CGFloat(selection) + selectedItemWidth/2
                    position = newPosition
                } else {
                    if percentage < 0 {
                        nextPosition += actualWidth + style.tabItemSpacing * CGFloat(selection+1)
                        nextPosition += ((dataStore.items[selection + 1])?.itemWidth ?? 0)/2
                    } else {
                        nextPosition += style.tabItemSpacing * CGFloat(selection-1)
                        nextPosition -= ((dataStore.items[selection - 1])?.itemWidth ?? 0)/2
                    }
                    position = lastPosition + (nextPosition - lastPosition)*abs(percentage)

                    if let selectedWidth = dataStore.items[selection]?.itemWidth,
                        let nextWidth = percentage > 0 ? dataStore.items[selection-1]?.itemWidth : dataStore.items[selection+1]?.itemWidth,
                        abs(percentage)>0 {
                        selectedItemWidth = selectedWidth - (selectedWidth-nextWidth)*abs(percentage)
                    }
                }

            }
            .onChange(of: selection) { newValue in
                let items = dataStore.items.filter { index, _ in
                    index < newValue
                }
                selectedItemWidth = dataStore.items[newValue]?.itemWidth ?? 0
                var newPosition = items.map({return $0.value.itemWidth ?? 0}).reduce(0, +)
                newPosition += (style.tabItemSpacing * CGFloat(newValue)) + selectedItemWidth/2
                position = newPosition
            }
        }

    @Environment(\.pagerStyle) var style: PagerStyle
    @EnvironmentObject private var settings: PagerSettings
}
