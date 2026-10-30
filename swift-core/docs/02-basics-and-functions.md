# Swift 02｜基础类型、函数与控制流

在 EngineeringLab 中，按钮把两个整数交给函数，接收一个字符串。先把这段关系放进不依赖 iOS 生命周期的程序，可以逐项观察变量、函数、解析与分支，避免同时猜测 Swift 语法和 SwiftUI 更新机制。

本单元的目标是能读懂一个声明、预测同步执行的顺序，并明确处理输入失败。它是语言基础的第一批内容；完整集合 API、类型设计、协议、泛型、错误、ARC 和并发将在后续语言单元展开。平台中的因果解释见 [iOS 01](../../docs/ios/01-language-runtime-concurrency.md)，App 的日志与断点操作统一见 [Xcode 使用与调试](../../ios/docs/project-started.md)。

2026-10-30 核对 Swift 官方资料。本单元使用 Apple Swift 6.4、Swift tools version 6.0 和 Swift 6 language mode，源码位于 [BasicsDemo/main.swift](../Sources/BasicsDemo/main.swift)。这是 macOS 上运行的独立命令行实验，不会创建另一个 iOS App，也不替代 EngineeringLab。

## 先运行同一个例子

在仓库根目录执行：

```bash
swift run --package-path swift-core BasicsDemo
```

第一次需要构建，随后执行程序。标准输出与构建进度可能出现在不同输出流；阅读下面以“修改前保存的文本”开头的程序输出即可。若提示找不到 Package.swift，检查是否指定 `--package-path swift-core`；命令行工具链配置见 [独立工程入口](01-project-and-run.md)。Xcode 安装或工具切换仍按环境说明手动处理。

代码有四个可观察的问题：保存过的字符串会不会跟着整数改变；文本能否解析为整数；解析成功是否就符合范围；传入的闭包何时执行。先预测每项结果，再运行核对。

## 常量、变量与类型

程序先声明：

```swift
let total: Int = 6
var completed = 3
```

`let` 声明常量，`var` 声明变量，`=` 提供初始化值。`total` 显式标注为 `Int`，`completed` 则从整数字面量推断为 `Int`。类型推断省去书写，不省去类型约束；后面可以写 `completed = 4`，不能写 `completed = "四"`。

本单元先认识几种常见类型：

| 表达 | 类型 | 当前含义 |
| --- | --- | --- |
| `3` | 此处推断为 `Int` | 整数计数 |
| `0.5` | 无其他上下文时通常推断为 `Double` | 浮点数，不能把任意浮点数直接当作 Int 参数 |
| `true` / `false` | `Bool` | 条件结果 |
| `"三个"` | `String` | 文本，不会自动转成整数 |
| `["3", "三个"]` | `[String]` | 按顺序保存多个字符串的数组 |
| `Int("3")` | `Int?` | 可能解析成功，也可能缺失的整数 |

Swift 的 `Int` 与 `Double` 不会在普通赋值中任意隐式互换，必要时显式转换并考虑精度或范围。字符串内的 `\(completed)` 是插值：计算其中表达式，把结果表达为文本；它不是订阅变量变化的机制。

当前例子保存一份摘要之后才改变整数：

```swift
let before = makeSummary(completed: completed, total: total)
completed = 4
```

`before` 保存当时返回的字符串。改变 `completed` 不会重跑已经结束的调用；只有后面再次调用，才会用 4 重新计算。这个行为帮助区分普通语言值与 UI 框架管理的更新关系。

## 函数声明与调用怎样对应

例子使用下面的方法包装现有纯函数：

```swift
func makeSummary(completed: Int, total: Int) -> String {
    let remaining = Practice.remaining(completed: completed, total: total)
    return "已完成 \(completed) / \(total)，剩余 \(remaining)"
}
```

`func` 引入函数名，圆括号声明参数，`-> String` 约束返回值。这里参数名同时作为调用标签，因此调用要写出 `completed:` 和 `total:`。函数体在调用时执行，局部 `remaining` 接收依赖方法返回的 `Int`，`return` 再把字符串交给外部。

`Practice.remaining` 中的点号表示通过 `Practice` 类型访问静态方法；`import SwiftCore` 让当前 executable 模块使用该模块的公开声明。这里先认识调用写法，Package 的 target 和产品集成由 [第 07 篇](../../docs/ios/07-engineering-foundations.md)解释。

参数也可以有不同的外部标签与内部名称：

```swift
func doubled(_ value: Int) -> Int {
    value * 2
}
let result = doubled(3)
```

`_` 省略外部标签，函数内部仍叫 `value`。仅包含一个返回表达式时可以省略 `return`；多语句的前一个函数明确写出 return。不要根据方法调用长得像 Dart，就省掉 Swift 所要求的标签。

### 作用域与执行顺序

一次同步调用中，先求得调用参数，再进入函数体，按控制流执行，返回后调用方继续。嵌套调用必须先取得结果，外层才能使用它。

`remaining` 属于函数体作用域，不能在顶层直接访问。两个函数都使用 `completed` 这个名字，也不意味着它们共享一个变量。当前参数为 Int 值，函数用自己的参数名接收本次输入；值与引用的完整语义会在类型单元继续说明。

