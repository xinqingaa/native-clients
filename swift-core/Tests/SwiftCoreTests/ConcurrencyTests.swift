import Synchronization
import Testing

@testable import SwiftCore

@Test func gateReleasesWorkAndStaysOpen() async {
  let gate = AsyncGate()
  let first = Task {
    await gate.wait()
    return 1
  }
  let second = Task {
    await gate.wait()
    return 2
  }
  await gate.waitUntilWaiting()
  await gate.open()
  #expect(await first.value == 1)
  #expect(await second.value == 2)
  await gate.wait()
}

@Test func cancellationDoesNotEndWorkUntilItObservesTheRequest() async {
  let gate = AsyncGate()
  let finished = Mutex(false)
  let worker = Task {
    defer { finished.withLock { $0 = true } }
    await gate.wait()
    try Task.checkCancellation()
    return 42
  }
  await gate.waitUntilWaiting()
  worker.cancel()
  #expect(worker.isCancelled)
  #expect(!finished.withLock { $0 })
  await gate.open()
  do {
    _ = try await worker.value
    Issue.record("取消后的工作不应交付结果")
  } catch is CancellationError {
    // 已观察取消并退出。
  } catch { Issue.record("非预期错误：\(error)") }
  #expect(finished.withLock { $0 })
}

@Test func actorReentrancyCanBreakInventoryWithoutASecondCheck() async {
  let result = await reservationExperiment(recheck: false)
  #expect(result.successes == 2)
  #expect(result.remaining == -1)
}

@Test func recheckingAfterSuspensionPreventsOverselling() async {
  let result = await reservationExperiment(recheck: true)
  #expect(result.successes == 1)
  #expect(result.remaining == 0)
}
