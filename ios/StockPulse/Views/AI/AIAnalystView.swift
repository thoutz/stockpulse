import SwiftUI

struct AIAnalystView: View {
    @Environment(StockPulseViewModel.self) private var vm
    @FocusState private var focused: Bool

    private let chipColumns = [
        GridItem(.flexible(), spacing: DS.Space.sm),
        GridItem(.flexible(), spacing: DS.Space.sm),
    ]

    private var isEmptyChat: Bool {
        vm.aiResponse.isEmpty && !vm.aiLoading
    }

    private var canClearChat: Bool {
        !vm.aiResponse.isEmpty || !vm.aiQuery.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isEmptyChat {
                emptyState
            } else {
                activeChat
            }
        }
        .spScreenBackground()
        .task {
            await vm.syncChatPrompts()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Ask AI")
                .font(DS.Font.sans(20, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            HStack(spacing: DS.Space.sm) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(vm.usesLiveData ? DS.Color.green : DS.Color.textDim)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(DS.Font.mono(10))
                        .foregroundStyle(vm.usesLiveData ? DS.Color.green : DS.Color.textDim)
                }
                if canClearChat {
                    Button {
                        focused = false
                        vm.clearAIChat()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(DS.Color.textMuted)
                    }
                    .disabled(vm.aiLoading)
                    .accessibilityLabel("Clear chat")
                }
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.sm)
    }

    // MARK: - Empty state (centered composer)

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: DS.Space.lg)

            VStack(spacing: DS.Space.lg) {
                ZStack {
                    Circle()
                        .fill(DS.Color.blue.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(DS.Color.blue)
                }

                Text("Ask about ripples, trends, and your watchlist")
                    .font(DS.Font.sans(13))
                    .foregroundStyle(DS.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.xl)

                suggestionChips

                chatComposer
                    .padding(.horizontal, DS.Space.md)
            }
            .spScrollContentWidth()

            Spacer(minLength: DS.Space.lg)
        }
    }

    // MARK: - Active chat (scroll + bottom composer)

    private var activeChat: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                if vm.aiLoading {
                    HStack(spacing: DS.Space.sm) {
                        ProgressView().tint(DS.Color.blue)
                        Text("Analyzing market data...")
                            .font(DS.Font.sans(13))
                            .foregroundStyle(DS.Color.textMuted)
                    }
                }

                if !vm.aiResponse.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        HStack {
                            SectionLabel(text: "Analysis")
                            Spacer()
                            if let generatedAt = vm.aiResponseGeneratedAt {
                                Text(DateFormatting.aiStamp(generatedAt))
                                    .font(DS.Font.mono(9))
                                    .foregroundStyle(DS.Color.textMuted)
                            }
                        }
                        HighlightedReportText(text: vm.aiResponse, fontSize: 14, emphasis: true)
                            .lineSpacing(4)
                    }
                    .spScrollContentWidth()
                    .padding(DS.Space.lg)
                    .background(DS.Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DS.Color.blue)
                            .frame(width: 3)
                    }
                }

                Spacer(minLength: DS.Space.xxl)
            }
            .padding(.horizontal, DS.Space.lg)
            .spScrollContentWidth()
        }
        .spVerticalScrollAxes()
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            chatComposer
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
                .background {
                    DS.Color.bg.opacity(0.95)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(DS.Color.border.opacity(0.5))
                                .frame(height: 1)
                        }
                }
        }
    }

    // MARK: - Shared components

    private var suggestionChips: some View {
        LazyVGrid(columns: chipColumns, alignment: .center, spacing: DS.Space.sm) {
            ForEach(vm.aiChatPrompts, id: \.self) { q in
                Button(q) {
                    vm.aiQuery = q
                    submitChat()
                }
                .font(DS.Font.sans(12))
                .foregroundStyle(DS.Color.textSecond)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
                .background(DS.Color.surface2)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
        }
        .spScrollContentWidth()
        .padding(.horizontal, DS.Space.lg)
    }

    @ViewBuilder
    private var chatComposer: some View {
        @Bindable var bindVm = vm
        HStack(alignment: .bottom, spacing: DS.Space.xs) {
            TextField("Ask about ripples, timing, trends...", text: $bindVm.aiQuery, axis: .vertical)
                .font(DS.Font.sans(14))
                .foregroundStyle(DS.Color.textPrimary)
                .tint(DS.Color.blue)
                .lineLimit(4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { submitChat() }
                .padding(.leading, DS.Space.md)
                .padding(.vertical, DS.Space.md)
                .padding(.trailing, DS.Space.xs)

            Button(action: submitChat) {
                Image(systemName: vm.aiLoading ? "arrow.triangle.2.circlepath" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? DS.Color.blue : DS.Color.textDim)
            }
            .disabled(!canSend)
            .padding(.trailing, DS.Space.sm)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(focused ? DS.Color.blue.opacity(0.4) : DS.Color.border, lineWidth: 1)
        )
    }

    private var canSend: Bool {
        !vm.aiQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.aiLoading
    }

    private var statusLabel: String {
        if vm.usesServerAPI && vm.usesLiveData { return "Server assistant + data" }
        if vm.usesLiveData { return "Full app + Massive data" }
        return "Waiting for market data"
    }

    private func submitChat() {
        guard canSend else { return }
        focused = false
        Task { await vm.askAI() }
    }
}
