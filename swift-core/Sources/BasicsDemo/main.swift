import SwiftCore

// 一次普通调用：先产生 Int，再用它组成 String。
func makeSummary(completed: Int, total: Int) -> String {
    let remaining = Practice.remaining(completed: completed, total: total)
    return "已完成 \(completed) / \(total)，剩余 \(remaining)"
}

// 输入来自外部时，先处理缺失和范围，才调用有前置条件的计算。
func summaryFromInput(_ input: String, total: Int) -> String? {
    guard let completed = Int(input) else { return nil }
    guard total > 0, completed >= 0, completed <= total else { return nil }
    return makeSummary(completed: completed, total: total)
}

// 闭包作为参数传入，声明函数本身不会调用它。
func perform(action: () -> String) {
    print("动作开始")
    let result = action()
    print("动作结果：\(result)")
}

let total: Int = 6
var completed = 3
let before = makeSummary(completed: completed, total: total)
completed = 4
print("修改前保存的文本：\(before)")
print("修改后重新计算：\(makeSummary(completed: completed, total: total))")

let inputs = ["3", "三个", "7", "0"]
for input in inputs {
    if let summary = summaryFromInput(input, total: total) {
        print("输入 \(input)：\(summary)")
    } else {
        print("输入 \(input)：无法生成摘要")
    }
}

print("准备调用动作")
perform {
    makeSummary(completed: 3, total: total)
}
print("动作调用结束")
