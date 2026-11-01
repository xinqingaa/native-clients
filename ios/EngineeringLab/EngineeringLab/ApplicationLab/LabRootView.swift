import SwiftUI

struct LabRootView: View {
    var body: some View {
        TabView {
            Tab("工程基础", systemImage: "hammer") {
                ContentView()
            }
            Tab("应用与生命周期", systemImage: "app.connected.to.app.below.fill") {
                ApplicationLabView()
            }
            Tab("UI 与交互", systemImage: "rectangle.3.group") {
                UILabView()
            }
        }
    }
}

struct ApplicationLabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = LessonStore()
    @State private var journal = LifecycleJournal()
    @State private var tasks = TaskExperiment()
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("学习条目") {
                    ForEach(store.items) { item in
                        NavigationLink(value: item.id) {
                            LessonRow(title: item.title, isComplete: item.isComplete)
                        }
                    }
                }
                StorageSection(store: store)
                Section {
                    NavigationLink("状态与对象寿命", value: "ownership-lab")
                    NavigationLink("生命周期与任务", value: "tasks")
                    NavigationLink("状态保存与恢复", value: "restoration")
                }
            }
            .navigationTitle("应用与生命周期")
            .navigationDestination(for: String.self) { route in
                switch route {
                case "ownership-lab":
                    StateLifetimeView()
                case "tasks":
                    LifecycleTasksView(tasks: tasks, journal: journal)
                case "restoration":
                    RestorationView(store: store, journal: journal)
                default:
                    LessonDetailView(itemID: route, store: store, journal: journal)
                }
            }
        }
        .task { store.loadIfNeeded() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            journal.record("Scene \(String(describing: phase))")
        }
    }
}

private struct LessonRow: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        Label(title, systemImage: isComplete ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isComplete ? .green : .primary)
    }
}

struct StorageSection: View {
    let store: LessonStore

    var body: some View {
        Section {
            Text(store.storageMessage)
                .font(.callout)
            if store.hasUnsavedChanges {
                Text("有尚未保存到文件的修改")
                    .foregroundStyle(.orange)
            }
            Button("保存条目到文件") { store.save() }
                .disabled(!store.hasLoaded)
                .accessibilityIdentifier("save-lessons")
        } header: {
            Text("当前数据")
        } footer: {
            Text("确认编辑只更新内存。需要跨启动保留时，再保存到文件。")
        }
    }
}

#Preview {
    LabRootView()
}
