#if DEBUG
import SwiftUI

/// Deterministic, network-free screens for visual QA and App Store screenshots.
/// Enable with the `DUOCARDS_DEMO_SCREEN` launch environment variable.
struct DemoLaunchView: View {
    let screen: String
    let api: any DuoCardsAPI

    var body: some View {
        switch screen {
        case "detail":
            NavigationStack {
                SetDetailView(set: PreviewFixtures.travelSet, api: api)
            }
        case "study":
            NavigationStack {
                StudyView(
                    title: PreviewFixtures.travelSet.name,
                    words: PreviewFixtures.travelWords,
                    api: api,
                    shuffle: false
                )
            }
        default:
            RootView()
        }
    }
}
#endif
