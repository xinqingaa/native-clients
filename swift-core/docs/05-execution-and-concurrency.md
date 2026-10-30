# Swift 实验 05｜调度与并发

这一组把队列和事件循环、任务作用域、隔离状态与异步数据流放在一起比较。ConcurrencyDemo 不传参数时运行全部内容；传 dispatch、runloop、tasks、actors 或 streams 可以只运行对应小节。所有输入为本地固定数据，不需要 App、Simulator 或外部服务。通用运行方法见[包 README](../README.md)。

```bash
swift run --package-path swift-core ConcurrencyDemo
```

入口的 runOnDispatchWorker 用 continuation 将同步实验交给 Dispatch 工作线程，再等待其完成。这样 DispatchGroup.wait 与手动 RunLoop 不会阻塞 Swift 协作执行器；其余子例使用 async 控制流。

## 队列与事件循环

两个子例分别观察队列提交关系和 RunLoop mode。均在 macOS 命令行执行，无需 iOS App。

```bash
swift run --package-path swift-core ConcurrencyDemo dispatch
swift run --package-path swift-core ConcurrencyDemo runloop
```

### Dispatch：提交、完成与等待

源码：[ConcurrencyDemo/DispatchExperiment.swift](../Sources/ConcurrencyDemo/DispatchExperiment.swift)。

```swift
let serial = DispatchQueue(label: "lesson.serial")
let group = DispatchGroup()
print("调用方：提交前")
serial.async(group: group) { print("串行任务 A") }
serial.async(group: group) { print("串行任务 B") }
print("调用方：已提交")
group.wait()
print("调用方：两项已结束")
serial.sync { print("sync：函数返回前执行完") }
print("调用方：sync 已返回")
```

serial 上的 A、B 按提交顺序执行。“调用方：已提交”与 A、B 的相对位置不固定：async 允许调用者继续，后台工作也可能很快开始。wait 返回后才有“两项已结束”；sync 中的打印一定早于“sync 已返回”。

这里在 Dispatch 工作线程上执行同步实验并等待另一条工作队列，没有阻塞 Swift 协作执行器，也没有向当前正在执行的串行队列同步提交。源码末尾另向并发队列提交两项工作，其输出可以是 1、2，也可以是 2、1；输出顺序不能证明实际 CPU 并行程度。

### RunLoop：到期不等于处理

源码：[RunLoopExperiment.swift](../Sources/ConcurrencyDemo/RunLoopExperiment.swift)。

```swift
let timer = Timer(fire: Date(timeIntervalSinceNow: -1), interval: 0, repeats: false) { _ in
    probe.record()
    print("Timer：回调执行")
}
let loop = RunLoop.current
loop.add(timer, forMode: .default)
defer { timer.invalidate() }
```

Timer 在注册前已到期，排除“没有触发只是尚未到期”的解释。probe 是用 Mutex 保护的计数对象，满足 Timer 回调的 Sendable 捕获要求；并不表示本实验的 Timer 会并行调用。

```swift
_ = loop.run(mode: RunLoop.Mode("LessonMode"), before: Date(timeIntervalSinceNow: 0.02))
print("运行其他mode后：\(probe.read())")
loop.run(until: Date(timeIntervalSinceNow: 0.1))
print("驱动default后：\(probe.read())")
```

LessonMode 没有注册源，run 可以立即返回，它不是精确等待 0.02 秒。到期的 Timer 注册在 default 中，因此自定义 mode 不会处理它；随后在 default 驱动时获得回调。0.1 秒是本次观察窗口，不是 Timer 的实时承诺。

### 预期与实际结果

2026-10-30 两个子例退出码均为 0。Dispatch 本次观察到“已提交、A、B”，检查其保证的先后关系，不要求所有打印保持固定顺序。

RunLoop 的预期与实际输出为：

```text
=== runloop ===
已注册，尚未驱动RunLoop：0
运行其他mode后：0
Timer：回调执行
驱动default后：1
一次性timer已失效：true
```

此处手动驱动独立命令行程序的 RunLoop。iOS App 的主线程循环由框架管理，不应将这段手动 run 嵌入 SwiftUI 的按钮或页面。common modes 与滚动场景的系统行为本单元没有设备验证。

官方资料：[Apple Run Loops](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html)。

队列和循环说明工作如何获得执行机会；下面的任务子例进一步观察异步工作的父子关系，以及谁负责等待结束。

## 任务组合与取消

源码：[TasksExperiment.swift](../Sources/ConcurrencyDemo/TasksExperiment.swift)，辅助对象：[AsyncGate.swift](../Sources/SwiftCore/AsyncGate.swift)。

```bash
swift run --package-path swift-core ConcurrencyDemo tasks
```

### 顺序依赖与结构化子任务

