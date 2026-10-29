import Foundation

enum BuildIdentity {
    #if DEBUG
    static let compilation = "Debug 条件分支"
    #else
    static let compilation = "非 Debug 条件分支"
    #endif

    static var environment: String {
        Bundle.main.object(forInfoDictionaryKey: "LabEnvironment") as? String ?? "未配置"
    }

    static var resource: String {
        guard let url = Bundle.main.url(forResource: "LessonNote", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "资源缺失或无法读取"
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
