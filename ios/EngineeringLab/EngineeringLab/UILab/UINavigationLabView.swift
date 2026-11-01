import SwiftUI

struct UICoordinatedNavigationView: View {
    @State private var catalog = UICatalog()
    @State private var router = UIRouter()
    @State private var presenter = UIPresenter()

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Picker("导航流程", selection: $router.flow) {
                Text("资料").tag(UIFlow.library)
                Text("收藏").tag(UIFlow.saved)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            if router.flow == .library {
                UIFlowView(flow: .library, catalog: catalog, router: router, presenter: presenter)
            } else {
                UIFlowView(flow: .saved, catalog: catalog, router: router, presenter: presenter)
            }
        }
        .sheet(item: sheetBinding, onDismiss: presentationDidDismiss) { presentation in
            switch presentation {
            case .editor(let session):
                UIEditorView(session: session, catalog: catalog, presenter: presenter)
                    .id(session.id)
            case .help:
                NavigationStack {
                    Text("当前只有一份呈现状态；编辑器与帮助互斥。")
                        .padding()
                        .navigationTitle("呈现帮助")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("关闭") { presenter.close() }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            case .preview: EmptyView()
            }
        }
        .fullScreenCover(isPresented: previewBinding, onDismiss: presentationDidDismiss) {
            NavigationStack {
                Text("这是一段独立的全屏流程，关闭后仍回到原来的导航位置。")
                    .padding()
                    .navigationTitle("全屏预览")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { presenter.close() }
                        }
                    }
            }
        }
        .alert(
            "路由没有执行",
            isPresented: Binding(
                get: { router.error != nil }, set: { if !$0 { router.error = nil } }
            )
        ) {
            Button("知道了", role: .cancel) { router.error = nil }
        } message: {
            Text(router.error ?? "")
        }
        .overlay(alignment: .top) {
            if let banner = presenter.banner {
                Text(banner)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("ui-banner")
            }
        }
    }

    private var sheetBinding: Binding<UIPresentation?> {
        Binding(
            get: { presenter.active?.isSheet == true ? presenter.active : nil },
            set: { value in
                if let value {
                    presenter.active = value
                } else if presenter.active?.isSheet == true {
                    presenter.close()
                }
            })
    }

    private var previewBinding: Binding<Bool> {
        Binding(
            get: {
                if case .preview = presenter.active { return true }
                return false
            },
            set: { if !$0, presenter.active?.isSheet == false { presenter.close() } })
    }

    private func presentationDidDismiss() {
        if let id = presenter.didDismiss() { router.open(id, in: .library, catalog: catalog) }
    }
}

private struct UIFlowView: View {
    let flow: UIFlow
    let catalog: UICatalog
    @Bindable var router: UIRouter
    let presenter: UIPresenter

    private var path: Binding<[UIRoute]> {
        flow == .library ? $router.libraryPath : $router.savedPath
    }

    var body: some View {
        NavigationStack(path: path) {
            List {
                Section("条目") {
                    ForEach(catalog.articles) { article in
                        NavigationLink(value: UIRoute.article(article.id)) {
                            Text(article.title)
                        }
                    }
                }
                Section("程序化路由") {
                    Button("进入布局详情") { router.open("layout", in: flow, catalog: catalog) }
                    Button("进入不存在的目标") { router.open("missing", in: flow, catalog: catalog) }
                }
                Section("呈现") {
                    Button("打开帮助 sheet") { presenter.show(.help) }
                    Button("打开全屏预览") { presenter.show(.preview) }
                    Button("显示可穿透提示") { presenter.banner = "提示只在当前实验内，下面控件仍可操作。" }
                    Button("清除提示") { presenter.banner = nil }
                }
                Section("当前路径") {
                    Text(verbatim: String(describing: path.wrappedValue)).font(.caption)
                }
            }
            .navigationTitle(flow == .library ? "资料" : "收藏")
            .navigationDestination(for: UIRoute.self) { route in
                switch route {
                case .article(let id):
                    UIArticleDetailView(
                        id: id, flow: flow, catalog: catalog, router: router, presenter: presenter)
                case .related(let id):
                    VStack(spacing: 20) {
                        Text("相关内容：\(catalog.article(id)?.title ?? id)")
                        Button("回到本流程根页") { router.root(flow) }
                    }
                    .navigationTitle("相关内容")
                }
            }
        }
    }
}

private struct UIArticleDetailView: View {
    let id: String
    let flow: UIFlow
    let catalog: UICatalog
    let router: UIRouter
    let presenter: UIPresenter

    var body: some View {
        Form {
            if let article = catalog.article(id) {
                Section(article.title) {
                    Text(article.note).accessibilityIdentifier("ui-article-note")
                    Text("版本：\(article.revision)")
                    Button("编辑草稿") { presenter.show(.editor(UIEditSession(article: article))) }
                }
                Section("导航操作") {
                    NavigationLink("继续进入相关内容", value: UIRoute.related(id))
                    Button("重复进入当前详情") { router.open(id, in: flow, catalog: catalog) }
                    Button("回到本流程根页") { router.root(flow) }
                }
            } else {
                ContentUnavailableView("条目已移除", systemImage: "doc.questionmark")
                Button("回到根页") { router.root(flow) }
            }
        }
        .navigationTitle("条目详情")
    }
}

private struct UIEditorView: View {
    let session: UIEditSession
    let catalog: UICatalog
    let presenter: UIPresenter
    @State private var draft: String
    @State private var error: String?
    @State private var confirmDiscard = false
    @FocusState private var editing: Bool

    init(session: UIEditSession, catalog: UICatalog, presenter: UIPresenter) {
        self.session = session
        self.catalog = catalog
        self.presenter = presenter
        self.draft = session.originalNote
    }

    private var isDirty: Bool { draft != session.originalNote }

    var body: some View {
        NavigationStack {
            Form {
                Section("局部草稿，完成后才提交") {
                    TextEditor(text: $draft)
                        .frame(minHeight: 140)
                        .focused($editing)
                        .accessibilityLabel("条目草稿")
                    if let error { Text(error).foregroundStyle(.red) }
                }
                Section {
                    NavigationLink("编辑规则") {
                        Text("输入先保存在这份会话中；提交时检查目标与版本。取消不修改资料。")
                            .padding()
                            .navigationTitle("编辑规则")
                    }
                    Button("保存并进入详情") { commit(openAfterDismiss: true) }
                }
            }
            .navigationTitle("编辑草稿")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if isDirty { confirmDiscard = true } else { presenter.close() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { commit(openAfterDismiss: false) }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { editing = false }
                }
            }
            .confirmationDialog("放弃本次草稿？", isPresented: $confirmDiscard, titleVisibility: .visible)
            {
                Button("放弃修改", role: .destructive) { presenter.close() }
                Button("继续编辑", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(isDirty)
    }

    private func commit(openAfterDismiss: Bool) {
        if let failure = catalog.commit(draft, session: session) {
            error = failure
            return
        }
        editing = false
        presenter.banner = nil
        presenter.close(thenOpen: openAfterDismiss ? session.articleID : nil)
    }
}
