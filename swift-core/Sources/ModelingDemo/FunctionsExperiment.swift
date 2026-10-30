enum FunctionsExperiment {
    static func run() {
        func scaled(_ value: Int, by factor: Int = 2) -> Int { value * factor }
        print("参数标签：\(scaled(3)) / \(scaled(3, by: 4))")
        let operation: (Int, Int) -> Int = scaled
        print("函数值：\(operation(2, 5))")
        func apply(to value: Int, transform: (Int) -> Int) -> Int { transform(value) }
        print("尾随闭包：\(apply(to: 3) { $0 + 1 })")
        var count = 1
        let live = { count }
        let snapshot = { [count] in count }
        count = 2
        print("捕获：变量 \(live())，创建时的值 \(snapshot())")
        func makeCounter() -> () -> Int {
            var value = 0
            return {
                value += 1
                return value
            }
        }
        let counter = makeCounter()
        print("逃出作用域的捕获：\(counter()) / \(counter())")
        struct ActionStore {
            var action: (() -> String)?
            mutating func save(_ action: @escaping () -> String) { self.action = action }
        }
        var store = ActionStore()
        store.save { "稍后调用" }
        print("保存的闭包：\(store.action?() ?? "无")")
        func choose(_ condition: Bool, fallback: @autoclosure () -> String) -> String {
            condition ? "已有结果" : fallback()
        }
        func expensive() -> String {
            print("默认表达式执行")
            return "备用结果"
        }
        print("autoclosure：\(choose(true, fallback: expensive()))")
        print("autoclosure：\(choose(false, fallback: expensive()))")
        func advance(_ value: inout Int) { value += 1 }
        var position = 3
        advance(&position)
        print("inout：\(position)")
    }
}
