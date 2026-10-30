# Swift 实验 01｜类型与数据处理

这一组从输入怎样进入类型开始，连接 Optional、枚举、集合转换与错误处理。它们共同决定哪些状态被保留、哪些信息在转换中丢失。所有小例子归在 ValuesDemo 中，无参数运行整组，也可以按本篇小节给出的参数单独运行；通用工具链与编辑器说明见[包 README](../README.md)。

```bash
swift run --package-path swift-core ValuesDemo
```

## Optional 与状态表达

用几组独立输入观察 Swift 的转换、解包与状态表达。源码：[ValuesDemo/OptionalExperiment.swift](../Sources/ValuesDemo/OptionalExperiment.swift)。

```bash
swift run --package-path swift-core ValuesDemo optional
```

### 类型与转换

```swift
let count = 3
let ratio: Double = 0.5
print("窄整数转换失败：\(Int8(exactly: 300) == nil)")
let pair = (completed: count, total: 6)
```

count 推断为 Int，ratio 明确为 Double。Int8 的范围不能容纳 300，exactly 初始化返回 nil，让调用者选择缺失路径。元组成员通过标签访问；源码用其成员调用 SwiftCore 的公开函数，结果为 3。

### 解包、可选链与默认表达式

```swift
func parse(_ text: String) -> Int? {
    guard let value = Int(text), value >= 0 else { return nil }
    return value
}
```

Int 解析和非负规则都成功才返回值；这里有意将格式错误与负数合并为 nil。源码用 if let 消费结果，输入 0 仍是有值，不会因为数值为零走缺失分支。需要保留错误原因时改用错误类型，见后面的错误实验。

```swift
struct Profile { var nickname: String? }
let profile: Profile? = Profile(nickname: "Lin")
print("可选链：\(profile?.nickname?.uppercased() ?? "匿名")")
func fallback() -> Int { print("正在计算默认值"); return 9 }
print("已有值：\(parse("0") ?? fallback())")
print("缺失时：\(parse("三个") ?? fallback())")
```

可选链跳过缺失后的访问。右侧 fallback 只在左侧缺失时执行，因此两次合并只有一次额外打印。

### 嵌套缺失与模式匹配

Optional 转换还可以直接比较两个写法：

```swift
let nested = Optional("42").map { Int($0) }
let flattened = Optional("42").flatMap { Int($0) }
```

原始 Optional 与 Int 解析各引入一层状态。map 保留两层，flatMap 展平一次；把输入改为 "x" 后，前者仍有一个外层值，只是内层解析缺失，后者则直接缺失。这个对照有助于判断默认值和展平操作是否丢掉了需要保留的区别。

```swift
let saved: [String: Int?] = ["known": nil]
switch saved["known"] {
case .some(.none): print("known：键存在，值缺失")
default: preconditionFailure("实验数据不符")
}
```

外层 Optional 表达是否有键，内层表达保存的值是否缺失。相同的模式匹配还可以提取枚举关联值：

```swift
enum Response {
    case idle
    case loaded([Int])
    case failed(String)
}
let response = Response.loaded([1, 2])
if case .loaded(let items) = response { print("模式匹配：\(items.count) 个元素") }
```

loaded 保存成功数据，failed 保存失败信息，不需要让两份数据同时存在。源码还用 for case 从 Any 数组中选出字符串，复用类型匹配与绑定能力。

### 预期与实际结果

2026-10-30 运行退出码 0，完整输出如下：

```text
=== optional ===
类型：Int，Double
窄整数转换失败：true
元组剩余：3
输入 3：有值 3
输入 三个：缺失
输入 -1：缺失
输入 0：有值 0
可选链：LIN
已有值：0
正在计算默认值
缺失时：9
Optional map：Optional(Optional(42))，flatMap：Optional(42)
known：键存在，值缺失
unknown：键不存在 true
模式匹配：2 个元素
类型转换：Swift
```

可以把 profile 改为 nil，观察可选链的备用显示；把字典中的 known 项删除，观察 switch 为什么不再进入当前分支。不要直接保留会触发 preconditionFailure 的输入作为正常基线。

## 字符串与集合

源码：[ValuesDemo/CollectionsExperiment.swift](../Sources/ValuesDemo/CollectionsExperiment.swift)。例子分别观察 Unicode、集合转换、切片索引和惰性消费。

```bash
swift run --package-path swift-core ValuesDemo collections
```

### 字符与编码

```swift
let composed = "é"
let decomposed = "e\u{301}"
let text = "A👨‍👩‍👧‍👦B"
let middle = text.index(after: text.startIndex)
```

前两个字符串在字符比较中相等，但 UTF-8 字节数分别是 2 和 3。家庭 emoji 是一个扩展字形簇，text 有三个 Character。index(after:) 取得第二个字符位置，不是将字节偏移加一。

### 集合转换与缺失

```swift
let numbers = [1, 2, 3, 4]
print("map：\(numbers.map { $0 * 2 })")
print("filter：\(numbers.filter { $0.isMultiple(of: 2) })")
print("compactMap：\(["1", "x", "3"].compactMap(Int.init))")
print("reduce：\(numbers.reduce(0, +))")
```

