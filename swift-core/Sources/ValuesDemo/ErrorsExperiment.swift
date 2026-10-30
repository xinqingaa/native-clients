enum ErrorsExperiment {
    static func run() {
        enum ParseFailure: Error { case notInteger, negative }
        func parse(_ text: String) throws(ParseFailure) -> Int {
            guard let value = Int(text) else { throw .notInteger }
            guard value >= 0 else { throw .negative }
            return value
        }
        func parseWithCleanup(_ text: String) throws(ParseFailure) -> Int {
            defer { print("清理：离开 \(text)") }
            defer { print("后注册的 defer 先执行") }
            return try parse(text)
        }
        for input in ["2", "x", "-1"] {
            do { print("解析 \(input)：\(try parseWithCleanup(input))") } catch {
                print("错误：\(error)")
            }
        }
        print("try? 丢弃原因：\((try? parse("x")) == nil)")
        print("try! 已知合法字面量：\(try! parse("3"))")
        func resultFromInput(_ text: String) -> Result<Int, ParseFailure> {
            do { return .success(try parse(text)) } catch { return .failure(error) }
        }
        let stored = resultFromInput("-1")
        switch stored {
        case .success(let value): print("结果：\(value)")
        case .failure(let error): print("保存的失败：\(error)")
        }
        func evaluate(_ operation: () throws -> Int) rethrows -> Int { try operation() }
        print("rethrows 非抛错调用：\(evaluate { 4 })")
        do { _ = try evaluate { try parse("x") } } catch { print("rethrows 传播：\(error)") }
    }
}