```swift
let a = await square(2)
let b = await square(a)
async let left = square(2)
async let right = square(3)
print("async let：\(await [left, right])")
```

square 立即返回平方值，前两个调用有数据依赖，结果依次是 4、16。async let 创建两个子任务，在消费结果时汇合为 4、9；这个小计算不用于测量耗时或证明并行。

```swift
let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
    for value in 1...3 { group.addTask { await square(value) } }
    var values: [Int] = []
    for await value in group { values.append(value) }
    return values
}
```

组按完成情况提供结果，源码只在展示时排序，不把排序后的数组当成完成顺序。另一个 throwing group 只有一个抛错子任务，在 group.next 消费时传播 rejected；组闭包因此抛错退出。多子任务场景还需考虑错误是否被消费、剩余任务是否合作取消，不能由此例推断首个失败会强制终止所有工作。

### 将取消与终结分开观察

```swift
let gate = AsyncGate()
let worker = Task {
    defer { print("worker：离开作用域，清理") }
    await gate.wait()
    try Task.checkCancellation()
    return 42
}
await gate.waitUntilWaiting()
worker.cancel()
print("取消已请求：\(worker.isCancelled)，尚未打开闸门")
await gate.open()
```

AsyncGate 是本实验特制的一次性 actor 闸门。wait 保存 continuation，open 恢复等待者；waitUntilWaiting 确认 worker 已挂起。它故意不处理取消，使取消后、开门前不会继续到 checkCancellation，也不会执行 defer。

开门后 worker 恢复，checkCancellation 抛错，退出作用域并清理。调用者 await worker.value 捕获取消错误时，任务已经终结。这个过程不靠 sleep 猜测执行进度；该闸门也不是可直接照搬的生产取消组件，拥有者必须最终开门以结束等待。

源码还创建一个执行 Task.sleep 的任务并立即取消，观察 sleep 可以响应取消，不需实际等待 30 秒。

### 普通 Task 与 detached 的上下文

```swift
enum Context { @TaskLocal static var label = "default" }
```

在 Context.$label.withValue 提供 parent 值的作用域中，普通 Task 继承此 task-local，detached 读取 default。源码保存两项句柄并等待结果，避免留下无主任务；这个例子观察上下文继承，不推断线程身份。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== tasks ===
顺序依赖：4 -> 16
async let：[4, 9]
task group（排序展示）：[1, 4, 9]
组错误在消费处传播：rejected
取消已请求：true，尚未打开闸门
worker：离开作用域，清理
调用方：观察取消且 worker 已终结
sleep：响应取消，无需等到期限
task-local：parent / default
```

Swift Testing 另验证取消标记设置后、开门前清理尚未发生，等待任务结束后清理已完成。该观察没有接入网络或设备资源，其关闭规则需在相应平台实现中验证。

任务可以并发推进，访问共享状态时还需要隔离规则。actor 子例保持相同的挂起与恢复观察方式，展示隔离并不自动提供跨 await 的业务事务。

## 隔离状态与重入

源码：[ActorsExperiment.swift](../Sources/ConcurrencyDemo/ActorsExperiment.swift)，重入对照：[ReservationExperiment.swift](../Sources/SwiftCore/ReservationExperiment.swift)。

```bash
swift run --package-path swift-core ConcurrencyDemo actors
```

### 隔离状态与跨域值

```swift
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
```

一百个子任务经 Counter 接口累加，等待组结束后读取 Snapshot。Snapshot 只保存 Int，是适合跨隔离传递的值。ActorsExperiment 的 run 标注为 MainActor，随后更新同域的 DisplayModel；该对象是普通模型，没有建立 iOS UI。

### 跨 await 的库存检查

```swift
public func reserve(after gate: AsyncGate, recheck: Bool) async -> Bool {
    guard available > 0 else { return false }
    await gate.wait()
    if recheck && available <= 0 { return false }
    available -= 1
    return true
}
```

available 是 Inventory actor 的隔离状态，初始为 1。辅助函数创建两次调用，各用一个闸门；确认两者均通过第一次检查并挂起后，让第一项完成，再恢复第二项。

recheck 为 false 时，两项都依赖旧检查，库存降为 -1。为 true 时，第二项恢复后发现库存已耗尽，返回 false。actor 始终串行执行这些片段，错误来自重入后沿用旧判断，而非未同步的内存访问。

辅助函数最终等待两项非结构化任务完成；闸门都由实验拥有者打开，测试能稳定复现相同顺序。

### 执行设置与编译约束

```swift
@concurrent
func calculate(_ value: Int) async -> Int { value * 2 }
```

concurrent 在 Swift 6.2 引入，明确使该函数运行在并发执行器上。返回 6 只验证计算结果，不证明固定线程。当前 Package 采用 Swift 6 language mode，未配置默认 MainActor 隔离或 NonisolatedNonsendingByDefault；Xcode App 模板可能采用不同默认设置，应按模块核对。

nonisolated 接口不能任意读写 actor 的隔离状态。Sendable 闭包也不能任意捕获可变的非 Sendable 引用；这两类失败在本篇最后的编译诊断中实际检查。sending、unsafe 绕过声明与进阶所有权本次不建立独立资源封装例子。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== actors ===
actor 计数与 MainActor 模型：100
不复核：成功 2，库存 -1
复核：成功 1，库存 0
@concurrent 计算结果：6
```

