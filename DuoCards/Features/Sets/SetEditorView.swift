import SwiftUI

struct SetEditorView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SetEditorViewModel
    let onSaved: (FlashcardSet) -> Void

    init(
        api: any DuoCardsAPI,
        set: FlashcardSet? = nil,
        onSaved: @escaping (FlashcardSet) -> Void
    ) {
        _viewModel = State(
            initialValue: SetEditorViewModel(api: api, set: set)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            Form {
                Section("Základní údaje") {
                    TextField("Název sady", text: $bindableViewModel.form.name)
                        .textInputAutocapitalization(.sentences)
                    TextField(
                        "Jazyk slov (volitelný)",
                        text: $bindableViewModel.form.fromLanguage
                    )
                    TextField(
                        "Jazyk překladů (volitelný)",
                        text: $bindableViewModel.form.toLanguage
                    )
                }

                Section {
                    if !viewModel.form.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DuoSpacing.sm) {
                                ForEach(viewModel.form.tags, id: \.self) { tag in
                                    Button {
                                        viewModel.removeTag(tag)
                                    } label: {
                                        Label(tag, systemImage: "xmark.circle.fill")
                                            .labelStyle(.titleAndIcon)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .accessibilityLabel("Odebrat tag \(tag)")
                                }
                            }
                        }
                    }

                    HStack {
                        TextField("Přidat tag", text: $bindableViewModel.pendingTag)
                            .submitLabel(.done)
                            .onSubmit { viewModel.addPendingTag() }
                        Button("Přidat") {
                            viewModel.addPendingTag()
                        }
                        .disabled(
                            viewModel.pendingTag.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty || viewModel.form.tags.count >= SetEditorViewModel.maximumTags
                        )
                    }
                } header: {
                    HStack {
                        Text("Tagy")
                        Spacer()
                        Text("\(viewModel.form.tags.count)/\(SetEditorViewModel.maximumTags)")
                    }
                }

                ForEach($bindableViewModel.form.words) { $card in
                    Section {
                        TextField("Slovo", text: $card.word, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                        TextField(
                            "Překlad",
                            text: $card.translation,
                            axis: .vertical
                        )
                        .textInputAutocapitalization(.sentences)
                        TextField(
                            "Výslovnost (volitelná)",
                            text: $card.pronunciation
                        )

                        Picker("Obtížnost", selection: $card.difficulty) {
                            ForEach(1...4, id: \.self) { difficulty in
                                Text("\(difficulty)").tag(difficulty)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button(role: .destructive) {
                            viewModel.removeWord(id: card.id)
                        } label: {
                            Label("Odebrat kartu", systemImage: "trash")
                        }
                        .disabled(viewModel.form.words.count == 1)
                    } header: {
                        Text("Karta \(position(of: card.id))")
                    }
                }

                Section {
                    Button {
                        viewModel.addWord()
                    } label: {
                        Label("Přidat kartu", systemImage: "plus.circle.fill")
                    }
                    .disabled(
                        viewModel.form.words.count >= SetEditorViewModel.maximumWords
                    )
                } header: {
                    Text(
                        "Karty \(viewModel.form.words.count)/\(SetEditorViewModel.maximumWords)"
                    )
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(DuoColors.red500)
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(viewModel.saveTitle)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }

    private func position(of id: UUID) -> Int {
        (viewModel.form.words.firstIndex { $0.id == id } ?? 0) + 1
    }

    private func save() {
        Task {
            if let savedSet = await viewModel.save() {
                onSaved(savedSet)
                dismiss()
            } else if viewModel.isUnauthorized {
                session.expireSession()
                dismiss()
            }
        }
    }
}

#Preview("Nová sada") {
    let api = MockDuoCardsAPI()
    SetEditorView(api: api) { _ in }
        .environment(
            AppSession(api: api, initialState: .signedIn(PreviewFixtures.user))
        )
}

#Preview("Upravit sadu") {
    let api = MockDuoCardsAPI()
    SetEditorView(api: api, set: PreviewFixtures.travelSet) { _ in }
        .environment(
            AppSession(api: api, initialState: .signedIn(PreviewFixtures.user))
        )
}
