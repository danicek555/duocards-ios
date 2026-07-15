import SwiftUI

@main
@MainActor
struct DuoCardsApp: App {
    @State private var session: AppSession
    private let demoScreen: String?

    init() {
#if DEBUG
        let requestedDemoScreen = ProcessInfo.processInfo.environment[
            "DUOCARDS_DEMO_SCREEN"
        ]
        demoScreen = requestedDemoScreen

        if requestedDemoScreen != nil {
            let api = MockDuoCardsAPI()
            let initialState: AppSession.State = requestedDemoScreen == "login"
                ? .signedOut
                : .signedIn(PreviewFixtures.user)
            _session = State(
                initialValue: AppSession(api: api, initialState: initialState)
            )
            return
        }
#else
        demoScreen = nil
#endif

        let configuration = AppConfiguration.live()
        let api = DuoCardsAPIClient(configuration: configuration)
        _session = State(initialValue: AppSession(api: api))
    }

    var body: some Scene {
        WindowGroup {
            launchView
                .environment(session)
                .tint(DuoColors.indigo600)
                .task {
                    if demoScreen == nil {
                        await session.restoreIfNeeded()
                    }
                }
        }
    }

    @ViewBuilder
    private var launchView: some View {
#if DEBUG
        if let demoScreen {
            DemoLaunchView(screen: demoScreen, api: session.api)
        } else {
            RootView()
        }
#else
        RootView()
#endif
    }
}
