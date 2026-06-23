import SwiftUI

struct TradeDashboardView: View {
    @Environment(StockPulseViewModel.self) private var vm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                connectionBanner
                autoTradeRunSection
                microTradeSection
                if let err = vm.tradeError {
                    Text(err)
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.red)
                        .padding(.horizontal, DS.Space.lg)
                }
                if let acct = vm.tradingAccount {
                    accountCards(acct)
                    if paperZeroBalanceBanner(acct: acct) {
                        paperZeroBanner
                    }
                }
                positionsSection
                proposalsSection
                activitySection
                historySection
                Spacer(minLength: DS.Space.xxl)
            }
            .padding(.top, DS.Space.lg)
            .spScrollContentWidth()
        }
        .spVerticalScrollAxes()
        .scrollContentBackground(.hidden)
        .spScreenBackground()
        .refreshable {
            await vm.refreshTradeTab()
        }
        .task {
            await vm.refreshTradeTab()
        }
        .onAppear {
            vm.startTradePolling()
        }
        .onDisappear {
            vm.stopTradePolling()
        }
    }

    private var header: some View {
        HStack {
            Text("Trade")
                .font(DS.Font.sans(20, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            if vm.tradeLoading {
                ProgressView().controlSize(.small).tint(DS.Color.blue)
            } else {
                Button("Refresh") {
                    Task { await vm.refreshTradeTab() }
                }
                .font(DS.Font.mono(10, weight: .bold))
                .foregroundStyle(DS.Color.blue)
            }
        }
        .padding(.horizontal, DS.Space.lg)
    }

    @ViewBuilder
    private var connectionBanner: some View {
        let status = vm.tradingStatus
        if let status {
            let isLive = status.accountMode == "live" || (status.connected && !status.paper)
            HStack(spacing: DS.Space.sm) {
                Circle()
                    .fill(status.connected ? (isLive ? DS.Color.green : DS.Color.orange) : DS.Color.orange)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionTitle(status: status, isLive: isLive))
                        .font(DS.Font.mono(11, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(connectionSubtitle(status: status, isLive: isLive))
                        .font(DS.Font.mono(9))
                        .foregroundStyle(isLive ? DS.Color.green : DS.Color.textDim)
                    if let msg = status.message, !msg.isEmpty, !status.connected || status.needsPaperFunding == true {
                        Text(msg)
                            .font(DS.Font.mono(9))
                            .foregroundStyle(status.needsPaperFunding == true ? DS.Color.orange : DS.Color.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if status.connected {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(status.tradingEnabled ? "TRADING ON" : "VIEW ONLY")
                            .font(DS.Font.mono(9, weight: .bold))
                            .foregroundStyle(status.tradingEnabled ? DS.Color.green : DS.Color.textDim)
                        if status.autoTradeEnabled == true {
                            Text("AUTO TRADE")
                                .font(DS.Font.mono(8, weight: .bold))
                                .foregroundStyle(DS.Color.orange)
                        }
                        if status.fractionalTrading == true, let min = status.minFractionalNotional {
                            Text("Fractional · min $\(String(format: "%.0f", min))")
                                .font(DS.Font.mono(8))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                }
            }
            .padding(DS.Space.md)
            .background(isLive ? DS.Color.green.opacity(0.06) : DS.Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isLive ? DS.Color.green.opacity(0.3) : DS.Color.border, lineWidth: 1)
            )
            .padding(.horizontal, DS.Space.lg)
        } else if !vm.tradeLoading {
            setupBanner
        }
    }

    @ViewBuilder
    private var autoTradeRunSection: some View {
        if vm.tradingStatus?.autoTradeEnabled == true {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack {
                    Text("AUTO-TRADE STATUS")
                        .font(DS.Font.mono(9, weight: .bold))
                        .foregroundStyle(DS.Color.textDim)
                    Spacer()
                    if let schedule = vm.tradingStatus?.autoTradeScheduleEt, !schedule.isEmpty {
                        Text("Runs \(schedule.joined(separator: " · ")) ET")
                            .font(DS.Font.mono(8))
                            .foregroundStyle(DS.Color.textMuted)
                    }
                }

                if let run = vm.tradingStatus?.lastAutoTradeRun {
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        Circle()
                            .fill(autoTradeStatusColor(run))
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(autoTradeStatusTitle(run))
                                .font(DS.Font.mono(11, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(autoTradeStatusDetail(run))
                                .font(DS.Font.mono(9))
                                .foregroundStyle(DS.Color.textSecond)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Last run · \(DateFormatting.aiStamp(run.at))")
                                .font(DS.Font.mono(8))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                } else {
                    Text("No auto-trade run recorded yet — first cycle after market open at 10:15 ET")
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let next = vm.tradingStatus?.nextAutoTradeRunAt {
                    Text("Next scheduled · \(DateFormatting.aiStamp(next))")
                        .font(DS.Font.mono(8))
                        .foregroundStyle(DS.Color.orange)
                }
            }
            .padding(DS.Space.md)
            .background(DS.Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Color.border, lineWidth: 1)
            )
            .padding(.horizontal, DS.Space.lg)
        }
    }

    private func autoTradeStatusColor(_ run: APIAutoTradeLastRun) -> Color {
        switch run.status {
        case "ok":
            return (run.executed ?? 0) > 0 ? DS.Color.green : DS.Color.orange
        case "failed":
            return DS.Color.red
        default:
            return DS.Color.orange
        }
    }

    private func autoTradeStatusTitle(_ run: APIAutoTradeLastRun) -> String {
        switch run.status {
        case "ok":
            let n = run.executed ?? 0
            return n > 0 ? "Submitted \(n) paper order\(n == 1 ? "" : "s")" : "Ran — no orders submitted"
        case "failed":
            return "Auto-trade failed"
        case "skipped":
            return "Skipped — \(autoTradeSkipLabel(run.reason))"
        default:
            return run.status.capitalized
        }
    }

    private func autoTradeStatusDetail(_ run: APIAutoTradeLastRun) -> String {
        if run.status == "ok", (run.executed ?? 0) > 0 {
            return "Check Positions and Cash flow below for fills."
        }
        if let skipped = run.skippedSymbols, !skipped.isEmpty {
            return "Cooldown symbols: \(skipped.joined(separator: ", "))"
        }
        if run.status == "failed", let reason = run.reason, !reason.isEmpty {
            return reason
        }
        return autoTradeSkipDetail(run.reason)
    }

    private func autoTradeSkipLabel(_ reason: String?) -> String {
        switch reason {
        case "market_closed": return "market closed"
        case "not_trading_day": return "weekend / holiday"
        case "no_approved_proposals": return "no new WATCH signals"
        case "no_orders_submitted": return "proposals rejected or failed"
        case "auto_trade_disabled": return "auto-trade off"
        default:
            if let reason, reason.hasPrefix("insufficient_buying_power") {
                return "low buying power"
            }
            return reason ?? "unknown"
        }
    }

    private func autoTradeSkipDetail(_ reason: String?) -> String {
        switch reason {
        case "market_closed":
            return "Runs only during market hours (9:30 AM–4:05 PM ET)."
        case "no_approved_proposals":
            return "Pulse WATCH list empty or all symbols on cooldown."
        case "no_orders_submitted":
            return "Candidates failed risk checks or Alpaca rejected the order."
        default:
            return "Pull to refresh after the next scheduled run."
        }
    }

    @ViewBuilder
    private var microTradeSection: some View {
        if vm.tradingStatus?.microTradeEnabled == true {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack {
                    Text("MICRO DAY-TRADE")
                        .font(DS.Font.mono(9, weight: .bold))
                        .foregroundStyle(DS.Color.textDim)
                    Spacer()
                    if let mins = vm.tradingStatus?.microScanIntervalMinutes {
                        Text("Every \(mins)m · TP +\(formatPct(vm.tradingStatus?.microTakeProfitPct)) · SL -\(formatPct(vm.tradingStatus?.microStopLossPct))")
                            .font(DS.Font.mono(8))
                            .foregroundStyle(DS.Color.textMuted)
                    }
                }
                if let notional = vm.tradingStatus?.microTradeNotional {
                    Text("$\(String(format: "%.0f", notional)) per entry · daily cap +$\(String(format: "%.0f", vm.tradingStatus?.microDailyProfitCapUsd ?? 0))")
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textSecond)
                }
                if let run = vm.tradingStatus?.lastMicroTradeRun {
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        Circle()
                            .fill(microStatusColor(run))
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(microStatusTitle(run))
                                .font(DS.Font.mono(11, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(microStatusDetail(run))
                                .font(DS.Font.mono(9))
                                .foregroundStyle(DS.Color.textSecond)
                            Text("Last scan · \(DateFormatting.aiStamp(run.at))")
                                .font(DS.Font.mono(8))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                } else {
                    Text("Scans all Monitor symbols for momentum, WATCH, and movers — auto TP/SL/flip")
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.Space.md)
            .background(DS.Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Color.blue.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, DS.Space.lg)
        }
    }

    private func formatPct(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f%%", value)
    }

    private func microStatusColor(_ run: APIMicroTradeLastRun) -> Color {
        switch run.status {
        case "ok":
            return ((run.entries ?? 0) + (run.exits ?? 0)) > 0 ? DS.Color.green : DS.Color.orange
        case "failed":
            return DS.Color.red
        default:
            return DS.Color.orange
        }
    }

    private func microStatusTitle(_ run: APIMicroTradeLastRun) -> String {
        switch run.status {
        case "ok":
            let e = run.entries ?? 0
            let x = run.exits ?? 0
            if e == 0 && x == 0 { return "Scan complete — no action" }
            var parts: [String] = []
            if e > 0 { parts.append("\(e) buy\(e == 1 ? "" : "s")") }
            if x > 0 { parts.append("\(x) sell\(x == 1 ? "" : "s")") }
            return parts.joined(separator: ", ")
        case "failed":
            return "Micro scan failed"
        case "skipped":
            return "Skipped — \(microSkipLabel(run.reason))"
        default:
            return run.status.capitalized
        }
    }

    private func microStatusDetail(_ run: APIMicroTradeLastRun) -> String {
        if run.status == "ok", ((run.entries ?? 0) + (run.exits ?? 0)) > 0 {
            return "Positions update in Cash flow below."
        }
        if let skipped = run.skippedSymbols, !skipped.isEmpty {
            return "Cooldown: \(skipped.joined(separator: ", "))"
        }
        switch run.reason {
        case "no_micro_signals":
            return "No Monitor symbols met entry rules this scan."
        case "daily_profit_cap_hit":
            return "Daily profit target hit — no new entries until tomorrow."
        default:
            return run.reason ?? "Next scan in a few minutes."
        }
    }

    private func microSkipLabel(_ reason: String?) -> String {
        switch reason {
        case "market_closed": return "market closed"
        case "micro_or_auto_disabled": return "micro/auto off"
        case "no_micro_signals": return "no momentum setups"
        case "daily_profit_cap_hit": return "daily cap reached"
        default: return reason ?? "unknown"
        }
    }

    private var setupBanner: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Trading setup")
                .font(DS.Font.mono(11, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Text("Add Alpaca Paper API keys on the server (ALPACA_PAPER=true), set TRADING_ENABLED=true, and reset paper balance at alpaca.markets if cash shows $0.")
                .font(DS.Font.mono(9))
                .foregroundStyle(DS.Color.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Space.lg)
    }

    private var paperZeroBanner: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("Paper account has $0 — not an app bug")
                .font(DS.Font.mono(11, weight: .bold))
                .foregroundStyle(DS.Color.orange)
            if let acctNum = vm.tradingAccount?.accountNumber ?? vm.tradingStatus?.accountNumber {
                Text("Linked Alpaca paper account: \(acctNum)")
                    .font(DS.Font.mono(9))
                    .foregroundStyle(DS.Color.textDim)
            }
            Text("Alpaca cannot add cash via API. To get ~$100,000 simulated money:")
                .font(DS.Font.mono(9))
                .foregroundStyle(DS.Color.textDim)
            Group {
                Text("1. app.alpaca.markets → Paper Trading")
                Text("2. Account menu (top left) → Open New Paper Account")
                Text("3. Choose $100,000 starting balance")
                Text("4. API Keys → generate new Paper keys")
                Text("5. Update server .env, run: scripts/push_alpaca_env_to_vps.sh")
            }
            .font(DS.Font.mono(9))
            .foregroundStyle(DS.Color.textSecond)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.orange.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, DS.Space.lg)
    }

    private func paperZeroBalanceBanner(acct: APITradingAccount) -> Bool {
        guard let status = vm.tradingStatus, status.connected, status.paper else { return false }
        if acct.needsPaperFunding == true || status.needsPaperFunding == true { return true }
        return acct.cash == 0 && acct.equity == 0
    }

    private func connectionTitle(status: APITradingStatus, isLive: Bool) -> String {
        guard status.connected else { return "Alpaca not connected" }
        return isLive ? "Alpaca Live · real money" : "Alpaca Paper · simulated"
    }

    private func connectionSubtitle(status: APITradingStatus, isLive: Bool) -> String {
        if status.connected {
            return isLive
                ? "Orders use your funded brokerage account"
                : "Simulated cash — reset paper balance at alpaca.markets if $0"
        }
        return "Configure Alpaca Paper API keys on api.tryan.app"
    }

    private func accountCards(_ acct: APITradingAccount) -> some View {
        VStack(spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                metricCard(title: "Portfolio", value: formatMoney(acct.equity))
                metricCard(
                    title: "Today",
                    value: formatSigned(acct.dayPl),
                    valueColor: acct.dayPl >= 0 ? DS.Color.green : DS.Color.red
                )
            }
            HStack(spacing: DS.Space.sm) {
                metricCard(title: "Cash", value: formatMoney(acct.cash))
                metricCard(title: "Buying power", value: formatMoney(acct.buyingPower))
            }
        }
        .padding(.horizontal, DS.Space.lg)
    }

    private func metricCard(title: String, value: String, valueColor: Color = DS.Color.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(DS.Font.mono(9))
                .foregroundStyle(DS.Color.textDim)
            Text(value)
                .font(DS.Font.mono(16, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Positions")
                .padding(.horizontal, DS.Space.lg)

            if vm.tradePositions.isEmpty {
                Text("No open positions")
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.textDim)
                    .padding(.horizontal, DS.Space.lg)
            } else {
                ForEach(vm.tradePositions) { pos in
                    positionRow(pos)
                }
            }
        }
    }

    private func positionRow(_ pos: APITradePosition) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                Text(pos.symbol)
                    .font(DS.Font.mono(14, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                if pos.isAuto == true {
                    Text("AUTO")
                        .font(DS.Font.mono(8, weight: .bold))
                        .foregroundStyle(DS.Color.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(formatSigned(pos.unrealizedPl))
                    .font(DS.Font.mono(12, weight: .bold))
                    .foregroundStyle(pos.unrealizedPl >= 0 ? DS.Color.green : DS.Color.red)
            }
            HStack {
                Text("\(formatQty(pos.qty)) @ \(formatMoney(pos.avgEntryPrice))")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textSecond)
                Spacer()
                Text(formatMoney(pos.marketValue))
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textDim)
            }
            if vm.canExecuteTrades {
                Button("Close position") {
                    Task { await vm.closeTradePosition(pos.symbol) }
                }
                .font(DS.Font.mono(10, weight: .bold))
                .foregroundStyle(DS.Color.red)
            }
        }
        .padding(DS.Space.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Space.lg)
    }

    @ViewBuilder
    private var proposalsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                SectionLabel(text: "Proposals")
                Spacer()
                if vm.canExecuteTrades {
                    if vm.tradingStatus?.autoTradeEnabled == true {
                        Text("Auto-trade is on — runs after each pulse (10:00, 1:00, 4:00 ET) with backup at 10:15, 1:15, 4:05")
                            .font(DS.Font.mono(9))
                            .foregroundStyle(DS.Color.orange)
                    } else {
                        Button("Scan WATCH") {
                            Task { await vm.scanTradeProposals() }
                        }
                        .font(DS.Font.mono(10, weight: .bold))
                        .foregroundStyle(DS.Color.blue)
                        .disabled(vm.tradeActionLoading)
                    }
                }
            }
            .padding(.horizontal, DS.Space.lg)

            let pending = vm.tradeDecisions.filter { $0.status == "proposed" }
            if pending.isEmpty {
                if vm.tradingStatus?.autoTradeEnabled == true {
                    Text("Auto-trade scans WATCH signals after each pulse — check back after market open, midday, or close sessions")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.textDim)
                        .padding(.horizontal, DS.Space.lg)
                } else {
                    Text("No pending proposals — tap Scan WATCH after pulse reports")
                        .font(DS.Font.mono(10))
                        .foregroundStyle(DS.Color.textDim)
                        .padding(.horizontal, DS.Space.lg)
                }
            } else {
                ForEach(pending) { decision in
                    proposalCard(decision)
                }
            }
        }
    }

    private func proposalCard(_ d: APITradeDecision) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                Text("\(d.action) \(d.symbol)")
                    .font(DS.Font.mono(12, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Text("\(Int(d.confidence * 100))%")
                    .font(DS.Font.mono(10, weight: .bold))
                    .foregroundStyle(DS.Color.blue)
            }
            Text("Fractional buy · $\(String(format: "%.2f", d.notionalUsd))")
                .font(DS.Font.mono(10, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Text(d.rationale)
                .font(DS.Font.mono(10))
                .foregroundStyle(DS.Color.textSecond)
                .fixedSize(horizontal: false, vertical: true)
            if vm.canExecuteTrades {
                Button("Execute") {
                    Task { await vm.executeTradeProposal(d.id) }
                }
                .font(DS.Font.mono(11, weight: .bold))
                .foregroundStyle(DS.Color.green)
                .disabled(vm.tradeActionLoading)
            }
        }
        .spScrollContentWidth()
        .padding(DS.Space.md)
        .background(DS.Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Color.green.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, DS.Space.lg)
    }

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionLabel(text: "Cash flow")
                .padding(.horizontal, DS.Space.lg)

            if vm.tradeActivities.isEmpty {
                Text("Deposits and fills appear here after Alpaca activity")
                    .font(DS.Font.mono(10))
                    .foregroundStyle(DS.Color.textDim)
                    .padding(.horizontal, DS.Space.lg)
            } else {
                ForEach(vm.tradeActivities.prefix(15)) { act in
                    activityRow(act)
                }
            }
        }
    }

    private func activityRow(_ act: APITradeActivity) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(activityLabel(act))
                    .font(DS.Font.mono(11, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                if let sym = act.symbol {
                    Text(sym)
                        .font(DS.Font.mono(9))
                        .foregroundStyle(DS.Color.textDim)
                }
            }
            Spacer()
            if let amt = act.netAmount {
                Text(formatSigned(amt))
                    .font(DS.Font.mono(11, weight: .bold))
                    .foregroundStyle(amt >= 0 ? DS.Color.green : DS.Color.red)
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.xs)
    }

    @ViewBuilder
    private var historySection: some View {
        let history = vm.tradeDecisions.filter { $0.status != "proposed" }
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionLabel(text: "Trade log")
                    .padding(.horizontal, DS.Space.lg)
                ForEach(history.prefix(10)) { d in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(d.status.uppercased()) \(d.action) \(d.symbol)")
                                .font(DS.Font.mono(10, weight: .bold))
                                .foregroundStyle(d.status == "rejected" || d.status == "failed" ? DS.Color.red : DS.Color.textSecond)
                            Spacer()
                            Text(DateFormatting.aiStamp(d.createdAt))
                                .font(DS.Font.mono(9))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                        if !d.rationale.isEmpty {
                            Text(d.rationale)
                                .font(DS.Font.mono(9))
                                .foregroundStyle(DS.Color.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)
                }
            }
        }
    }

    private func formatMoney(_ v: Double) -> String {
        String(format: "$%.2f", v)
    }

    private func formatSigned(_ v: Double) -> String {
        String(format: "%+$%.2f", v)
    }

    private func formatQty(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f sh", v)
            : String(format: "%.4f sh", v)
    }

    private func activityLabel(_ act: APITradeActivity) -> String {
        switch act.activityType.uppercased() {
        case "CSD": return "Deposit"
        case "CSW": return "Withdrawal"
        case "FILL":
            let side = (act.side ?? "").capitalized
            return "\(side) fill"
        case "DIV": return "Dividend"
        default: return act.activityType
        }
    }
}
