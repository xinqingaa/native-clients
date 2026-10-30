import Dispatch
import Synchronization

func callbackValue(_ completion: @escaping @Sendable (Int) -> Void) {
    DispatchQueue.global().async { completion(7) }
}
func bridgedValue() async -> Int {
    await withCheckedContinuation { continuation in
        callbackValue { continuation.resume(returning: $0) }
    }
}
enum StreamsExperiment {
    static func run() async {
        print("回调桥接：\(await bridgedValue())")
        // 先生产后消费，确定性展示容量为 2 时保留最新两项。
        let (stream, continuation) = AsyncStream<Int>.makeStream(
            bufferingPolicy: .bufferingNewest(2))
        for value in 1...4 {
            if case .dropped(let dropped) = continuation.yield(value) { print("缓冲丢弃：\(dropped)") }
        }
        continuation.finish()
        var received: [Int] = []
        for await value in stream { received.append(value) }
        print("finish 后仍可消费缓冲：\(received)")
        let (cancelledStream, producer) = AsyncStream<Int>.makeStream()
        let stopped = Mutex(false)
        producer.onTermination = { reason in
            if case .cancelled = reason { stopped.withLock { $0 = true } }
        }
        let consumer = Task { for await _ in cancelledStream {} }
        consumer.cancel()
        await consumer.value
        print("消费取消触发终止回调：\(stopped.withLock { $0 })")
        if case .terminated = producer.yield(9) { print("终止后拒收新值") }
    }
}
