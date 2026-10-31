import SwiftUI

/// 只记录普通对象的创建和释放，不让日志器额外持有观察对象。
nonisolated final class LifetimeProbe: Sendable {
    let id = UUID().uuidString

    init() {
        print("[AppLab][memory] init \(id)")
    }

    deinit {
        print("[AppLab][memory] deinit \(id)")
    }
}

struct StateLifetimeView: View {
    @State private var input = 0
    @State private var generation = 0
    @State private var retainedProbe: LifetimeProbe?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LifetimeControls(input: $input, generation: $generation)
                LifetimeContent(input: input) { retainedProbe = $0 }
                    .id(generation)
                RetainedObjectPanel(probe: retainedProbe) { retainedProbe = nil }
            }
            .padding()
        }
        .navigationTitle("状态与对象寿命")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LifetimeControls: View {
    @Binding var input: Int
    @Binding var generation: Int

    var body: some View {
        GroupBox("父级控制") {
            VStack(alignment: .leading, spacing: 12) {
                Stepper("父级输入：\(input)", value: $input, in: 0...99)
                Button("重建子视图身份") { generation += 1 }
                Text("当前身份编号：\(generation)")
                    .font(.caption)
                Text("改变输入用于观察普通更新；重建身份用于观察局部状态重新建立。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LifetimeContent: View {
    let input: Int
    let onRetain: (LifetimeProbe) -> Void
    @State private var count = 0
    @State private var probe: LifetimeProbe?

    var body: some View {
        GroupBox("子视图状态") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("接收到的父级输入", value: input.formatted())
                LabeledContent("局部计数", value: count.formatted())
                Button("子视图计数 +1") { count += 1 }
                if let probe {
                    Text(verbatim: "对象 ID：\(probe.id)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button("让父级保留当前对象") { onRetain(probe) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            if probe == nil { probe = LifetimeProbe() }
        }
        .onAppear { print("[AppLab][view] lifetime content appear") }
        .onDisappear { print("[AppLab][view] lifetime content disappear") }
    }
}

private struct RetainedObjectPanel: View {
    let probe: LifetimeProbe?
    let release: () -> Void

    var body: some View {
        GroupBox("父级额外引用") {
            VStack(alignment: .leading, spacing: 12) {
                if let probe {
                    Text(verbatim: "保留 ID：\(probe.id)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text("未保留对象")
                }
                Button("移除父级引用", action: release)
                    .disabled(probe == nil)
                Text("在 Xcode 控制台查看 [AppLab][memory] 的 init / deinit，按对象 ID 对照。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
