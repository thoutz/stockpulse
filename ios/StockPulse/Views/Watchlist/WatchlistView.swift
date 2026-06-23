import SwiftUI

struct WatchlistView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @State private var selectedTicker: String?
    @State private var scrubDisplay: MonitorScrubDisplay?

    private var isSearching: Bool {
        !vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            monitorHeader
            SearchField(text: $vm.searchQuery, isLoading: vm.searchLoading)
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.sm)
                .background(DS.Color.surface)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(DS.Color.border).frame(height: 1)
                }
                .onChange(of: vm.searchQuery) { _, _ in vm.performSearch() }

            if isSearching {
                SearchResultsList()
            } else {
                if let error = vm.monitorSyncError {
                    Text(error)
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, DS.Space.sm)
                }

                if vm.isAtFavoriteLimit {
                    favoriteLimitBanner
                }

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: DS.Space.md) {
                            monitorSection(tier: .hot, rows: vm.monitorHot)
                            monitorSection(tier: .warm, rows: vm.monitorWarm)
                            monitorSection(tier: .cold, rows: vm.monitorCold)

                            if vm.monitorHot.isEmpty && vm.monitorWarm.isEmpty && vm.monitorCold.isEmpty {
                                legacyWatchlistFallback
                            }
                        }
                        .padding(.vertical, DS.Space.sm)
                        .spScrollContentWidth()
                    }
                    .spVerticalScrollAxes()
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await vm.refresh()
                        await vm.syncMonitor(force: true)
                    }
                    .onChange(of: selectedTicker) { _, ticker in
                        guard let ticker else { return }
                        // Defer until expansion layout completes so scrollTo doesn't hide the detail panel.
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.25)) {
                                scrollProxy.scrollTo(ticker, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .spScreenBackground()
        .onAppear {
            vm.startMonitorPolling()
            if let ticker = vm.focusedTicker {
                selectedTicker = ticker
                vm.focusedTicker = nil
            }
        }
        .onDisappear { vm.stopMonitorPolling() }
        .onChange(of: vm.focusedTicker) { _, ticker in
            guard let ticker else { return }
            withAnimation(.spring(response: 0.25)) {
                selectedTicker = ticker
                scrubDisplay = nil
            }
            vm.focusedTicker = nil
        }
        .onChange(of: selectedTicker) { _, ticker in
            if ticker == nil {
                scrubDisplay = nil
            }
        }
        .onChange(of: vm.monitorChartRange) { _, _ in
            guard let ticker = selectedTicker else { return }
            Task { await vm.loadMonitorChart(symbol: ticker) }
        }
    }

    private var monitorHeader: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                Text("Monitor")
                    .font(DS.Font.sans(20, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Text(vm.dataThroughLabel)
                    .font(DS.Font.mono(11))
                    .foregroundStyle(vm.usesLiveData ? DS.Color.orange : DS.Color.textMuted)
            }

            HStack {
                Text("Favorites \(vm.favoriteCount)/\(vm.favoriteLimit)")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textMuted)
                Spacer()
                Menu {
                    Button("No sector focus") {
                        Task { await vm.setMonitorFocus(sectorId: nil) }
                    }
                    ForEach(IndustryCatalog.industries) { industry in
                        Button(industry.name) {
                            Task { await vm.setMonitorFocus(sectorId: industry.id) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                        Text(focusLabel)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(DS.Font.mono(11, weight: .semibold))
                    .foregroundStyle(DS.Color.blue)
                }
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
        .background(DS.Color.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.border).frame(height: 1)
        }
    }

    private var focusLabel: String {
        if let id = vm.monitorFocusSectorId,
           let industry = IndustryCatalog.industries.first(where: { $0.id == id }) {
            return "Focus: \(industry.name)"
        }
        return "Set focus sector"
    }

    private var favoriteLimitBanner: some View {
        Text("Favorite limit reached. Remove one to add another.")
            .font(DS.Font.mono(11))
            .foregroundStyle(DS.Color.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.sm)
            .background(DS.Color.orange.opacity(0.08))
    }

    @ViewBuilder
    private func monitorSection(tier: MonitorTier, rows: [MonitorSymbolRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: tier.icon)
                        .font(.system(size: 11))
                    Text(tier.label)
                        .font(DS.Font.mono(10, weight: .bold))
                }
                .foregroundStyle(DS.Color.textMuted)
                .padding(.horizontal, DS.Space.lg)
                .padding(.bottom, DS.Space.xs)

                ForEach(rows) { row in
                    VStack(spacing: 0) {
                        MonitorRow(
                            row: row,
                            isExpanded: selectedTicker == row.symbol,
                            scrubDisplay: selectedTicker == row.symbol ? scrubDisplay : nil,
                            rangeChange: selectedTicker == row.symbol
                                ? vm.monitorChartPeriodChange(symbol: row.symbol)
                                : nil,
                            onTap: { toggleMonitorSelection(row.symbol) }
                        )

                        if selectedTicker == row.symbol {
                            MonitorExpandedDetail(
                                row: row,
                                vm: vm,
                                scrubDisplay: $scrubDisplay,
                                onRemove: row.isFavorite ? {
                                    Task { await vm.removeFavorite(symbol: row.symbol) }
                                    toggleMonitorSelection(row.symbol)
                                } : nil
                            )
                            .padding(.horizontal, DS.Space.lg)
                            .padding(.bottom, DS.Space.md)
                            .task(id: "\(row.symbol)-\(vm.monitorChartRange.rawValue)") {
                                await vm.loadMonitorChart(symbol: row.symbol)
                            }
                        }
                    }
                    .id(row.symbol)
                    .background(selectedTicker == row.symbol ? DS.Color.blue.opacity(0.06) : DS.Color.bg)

                    Rectangle().fill(DS.Color.border).frame(height: 1)
                        .padding(.leading, DS.Space.lg)
                }
            }
            .spScrollContentWidth()
        }
    }

    private var legacyWatchlistFallback: some View {
        LazyVStack(spacing: 0) {
            ForEach(vm.watchItems) { item in
                WatchRow(
                    item: item,
                    isSelected: selectedTicker == item.ticker,
                    isFavorite: vm.isFavorite(item.ticker)
                ) {
                    withAnimation(.spring(response: 0.25)) {
                        selectedTicker = selectedTicker == item.ticker ? nil : item.ticker
                    }
                }
                Rectangle().fill(DS.Color.border).frame(height: 1)
            }
        }
        .spScrollContentWidth()
    }

    private func toggleMonitorSelection(_ symbol: String) {
        withAnimation(.spring(response: 0.25)) {
            if selectedTicker == symbol {
                vm.clearMonitorChartCache(symbol: symbol)
                selectedTicker = nil
                scrubDisplay = nil
            } else {
                if let previous = selectedTicker {
                    vm.clearMonitorChartCache(symbol: previous)
                }
                scrubDisplay = nil
                selectedTicker = symbol
            }
        }
    }
}

