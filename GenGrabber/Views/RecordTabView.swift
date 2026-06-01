import SwiftUI

struct RecordTabView: View {
    @Bindable var session: SessionModel
    var aiSettings: AISettings
    let tabIndex: Int

    var body: some View {
        if session.tabs.indices.contains(tabIndex) {
            HStack(alignment: .top, spacing: 12) {
                MetadataColumnView(session: session, tabIndex: tabIndex)
                ImageColumnView(session: session, aiSettings: aiSettings, tabIndex: tabIndex)
            }
            .padding(12)
        }
    }
}
