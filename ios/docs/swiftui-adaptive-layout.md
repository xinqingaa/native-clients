# EngineeringLab｜容器适配、分栏与独立区域布局

本组先用可控宽度学习局部空间与身份，再观察真实分栏，最后独立运行 Duo 区域和 ArrangementView。机制见[第三章自适应部分](../../docs/ios/03-ui-rendering-interaction.md#界面怎样适应窗口语言与-iphone-duo)，环境见[第三章运行入口](swiftui-ui-lab.md)。实现位于 [UIAdaptiveLabView.swift](../EngineeringLab/EngineeringLab/UILab/UIAdaptiveLabView.swift)。

## 容器宽度与环境不是同一个量

进入“自适应与 Duo”，默认选择“1. 容器与布局身份”。Slider 把演示容器限制为 180～300 pt，内部 GeometryReader 显示局部宽度，环境同时显示 horizontalSizeClass、Dynamic Type 与 safeAreaInsets。

先只移动 Slider。预期局部宽度变化，而 size class 不必跟着变化，因为它继承所在界面的环境，并不按照这个 frame 自动分类。再用真实窗口变化比较两者。Slider 是受控的局部实验，不代替旋转、折叠或分屏证据。

ViewThatFits 按声明顺序尝试完整与紧凑候选：

```swift
ViewThatFits(in: .horizontal) {
    HStack {
        Text("保存当前正在编辑的全部内容")
        Image(systemName: "checkmark.circle")
    }
    Label("保存", systemImage: "checkmark.circle")
}
.frame(width: width, alignment: .leading)
```

它比较水平方向理想尺寸能否放入提议，先选第一个能容纳的候选。减小宽度后观察文字表示是否切换；如当前字体下 180 pt 仍能容纳完整内容，也应记录事实，再使用更大系统文字制造空间条件，不把候选切换写成固定宽度保证。

## AnyLayout 与条件分支怎样影响子状态

同页有两组 A/B 按钮，各自子 View 内有局部 State count，父级另有共享草稿。第一组只替换布局算法：

```swift
let layout = width >= 240
    ? AnyLayout(HStackLayout())
    : AnyLayout(VStackLayout())

layout {
    UIAdaptiveLocalCounter(title: "A")
    UIAdaptiveLocalCounter(title: "B")
}
```

第二组使用 if/else 分别创建 HStack 和 VStack，内部再次创建自己的计数按钮。先给两组 A 各加两次，编辑父级草稿，再把宽度跨过 240 pt。

预期 AnyLayout 的子状态继续关联原身份，条件分支中的局部状态重新建立；两者之外的父级草稿都可保留。这个对照同时观察“子树连续性”和“上层存储仍在”，避免只凭草稿保留就断言整段交互状态未重建。顶部复位会结束整个当前子实验状态，适合重新比较。

## 分栏怎样保存选择、深入路径与草稿

顶部选择“2. 分栏与草稿”。UISplitAdaptiveView 拥有 selectedID、detailPath 和 drafts 字典，三者回答不同问题：当前看哪个条目、在详情上继续深入了几层、每个条目编辑到什么内容。

```swift
@State private var selectedID: String? = "layout"
@State private var detailPath: [UIAdaptiveDestination] = []
@State private var drafts = Dictionary(
    uniqueKeysWithValues: UIArticle.samples.map { ($0.id, $0.note) }
)
```

侧栏 List(selection:) 与 NavigationLink(value:) 共同连接选择，详情根据 selectedID 查文章，并将同一字典项的 Binding 交给编辑区域。改选目标时清空 detailPath，使新目标回到自己的详情根页；宽度改变本身不清空选择和草稿。

详情使用自己的局部 GeometryReader，达到 650 pt 且不属于辅助功能字号时，编辑区与说明并列；其余纵排。650 是当前内容的演示断点。详情底部 safeAreaInset 预留说明位置，背景与前景避让分别处理，没有再次手工扣除同一 inset。

先编辑布局条目，改选导航条目写不同文字，再切回。之后隐藏侧栏、改变窗口或设备姿态，观察局部宽度、排列和文字；进入“继续深入详情”后再比较返回关系。inspector 与工具栏选项按当前系统提供可达操作，大字与 RTL 模拟关闭后恢复继承环境。

本例不提供多 Scene 或状态持久化。宽窄转换能保留这些存储，也不能单独证明所有焦点、选择区与滚动像素都保留。

## 区域与 ArrangementView 为什么独立全屏运行

顶部“区域实验”从稳定外层打开 fullScreenCover，内容不嵌在 NavigationSplitView、List 或 ScrollView 中。关闭入口也由稳定宿主提供。Apple 当前 ArrangementView 指导要求避免这些布局嵌套，因此本次修正了旧实现从分栏详情推入 arrangement 的组织。

iOS 27.1 及以上使用 ArrangementView，旧系统保留同一上层 note，回退为普通纵排；工程最低部署版本仍为 iOS 18.0。新工具栏接口也保留可用性分支。

```swift
ArrangementView {
    UIArrangementPrimary(note: $note)
} secondary: {
    UIArrangementSecondary()
}
.arrangementViewStyle(.split)
```

开关切换 split/overlay。split 通常将主次内容分配到不同区域，但受限条件下可能只显示主要内容；overlay 在平面环境叠放，在适当折叠条件下再分开。它没有管理导航路径。

两种样式当前由条件分支创建，所以分支切换可以重建子树；note 放在外层，使文字继续存在。焦点和文字选择区另行观察，不能据此宣称所有交互无缝延续。

### 区域坐标、活动状态与方向

GeometryReader 查询与自身相交的区域，并在同一范围的 Canvas 上画边框：

```swift
let division = geometry.reservedRegions(
    kind: .division,
    options: includeInactive ? .includeInactive : [],
    layoutDirectionBehavior: .fixed
)
let occlusion = geometry.reservedRegions(
    kind: .occlusion,
    options: includeInactive ? .includeInactive : [],
    layoutDirectionBehavior: .fixed
)
```

division 用活动橙色边框，occlusion 用活动红色边框，非活动区域用灰色。frame 可能部分超出局部边界，已包含 margins，不再次扩张。默认区域查询会镜像以配合布局方向，而 Canvas 直接使用几何坐标，所以这里显式 fixed，避免 RTL 下诊断框错位。将区域用于会自动镜像的自定义 Layout 时则要重新选择方向行为。

“连同非活动区域一起查询”改变观察集合，不强迫系统激活区域；“模拟 RTL”比较坐标诊断与布局方向。没有活动 division 时显示零是正常结果，不人为画中线。区域是布局输入，不是硬编码设备属性。

依次对照平面与部分折叠、split 与 overlay、active 与 includeInactive、LTR 与 RTL，记录实际姿态、数量与位置。普通旋转不能代替折叠验证；设备控制没有姿态能力时，应标注未执行。

## 工程前提与资料核验

2026-11-01 读取了 Info.plist、project.pbxproj 和配置来源：Debug/Release 通过 build setting 生成启动画面；iPad 声明四个方向；未声明 UIRequiresFullScreen；没有额外 xcconfig。UILab 没有 UIScreen.main、全局窗口枚举和设备类别推导布局的实现。本次保留这些配置，不为学习实验改变最低部署版本。

AnyLayout、ViewThatFits 和 NavigationSplitView 从 iOS 16 提供；reserved regions 与 ArrangementView 以本机公开 SDK 和 Apple 文档确认 iOS 27.1。核心依据为 [AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)、[ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)、[ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview)和[区域查询](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:))。

