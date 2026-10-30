# Swift 实验 03｜协议与泛型

这组实验围绕同一个问题：当具体类型被抽象以后，哪些能力和类型关系仍可使用？所有内容位于[ProtocolsDemo.swift](../Sources/ProtocolsDemo/ProtocolsDemo.swift)，不传参数运行整组；也可选择 dispatch、abstraction、associated，分别观察派发、类型隐藏和关联类型。通用运行方法见[包 README](../README.md)。

```bash
swift run --package-path swift-core ProtocolsDemo
```

## 协议要求与扩展新增方法

只运行本节：`swift run --package-path swift-core ProtocolsDemo dispatch`。

```swift
protocol Named {
    var name: String { get }
    func requiredLabel() -> String
}
extension Named {
    func requiredLabel() -> String { "协议默认" }
    func extraLabel() -> String { "扩展方法" }
}
struct Person: Named {
    let name: String
    func requiredLabel() -> String { "Person 要求实现" }
    func extraLabel() -> String { "Person 同名方法" }
}
```

requiredLabel 是协议要求，Person 的遵循提供具体实现；extraLabel 仅在扩展增加。源码让同一 Person 分别经具体类型、any Named 调用。两次 requiredLabel 都选择 Person 实现，extraLabel 则分别选择 Person 同名方法和协议扩展方法。

同一子例还对比已经建立的类遵循：

```swift
class BaseNamed: Named { let name = "Base" }
final class ChildNamed: BaseNamed {
    func requiredLabel() -> String { "子类同名方法" }
}
```

BaseNamed 使用默认实现满足要求，ChildNamed 增加同名方法。具体子类调用找到该方法，经 any Named 调用却沿父类已经建立的遵循使用默认实现。父类没有声明这项类方法，子类也就没有通过 override 改写父类的方法入口。若需要这条动态重写关系，应让父类提供相应方法，并由子类显式重写。

## 泛型、some 与 any

只运行本节：`swift run --package-path swift-core ProtocolsDemo abstraction`。

```swift
func same<T: Equatable>(_ left: T, _ right: T) -> Bool { left == right }
func makePerson() -> some Named { Person(name: "Qin") }
```

same 保留两个参数的共同 T，不能随意把 Int 与 String 作为两种类型传入。makePerson 隐藏 Person 名称但固定底层类型；源码的 any Named 数组则同时保存 Person 和 Robot。两者可以调用 name，但保留的类型关系不同。

## 关联类型、条件遵循与擦除

只运行本节：`swift run --package-path swift-core ProtocolsDemo associated`。

```swift
protocol Source {
    associatedtype Item
    func read() -> Item
}
struct Constant<T>: Source {
    let value: T
    func read() -> T { value }
}
func readPair<S: Source>(_ source: S) -> (S.Item, S.Item) {
    (source.read(), source.read())
}
extension Constant: Equatable where T: Equatable {}
```

readPair 保留两项输出的关联类型。Constant 只在内部 T 可相等比较时遵循 Equatable。类型擦除则进一步把 Source 的具体类型藏到包装器后面：

```swift
struct AnyIntSource: Source {
    private let getter: () -> Int
    init<S: Source>(_ source: S) where S.Item == Int { getter = source.read }
    func read() -> Int { getter() }
}
```

初始化时仍用泛型约束保证输出是 Int，保存后只暴露统一的读取能力。这里捕获 read 方法，原来源需要的值或引用也随闭包保留；擦除没有自动复制引用对象或增加同步保护。本例观察接口关系，没有测量间接访问或分配成本。

## 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== dispatch ===
具体类型：Person 要求实现 / Person 同名方法
协议视角：Person 要求实现 / 扩展方法
继承遵循：子类同名方法 / 协议默认

=== abstraction ===
泛型：true，some：Qin
any 异构存储：["Lin", "R1"]

=== associated ===
关联类型：7/7，条件遵循：true
类型擦除：7
```

把 extraLabel 增加为协议要求，再运行，可观察协议视角调用的变化；修改后恢复。这个对照用于理解要求与扩展的区别，不把所有协议调用归为同一种派发。