map 保留元素数量，filter 筛选，compactMap 把 x 的解析失败丢弃，reduce 依次求和。若每条解析失败都要展示原因，compactMap 就不足以承担结果收集。字典和 Set 的输出在示例中先排序，以便稳定阅读；这不改变其原有遍历语义。

### 切片、复制和 lazy

```swift
let slice = numbers[1...2]
var copy = numbers
copy[0] = 9
let deferred = numbers.lazy.map { value in
    print("计算元素 \(value)")
    return value * 10
}
```

slice 的 startIndex 仍为 1，转为 Array 后才是 0。copy 的修改不改变 numbers；这个结果展示值语义，没有测量底层复制发生的时机或成本。lazy 的闭包直到读取首项才运行；它依然在消费过程中同步求值。

### 预期与实际结果

2026-10-30 运行退出码 0，输出如下：

```text
=== collections ===
Unicode：字符相等 true，字节数 2/3
字符串：3 个字符，中间是 👨‍👩‍👧‍👦
map：[2, 4, 6, 8]
filter：[2, 4]
compactMap：[1, 3]
reduce：10
字典：["a", "b"]，缺失 true
集合：[1, 2, 3]
切片起始索引：1，转数组后：0
数组值：[1, 2, 3, 4] / [9, 2, 3, 4]
已建立 lazy，尚未消费
计算元素 1
首项：10
```

把首项消费改成 Array(deferred)，可观察所有元素何时被求值；不要将这个额外打印实验解释为性能比较。长期保存小 ArraySlice 时还应留意对原存储的持有，需要长期保留这一小段时，可将其转换为 Array。

前面的 compactMap 已将无法解析的项丢弃。若需要向调用者交付失败原因，就需要把同一个转换问题继续组织成错误或结果，而不只是增加一个备用数值。

## 错误传播与作用域清理

源码：[ValuesDemo/ErrorsExperiment.swift](../Sources/ValuesDemo/ErrorsExperiment.swift)。格式错误、范围错误与正常输入分别经过同一清理路径。

```bash
swift run --package-path swift-core ValuesDemo errors
```

### typed throws 与捕获

```swift
enum ParseFailure: Error { case notInteger, negative }
func parse(_ text: String) throws(ParseFailure) -> Int {
    guard let value = Int(text) else { throw .notInteger }
    guard value >= 0 else { throw .negative }
    return value
}
```

该函数限定失败类型为 ParseFailure。do-catch 中的 error 因而保持此类型；普通 throws 则允许任意 Error。typed throws 不保证调用一定失败，也不改变同步调用关系。

### defer 的顺序

```swift
func parseWithCleanup(_ text: String) throws(ParseFailure) -> Int {
    defer { print("清理：离开 \(text)") }
    defer { print("后注册的 defer 先执行") }
    return try parse(text)
}
```

两个 defer 都在调用 parse 前注册。成功返回和抛错都会先运行后注册项，再打印清理；调用者只有在函数退出后才打印结果或错误。不要把这项保证扩展到进程终止或不可恢复陷阱。

### 将失败保存为值

```swift
func resultFromInput(_ text: String) -> Result<Int, ParseFailure> {
    do { return .success(try parse(text)) }
    catch { return .failure(error) }
}
func evaluate(_ operation: () throws -> Int) rethrows -> Int { try operation() }
```

Result 将这次操作的结果保存下来，之后再 switch 消费。rethrows 的调用是否需要 try 与传入闭包有关；源码分别调用不抛错闭包和 parse 的抛错闭包。try? 会丢弃失败原因；try! 例子只对已知合法字面量使用，默认运行不触发陷阱。

### 预期与实际结果

2026-10-30 运行退出码 0：

```text
=== errors ===
后注册的 defer 先执行
清理：离开 2
解析 2：2
后注册的 defer 先执行
清理：离开 x
错误：notInteger
后注册的 defer 先执行
清理：离开 -1
错误：negative
try? 丢弃原因：true
try! 已知合法字面量：3
保存的失败：negative
rethrows 非抛错调用：4
rethrows 传播：notInteger
```

把输入数组增加空字符串、0 等值，检查错误种类与清理顺序。Optional、Result 与 throws 的选择应保留调用方所需信息；前置条件失败不属于这里的可恢复错误实验。

## 类型与分支的编译诊断

下面两个文件不加入 Package targets，故意违反类型规则。从仓库根目录运行，预期都以非零退出：

```bash
swiftc -swift-version 6 -typecheck swift-core/Diagnostics/TypeMismatch.swift
swiftc -swift-version 6 -typecheck swift-core/Diagnostics/NonExhaustive.swift
```

[TypeMismatch.swift](../Diagnostics/TypeMismatch.swift) 将 String 赋给 Int；[NonExhaustive.swift](../Diagnostics/NonExhaustive.swift) 定义 idle、loaded 两个状态，却只处理 idle。2026-10-30 在 Apple Swift 6.4 上，退出码均为 1，分别报告 cannot convert value of type 'String' to specified type 'Int' 与 switch must be exhaustive。

可以分别改成整数、补全 loaded 分支，再执行同一命令确认诊断消失，之后恢复有意错误的基线。诊断不是正常示例失败，也不需要把这些文件加入构建。
