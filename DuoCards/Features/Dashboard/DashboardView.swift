import SwiftUI

struct DashboardView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    let user: User
    let api: any DuoCardsAPI
    @State private var viewModel: DashboardViewModel
    @State private var showsCreateEditor = false

    init(user: User, api: any DuoCardsAPI) {
        self.user = user
        self.api = api
        _viewModel = State(initialValue: DashboardViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()
                ScrollView {
                    LazyVStack(spacing: DuoSpacing.lg) {
                        dashboardHeader
                        stats

                        if viewModel.isLoading && viewModel.sets.isEmpty {
                            ProgressView("Načítám vaše sady…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 64)
                        } else if let message = viewModel.errorMessage {
                            errorState(message)
                        } else if viewModel.sets.isEmpty {
                            emptyState
                        } else {
                            setsSection
                        }
                    }
                    .frame(maxWidth: 760)
                    .padding(.horizontal, DuoSpacing.lg)
                    .padding(.bottom, DuoSpacing.xxl)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await load()
                }
            }
            .navigationTitle("DuoCards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DuoBrandMark(size: 32)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showsCreateEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Vytvořit sadu")

                    Menu {
                        Text(user.email)
                        Divider()
                        Button(role: .destructive) {
                            Task { await session.logout() }
                        } label: {
                            Label("Odhlásit se", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                    .accessibilityLabel("Účet")
                }
            }
            .sheet(isPresented: $showsCreateEditor) {
                SetEditorView(api: api) { createdSet in
                    viewModel.upsert(createdSet)
                    Task { await load() }
                }
            }
            .task {
                await load()
            }
        }
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: DuoSpacing.xs) {
            Text("Vítejte zpět, \(user.nickname)")
                .font(.title2.bold())
                .foregroundStyle(DuoColors.primaryText(for: colorScheme))
            Text("Vyberte sadu a pokračujte ve studiu.")
                .font(.subheadline)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DuoSpacing.md)
    }

    private var stats: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 10
        ) {
            StatTile(
                title: "Sady",
                value: "\(viewModel.sets.count)",
                icon: "rectangle.stack.fill",
                color: DuoColors.indigo600
            )
            StatTile(
                title: "Slova",
                value: "\(viewModel.totalWords)",
                icon: "text.book.closed.fill",
                color: DuoColors.emerald600
            )
            StatTile(
                title: "AI coiny",
                value: viewModel.coins.map(String.init) ?? "—",
                icon: "sparkles",
                color: DuoColors.violet600
            )
        }
    }

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: DuoSpacing.md) {
            HStack {
                Text("Moje sady")
                    .font(.title3.bold())
                Spacer()
                Text("\(viewModel.sets.count)")
                    .font(.caption.bold())
                    .foregroundStyle(DuoColors.indigo600)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DuoColors.indigo50)
                    .clipShape(Capsule())
            }

            ForEach(viewModel.sets) { set in
                NavigationLink {
                    SetDetailView(
                        set: set,
                        api: api
                    ) { updatedSet in
                        if let updatedSet {
                            viewModel.upsert(updatedSet)
                        } else {
                            viewModel.removeSet(id: set.id)
                        }
                        Task { await load() }
                    }
                } label: {
                    FlashcardSetRow(set: set)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Zatím nemáte žádnou sadu", systemImage: "rectangle.stack.badge.plus")
        } description: {
            Text("Vytvořte první sadu a přidejte do ní vlastní kartičky.")
        } actions: {
            Button("Vytvořit sadu") {
                showsCreateEditor = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 48)
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Sady se nepodařilo načíst", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Zkusit znovu") {
                Task { await load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }

    private func load() async {
        await viewModel.load()
        if viewModel.isUnauthorized {
            session.expireSession()
        }
    }
}

private struct StatTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DuoSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(DuoColors.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(DuoColors.secondaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .duoCard(padding: DuoSpacing.md)
    }
}

private struct FlashcardSetRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let set: FlashcardSet

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(set.name)
                        .font(.headline)
                        .foregroundStyle(DuoColors.primaryText(for: colorScheme))
                        .multilineTextAlignment(.leading)
                    if set.fromLanguage != nil || set.toLanguage != nil {
                        Text("\(flag(for: set.fromLanguage))  →  \(flag(for: set.toLanguage))")
                            .font(.title3)
                    }
                }
                Spacer()
                Text("\(set.wordCount) karet")
                    .font(.caption.bold())
                    .foregroundStyle(DuoColors.indigo600)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DuoColors.indigo50)
                    .clipShape(Capsule())
            }

            if !set.tags.isEmpty || set.isAIGenerated {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if set.isAIGenerated {
                            TagChip(title: "AI generováno", isAI: true)
                        }
                        ForEach(set.tags, id: \.self) { tag in
                            TagChip(title: tag, isAI: false)
                        }
                    }
                }
            }
        }
        .duoCard()
    }

    private func flag(for language: String?) -> String {
        guard let language else { return "🌐" }
        return [
            "English": "🇬🇧", "Spanish": "🇪🇸", "French": "🇫🇷",
            "German": "🇩🇪", "Czech": "🇨🇿", "Italian": "🇮🇹",
            "Japanese": "🇯🇵", "Chinese": "🇨🇳", "Korean": "🇰🇷",
            "Portuguese": "🇵🇹", "Polish": "🇵🇱", "Ukrainian": "🇺🇦"
        ][language] ?? "🌐"
    }
}

struct TagChip: View {
    let title: String
    let isAI: Bool

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(isAI ? DuoColors.violet600 : DuoColors.gray700)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isAI ? DuoColors.violet100 : DuoColors.gray100)
            .clipShape(Capsule())
    }
}

#Preview("Dashboard") {
    let api = MockDuoCardsAPI()
    DashboardView(user: PreviewFixtures.user, api: api)
        .environment(
            AppSession(api: api, initialState: .signedIn(PreviewFixtures.user))
        )
}
