import SwiftCore

enum OptionalExperiment {
    static func run() {
        // exactly 转换把范围失败表达为 Optional。
        let count = 3
        let ratio: Double = 0.5
        print("类型：\(type(of: count))，\(type(of: ratio))")
        print("窄整数转换失败：\(Int8(exactly: 300) == nil)")
        let pair = (completed: count, total: 6)
        print("元组剩余：\(Practice.remaining(completed: pair.completed, total: pair.total))")

        func parse(_ text: String) -> Int? {
            guard let value = Int(text), value >= 0 else { return nil }
            return value
        }
        for text in ["3", "三个", "-1", "0"] {
            if let value = parse(text) {
                print("输入 \(text)：有值 \(value)")
            } else {
                print("输入 \(text)：缺失")
            }
        }
        struct Profile { var nickname: String? }
        let profile: Profile? = Profile(nickname: "Lin")
        print("可选链：\(profile?.nickname?.uppercased() ?? "匿名")")
        func fallback() -> Int {
            print("正在计算默认值")
            return 9
        }
        print("已有值：\(parse("0") ?? fallback())")
        print("缺失时：\(parse("三个") ?? fallback())")

        let nested = Optional("42").map { Int($0) }
        let flattened = Optional("42").flatMap { Int($0) }
        print("Optional map：\(String(describing: nested))，flatMap：\(String(describing: flattened))")

        // 查询字典增加一层 Optional，区分键不存在与有键但值为 nil。
        let saved: [String: Int?] = ["known": nil]
        switch saved["known"] {
        case .some(.none): print("known：键存在，值缺失")
        default: preconditionFailure("实验数据不符")
        }
        print("unknown：键不存在 \(saved["unknown"] == nil)")
        enum Response {
            case idle
            case loaded([Int])
            case failed(String)
        }
        let response = Response.loaded([1, 2])
        if case .loaded(let items) = response { print("模式匹配：\(items.count) 个元素") }
        let mixed: [Any] = [1, "Swift", true]
        for case let text as String in mixed { print("类型转换：\(text)") }
    }
}