两种库存行为分别有 Swift Testing 用例，均已通过。命令行 MainActor 的执行不能直接替代 iOS 主线程 UI 观察；本例不使用 Thread.current 推断跨 await 的线程归属。

一次回调与持续事件流则需要进一步安排生产结束、消费取消和缓冲；下面继续使用同一入口观察这些关系。

## 回调与异步流

源码：[StreamsExperiment.swift](../Sources/ConcurrencyDemo/StreamsExperiment.swift)。回调和生产输入均为本地固定数据，没有外部业务接口。

```bash
swift run --package-path swift-core ConcurrencyDemo streams
```

### 一次回调接回 async

```swift
func callbackValue(_ completion: @escaping @Sendable (Int) -> Void) {
    DispatchQueue.global().async { completion(7) }
}
func bridgedValue() async -> Int {
    await withCheckedContinuation { continuation in
        callbackValue { continuation.resume(returning: $0) }
    }
}
```

callbackValue 的契约在这里由源码限定：提交一次工作、回调一次。continuation 将返回值交给等待中的任务，不需要阻塞线程等待。这里没有取消接口或多种竞争结果，因而不具备生产环境完整的取消桥接协议；若新增失败、取消和迟到回调，需要明确唯一恢复者。

### 有界缓冲与 finish

```swift
let (stream, continuation) = AsyncStream<Int>.makeStream(bufferingPolicy: .bufferingNewest(2))
for value in 1...4 {
    if case .dropped(let dropped) = continuation.yield(value) {
        print("缓冲丢弃：\(dropped)")
    }
}
continuation.finish()
```

先生产四项、再消费，让缓冲行为不依赖任务调度速度。容量为 2 且保留最新元素时，1、2 被丢弃，消费者最终取得 3、4。finish 表达不再生产，消费者仍可读完已有缓冲。yield 不会等待消费者逐项接收，因此有界缓冲不等于背压。

### 消费取消与终止回调

```swift
let (cancelledStream, producer) = AsyncStream<Int>.makeStream()
let stopped = Mutex(false)
producer.onTermination = { reason in
    if case .cancelled = reason { stopped.withLock { $0 = true } }
}
let consumer = Task { for await _ in cancelledStream {} }
consumer.cancel()
await consumer.value
```

没有生产元素时，迭代器等待下一项；任务取消使等待结束并触发 cancelled 终止回调。Mutex 保护回调写入的标记，主路径在任务结束后读取。取消可能早于第一次 next，实验不依赖它们的竞争顺序。

真实订阅可在 onTermination 中接入注销操作；这个例子只设置标记，没有证明任何真实外部资源已关闭。再 yield 一个值，结果为 terminated，表明该流已不接收新输入。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== streams ===
回调桥接：7
缓冲丢弃：1
缓冲丢弃：2
finish 后仍可消费缓冲：[3, 4]
消费取消触发终止回调：true
终止后拒收新值
```

把 bufferingNewest 改为 bufferingOldest 可比较保留最早元素时丢弃哪一项；仍保持先生产后消费，便于解释结果。需要无丢失、生产者等待消费者的协议时，应另选适合背压的接口或设计。

## 隔离与 Sendable 诊断

正常示例通过类型检查，下面用独立错误文件观察边界。它们不参与 Package 构建，从仓库根目录执行：

```bash
swiftc -swift-version 6 -typecheck swift-core/Diagnostics/ActorIsolation.swift
swiftc -swift-version 6 -typecheck swift-core/Diagnostics/SendableCapture.swift
```

[ActorIsolation.swift](../Diagnostics/ActorIsolation.swift) 在同步非隔离函数中直接读取 actor 的可变属性；[SendableCapture.swift](../Diagnostics/SendableCapture.swift) 则让 Sendable 闭包捕获没有并发安全契约的可变类实例。

2026-10-30，Apple Swift 6.4 的两条命令均返回 1，分别包含 actor-isolated property 'value' can not be referenced from a nonisolated context 与 capture of 'box' with non-Sendable type 'Box' in a '@Sendable' closure。错误文字可随工具链变化，判断依据是隔离访问和捕获规则。

前者可改为异步读取并使用 await，后者应选择适合的值、隔离或同步设计。修正后可以重新检查并恢复原文件；不要只增加 unchecked 标记，也不要把有意错误的文件加入正常 targets。
