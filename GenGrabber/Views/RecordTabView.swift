import SwiftUI

struct RecordTabView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MetadataColumnView(session: session, tabIndex: tabIndex)
            ImageColumnView(session: session, tabIndex: tabIndex)
        }
        .padding(12)
    }
}
