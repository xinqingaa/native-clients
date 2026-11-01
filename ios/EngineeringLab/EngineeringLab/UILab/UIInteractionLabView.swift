import SwiftUI

struct UIInteractionLabView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("1. 文本、焦点与提交") { UIFormInputView() }
                NavigationLink("2. 拖动临时值与滚动竞争") { UIDragExperimentView() }
                NavigationLink("3. 属性动画与转场") { UIAnimationExperimentView() }
                NavigationLink("4. 局部动画范围与自定义插值") { UIAnimationScopeView() }
            }.navigationTitle("输入与动画")
        }
    }
}

private struct UIFormInputView: View {
    @State private var name = ""
    @State private var amount = ""
    @State private var result = "尚未提交"
    @State private var showHint = false
    @FocusState private var focus: Field?
    private enum Field: String, Hashable { case name, amount }

    var body: some View {
        Form {
            Section("原始文本在提交前保持原样") {
                TextField("名称（允许中文组合输入）", text: $name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .amount }
                TextField("数量", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .amount)
                Button("校验并提交", action: submit)
                Text(result).accessibilityIdentifier("ui-form-result")
            }
            Section("观察焦点与原始输入") {
                Text("焦点：\(focus?.rawValue ?? "无")")
                Text("原始数量：\(amount)")
                Button("编辑提示") { showHint = true }
                    .popover(isPresented: $showHint) {
                        Text("输入阶段保留原始文本，提交时再按当前地区解析数字。")
                            .padding().presentationCompactAdaptation(.popover)
                    }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("文本与焦点")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成输入") { focus = nil }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("复位") { name = ""; amount = ""; result = "尚未提交"; focus = nil }
            }
        }
    }

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
}

private struct UIDragExperimentView: View {
    @State private var simultaneous = false
    @State private var offset = CGSize.zero
    @GestureState private var dragging = CGSize.zero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("拖动与滚动同时识别", isOn: $simultaneous)
                Text("确认位置：\(Int(offset.width)), \(Int(offset.height))")
                Text("本次临时位移：\(Int(dragging.width)), \(Int(dragging.height))")
                UIDragSurface(offset: offset, dragging: dragging, simultaneous: simultaneous, gesture: drag)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("拖动位置")
                    .accessibilityValue("水平 \(Int(offset.width))，垂直 \(Int(offset.height))")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: offset.width += 10
                        case .decrement: offset.width -= 10
                        @unknown default: break
                        }
                    }
                Button("复位拖动") { offset = .zero }
                ForEach(0..<12) { index in
                    Text("用于观察滚动的内容 \(index)")
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(.blue.opacity(0.06))
                }
            }.padding()
        }.navigationTitle("拖动与滚动")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragging) { value, state, _ in state = value.translation }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
}

private struct UIDragSurface<G: Gesture>: View {
    let offset: CGSize
    let dragging: CGSize
    let simultaneous: Bool
    let gesture: G

    var body: some View {
        VStack {
            if simultaneous { surface.simultaneousGesture(gesture) }
            else { surface.gesture(gesture) }
        }.frame(height: 130).clipped().border(.orange)
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.orange.opacity(0.25))
            .overlay { Text("从这里开始拖动") }
            .frame(height: 70)
            .offset(x: offset.width + dragging.width, y: offset.height + dragging.height)
            .contentShape(Rectangle())
    }
}

private struct UIAnimationExperimentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var showDetails = false
    @State private var suppressMotion = false
    private var shouldReduce: Bool { reduceMotion || suppressMotion }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("本实验减少动态效果", isOn: $suppressMotion)
                Text(reduceMotion ? "系统 Reduce Motion：开启" : "系统 Reduce Motion：关闭")
                Text("业务目标：\(expanded ? "展开" : "收起")")
                Button("改变动画目标") {
                    withAnimation(shouldReduce ? nil : .spring(duration: 1.2)) { expanded.toggle() }
                }
                RoundedRectangle(cornerRadius: expanded ? 36 : 8)
                    .fill(.blue).frame(height: expanded ? 160 : 60)
                    .accessibilityLabel("动画目标")
                    .accessibilityValue(expanded ? "展开" : "收起")
                Button("插入或移除说明") {
                    withAnimation(shouldReduce ? nil : .easeInOut(duration: 1)) { showDetails.toggle() }
                }
                if showDetails {
                    Text("这份内容发生插入或移除；上面的图形一直存在。")
                        .padding().background(.blue.opacity(0.1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }.padding()
        }.navigationTitle("目标与中间画面")
    }
}

private struct UIAnimationScopeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var dimmed = false
    @State private var disablesSecond = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("第二块清除动画上下文", isOn: $disablesSecond)
                Button("同时改变高度、透明度和进度") {
                    expanded.toggle()
                    dimmed.toggle()
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text("同一更新中的高度与透明度")
                    RoundedRectangle(cornerRadius: 12).fill(.blue)
                        .frame(height: expanded ? 120 : 50).opacity(dimmed ? 0.3 : 1)
                    Text("第二块：局部 Transaction")
                    RoundedRectangle(cornerRadius: 12).fill(.orange)
                        .frame(height: expanded ? 120 : 50).opacity(dimmed ? 0.3 : 1)
                        .transaction { transaction in
                            if disablesSecond { transaction.animation = nil; transaction.disablesAnimations = true }
                        }
                    UIProgressShape(progress: expanded ? 0.9 : 0.2)
                        .fill(.green).frame(height: 30)
                    Text("目标进度：\(expanded ? "90%" : "20%")")
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.5), value: expanded)
            }.padding()
        }.navigationTitle("动画范围与插值")
    }
}

/// 使用显式 animatableData，在插值写入时把绘制进度限制在有效范围。
nonisolated private struct UIProgressShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = min(max(newValue, 0), 1) }
    }
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * progress, height: rect.height))
    }
}
