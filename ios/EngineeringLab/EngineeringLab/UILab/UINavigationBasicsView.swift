import SwiftUI

private enum UINavigationLesson: String, CaseIterable, Identifiable {
    case direct, path, presentation, coordinated
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self {
        case .direct: "1. 简单链接与返回"
        case .path: "2. 类型化路径与多级返回"
        case .presentation: "3. 基础模态与结果"
        case .coordinated: "4. 路由与编辑流程组合"
        }
    }
}

struct UINavigationLabView: View {
    @State private var lesson = UINavigationLesson.direct
    @State private var generation = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("导航子实验", selection: $lesson) {
                    ForEach(UINavigationLesson.allCases) { lesson in Text(lesson.title).tag(lesson) }
                }.pickerStyle(.menu)
                Spacer()
                Button("复位") { generation = UUID() }
            }.padding(.horizontal)
            Divider()
            lessonContent.id(generation)
        }
    }

    @ViewBuilder private var lessonContent: some View {
        switch lesson {
        case .direct: UIDirectNavigationView()
        case .path: UITypedPathView()
        case .presentation: UIBasicPresentationView()
        case .coordinated: UICoordinatedNavigationView()
        }
    }
}

struct UIDirectNavigationView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("进入文章详情") { UIDirectDetailView() }
                Text("本例由系统管理路径，下一组再把路径交给应用状态。")
                    .font(.caption)
            }.navigationTitle("简单链接")
        }
    }
}

private struct UIDirectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 24) {
            Text("详情仍在同一个导航栈内")
            Button("程序请求返回") { dismiss() }
        }.navigationTitle("文章详情")
    }
}

struct UITypedPathView: View {
    @State private var path: [UIRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("根页不在 path 内") {
                    NavigationLink("链接进入布局详情", value: UIRoute.article("layout"))
                    Button("程序进入导航详情") { path.append(.article("navigation")) }
                    Button("一次建立两级路径") { path = [.article("layout"), .related("layout")] }
                }
            }
            .navigationTitle("类型化路径")
            .navigationDestination(for: UIRoute.self) { route in
                switch route {
                case .article(let id):
                    VStack(spacing: 20) {
                        Text("当前文章 ID：\(id)")
                        NavigationLink("进入相关内容", value: UIRoute.related(id))
                        Button("返回根页") { path.removeAll() }
                    }.navigationTitle("详情 \(id)")
                case .related(let id):
                    VStack(spacing: 20) {
                        Text("相关内容属于：\(id)")
                        Button("返回一级") { if !path.isEmpty { path.removeLast() } }
                        Button("返回对应文章") {
                            if let index = path.firstIndex(of: .article(id)) {
                                path.removeSubrange(path.index(after: index)..<path.endIndex)
                            }
                        }
                        Button("替换成导航详情") { path = [.article("navigation")] }
                        Button("返回根页") { path.removeAll() }
                    }.navigationTitle("相关内容")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("path：\(String(describing: path))")
                .font(.caption).padding(8).frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .accessibilityIdentifier("ui-basic-path")
        }
    }
}

private struct UIBasicEditTarget: Identifiable {
    let id = UUID()
    let original: String
}

struct UIBasicPresentationView: View {
    @State private var showsHelp = false
    @State private var showsPreview = false
    @State private var showsBanner = false
    @State private var target: UIBasicEditTarget?
    @State private var saved = "原始文字"
    @State private var result = "尚未关闭编辑器"

    var body: some View {
        NavigationStack {
            Form {
                Section("系统呈现") {
                    Button("打开布尔 sheet") { showsHelp = true }
                    Button("打开 item 编辑器") { target = UIBasicEditTarget(original: saved) }
                    Button("打开全屏预览") { showsPreview = true }
                }
                Section("结果仍由父级拥有") {
                    Text("已确认：\(saved)").accessibilityIdentifier("ui-basic-saved")
                    Text(result)
                }
                Section("局部覆盖") {
                    Toggle("显示可穿透提示", isOn: $showsBanner)
                }
            }
            .navigationTitle("基础呈现")
            .sheet(isPresented: $showsHelp) { UIBasicHelpView() }
            .sheet(item: $target, onDismiss: { result = "编辑器已关闭" }) { target in
                UIBasicEditorView(original: target.original) { saved = $0 }
                    .id(target.id)
            }
            .fullScreenCover(isPresented: $showsPreview) { UIBasicHelpView() }
            .overlay(alignment: .top) {
                if showsBanner {
                    Text("局部提示：下方按钮仍可操作")
                        .padding().background(.regularMaterial).allowsHitTesting(false)
                }
            }
        }
    }
}

private struct UIBasicHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 24) {
            Text("dismiss 从这份呈现内容的环境读取")
            Button("关闭") { dismiss() }
        }.padding()
    }
}

private struct UIBasicEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    let save: (String) -> Void

    init(original: String, save: @escaping (String) -> Void) {
        self.draft = original
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form { TextField("本次草稿", text: $draft) }
                .navigationTitle("独立草稿")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { save(draft); dismiss() } }
                }
        }
    }
}
