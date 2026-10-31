import SwiftUI

struct RestorationView: View {
    let store: LessonStore
    let journal: LifecycleJournal
    @State private var temporaryText = ""
    @SceneStorage("app-lab.scene-scratch") private var sceneScratch = ""
    @AppStorage("app-lab.show-hints") private var showHints = true
    @State private var confirmsReset = false

    var body: some View {
        Form {
            Section("三种状态") {
                TextField("页面临时文字", text: $temporaryText)
                    .accessibilityIdentifier("temporary-text")
                TextField("场景便笺", text: $sceneScratch)
                    .accessibilityIdentifier("scene-scratch")
                Toggle("显示学习提示", isOn: $showHints)
                if showHints {
                    Text("临时文字随本页身份结束；场景便笺由系统择机保存；学习提示写入用户偏好。")
                        .font(.callout)
                }
            }
            StorageSection(store: store)
            Section {
                Button("清除第二章实验数据", role: .destructive) { confirmsReset = true }
            } footer: {
                Text("清除条目文件、当前场景便笺与学习提示偏好。不会清除工程基础实验。")
            }
        }
        .navigationTitle("状态保存与恢复")
        .confirmationDialog("清除第二章实验数据？", isPresented: $confirmsReset) {
            Button("清除", role: .destructive) {
                if store.reset() {
                    temporaryText = ""
                    sceneScratch = ""
                    showHints = true
                    journal.record("已清除第二章实验数据")
                }
            }
        }
        .onAppear { journal.record("恢复页出现") }
        .onDisappear { journal.record("恢复页消失") }
    }
}
