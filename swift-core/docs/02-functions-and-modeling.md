# Swift 实验 02｜函数与类型组织

同一组中先观察调用和捕获，再将状态放进类型，最后用包装器与构建器复用表达。它们都在回答行为怎样接收数据、保存状态和组合结果。ModelingDemo 不传参数时按本篇顺序运行全部子例；通用运行方法见[包 README](../README.md)。

```bash
swift run --package-path swift-core ModelingDemo
```

## 函数与闭包

源码：[ModelingDemo/FunctionsExperiment.swift](../Sources/ModelingDemo/FunctionsExperiment.swift)。

```bash
swift run --package-path swift-core ModelingDemo functions
```

### 标签、默认参数与函数值

```swift
func scaled(_ value: Int, by factor: Int = 2) -> Int { value * factor }
let operation: (Int, Int) -> Int = scaled
func apply(to value: Int, transform: (Int) -> Int) -> Int { transform(value) }
```

scaled 的第一个参数省略调用标签，第二个使用 by；调用时可省略默认参数。保存为 operation 后，其类型要求两个位置参数，调用不再使用 by 标签，也不能省略第二个参数。apply 接收同步转换闭包，源码用尾随写法取得 4。

### 捕获当前变量与捕获列表

```swift
var count = 1
let live = { count }
let snapshot = { [count] in count }
count = 2
func makeCounter() -> () -> Int {
    var value = 0
    return { value += 1; return value }
}
```

live 读取变量后来的值，snapshot 保存创建时的 Int 值。makeCounter 返回的闭包保存局部可变状态，两次调用得到 1、2；函数返回不表示闭包捕获的存储随之消失。若捕获的是类引用，快照仍共享对象内容。

### 保存行为与延迟求值

```swift
struct ActionStore {
    var action: (() -> String)?
    mutating func save(_ action: @escaping () -> String) { self.action = action }
}
func choose(_ condition: Bool, fallback: @autoclosure () -> String) -> String {
    condition ? "已有结果" : fallback()
}
```

save 允许调用结束后再使用闭包，所以参数标注 escaping。choose 将传入表达式包装成无参闭包，只在 condition 为 false 时求值；两种特性都没有创建线程或任务。

inout 的调用在源码中使用 advance(&position)，结果为 4。函数在调用期间获得可变访问，调用结束后这项访问也结束；它不允许将访问永久保存到逃逸闭包。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== functions ===
参数标签：6 / 12
函数值：10
尾随闭包：4
捕获：变量 2，创建时的值 1
逃出作用域的捕获：1 / 2
保存的闭包：稍后调用
autoclosure：已有结果
默认表达式执行
autoclosure：备用结果
inout：4
```

将 capture list 去掉，比较 snapshot 的输出；另建第二个 makeCounter 返回值，可验证两份捕获状态分别增长。对象强弱捕获与释放在 ARC 实验继续观察。

捕获可以保存一个函数的局部状态，命名类型则让这份状态的成员、初始化与访问规则更明确。下面使用同一入口的 members 子例继续观察。

## 成员与初始化

源码：[ModelingDemo/MembersExperiment.swift](../Sources/ModelingDemo/MembersExperiment.swift)。

```bash
swift run --package-path swift-core ModelingDemo members
```

### 值、身份与成员修改

```swift
struct Point {
    var x: Int
    mutating func move(by distance: Int) { x += distance }
}
final class Box {
    var value: Int
    init(_ value: Int) { self.value = value }
}
```

Point 副本的 move 不影响原值；两个 Box 引用则能看到同一次属性修改，=== 检查共同身份。let 固定类引用仍允许修改其 var 属性。带关联值的 enum 已在基础实验中展示。

### 初始化、观察器和 lazy

```swift
struct Progress {
    var completed: Int {
        didSet { print("didSet：\(oldValue) -> \(completed)") }
    }
    let total: Int
    var remaining: Int { total - completed }
    lazy var initialSummary = "首次访问时已完成 \(completed)"
    init?(completed: Int, total: Int) {
        guard total > 0, (0...total).contains(completed) else { return nil }
        self.completed = completed
        self.total = total
    }
}
```

初始化先校验计数规则，失败返回 nil。该初始化中的直接属性赋值不触发这里的 didSet；随后从 1 改为 2、从 2 改为 3 才打印观察器。remaining 每次重新计算，initialSummary 在第一次访问后保留文字。lazy 存储的首次访问可能修改结构体自身，因此这里的 progress 使用 var。

### 继承、扩展与模块

```swift
class Vehicle {
    let name: String
    init(name: String) { self.name = name }
    convenience init() { self.init(name: "默认车辆") }
    func describe() -> String { name }
}
final class Bicycle: Vehicle {
    override func describe() -> String { "自行车：\(name)" }
}
```

Bicycle 继承初始化器并重写 describe，经 Vehicle 引用调用仍得到重写结果。便利初始化委托给指定初始化。Point 的扩展提供计算属性和下标，没有增加存储。

源码普通 import SwiftCore 后调用 Practice.remaining，依赖其 public 可见性。private 限定声明所在范围，fileprivate 限定源文件，internal 限定模块，package 面向同包模块；public 提供外部使用，open 还涉及外部继承与重写。访问边界不由磁盘文件夹层次推断。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== members ===
值：1/3，引用：3，同一对象 true
didSet：1 -> 2
计算属性：4，lazy：首次访问时已完成 2
didSet：2 -> 3
再次访问：3，lazy：首次访问时已完成 2
可失败初始化：true
重写：自行车：City，便利初始化：默认车辆
扩展与下标：2 / 6
跨模块公开方法：4
```