struct MonitorRow: View {
    let row: MonitorSymbolRow
    let isExpanded: Bool
    var scrubDisplay: MonitorScrubDisplay?
    var rangeChange: Double?
    let onTap: () -> Void

    private var headerPrice: String {
        if let scrub = scrubDisplay {
            return String(format: "$%.2f", scrub.price)
        }
        return String(format: "$%.2f", row.price)
    }

    private var headerSubLabel: String {
        if let scrub = scrubDisplay {
            return scrub.dateLabel
        }
        return "Live · \(row.tier.label)"
    }

    private var headerChange: Double? {
        if let scrub = scrubDisplay {
            return scrub.changePct
        }
        return isExpanded ? rangeChange : row.change1D
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: isExpanded ? .top : .center, spacing: DS.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if row.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(DS.Color.orange)
                        }
                        Text(row.symbol)
                            .font(DS.Font.mono(isExpanded ? 16 : 14, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                    }
                    if !row.name.isEmpty {
                        Text(row.name)
                            .font(DS.Font.sans(isExpanded ? 11 : 10))
                            .foregroundStyle(DS.Color.textMuted)
                            .lineLimit(isExpanded ? 2 : 1)
                    }
                    if isExpanded, scrubDisplay == nil {
                        Text(headerSubLabel)
                            .font(DS.Font.mono(10))
                            .foregroundStyle(DS.Color.textMuted)
                    }
                }
                .frame(minWidth: 88, alignment: .leading)