## 实际验证

旧实现于 2026-11-01 在 iPhone Duo / iOS 27.1 Simulator 观察过：展开后约 951×669 pt；隐藏侧栏使详情从约 547 增至 867 pt，跨过 650 断点后改为横排，草稿保留；Open 时活动 division 0、occlusion 1，Partially Open 后 division 1、occlusion 1。尺寸只描述当次窗口条件，不能当成设备固定常量。

本次修正了 Arrangement 的嵌套和区域方向，并加入基础身份对照。重写后的基础页已在同一 Simulator 打开：演示宽度与局部宽度均显示 280 pt，size class 为 regular，ViewThatFits 显示完整候选；两组 A 的局部计数都可从 0 增至 1。

本轮未完成 Slider 跨越 240 pt 的操作，因此 AnyLayout 保留与条件分支重建仍是机制分析和待运行的对照，不能用这次按钮计数证明。修正后的独立区域页、split / overlay、活动 / 非活动区域、RTL 坐标以及分栏变化未重新完成整组交互检查；旧区域观察不作为修正后实现全部通过的依据。相关源码已通过 Debug / Release 构建。

iOS 18 runtime、真实设备触摸与折叠、分屏、多 Scene、中文组合输入、VoiceOver 及摄像头激活遮挡未执行，不从模拟器的宽空间页面推断这些条件下的行为。
