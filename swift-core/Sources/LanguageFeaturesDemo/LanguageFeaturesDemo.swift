struct Point {
    var x: Int
}

final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}

struct Envelope {
    var box: Box
}

protocol Named {
    var name: String { get }
}

struct Person: Named {
    let name: String
}

func names<T: Named>(_ values: [T]) -> [String] {
    values.map(\.name)
}

func makePerson() -> some Named { Person(name: "Lin") }

enum LoadState {
    case idle
    case loaded([Int])
    case failed(String)
}

enum ParseFailure: Error {
    case notInteger
    case negative
}

func parseCount(_ text: String) throws(ParseFailure) -> Int {
    guard let value = Int(text) else { throw .notInteger }
    guard value >= 0 else { throw .negative }
    return value
}

func parseWithCleanup(_ text: String) throws -> Int {
    defer { print("defer：离开解析作用域") }
    return try parseCount(text)
}

final class Owner {
    let name: String
    var action: (() -> String)?
    init(name: String) { self.name = name }
    func installAction() {
        action = { [weak self] in self?.name ?? "owner 已释放" }
    }
    deinit { print("ARC：Owner 已释放") }
}

func makeReader() -> () -> String {
    let owner = Owner(name: "Lin")
    owner.installAction()
    let reader = owner.action!
    // 显式限定强引用至少存活至此；返回的闭包仅弱持有 owner。
    withExtendedLifetime(owner) { print("ARC：存活时读取 \(reader())") }
    return reader
}

@main
struct LanguageFeaturesDemo {
    static func main() {
        print("== 类型、Unicode 与 Optional ==")
        let text = "e\u{301}"
        print("字符数=\(text.count)，UTF8字节数=\(text.utf8.count)")
        let missing = Int("三个")
        let zero = Int("0")
        print("解析失败=\(missing == nil)，零有值=\(zero != nil)")
        print("默认值掩盖区别=\((missing ?? 0) == zero)")
        let saved: [String: Int?] = ["known": nil]
        switch saved["known"] {
        case .some(.none): print("嵌套Optional：键存在，值为nil")
        default: preconditionFailure("预期键存在")
        }
        print("缺失键=\(saved["unknown"] == nil)")

        print("== 值、引用与集合 ==")
        let original = Point(x: 1)
        var copy = original
        copy.x = 2
        print("结构体：原值=\(original.x)，副本=\(copy.x)")
        let first = Box(1)
        let alias = first
        alias.value = 2
        print("类：同一身份=\(first === alias)，原引用读取=\(first.value)")
        let wrapped = Envelope(box: Box(3))
        let wrappedCopy = wrapped
        wrappedCopy.box.value = 4
        print("结构体内引用仍共享=\(wrapped.box.value)")
        let values = [1, 2]
        var changed = values
        changed[0] = 9
        print("数组值独立：\(values)，\(changed)")
        let boxes = [Box(5)]
        let aliases = boxes
        aliases[0].value = 6
        print("数组内对象共享=\(boxes[0].value)")

        print("== 闭包、协议与模式 ==")
        var count = 1
        let live = { count }
        let snapshot = { [count] in count }
        count = 2
        print("捕获变量=\(live())，捕获列表快照=\(snapshot())")
        print("泛型名称=\(names([Person(name: "Lin")]))")
        let hidden = makePerson()
        let erased: any Named = Person(name: "Qin")
        print("some=\(hidden.name)，any=\(erased.name)")
        let state = LoadState.loaded([1, 2])
        switch state {
        case .idle: print("未加载")
        case .loaded(let items): print("枚举关联值数量=\(items.count)")
        case .failed(let message): print("失败=\(message)")
        }

        print("== 错误与清理 ==")
        for input in ["2", "三个", "-1"] {
            do { print("输入 \(input)：\(try parseWithCleanup(input))") }
            catch { print("输入 \(input)：\(error)") }
        }

        print("== ARC 与弱捕获 ==")
        let reader = makeReader()
        print("ARC：返回后读取 \(reader())")
    }
}
