import BuildLessonKit
import SwiftUI

// struct 定义一个值类型
// View 表示 SwiftUI 页面描述
// body 返回页面内容
// #Preview 为 Xcode 预览提供输入
struct ContentView: View {
    @State private var summary = "尚未生成"

    var body: some View {
        NavigationStack {
            Form {
                Section("当前产物") {
                    LabeledContent("编译条件", value: BuildIdentity.compilation)
                    LabeledContent("业务环境", value: BuildIdentity.environment)
                }
                Section("应用资源") {
                    Text(BuildIdentity.resource)
                }
                Section("本地模块") {
                    Text(summary)
                    Button("生成学习摘要") {
                        summary = LessonSummary.make(completed: 3, total: 6)
                        print("[EngineeringLab] \(summary)")
                    }
                }
            }
            .navigationTitle("工程基础实验学习")
        }
    }
}

#Preview {
    ContentView()
}
