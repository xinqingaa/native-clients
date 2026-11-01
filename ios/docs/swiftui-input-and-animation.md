# EngineeringLab｜文本、手势与动画过程

本组把输入、拖动和动画拆开学习。先接好数据与事件，再比较连续过程及其结束规则。机制见[第三章输入](../../docs/ios/03-ui-rendering-interaction.md#输入焦点与手势怎样推动状态)与[动画](../../docs/ios/03-ui-rendering-interaction.md#动画怎样连接目标与过程)，工具条件见[第三章运行入口](swiftui-ui-lab.md)。源码在 [UIInteractionLabView.swift](../EngineeringLab/EngineeringLab/UILab/UIInteractionLabView.swift)。

## 文本绑定、焦点与提交

进入“输入与动画 → 1. 文本、焦点与提交”。UIFormInputView 分别拥有 name、amount 和 result，两个输入字段通过 Binding 写回原始字符串。FocusState 用可选枚举表达当前字段：

```swift
@State private var name = ""
@State private var amount = ""
@FocusState private var focus: Field?
private enum Field: String, Hashable { case name, amount }

TextField("名称（允许中文组合输入）", text: $name)
    .focused($focus, equals: .name)
    .submitLabel(.next)
    .onSubmit { focus = .amount }

TextField("数量", text: $amount)
    .keyboardType(.decimalPad)
    .focused($focus, equals: .amount)
```

`focused` 注册字段与状态值的关系。用户选择名称后 focus 变为 name，名称的 Next 触发 onSubmit，再请求数量字段获得焦点。小数键盘不一定提供 Return，所以键盘工具栏另有“完成输入”，把 focus 设为 nil。

提交函数先检查名称，再按当前格式规则解析数量：

```swift
private func submit() {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result = "请填写名称"; focus = .name; return
    }
    guard let number = try? Decimal(amount, format: .number), number > 0 else {
        result = "请输入大于零的数量"; focus = .amount; return
    }
    focus = nil
    result = "已提交：\(name)，数量 \(number.formatted(.number))"
}
```

解析失败只反馈错误和焦点，不把用户原文改成零。名称、数量可以保留编辑中间状态，完成时才交出结果。这份实验没有定义货币、小数位截断和跨地区存储协议，键盘类型也不能代替输入校验。

依次执行空表单提交、名称非空但数量无效、有效正数提交。观察焦点、原始数量和结果。Form 与 scrollDismissesKeyboard 配合让内容可滚动并支持交互收起；“编辑提示”单独使用 popover，关闭后应能再次打开。

中文输入法还要检查拼音组合、候选选择、光标移动和中途改字。直接通过工具插入一个完整中文字符串只证明赋值显示，不能证明组合过程。硬件键盘下焦点可以存在而无软件键盘，应单独核对。

## 临时位移怎样变成确认位置

选择“2. 拖动临时值与滚动竞争”。页面显示 offset 与 dragging 两份值，画面位置是它们的和：

```swift
@State private var offset = CGSize.zero
@GestureState private var dragging = CGSize.zero

private var drag: some Gesture {
    DragGesture(minimumDistance: 12)
        .updating($dragging) { value, state, _ in
            state = value.translation
        }
        .onEnded { value in
            offset.width += value.translation.width
            offset.height += value.translation.height
        }
}
```

识别中 translation 更新临时值，松手正常结束后计入正式位置；GestureState 随识别结束或取消复位。第一次向右拖动再松手，预期正式水平值增加、临时值回零；第二次拖动从前次正式位置继续。固定 12 pt 是实验阈值，不是通用推荐。

卡片在 ScrollView 中，下面有足够内容供滚动。开关分别采用普通 gesture 与 simultaneousGesture，比较卡片外纵向滚动、卡片内纵向拖动和横向拖动。记录卡片位置和页面滚动是否一起改变；系统手势与容器竞争仍受实际环境影响，不把同时识别解释成任何组合都无冲突。

卡片允许移出其裁剪区域，“复位拖动”可恢复。可访问调整动作每次水平改变 10 pt，另有明确复位按钮；这提供替代操作入口，真实 VoiceOver 是否可用仍需实际验证。若未成功制造取消条件，只记录正常结束，不能把临时值正常归零写成已验证取消路径。

## 属性动画、转场与中途改变目标

选择“3. 属性动画与转场”。expanded 决定高度和圆角，按钮在动画上下文中改变目标：

```swift
withAnimation(shouldReduce ? nil : .spring(duration: 1.2)) {
    expanded.toggle()
}

RoundedRectangle(cornerRadius: expanded ? 36 : 8)
    .fill(.blue)
    .frame(height: expanded ? 160 : 60)
```

目标文字立即反映 expanded，而图形逐渐走向目标。连续点击可在运动中再次改变目标，最终画面应匹配最后目标，不要求每次都先完成旧过程。

说明文字使用独立 showDetails 和条件分支：

```swift
if showDetails {
    Text("这份内容发生插入或移除；上面的图形一直存在。")
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

其按钮用 withAnimation 修改 showDetails，所以插入和移除可以采用 transition；上面的圆角图形始终存在，属于同身份属性变化。两者分别操作，避免把相邻布局变化误认为同一动画机制。

“本实验减少动态效果”与系统 accessibilityReduceMotion 取或值，开启任意一项都会为本例传入 nil 动画，保留目标结果。局部开关便于重复对照，不冒充系统偏好已经切换。观察动画过程用于理解机制，流畅度仍需要帧时间测量。

## animation 的范围与 Transaction

选择“4. 局部动画范围与自定义插值”。一次按钮操作同时改变 expanded 和 dimmed。外层局部 VStack 配置：

```swift
.animation(reduceMotion ? nil : .easeInOut(duration: 1.5), value: expanded)
```

expanded 是触发值。它改变时，同一轮更新里的高度、透明度和进度都在该子树内，因此可能一起接收动画，而非只有直接使用 expanded 的属性参与。

第二块图形可通过自己的 Transaction 清除上下文：

```swift
.transaction { transaction in
    if disablesSecond {
        transaction.animation = nil
        transaction.disablesAnimations = true
    }
}
```

先保持开关开启，改变目标，比较第一块逐渐变化与第二块直接到达目标；再关闭开关重复。这里修改的是局部子树接收的动画信息，业务目标仍然在同一个按钮 action 中更新。

### 可动画数据怎样驱动自绘几何

同页 UIProgressShape 用一份 CGFloat 描述进度：

```swift
nonisolated private struct UIProgressShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = min(max(newValue, 0), 1) }
    }
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY,
                    width: rect.width * progress, height: rect.height))
    }
}
```

显式 animatableData 在插值写入时限制进度范围，path 使用当前插值数据计算宽度。目标为 20% 或 90%，中间宽度由动画提供，不通过定时器更新业务状态，setter 也没有业务副作用。

当前 SDK 还提供 @Animatable 宏，常规存储属性可交给宏合成；本例保留显式协议实现，是因为写入需要范围限制，并兼顾工程最低系统。多个插值量在新部署目标下可用 AnimatableValues，旧系统可采用 AnimatablePair，本例单值不需要组合类型。

## 实际验证

重写后的四个子实验已通过 2026-11-01 的 Debug / Release 构建；本轮未完成这些新入口的交互复测。因此，前文的焦点、校验、拖动、动画范围和进度操作均为可执行的实验步骤与预期，不记为本轮运行通过。

改写前的同日实现曾观察到焦点转移、12.5 提交、水平拖动和基本动画，这些历史观察不能覆盖新增的目标显示、局部减少动态效果、Transaction 与进度插值。中文组合输入、硬件键盘、系统减少动态效果、真实 VoiceOver 与手势取消也未完成验证。没有对动画帧时间作测量。
