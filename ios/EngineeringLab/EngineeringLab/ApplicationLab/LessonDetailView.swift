import SwiftUI

struct LessonDetailView: View {
    let itemID: String
    let store: LessonStore
    let journal: LifecycleJournal
    @State private var visits = 0
    @State private var editorItem: LearningItem?

    var body: some View {
        Form {
            if let item = store.item(id: itemID) {
                LessonContentSection(item: item) {
                    store.update(id: item.id, note: item.note, isComplete: !item.isComplete)
                }
                Section("页面局部状态") {
                    LabeledContent("本次详情内点击", value: visits.formatted())
                    Button("局部计数 +1") { visits += 1 }
                    Text("返回列表再进入，计数重新开始；条目仍由上层模型持有。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button("编辑条目") { editorItem = item }
            } else {
                Text("条目不存在，请返回列表。")
            }
        }
        .navigationTitle("条目详情")
        .sheet(item: $editorItem) { item in
            LessonEditorView(item: item) { draft in
                store.update(id: item.id, note: draft.note, isComplete: draft.isComplete)
                journal.record("确认编辑 \(item.id)，更新内存")
            }
        }
        .onAppear { journal.record("详情出现 \(itemID)") }
        .onDisappear { journal.record("详情消失 \(itemID)") }
    }
}

private struct LessonContentSection: View {
    let item: LearningItem
    let toggleComplete: () -> Void

    var body: some View {
        Section("共享条目") {
            Text(item.title).font(.headline)
            Text(item.note.isEmpty ? "尚无笔记" : item.note)
            Button(action: toggleComplete) {
                Label(
                    item.isComplete ? "标记为未完成" : "标记为完成",
                    systemImage: item.isComplete ? "checkmark.circle.fill" : "circle")
            }
        }
    }
}

struct LessonDraft: Equatable {
    var note: String
    var isComplete: Bool
}

struct LessonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let item: LearningItem
    let onConfirm: (LessonDraft) -> Void
    @State private var draft: LessonDraft

    init(item: LearningItem, onConfirm: @escaping (LessonDraft) -> Void) {
        self.item = item
        self.onConfirm = onConfirm
        self.draft = LessonDraft(note: item.note, isComplete: item.isComplete)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.title) {
                    DraftFields(note: $draft.note, isComplete: $draft.isComplete)
                    Text("\(draft.note.count) / 2000 字符")
                        .foregroundStyle(draft.note.count > 2_000 ? .red : .secondary)
                }
                Section {
                    Text("取消或下滑关闭会放弃本次草稿。确认只更新内存，保存文件需回列表操作。")
                }
            }
            .navigationTitle("编辑草稿")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        onConfirm(draft)
                        dismiss()
                    }
                    .disabled(draft.note.count > 2_000)
                }
            }
        }
    }
}

private struct DraftFields: View {
    @Binding var note: String
    @Binding var isComplete: Bool

    var body: some View {
        TextField("学习笔记", text: $note, axis: .vertical)
            .lineLimit(3...6)
            .accessibilityIdentifier("lesson-note")
        Toggle("已完成", isOn: $isComplete)
    }
}
