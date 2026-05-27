import SwiftUI

struct ImageColumnView: View {
    @Bindable var session: SessionModel
    let tabIndex: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // LaFrance — always one
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAFRANCE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    ImageSlotView(
                        label: "",
                        image: $session.tabs[tabIndex].lafranceImage
                    )
                }

                // Page groups
                ForEach(Array(session.tabs[tabIndex].pages.indices), id: \.self) { pageIndex in
                    PageGroupView(
                        pageNumber: pageIndex + 1,
                        page: $session.tabs[tabIndex].pages[pageIndex],
                        canRemove: pageIndex > 0,
                        onRemove: {
                            session.tabs[tabIndex].pages.remove(at: pageIndex)
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}
