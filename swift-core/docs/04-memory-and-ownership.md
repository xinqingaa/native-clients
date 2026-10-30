# Swift 实验 04｜内存与所有权

从外层值复制、内部对象共享，继续追踪对象与闭包之间的持有关系。MemoryDemo 不传参数运行整组；也可传 sharing、cycles、captures，只观察共享、引用环或强弱捕获。通用运行方法见[包 README](../README.md)。

```bash
swift run --package-path swift-core MemoryDemo
```

## 外层值与内部对象

源码：[MemoryDemo.swift](../Sources/MemoryDemo/MemoryDemo.swift)。单独运行本节用 `swift run --package-path swift-core MemoryDemo sharing`。

```swift
final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}
struct Envelope { let box: Box }
let original = Envelope(box: Box(1))
let copy = original
copy.box.value = 2
```

复制 Envelope 后，两份值仍保存同一个 Box 引用。数组中保存类实例也是如此；改变 aliases 的元素对象后，经 boxes 读取到 4。与集合实验中的 Int 数组修改对照，可以区分外层值复制与内部对象共享。

## 引用环与主动断开

单独运行引用环用 `swift run --package-path swift-core MemoryDemo cycles`；弱读取与后面的 unowned 对照归在 captures 子例。

```swift
final class Owner {
    let name: String
    var action: (() -> String)?
    init(_ name: String) { self.name = name }
    func installStrong() { action = { self.name } }
    func installWeak() { action = { [weak self] in self?.name ?? "已释放" } }
    deinit { print("释放：\(name)") }
}
```

installStrong 建立 Owner → action → Owner 的强引用环。cycleExperiment 离开 do 作用域后，只留下外部 weak 引用，但对象仍活着。经 weak 找到对象并清空 action 后，环解除，随后 weak 变为 nil。

weakReader 返回一个弱捕获闭包，原对象只被函数中的局部变量强持有。withExtendedLifetime 明确保证第一次读取期间对象存活；函数结束、返回闭包不再强持有对象，后一次读取得到备用文字。

## unowned 的寿命条件

单独运行强弱捕获对照用 `swift run --package-path swift-core MemoryDemo captures`。

```swift
final class Card {
    unowned let owner: Owner
    init(owner: Owner) { self.owner = owner }
}
```

这里由独立的 holder 强持有 Owner，并用 withExtendedLifetime 保证读取 Card.owner 时 holder 存活。unowned 不会变成 nil；让 Card 在 Owner 结束后继续读取会违反约定，本例默认不触发这种陷阱。

## 预期与实际结果

2026-10-30 Debug 运行退出码 0，观察如下：

```text
=== sharing ===
结构体内引用共享：2
数组内引用共享：4

=== cycles ===
外部持有结束后仍存活：true
释放：strong
断环后已释放：true

=== captures ===
存活时：weak
释放：weak
返回后弱读取：已释放
寿命约定成立时：unowned
释放：unowned
```

holder 与 card 都是子例中的局部值，本次观察到子例结束时 holder 释放。需要确认读取期间的寿命时仍以 withExtendedLifetime 的显式保证为准，不用某一份优化配置下的打印位置推断全部对象寿命。borrowing、consuming、非复制类型和 UnsafePointer 本次仅在核心正文说明定位；这里没有构造手动存储管理或跨语言资源封装。
