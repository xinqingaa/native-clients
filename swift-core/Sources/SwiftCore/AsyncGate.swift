/// 实验用的一次性闸门：open 后所有等待者继续，后来的等待者直接通过。
/// 故意不响应任务取消，用于分开观察“取消请求”和“实际终结”。
public actor AsyncGate {
  private var opened = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var observers: [CheckedContinuation<Void, Never>] = []

  public init() {}

  public func wait() async {
    guard !opened else { return }
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
      let ready = observers
      observers.removeAll()
      for observer in ready { observer.resume() }
    }
  }

  /// 等待至少一个消费者已到达闸门，避免用 sleep 猜测执行进度。
  public func waitUntilWaiting() async {
    guard !opened, waiters.isEmpty else { return }
    await withCheckedContinuation { observers.append($0) }
  }

  public func open() {
    opened = true
    let pending = waiters + observers
    waiters.removeAll()
    observers.removeAll()
    for continuation in pending { continuation.resume() }
  }
}
