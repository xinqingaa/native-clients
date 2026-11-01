import Foundation

@main
struct UILabChecks {
    @MainActor
    static func main() throws {
        let catalog = UICatalog()
        let router = UIRouter()
        router.open("layout", in: .library, catalog: catalog)
        router.open("layout", in: .library, catalog: catalog)
        try check(router.libraryPath == [.article("layout")], "栈顶重复详情不应重复入栈")
        router.open("adaptive", in: .saved, catalog: catalog)
        try check(router.libraryPath == [.article("layout")], "切换流程不能清空另一条路径")
        try check(router.savedPath == [.article("adaptive")], "收藏流程应保存独立路径")
        router.open("missing", in: .library, catalog: catalog)
        try check(
            router.flow == .saved && router.libraryPath == [.article("layout")], "无效路由不能切流程或污染路径")
        try check(router.error != nil, "无效路由应反馈失败")
        router.root(.saved)
        try check(router.savedPath.isEmpty && !router.libraryPath.isEmpty, "返回根页只影响指定流程")
        print("PASS: route validity / duplicate policy / independent paths")

        let article = catalog.articles[0]
        let first = UIEditSession(article: article)
        let stale = UIEditSession(article: article)
        try check(catalog.commit("  \n", session: first) != nil, "空草稿不能提交")
        try check(catalog.article(article.id)?.revision == 0, "校验失败不能改变模型")
        try check(catalog.commit("已确认的文字", session: first) == nil, "有效草稿应提交")
        try check(catalog.commit("迟到覆盖", session: stale) != nil, "旧编辑会话不能覆盖新版本")
        try check(catalog.article(article.id)?.note == "已确认的文字", "拒绝旧会话后保留已确认内容")
        let missing = UIEditSession(article: UIArticle(id: "removed", title: "已删除", note: "草稿"))
        try check(catalog.commit("不能写入", session: missing) != nil, "不存在的目标不能提交")
        print("PASS: invalid / stale / removed edit sessions preserve data")

        let presenter = UIPresenter()
        presenter.show(.editor(UIEditSession(article: article)))
        let original = presenter.active?.id
        presenter.show(.help)
        try check(presenter.active?.id == original, "互斥呈现不能覆盖正在编辑的会话")
        presenter.close(thenOpen: "layout")
        try check(presenter.active == nil && presenter.isClosing, "关闭时先清展示状态，等待转场完成")
        presenter.show(.preview)
        try check(presenter.active == nil, "关闭转场期间不能打开另一呈现")
        try check(presenter.didDismiss() == "layout", "关闭完成后才能交付下一路由")
        try check(presenter.didDismiss() == nil, "后续路由只能消费一次")
        presenter.show(.help)
        try check(presenter.active?.id == "help", "关闭完成后应允许新呈现")
        presenter.close()
        try check(presenter.didDismiss() == nil, "取消关闭不应产生路由")
        print("PASS: presentation exclusion / dismissal handoff / cancellation")
        print("UILab checks passed")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(description: message) }
    }
    private struct Failure: Error, CustomStringConvertible { let description: String }
}
