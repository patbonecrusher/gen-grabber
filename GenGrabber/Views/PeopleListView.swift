import SwiftUI

struct PeopleListView: View {
    @Bindable var session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PEOPLE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(session.people) { person in
                PersonRowView(session: session, personID: person.id)
            }

            Button {
                session.addPerson()
            } label: {
                Label("Add Person", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
