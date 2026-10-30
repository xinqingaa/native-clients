import SwiftCore

func square(_ value: Int) async -> Int { value * value }
enum Context { @TaskLocal static var label = "default" }
enum TasksExperiment {
    static func run() async {
        let a = await square(2)
        let b = await square(a)
        print("顺序依赖：\(a) -> \(b)")
        async let left = square(2)
        async let right = square(3)
        print("async let：\(await [left, right])")
        let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for value in 1...3 { group.addTask { await square(value) } }
            var values: [Int] = []
            for await value in group { values.append(value) }
            return values
        }
        print("task group（排序展示）：\(results.sorted())")
        enum Failure: Error { case rejected }
        do {
            try await withThrowingTaskGroup(of: Int.self) { group in
                group.addTask { throw Failure.rejected }
                _ = try await group.next()
            }
        } catch { print("组错误在消费处传播：\(error)") }
        let gate = AsyncGate()
        let worker = Task {
            defer { print("worker：离开作用域，清理") }
            await gate.wait()  // 实验闸门故意不响应取消。
            try Task.checkCancellation()
            return 42
        }
        await gate.waitUntilWaiting()
        worker.cancel()
        print("取消已请求：\(worker.isCancelled)，尚未打开闸门")
        await gate.open()
        do { print("worker 结果：\(try await worker.value)") } catch is CancellationError {
            print("调用方：观察取消且 worker 已终结")
        } catch { print("意外错误：\(error)") }
        let sleeping = Task { try await Task.sleep(for: .seconds(30)) }
        sleeping.cancel()
        do { try await sleeping.value } catch is CancellationError {
            print("sleep：响应取消，无需等到期限")
        } catch { print("意外错误：\(error)") }
        await Context.$label.withValue("parent") {
            let inherited = Task { Context.label }
            let detached = Task.detached { Context.label }
            print("task-local：\(await inherited.value) / \(await detached.value)")
        }
    }
}
