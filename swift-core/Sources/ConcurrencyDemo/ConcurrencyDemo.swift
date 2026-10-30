// 闸门隔离实验顺序，不靠 sleep 猜测两个任务何时到达挂起点。
actor Gate {
    private var opened = false
    private var parked = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            parked = true
            let ready = observers
            observers.removeAll()
            for observer in ready { observer.resume() }
        }
    }

    func waitUntilParked() async {
        guard !parked else { return }
        await withCheckedContinuation { observers.append($0) }
    }

    func open() {
        opened = true
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}

actor Counter {
    private var value = 0
    func increment() { value += 1 }
    func read() -> Int { value }
}

actor Inventory {
    private var available = 1
    func reserve(after gate: Gate, recheck: Bool) async -> Bool {
        guard available > 0 else { return false }
        await gate.wait()
        // recheck=false 是刻意保留的错误设计：它无数据竞争，却会超卖。
        if recheck && available <= 0 { return false }
        available -= 1
        return true
    }
    func read() -> Int { available }
}

func reservationExperiment(recheck: Bool) async -> (Int, Int) {
    let inventory = Inventory()
    let firstGate = Gate()
    let secondGate = Gate()
    let first = Task { await inventory.reserve(after: firstGate, recheck: recheck) }
    await firstGate.waitUntilParked()
    let second = Task { await inventory.reserve(after: secondGate, recheck: recheck) }
    await secondGate.waitUntilParked()
    await firstGate.open()
    await secondGate.open()
    let firstResult = await first.value
    let secondResult = await second.value
    let successes = [firstResult, secondResult].filter { $0 }.count
    return (successes, await inventory.read())
}

func square(_ value: Int) async -> Int { value * value }

@main
struct ConcurrencyDemo {
    static func main() async {
        print("== 顺序await与子任务 ==")
        let first = await square(2)
        let second = await square(3)
        print("顺序结果=\([first, second])")
        async let left = square(2)
        async let right = square(3)
        let joined = await [left, right]
        print("async let汇合=\(joined)")

        let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for value in 1...3 { group.addTask { await square(value) } }
            var finished: [Int] = []
            for await value in group { finished.append(value) }
            return finished
        }
        // 不假定完成顺序，也不用总耗时冒充并行证据。
        print("task group结果排序后=\(results.sorted())")

        print("== actor串行保护状态 ==")
        let counter = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 { group.addTask { await counter.increment() } }
        }
        print("计数=\(await counter.read())")

        print("== actor可重入 ==")
        let broken = await reservationExperiment(recheck: false)
        let repaired = await reservationExperiment(recheck: true)
        print("挂起后不复核：成功\(broken.0)，库存\(broken.1)")
        print("挂起后复核：成功\(repaired.0)，库存\(repaired.1)")

        print("== 取消与等待终结 ==")
        let worker = Task {
            defer { print("取消：执行清理") }
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 30_000_000_000)
            return 42
        }
        worker.cancel()
        do { print("取消：得到结果\(try await worker.value)") }
        catch is CancellationError { print("取消：调用方观察到CancellationError") }
        catch { print("取消：意外错误\(error)") }
    }
}
