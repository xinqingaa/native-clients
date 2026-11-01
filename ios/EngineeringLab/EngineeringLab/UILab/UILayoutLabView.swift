import SwiftUI

struct UILayoutLabView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("1. 尺寸、换行与 modifier 顺序") { UILayoutBasicsView() }
                NavigationLink("2. 占位、绘制与命中") { UIPlacementView() }
                NavigationLink("3. 自定义 Layout 的提议与放置") { UIMeasuredLayoutView() }
                NavigationLink("4. Shape、Path 与 Canvas") { UIDrawingView() }
                NavigationLink("5. 语言、方向与主题") { UILocalizedLayoutView() }
            }.navigationTitle("布局与绘制")
        }
    }
}

private struct UILayoutBasicsView: View {
    @State private var width = 240.0
    @State private var paddedBackground = true
    @State private var priority = false
    @State private var fixedHeight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("父级给内容的宽度：\(Int(width)) pt")
                Slider(value: $width, in: 160...300, step: 10)
                Toggle("背景包含 padding", isOn: $paddedBackground)
                UIModifierSample(paddedBackground: paddedBackground)
                    .frame(width: width, alignment: .leading).border(.orange)
                Toggle("长标题优先获得空间", isOn: $priority)
                Toggle("文字采用理想高度", isOn: $fixedHeight)
                HStack(alignment: .top) {
                    Text("SwiftUI 中会随可用宽度换行的长标题")
                        .fixedSize(horizontal: false, vertical: fixedHeight)
                        .layoutPriority(priority ? 1 : 0)
                        .border(.blue)
                    Text("另一段同样需要空间的说明").border(.green)
                }.frame(width: width, alignment: .leading).border(.orange)
                Text("橙框是外层范围；蓝绿框是子内容返回的范围。改变优先级后比较两段文字如何分配空间。")
                    .font(.caption)
            }.padding()
        }
        .navigationTitle("尺寸与修饰顺序")
        .toolbar { Button("复位") { width = 240; paddedBackground = true; priority = false; fixedHeight = false } }
    }
}

private struct UIModifierSample: View {
    let paddedBackground: Bool
    var body: some View {
        if paddedBackground {
            Text("Layout notes", tableName: "UILayout", comment: "布局对照标题")
                .padding(20).background(.blue.opacity(0.2))
        } else {
            Text("Layout notes", tableName: "UILayout", comment: "布局对照标题")
                .background(.blue.opacity(0.2)).padding(20)
        }
    }
}

private struct UIPlacementView: View {
    @State private var moved = false
    @State private var clips = false
    @State private var decorationBlocks = false
    @State private var rectangularHit = false
    @State private var taps = 0

    var body: some View {
        Form {
            Section("offset 保留原占位") {
                Toggle("移动画面", isOn: $moved)
                HStack {
                    Text("原布局空间").padding()
                        .offset(x: moved ? 45 : 0).border(.orange)
                    Text("相邻内容").padding().border(.blue)
                }
            }
            Section("可见像素与命中区域") {
                Toggle("裁剪圆形到 80 pt 高", isOn: $clips)
                Toggle("明确使用矩形命中区域", isOn: $rectangularHit)
                UIHitSample(clips: clips, rectangularHit: rectangularHit) { taps += 1 }
                Text("点击次数：\(taps)")
            }
            Section("覆盖层参与命中") {
                Toggle("装饰层拦截点击", isOn: $decorationBlocks)
                Button("底层按钮：\(taps)") { taps += 1 }
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .overlay {
                        Rectangle().fill(.orange.opacity(0.35))
                            .allowsHitTesting(decorationBlocks)
                            .accessibilityHidden(true)
                    }
            }
        }
        .navigationTitle("占位与命中")
        .toolbar { Button("复位") { moved = false; clips = false; decorationBlocks = false; rectangularHit = false; taps = 0 } }
    }
}

private struct UIHitSample: View {
    let clips: Bool
    let rectangularHit: Bool
    let tapped: () -> Void

    var body: some View {
        Circle().fill(.blue.opacity(0.25))
            .frame(width: 140, height: 140)
            .frame(height: clips ? 80 : 140)
            .clipped()
            .contentShape(rectangularHit ? AnyShape(Rectangle()) : AnyShape(Circle()))
            .onTapGesture(perform: tapped)
            .border(.orange)
            .accessibilityLabel("命中实验圆形")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tapped() }
    }
}

