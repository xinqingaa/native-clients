@propertyWrapper
struct Clamped {
    private var value: Int
    var wrappedValue: Int {
        get { value }
        set { value = min(max(newValue, 0), 100) }
    }
    var projectedValue: String { "当前值 \(value)" }
    init(wrappedValue: Int) { value = min(max(wrappedValue, 0), 100) }
}
struct Settings { @Clamped var volume = 50 }
@resultBuilder
enum LinesBuilder {
    static func buildBlock(_ components: [String]...) -> [String] { components.flatMap { $0 } }
    static func buildExpression(_ expression: String) -> [String] { [expression] }
    static func buildOptional(_ component: [String]?) -> [String] { component ?? [] }
    static func buildEither(first: [String]) -> [String] { first }
    static func buildEither(second: [String]) -> [String] { second }
}
func lines(@LinesBuilder _ content: () -> [String]) -> [String] { content() }
enum CompositionExperiment {
    static func run() {
        var settings = Settings()
        settings.volume = 120
        print("包装值：\(settings.volume)，投影：\(settings.$volume)")
        let showDetail = true
        let output = lines {
            "标题"
            if showDetail { "详情" }
            if showDetail { "展开" } else { "折叠" }
        }
        print("构建器：\(output.joined(separator: " / "))")
    }
}
