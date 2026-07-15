import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                LaunchLoadingView()
            case .signedOut:
                LoginView()
            case let .signedIn(user):
                DashboardView(user: user, api: session.api)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.state)
    }
}

private struct LaunchLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            DuoBackground()
            VStack(spacing: DuoSpacing.lg) {
                DuoBrandMark(size: 76)
                Text("DuoCards")
                    .font(.largeTitle.bold())
                    .foregroundStyle(DuoColors.brandGradient)
                ProgressView()
                    .tint(DuoColors.indigo600)
                Text("Obnovuji přihlášení…")
                    .font(.subheadline)
                    .foregroundStyle(
                        DuoColors.secondaryText(for: colorScheme)
                    )
            }
        }
    }
}