                Spacer(minLength: 4)

                if isExpanded {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(headerPrice)
                            .font(DS.Font.mono(22, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                        if let change = headerChange {
                            Text(String(format: "%+.2f%%", change))
                                .font(DS.Font.mono(14, weight: .bold))
                                .foregroundStyle(change >= 0 ? DS.Color.green : DS.Color.red)
                        }
                        if scrubDisplay != nil {
                            Text(headerSubLabel)
                                .font(DS.Font.mono(10))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(String(format: "%.2f", row.price))")
                            .font(DS.Font.mono(13, weight: .semibold))
                            .foregroundStyle(DS.Color.textPrimary)
                        Text(String(format: "%+.2f%%", row.change1D))
                            .font(DS.Font.mono(11))
                            .foregroundStyle(row.change1D >= 0 ? DS.Color.green : DS.Color.red)
                    }

                    if let change5M = row.change5M {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("5m")
                                .font(DS.Font.mono(9))
                                .foregroundStyle(DS.Color.textMuted)
                            Text(String(format: "%+.1f%%", change5M))
                                .font(DS.Font.mono(11, weight: .bold))
                                .foregroundStyle(change5M >= 0 ? DS.Color.green : DS.Color.red)
                        }
                        .frame(width: 48, alignment: .trailing)
                    }
                }

                if let lag = row.lagSeconds {
                    Text(lag < 90 ? "●" : "○")
                        .font(.system(size: 8))
                        .foregroundStyle(lag < 90 ? DS.Color.green : DS.Color.textMuted)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isExpanded ? DS.Color.blue : DS.Color.textMuted)
                    .frame(width: 16)
            }
            .padding(.vertical, isExpanded ? DS.Space.md : DS.Space.sm)
            .padding(.horizontal, DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MonitorExpandedDetail: View {
    let row: MonitorSymbolRow
    @Bindable var vm: StockPulseViewModel
    @Binding var scrubDisplay: MonitorScrubDisplay?
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            MonitorPriceChartView(
                symbol: row.symbol,
                bars: vm.monitorChartBars(symbol: row.symbol),
                livePrice: row.price,
                range: $vm.monitorChartRange,
                scrubDisplay: $scrubDisplay,
                loading: vm.monitorChartLoading,
                error: vm.monitorChartError
            )

            HStack(spacing: DS.Space.sm) {
                statBox(label: "1D", value: String(format: "%+.2f%%", row.change1D), positive: row.change1D >= 0)
                if let c5 = row.change5M {
                    statBox(label: "5M", value: String(format: "%+.1f%%", c5), positive: c5 >= 0)
                }
                statBox(label: "30D", value: String(format: "%+.1f%%", row.change30D), positive: row.change30D >= 0)
            }

            if let onRemove {
                Button(action: onRemove) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.slash")
                        Text("Remove from favorites")
                    }
                    .font(DS.Font.mono(12, weight: .bold))
                    .foregroundStyle(DS.Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.sm)
                    .background(DS.Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .spScrollContentWidth()
    }

    private func statBox(label: String, value: String, positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(text: label)
            Text(value)
                .font(DS.Font.mono(13, weight: .bold))
                .foregroundStyle(positive ? DS.Color.green : DS.Color.red)
        }
        .padding(DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

struct SearchField: View {
    @Binding var text: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(DS.Color.textMuted)
            TextField("", text: $text, prompt: Text("Search stocks (e.g. AAPL, Apple)")
                .foregroundColor(DS.Color.textMuted))
                .font(DS.Font.mono(13))
                .foregroundStyle(DS.Color.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.Color.textMuted)
            } else if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Color.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .background(DS.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

struct SearchResultsList: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let error = vm.searchError {
                    Text(error)
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.lg)
                } else if vm.searchResults.isEmpty && !vm.searchLoading {
                    Text("No matches")
                        .font(DS.Font.sans(12))
                        .foregroundStyle(DS.Color.textMuted)
                        .padding(DS.Space.lg)
                }
                ForEach(vm.searchResults) { result in
                    SearchResultRow(
                        result: result,
                        isFavorite: vm.isFavorite(result.symbol),
                        atLimit: vm.isAtFavoriteLimit
                    ) {
                        Task { await vm.addFavorite(symbol: result.symbol, name: result.name) }
                    }
                    Rectangle().fill(DS.Color.border).frame(height: 1)
                }
            }
            .spScrollContentWidth()
        }
        .spVerticalScrollAxes()
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }
}