改变首次读取 lazy 前后的赋值位置，可判断文字保存的是哪个时刻的 completed。需要验证跨模块不可访问时，可临时移除 Practice 或 remaining 的 public，再用 `swift build --package-path swift-core --target ModelingDemo` 查看诊断后恢复；本次只运行了公开接口的正常路径。

当多个属性需要重复相同的存取策略，或者多个表达式需要组合成一个结果时，可以再把这些重复规则交给包装类型或构建器。

## 包装器与构建器

源码：[CompositionExperiment.swift](../Sources/ModelingDemo/CompositionExperiment.swift)。子例观察两种语言组合能力。

```bash
swift run --package-path swift-core ModelingDemo composition
```

### 包装属性的存储与访问

```swift
@propertyWrapper
struct Clamped {
    private var value: Int
    var wrappedValue: Int {
        get { value }
        set { value = min(max(newValue, 0), 100) }
    }
    var projectedValue: String { "当前值 \(value)" }
    init(wrappedValue: Int) { value = min(max(wrappedValue, 0), 100) }
}
struct Settings { @Clamped var volume = 50 }
```

编译器为 volume 建立包装存储，普通 volume 访问经过 wrappedValue。初始化与后续赋值都将值限制在 0～100；$volume 读取 projectedValue。这个包装器不包含 UI 更新或持久化逻辑，效果完全来自这里的实现。

### 将代码块组合成结果

```swift
@resultBuilder
enum LinesBuilder {
    static func buildBlock(_ components: [String]...) -> [String] { components.flatMap { $0 } }
    static func buildExpression(_ expression: String) -> [String] { [expression] }
    static func buildOptional(_ component: [String]?) -> [String] { component ?? [] }
    static func buildEither(first: [String]) -> [String] { first }
    static func buildEither(second: [String]) -> [String] { second }
}
func lines(@LinesBuilder _ content: () -> [String]) -> [String] { content() }
```

buildExpression 将单个字符串转为数组，buildBlock 合并各部分；没有 else 的 if 对应可选部分，有 else 的分支对应 buildEither。调用端可以写：

```swift
let output = lines {
    "标题"
    if showDetail { "详情" }
    if showDetail { "展开" } else { "折叠" }
}
```

showDetail 来自调用方上下文。编译器转换这段代码，最后得到普通字符串数组；这里没有创建 SwiftUI 视图。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== composition ===
包装值：100，投影：当前值 100
构建器：标题 / 详情 / 展开
```

将赋值 120 改成负数，包装结果为 0；将 showDetail 改为 false，结果只保留“标题 / 折叠”。恢复后再运行基线。

宏的角色是编译期生成或补充代码，与这里的存取包装、构建器转换分别理解。本单元没有建立自定义宏插件 target；编写宏及其工具依赖属于后续扩展。
