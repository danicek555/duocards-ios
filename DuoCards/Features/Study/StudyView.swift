import AVFoundation
import SwiftUI
import UIKit

struct StudyView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @State private var viewModel: StudyViewModel
    @State private var isFlipped = false
    @State private var audioPlayer: AVAudioPlayer?

    init(
        title: String,
        words: [Word],
        api: any DuoCardsAPI,
        shuffle: Bool = true
    ) {
        self.title = title
        _viewModel = State(
            initialValue: StudyViewModel(
                words: words,
                api: api,
                shuffle: shuffle
            )
        )
    }

    var body: some View {
        ZStack {
            DuoBackground()
            if let word = viewModel.currentWord {
                VStack(spacing: DuoSpacing.lg) {
                    progressHeader

                    if let mediaErrorMessage = viewModel.mediaErrorMessage {
                        Label(
                            mediaErrorMessage,
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(DuoColors.red500)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    FlipCard(
                        word: word,
                        imageDataURL: viewModel.currentImageDataURL,
                        isFlipped: isFlipped
                    )
                        .id(viewModel.currentIndex)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isFlipped.toggle()
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(
                            isFlipped
                                ? "Překlad \(word.translation). Klepnutím otočíte kartu."
                                : "Slovo \(word.word). Klepnutím zobrazíte překlad."
                        )

                    navigationButtons
                }
                .frame(maxWidth: 680)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(DuoSpacing.lg)
                .task(id: viewModel.currentIndex) {
                    await viewModel.loadCurrentMedia()
                    if viewModel.isUnauthorized {
                        session.expireSession()
                    }
                }
            } else {
                ContentUnavailableView(
                    "Žádné kartičky",
                    systemImage: "rectangle.stack"
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopAudioPlayback()
        }
    }

    private var progressHeader: some View {
        VStack(spacing: DuoSpacing.sm) {
            HStack {
                Text("Karta \(viewModel.currentIndex + 1) z \(viewModel.words.count)")
                Spacer()
                if viewModel.isLoadingMedia {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Načítám média")
                } else if viewModel.currentAudioDataURL != nil {
                    Button {
                        playCurrentAudio()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DuoColors.indigo600)
                    .accessibilityLabel("Přehrát výslovnost")
                }
                Text(isFlipped ? "PŘEKLAD" : "SLOVO")
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(
                        isFlipped ? DuoColors.violet600 : DuoColors.indigo600
                    )
            }
            .font(.caption)
            .foregroundStyle(DuoColors.secondaryText(for: colorScheme))

            ProgressView(value: viewModel.progress)
                .tint(DuoColors.indigo600)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: DuoSpacing.md) {
            Button {
                moveCard {
                    viewModel.previous()
                }
            } label: {
                Label("Předchozí", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasPrevious)

            Button {
                moveCard {
                    viewModel.next()
                }
            } label: {
                Label("Další", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasNext)
        }
        .fontWeight(.semibold)
    }

    private func moveCard(_ action: () -> Void) {
        stopAudioPlayback()
        withAnimation(.easeOut(duration: 0.15)) {
            isFlipped = false
        }
        action()
    }

    private func playCurrentAudio() {
        guard let dataURL = viewModel.currentAudioDataURL else { return }

        viewModel.mediaErrorMessage = nil

        do {
            let decoded = try DataURLDecoder.decode(dataURL)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            let player = try AVAudioPlayer(data: decoded.data)
            guard player.prepareToPlay(), player.play() else {
                throw AudioPlaybackError.couldNotStart
            }
            audioPlayer = player
        } catch {
            audioPlayer = nil
            viewModel.mediaErrorMessage =
                "Výslovnost se nepodařilo přehrát. Zkuste to prosím znovu."
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private enum AudioPlaybackError: Error {
        case couldNotStart
    }
}

private struct FlipCard: View {
    let word: Word
    let imageDataURL: String?
    let isFlipped: Bool

    var body: some View {
        ZStack {
            CardFace(
                word: word,
                imageDataURL: imageDataURL,
                side: .front
            )
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
            CardFace(
                word: word,
                imageDataURL: imageDataURL,
                side: .back
            )
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(.easeInOut(duration: 0.5), value: isFlipped)
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .contentShape(RoundedRectangle(cornerRadius: DuoRadius.hero))
    }
}

private struct CardFace: View {
    enum Side {
        case front
        case back
    }

    @Environment(\.colorScheme) private var colorScheme
    let word: Word
    let imageDataURL: String?
    let side: Side

    private var artwork: UIImage? {
        DataURLDecoder.image(from: imageDataURL)
    }

    private var accent: Color {
        switch word.difficulty {
        case 2: DuoColors.amber500
        case 3: Color.orange
        case 4...: DuoColors.red500
        default: DuoColors.emerald600
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DuoRadius.hero)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.3 : 0.12),
                            DuoColors.surface(for: colorScheme)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: DuoRadius.hero))
                Color.black.opacity(colorScheme == .dark ? 0.58 : 0.42)
                    .clipShape(RoundedRectangle(cornerRadius: DuoRadius.hero))
            }

            VStack(spacing: DuoSpacing.xl) {
                HStack(spacing: DuoSpacing.sm) {
                    Circle()
                        .fill(artwork == nil ? accent : .white)
                        .frame(width: 8, height: 8)
                    Text(side == .front ? "SLOVO" : "PŘEKLAD")
                        .font(.caption.bold().monospaced())
                        .tracking(1.6)
                    Circle()
                        .fill(artwork == nil ? accent : .white)
                        .frame(width: 8, height: 8)
                }
                .foregroundStyle(artwork == nil ? accent : .white)

                Text(side == .front ? word.word : word.translation)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.45)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        artwork == nil
                            ? DuoColors.primaryText(for: colorScheme)
                            : .white
                    )
                    .shadow(
                        color: artwork == nil ? .clear : .black.opacity(0.6),
                        radius: 5,
                        y: 2
                    )
                    .padding(.horizontal)

                if side == .back,
                   let pronunciation = word.pronunciation,
                   !pronunciation.isEmpty {
                    Text(pronunciation)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(
                            artwork == nil ? DuoColors.violet600 : .white
                        )
                }

                Text(
                    side == .front
                        ? "Klepnutím zobrazíte překlad"
                        : "Klepnutím otočíte zpět"
                )
                .font(.caption)
                .foregroundStyle(
                    artwork == nil
                        ? DuoColors.secondaryText(for: colorScheme)
                        : .white.opacity(0.9)
                )
            }
            .padding(DuoSpacing.xl)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DuoRadius.hero)
                .stroke(accent.opacity(0.65), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 14)
        .clipped()
    }
}

#Preview("Studium") {
    NavigationStack {
        StudyView(
            title: PreviewFixtures.travelSet.name,
            words: PreviewFixtures.travelWords,
            api: MockDuoCardsAPI(),
            shuffle: false
        )
    }
    .environment(
        AppSession(
            api: MockDuoCardsAPI(),
            initialState: .signedIn(PreviewFixtures.user)
        )
    )
}