struct SearchResultRow: View {
    let result: APITickerSearchResult
    let isFavorite: Bool
    let atLimit: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.symbol)
                    .font(DS.Font.mono(14, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                if !result.name.isEmpty {
                    Text(result.name)
                        .font(DS.Font.sans(11))
                        .foregroundStyle(DS.Color.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DS.Space.sm)
            Button(action: onAdd) {
                Image(systemName: isFavorite ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isFavorite ? DS.Color.green : (atLimit ? DS.Color.textDim : DS.Color.blue))
            }
            .buttonStyle(.plain)
            .disabled(isFavorite || atLimit)
        }
        .padding(.vertical, DS.Space.sm)
        .padding(.horizontal, DS.Space.lg)
        .background(DS.Color.bg)
    }
}

struct WatchRow: View {
    let item: WatchItem
    let isSelected: Bool
    let isFavorite: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(DS.Color.orange)
                        }
                        Text(item.ticker)
                            .font(DS.Font.mono(14, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                    }
                    if !item.rippleBadges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(item.rippleBadges, id: \.catalystTicker) { badge in
                                HStack(spacing: 3) {
                                    Image(systemName: badge.verdict.icon)
                                        .font(.system(size: 8))
                                    Text("↑\(badge.catalystTicker)")
                                        .font(DS.Font.mono(9, weight: .bold))
                                }
                                .foregroundStyle(DS.Color.verdict(badge.verdict))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(DS.Color.verdict(badge.verdict).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                }
                .frame(width: 88, alignment: .leading)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", item.currentPrice))")
                        .font(DS.Font.mono(13, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(String(format: "%+.2f%%", item.change1D))
                        .font(DS.Font.mono(11))
                        .foregroundStyle(item.change1D >= 0 ? DS.Color.green : DS.Color.red)
                }
                .frame(width: 76, alignment: .trailing)

                SparklineView(
                    points: item.normalizedHistory,
                    positive: item.change30D >= 0,
                    height: 34,
                    width: 72,
                    showArea: true,
                    tracePhaseOffset: item.ticker.hashValue
                )
                .padding(.horizontal, DS.Space.sm)

                Text(String(format: "%+.1f%%", item.change30D))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(item.change30D >= 0 ? DS.Color.green : DS.Color.red)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.vertical, DS.Space.sm)
            .padding(.horizontal, DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? DS.Color.blue.opacity(0.06) : DS.Color.bg)
        }
        .buttonStyle(.plain)
    }
}

struct WatchDetailBanner: View {
    let item: WatchItem
    let isFavorite: Bool
    let onRemove: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ticker)
                        .font(DS.Font.mono(22, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("$\(String(format: "%.2f", item.currentPrice))")
                        .font(DS.Font.mono(16))
                        .foregroundStyle(DS.Color.textSecond)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.textMuted)
                        .font(.title2)
                }
            }

            HStack(spacing: DS.Space.sm) {
                statBox(label: "1D", value: String(format: "%+.2f%%", item.change1D), positive: item.change1D >= 0)
                statBox(label: "30D", value: String(format: "%+.1f%%", item.change30D), positive: item.change30D >= 0)
            }

            SparklineView(
                points: item.normalizedHistory,
                positive: item.change30D >= 0,
                height: 80,
                width: UIScreen.main.bounds.width - 48,
                showArea: true,
                tracePhaseOffset: item.ticker.hashValue
            )

            if isFavorite {
                Button(action: onRemove) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.slash")
                        Text("Remove from favorites")
                    }
                    .font(DS.Font.mono(12, weight: .bold))
                    .foregroundStyle(DS.Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.sm)
                    .background(DS.Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Space.lg)
        .background(DS.Color.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.border).frame(height: 1)
        }
    }

    private func statBox(label: String, value: String, positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(text: label)
            Text(value)
                .font(DS.Font.mono(13, weight: .bold))
                .foregroundStyle(positive ? DS.Color.green : DS.Color.red)
        }
        .padding(DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
