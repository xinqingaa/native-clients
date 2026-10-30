# Swift 实验验证

在仓库根目录运行：

```bash
swift test --package-path swift-core
```

现有测试使用 Swift Testing：

- [PracticeTests.swift](SwiftCoreTests/PracticeTests.swift)：保留原有纯函数检查。
- [ConcurrencyTests.swift](SwiftCoreTests/ConcurrencyTests.swift)：检查闸门打开后工作继续、打开状态保持；取消请求与清理终结分离；actor 重入时的超卖对照，以及恢复后复核的结果。

测试用闸门建立执行关系，不依赖固定 sleep 时长。2026-10-30 五个用例均通过；各 executable 的实际运行与编译诊断检查另记录在对应实验文档，不将测试数量当作全部知识覆盖。