private struct UIMeasuredLayoutView: View {
    @Environment(\.dynamicTypeSize) private var inheritedTypeSize
    @Environment(\.layoutDirection) private var inheritedDirection
    @State private var width = 280.0
    @State private var largeText = false
    @State private var rtl = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Slider(value: $width, in: 160...300, step: 10)
                Text("给 Layout 的宽度：\(Int(width)) pt")
                Toggle("模拟辅助功能大字", isOn: $largeText)
                Toggle("模拟从右向左布局", isOn: $rtl)
                UIEqualWidthLayout {
                    Text("短标题").padding(8).frame(maxWidth: .infinity).background(.blue.opacity(0.15))
                    Text("需要更多空间的标题").padding(8).frame(maxWidth: .infinity).background(.green.opacity(0.15))
                }
                .frame(width: width)
                .dynamicTypeSize(largeText ? .accessibility2 : inheritedTypeSize)
                .environment(\.layoutDirection, rtl ? .rightToLeft : inheritedDirection)
                .border(.orange)
                Text("控制台 [UI03 layout] 输出提议、子项响应与最终 bounds。系统可以多次测量；不把调用次数当作布局轮数。")
                    .font(.caption)
            }.padding()
        }
        .navigationTitle("测量与放置")
        .toolbar { Button("复位") { width = 280; largeText = false; rtl = false } }
    }
}

/// 最小等宽容器；未指定或无限宽提议时使用有限的理想宽度。
struct UIEqualWidthLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = finiteWidth(proposal.width)
        let childWidth = widthPerChild(width, count: subviews.count)
        let sizes = subviews.map { $0.sizeThatFits(.init(width: childWidth, height: nil)) }
        let result = CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
        #if DEBUG
        print("[UI03 layout] proposal=\(proposal), children=\(sizes), result=\(result)")
        #endif
        return result
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let childWidth = widthPerChild(bounds.width, count: subviews.count)
        #if DEBUG
        print("[UI03 layout] bounds=\(bounds), placementWidth=\(childWidth)")
        #endif
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + CGFloat(index) * (childWidth + spacing), y: bounds.minY),
                       anchor: .topLeading, proposal: .init(width: childWidth, height: nil))
        }
    }

    private func finiteWidth(_ proposed: CGFloat?) -> CGFloat {
        guard let proposed, proposed.isFinite else { return 280 }
        return max(0, proposed)
    }

    private func widthPerChild(_ width: CGFloat, count: Int) -> CGFloat {
        max(0, (width - spacing * CGFloat(max(0, count - 1))) / CGFloat(max(1, count)))
    }
}

private struct UIDrawingView: View {
    @State private var high = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("改变中间采样点", isOn: $high)
                Text("Shape 用局部矩形生成 Path")
                UITriangleShape().stroke(.green, lineWidth: 3).frame(height: 100)
                Text("Canvas 将多个采样点绘制在同一块区域")
                UITrendDrawing(high: high)
                Text("改变采样值后，Canvas 闭包重新描述线段；每个点没有自动变成独立控件。")
                    .font(.caption)
            }.padding()
        }.navigationTitle("Shape 与 Canvas")
    }
}

nonisolated private struct UITriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct UITrendDrawing: View {
    let high: Bool
    var body: some View {
        Canvas { context, size in
            let samples: [CGFloat] = [0.7, 0.45, high ? 0.1 : 0.6, 0.3, 0.2]
            var path = Path()
            for (index, value) in samples.enumerated() {
                let point = CGPoint(x: size.width * CGFloat(index) / 4, y: size.height * value)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(.blue), lineWidth: 3)
        }
        .frame(height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("趋势摘要")
        .accessibilityValue(high ? "中间点升高，最终位置高于起点。" : "五个采样点，最终位置高于起点。")
    }
}

private struct UILocalizedLayoutView: View {
    @Environment(\.locale) private var inheritedLocale
    @Environment(\.layoutDirection) private var inheritedDirection
    @Environment(\.colorScheme) private var inheritedScheme
    @State private var language = 0
    @State private var rtl = false
    @State private var dark = false

    var body: some View {
        Form {
            Picker("演示资源语言", selection: $language) {
                Text("跟随系统").tag(0)
                Text("简体中文").tag(1)
                Text("English").tag(2)
            }
            Toggle("模拟 RTL", isOn: $rtl)
            Toggle("局部深色主题", isOn: $dark)
            VStack(alignment: .leading, spacing: 16) {
                Text("Layout notes", tableName: "UILayout", comment: "布局对照标题")
                    .font(.title)
                HStack { Text("开始"); Spacer(); Image(systemName: "arrow.forward") }
                Text(1234.5, format: .number)
                Text("仅标题提供中英资源；方向开关只改变排列，不翻译文字。")
                    .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .environment(\.locale, language == 1 ? Locale(identifier: "zh-Hans") :
                            language == 2 ? Locale(identifier: "en") : inheritedLocale)
            .environment(\.layoutDirection, rtl ? .rightToLeft : inheritedDirection)
            .environment(\.colorScheme, dark ? .dark : inheritedScheme)
        }
        .navigationTitle("语言与主题")
    }
}
