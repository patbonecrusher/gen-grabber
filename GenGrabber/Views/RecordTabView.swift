import SwiftUI

struct RecordTabView: View {
    @Bindable var session: SessionModel
    var aiSettings: AISettings
    let tabID: UUID

    var body: some View {
        if session.tabs.contains(where: { $0.id == tabID }) {
            HStack(alignment: .top, spacing: 12) {
                MetadataColumnView(session: session, tabID: tabID)
                ImageColumnView(session: session, aiSettings: aiSettings, tabID: tabID)
            }
            .padding(12)
        }
    }
}
