import SwiftUI

/// A checklist of follow-up tasks for the open folder, saved as a Markdown `todo.md` so the
/// list stays readable from Finder.
struct TodoTabView: View {
    @Bindable var session: SessionModel
    @FocusState private var focusedTodoID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("To Do")
                    .font(.headline)

                if session.openTodoCount > 0 {
                    Text("\(session.openTodoCount) open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear Completed") {
                    session.clearCompletedTodos()
                }
                .controlSize(.small)
                .disabled(!session.todos.contains { $0.done })

                Button {
                    addTodo()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if session.todos.isEmpty {
                ContentUnavailableView {
                    Label("Nothing To Do", systemImage: "checklist")
                } description: {
                    Text("Add a follow-up task for this folder — it saves as todo.md.")
                } actions: {
                    Button("Add Task") { addTodo() }
                }
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(session.todos) { todo in
                            if let index = session.todos.firstIndex(where: { $0.id == todo.id }) {
                                row(at: index)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    @ViewBuilder
    private func row(at index: Int) -> some View {
        let todo = session.todos[index]

        HStack(spacing: 8) {
            Toggle(isOn: $session.todos[index].done) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            TextField("Task", text: $session.todos[index].text)
                .textFieldStyle(.plain)
                .focused($focusedTodoID, equals: todo.id)
                .strikethrough(todo.done)
                .foregroundStyle(todo.done ? .secondary : .primary)
                // Enter starts the next task, so a list can be typed straight through.
                .onSubmit { addTodo() }

            Button {
                session.removeTodo(todo.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.textBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func addTodo() {
        session.addTodo()
        focusedTodoID = session.todos.last?.id
    }
}