## Optional：没有值是单独一种情况

输入文本可能是 `"3"`、`"三个"` 或 `"7"`。其中格式失败和范围失败是两个问题：`Int("三个")` 没有整数；`Int("7")` 有整数，但在总量为 6 时违反示例规则。

```swift
func summaryFromInput(_ input: String, total: Int) -> String? {
    guard let completed = Int(input) else { return nil }
    guard total > 0, completed >= 0, completed <= total else { return nil }
    return makeSummary(completed: completed, total: total)
}
```

`String?` 允许函数返回字符串或 `nil`。第一条 `guard let` 尝试解析并绑定整数，失败时从当前函数返回 nil；成功后，新常量 `completed` 在后续作用域可用。第二条 guard 检查范围，逗号连接的条件需要全部满足，失败同样提前返回。只有通过两关，才调用有内部前置条件的计算。

调用方使用 `if let summary = ...`，有结果时在 if 分支中使用解包后的 String，没有结果时进入 else。`if let` 绑定的名字仅在对应分支作用域可用，与 guard 成功后可继续使用不同。

`??` 可以在缺失时提供默认值，例如 `Int("三个") ?? 0`；这会失去解析失败与真正输入 0 的区别。`!` 强制解包则会在 nil 时失败。这两种写法都不能替代输入规则。

本例有意把各种失败合为 nil，因为当前调用方只需要“能否生成摘要”。若界面要分别提示“请输入整数”和“不能超过总量”，应该进一步返回带原因的结果或抛出可处理错误；这属于后续错误表达单元。

## 数组、循环与分支怎样组合

程序把四种输入放进一个 `[String]` 数组：

```swift
let inputs = ["3", "三个", "7", "0"]
for input in inputs {
    if let summary = summaryFromInput(input, total: total) {
        print("输入 \(input)：\(summary)")
    } else {
        print("输入 \(input)：无法生成摘要")
    }
}
```

`for ... in` 依次把每个元素交给循环体，每次调用都独立验证。当前代码同步执行，没有并行启动四个任务，也没有改变完成顺序的机制。

当需要按条件表达多种互斥情况时，可以进一步使用 `switch`；当重复次数由条件决定时再使用 `while`。当前只用一个循环与 if/guard，先把数据、分支和返回连接起来，不为覆盖所有语法而增加业务流程。

## 闭包：把行为作为参数传入

按钮动作使用闭包。先用不依赖 SwiftUI 的函数观察同一语言构造：

```swift
func perform(action: () -> String) {
    print("动作开始")
    let result = action()
    print("动作结果：\(result)")
}

perform {
    makeSummary(completed: 3, total: total)
}
```

`() -> String` 是函数类型：不接收参数，返回字符串。`action` 接收一段行为，执行到 `action()` 才调用它。尾随闭包让最后的闭包参数写在括号外；这里只有一个参数，所以调用也省略圆括号。

闭包内部使用外部 `total`，这是捕获当前上下文的一个例子。本例在 perform 返回前同步调用闭包，不保存它，也没有并发；不能据此推断任意异步回调的捕获、对象寿命和线程保证。后续闭包与 ARC 单元再展开这些条件。

与 EngineeringLab 的区别在于触发者：本例由 perform 立即调用 action，App 由按钮机制在激活时调用动作。闭包语法相同，调用时机由接收行为的一方决定。

## 预期输出与验证边界

程序输出应为：

```text
修改前保存的文本：已完成 3 / 6，剩余 3
修改后重新计算：已完成 4 / 6，剩余 2
输入 3：已完成 3 / 6，剩余 3
输入 三个：无法生成摘要
输入 7：无法生成摘要
输入 0：已完成 0 / 6，剩余 6
准备调用动作
动作开始
动作结果：已完成 3 / 6，剩余 3
动作调用结束
```

重点观察：修改整数不追改旧文本；格式和范围都可能使函数返回 nil；0 在本例规则下合法；动作输出位于 perform 的开始与结束之间。运行记录见本节下方的实际检查，不把预计输出当作已执行证据。

可以先预测再修改 `completed = 4` 或 inputs 中的值，重复运行并恢复。不要把负数或超范围数据直接传给 `Practice.remaining` 来练习普通校验，因为其中 precondition 可能终止进程，无法继续后续输入。

### 实际检查

2026-10-30，在 Apple Swift 6.4、macOS arm64 环境执行：

| 检查 | 实际结果 | 覆盖范围 |
| --- | --- | --- |
| `swift run --package-path swift-core BasicsDemo` | 退出码 0，标准输出与上方十行一致 | 旧文本保留、重新计算、格式失败、范围失败、合法 0 和同步闭包顺序 |
| `swift test --package-path swift-core` | 退出码 0，现有 Swift Testing 用例 1 个通过 | 验证既有纯计算；没有新增镜像实现的单元测试 |

命令构建时生成的中间文件仍在已忽略的 `.build`。该实验只能证明独立程序中的行为；页面更新、Preview、调试器和真机行为需要工程中的独立证据。

## 官方参考

- [Swift：The Basics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/)
- [Swift：Strings and Characters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/)
- [Swift：Collection Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/)
- [Swift：Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/)
- [Swift：Control Flow](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/)
- [Swift：Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
