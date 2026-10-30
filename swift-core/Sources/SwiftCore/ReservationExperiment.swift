public actor Inventory {
  private var available = 1
  public init() {}

  /// false 是错误对照：无数据竞争，但跨 await 的旧判断会失效。
  public func reserve(after gate: AsyncGate, recheck: Bool) async -> Bool {
    guard available > 0 else { return false }
    await gate.wait()
    if recheck && available <= 0 { return false }
    available -= 1
    return true
  }
  public func remaining() -> Int { available }
}

public func reservationExperiment(recheck: Bool) async -> (successes: Int, remaining: Int) {
  let inventory = Inventory()
  let firstGate = AsyncGate()
  let secondGate = AsyncGate()
  let first = Task { await inventory.reserve(after: firstGate, recheck: recheck) }
  await firstGate.waitUntilWaiting()
  let second = Task { await inventory.reserve(after: secondGate, recheck: recheck) }
  await secondGate.waitUntilWaiting()
  // 两次调用都通过初次检查后，明确让 first 先完成。
  await firstGate.open()
  let firstResult = await first.value
  await secondGate.open()
  let secondResult = await second.value
  return ([firstResult, secondResult].filter { $0 }.count, await inventory.remaining())
}
