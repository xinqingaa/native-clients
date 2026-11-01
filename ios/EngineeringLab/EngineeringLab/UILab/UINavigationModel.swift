import Foundation
import Observation

struct UIArticle: Identifiable, Equatable {
    let id: String
    let title: String
    var note: String
    var revision = 0

    static let samples = [
        UIArticle(id: "layout", title: "布局与画面", note: "观察尺寸提议与显示变换。"),
        UIArticle(id: "navigation", title: "导航与呈现", note: "路径描述当前浏览位置。"),
        UIArticle(id: "adaptive", title: "自适应与折叠", note: "改变空间，保留正在编辑的内容。"),
    ]
}

struct UIEditSession: Identifiable {
    let id = UUID()
    let articleID: String
    let originalNote: String
    let revision: Int

    init(article: UIArticle) {
        articleID = article.id
        originalNote = article.note
        revision = article.revision
    }
}

@MainActor @Observable
final class UICatalog {
    private(set) var articles = UIArticle.samples

    func article(_ id: String) -> UIArticle? { articles.first { $0.id == id } }

    /// 在真正提交时重新检查目标和版本，失败保留编辑器里的草稿。
    func commit(_ text: String, session: UIEditSession) -> String? {
        guard let index = articles.firstIndex(where: { $0.id == session.articleID }) else {
            return "条目已不存在，草稿仍保留。"
        }
        guard articles[index].revision == session.revision else {
            return "条目已经改变，请保留草稿并重新打开编辑器。"
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "内容不能为空。"
        }
        articles[index].note = text
        articles[index].revision += 1
        return nil
    }
}

enum UIFlow: String, CaseIterable, Identifiable {
    case library, saved
    var id: Self { self }
}

enum UIRoute: Hashable, Codable {
    case article(String)
    case related(String)
}

@MainActor @Observable
final class UIRouter {
    var flow = UIFlow.library
    var libraryPath: [UIRoute] = []
    var savedPath: [UIRoute] = []
    var error: String?

    func open(_ id: String, in target: UIFlow, catalog: UICatalog) {
        guard catalog.article(id) != nil else {
            error = "没有找到这个条目，当前路径未改变。"
            return
        }
        flow = target
        let route = UIRoute.article(id)
        // 本实验只抑制当前栈顶的重复详情；同一目标可在不同流程中出现。
        if target == .library {
            if libraryPath.last != route { libraryPath.append(route) }
        } else if savedPath.last != route {
            savedPath.append(route)
        }
    }

    func root(_ target: UIFlow) {
        if target == .library { libraryPath.removeAll() } else { savedPath.removeAll() }
    }
}

enum UIPresentation: Identifiable {
    case editor(UIEditSession)
    case help
    case preview

    var id: String {
        switch self {
        case .editor(let session): "editor-\(session.id)"
        case .help: "help"
        case .preview: "preview"
        }
    }

    var isSheet: Bool {
        if case .preview = self { return false }
        return true
    }
}

@MainActor @Observable
final class UIPresenter {
    var active: UIPresentation?
    private(set) var isClosing = false
    private(set) var pendingArticleID: String?
    var banner: String?

    func show(_ presentation: UIPresentation) {
        guard active == nil, !isClosing else { return }
        active = presentation
    }

    func close(thenOpen id: String? = nil) {
        guard active != nil else { return }
        pendingArticleID = id
        isClosing = true
        active = nil
    }

    /// 用户交互式关闭也经同一出口；不靠固定延时猜转场结束。
    func didDismiss() -> String? {
        let next = pendingArticleID
        pendingArticleID = nil
        isClosing = false
        return next
    }
}
