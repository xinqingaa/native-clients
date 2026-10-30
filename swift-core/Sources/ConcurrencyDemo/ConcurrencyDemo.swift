import Dispatch
import SwiftCore

/// 阻塞式队列和手动 RunLoop 实验交给 Dispatch 工作线程，避免阻塞协作执行器。
func runOnDispatchWorker(_ work: @escaping @Sendable () -> Void) async {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            work()
            continuation.resume()
        }
    }
}

@main
struct ConcurrencyDemo {
    static func main() async {
        let selection = ExperimentSelection(["dispatch", "runloop", "tasks", "actors", "streams"])
        if selection.includes("dispatch") {
            await runOnDispatchWorker { DispatchExperiment.run() }
        }
        if selection.includes("runloop") {
            await runOnDispatchWorker { RunLoopExperiment.run() }
        }
        if selection.includes("tasks") { await TasksExperiment.run() }
        if selection.includes("actors") { await ActorsExperiment.run() }
        if selection.includes("streams") { await StreamsExperiment.run() }
    }
}
