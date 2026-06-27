import SwiftUI

struct PersonRowView: View {
    @Bindable var session: SessionModel
    let personID: UUID

    private var personIndex: Int? {
        session.people.firstIndex { $0.id == personID }
    }

    var body: some View {
        if let index = personIndex {
            let last = session.people[index].lastName
            let first = session.people[index].firstName
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Picker("", selection: $session.people[index].gender) {
                        Text("M").tag(Gender.male)
                        Text("F").tag(Gender.female)
                    }
                    .labelsHidden()
                    .frame(width: 50)

                    TextField("Last Name", text: $session.people[index].lastName)
                        .textFieldStyle(.roundedBorder)

                    TextField("First Name", text: $session.people[index].firstName)
                        .textFieldStyle(.roundedBorder)

                    PersonStatusButton(session: session, last: last, first: first)

                    Button {
                        session.removePerson(personID)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isPersonReferenced(personID))
                    .help(session.isPersonReferenced(personID)
                        ? "Cannot remove — referenced by a record tab"
                        : "Remove person")
                }

                StatusBadgeRow(
                    statuses: session.statuses(last: last, first: first),
                    origin: session.origin(last: last, first: first)
                )
            }
        }
    }
}
