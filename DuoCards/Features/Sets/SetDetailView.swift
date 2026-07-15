import SwiftUI

struct SetDetailView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let api: any DuoCardsAPI
    let onMutation: (FlashcardSet?) -> Void
    @State private var viewModel: SetDetailViewModel
    @State private var showStudy = false
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false

    init(
        set: FlashcardSet,
        api: any DuoCardsAPI,
        onMutation: @escaping (FlashcardSet?) -> Void = { _ in }
    ) {
        self.api = api
        self.onMutation = onMutation
        _viewModel = State(
            initialValue: SetDetailViewModel(set: set, api: api)
        )
    }

    var body: some View {
        ZStack {
            DuoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: DuoSpacing.xl) {
                    setHeader

                    if viewModel.isLoading && viewModel.set.words.isEmpty {
                        ProgressView("Načítám karty…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if let message = viewModel.errorMessage,
                              viewModel.set.words.isEmpty {
                        ContentUnavailableView {
                            Label("Sadu nelze načíst", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Zkusit znovu") {
                                Task { await load() }
                            }
                        }
                    } else if viewModel.set.words.isEmpty {
                        ContentUnavailableView(
                            "Sada je prázdná",
                            systemImage: "rectangle.stack",
                            description: Text("Tato sada zatím neobsahuje žádné kartičky.")
                        )
                    } else {
                        wordsList
                    }
                }
                .frame(maxWidth: 760)
                .padding(DuoSpacing.lg)
                .padding(.bottom, 88)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(viewModel.set.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showsEditor = true
                    } label: {
                        Label("Upravit sadu", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("Smazat sadu", systemImage: "trash")
                    }
                } label: {
                    if viewModel.isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .disabled(viewModel.isDeleting)
                .accessibilityLabel("Akce se sadou")
            }
        }
        .safeAreaInset(edge: .bottom) {
            studyButton
        }
        .navigationDestination(isPresented: $showStudy) {
            StudyView(
                title: viewModel.set.name,
                words: viewModel.set.words,
                api: session.api
            )
        }
        .sheet(isPresented: $showsEditor) {
            SetEditorView(api: api, set: viewModel.set) { updatedSet in
                viewModel.replace(with: updatedSet)
                onMutation(updatedSet)
            }
        }
        .confirmationDialog(
            "Smazat sadu \"\(viewModel.set.name)\"?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Smazat sadu", role: .destructive) {
                deleteSet()
            }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Sada i všechny její kartičky budou trvale odstraněny.")
        }
        .alert(
            "Sadu nelze smazat",
            isPresented: Binding(
                get: { viewModel.mutationErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.mutationErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.mutationErrorMessage ?? "Neznámá chyba.")
        }
        .task {
            await load()
        }
    }

    private var setHeader: some View {
        VStack(alignment: .leading, spacing: DuoSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.set.name)
                        .font(.title2.bold())
                    if let from = viewModel.set.fromLanguage,
                       let to = viewModel.set.toLanguage {
                        Text("\(from) → \(to)")
                            .font(.subheadline)
                            .foregroundStyle(
                                DuoColors.secondaryText(for: colorScheme)
                            )
                    }
                }
                Spacer()
                Label(
                    "\(viewModel.set.wordCount)",
                    systemImage: "rectangle.stack.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(DuoColors.indigo600)
            }

            if !viewModel.set.tags.isEmpty || viewModel.set.isAIGenerated {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        if viewModel.set.isAIGenerated {
                            TagChip(title: "AI generováno", isAI: true)
                        }
                        ForEach(viewModel.set.tags, id: \.self) { tag in
                            TagChip(title: tag, isAI: false)
                        }
                    }
                }
            }
        }
        .duoCard()
    }

    private var wordsList: some View {
        VStack(alignment: .leading, spacing: DuoSpacing.md) {
            Text("Kartičky")
                .font(.title3.bold())

            ForEach(Array(viewModel.set.words.enumerated()), id: \.element.id) {
                index,
                word in
                HStack(alignment: .top, spacing: DuoSpacing.md) {
                    Text("\(index + 1)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(DuoColors.indigo600)
                        .frame(width: 28, height: 28)
                        .background(DuoColors.indigo50)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(.headline)
                        Text(word.translation)
                            .font(.subheadline)
                            .foregroundStyle(
                                DuoColors.secondaryText(for: colorScheme)
                            )
                        if let pronunciation = word.pronunciation,
                           !pronunciation.isEmpty {
                            Text(pronunciation)
                                .font(.caption)
                                .foregroundStyle(DuoColors.violet600)
                        }
                    }
                    Spacer()
                }
                .duoCard(padding: DuoSpacing.md)
            }
        }
    }

    private var studyButton: some View {
        Button {
            showStudy = true
        } label: {
            Label("Začít studovat", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(DuoColors.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: DuoRadius.medium))
        }
        .disabled(viewModel.set.words.isEmpty)
        .opacity(viewModel.set.words.isEmpty ? 0.5 : 1)
        .padding(.horizontal, DuoSpacing.lg)
        .padding(.vertical, DuoSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private func load() async {
        await viewModel.load()
        if viewModel.isUnauthorized {
            session.expireSession()
        }
    }

    private func deleteSet() {
        Task {
            if await viewModel.delete() {
                onMutation(nil)
                dismiss()
            } else if viewModel.isUnauthorized {
                session.expireSession()
                dismiss()
            }
        }
    }
}

#Preview("Detail sady") {
    NavigationStack {
        SetDetailView(
            set: PreviewFixtures.travelSet,
            api: MockDuoCardsAPI()
        )
    }
    .environment(
        AppSession(
            api: MockDuoCardsAPI(),
            initialState: .signedIn(PreviewFixtures.user)
        )
    )
}
