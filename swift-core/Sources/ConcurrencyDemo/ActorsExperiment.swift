import SwiftCore

struct Snapshot: Sendable { let count: Int }
actor Counter {
    private var value = 0
    func increment() { value += 1 }
    func snapshot() -> Snapshot { Snapshot(count: value) }
}
@MainActor
final class DisplayModel {
    private(set) var count = 0
    func update(_ snapshot: Snapshot) { count = snapshot.count }
}
@concurrent
func calculate(_ value: Int) async -> Int { value * 2 }
@MainActor
enum ActorsExperiment {
    static func run() async {
        let counter = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 { group.addTask { await counter.increment() } }
        }
        let snapshot = await counter.snapshot()
        let model = DisplayModel()
        model.update(snapshot)
        print("actor 计数与 MainActor 模型：\(model.count)")
        let broken = await reservationExperiment(recheck: false)
        let repaired = await reservationExperiment(recheck: true)
        print("不复核：成功 \(broken.successes)，库存 \(broken.remaining)")
        print("复核：成功 \(repaired.successes)，库存 \(repaired.remaining)")
        print("@concurrent 计算结果：\(await calculate(3))")
    }
}
