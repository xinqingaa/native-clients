import SwiftUI

struct LifecycleTasksView: View {
    let tasks: TaskExperiment
    let journal: LifecycleJournal
    @State private var showPanel = true
    @State private var input = 1

    var body: some View {
        Form {
            Section {
                Toggle("显示关联任务面板", isOn: $showPanel)
                Stepper("任务输入：\(input)", value: $input, in: 1...9)
                if showPanel {
                    AttachedTaskPanel(input: input, tasks: tasks, journal: journal)
                }
            } header: {
                Text("SwiftUI 关联任务")
            } footer: {
                Text("改变输入会取消旧任务并启动新任务；隐藏面板会移除关联视图。每轮共 8 步。")
            }
            ManualTaskSection(tasks: tasks, journal: journal)
            JournalSection(journal: journal)
        }
        .navigationTitle("生命周期与任务")
        .onAppear { journal.record("任务页出现") }
        .onDisappear { journal.record("任务页消失") }
    }
}

private struct AttachedTaskPanel: View {
    let input: Int
    let tasks: TaskExperiment
    let journal: LifecycleJournal

    var body: some View {
        Text(tasks.attachedStatus)
            .task(id: input) { await tasks.runAttached(input: input, journal: journal) }
            .onAppear { journal.record("关联面板出现") }
            .onDisappear { journal.record("关联面板消失") }
    }
}

private struct ManualTaskSection: View {
    let tasks: TaskExperiment
    let journal: LifecycleJournal

    var body: some View {
        Section {
            Text(tasks.manualStatus)
            Button("开始手动任务") { tasks.startManual(journal: journal) }
                .disabled(tasks.manualIsRunning)
            Button("取消手动任务") { tasks.cancelManual() }
                .disabled(!tasks.manualIsRunning)
        } header: {
            Text("模型持有的手动任务")
        } footer: {
            Text("返回列表不会自动取消它。8 步后结束，也可明确取消；进入后台不保证继续执行。")
        }
    }
}

struct JournalSection: View {
    let journal: LifecycleJournal

    var body: some View {
        Section {
            ForEach(journal.entries.reversed()) { entry in
                Text(verbatim: "\(entry.id). \(entry.message)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        } header: {
            Text("最近事件")
        } footer: {
            Text("仅保留当前进程最近 60 条。前后台与页面事件的顺序以实际操作为准。")
        }
    }
}
