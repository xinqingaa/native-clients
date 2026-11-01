import SwiftUI

struct UIAdaptiveLabView: View {
    @State private var showsSplit = false
    @State private var showsRegions = false
    @State private var generation = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("适配子实验", selection: $showsSplit) {
                    Text("1. 容器与布局身份").tag(false)
                    Text("2. 分栏与草稿").tag(true)
                }.pickerStyle(.menu)
                Button("区域实验") { showsRegions = true }
                Button("复位") { generation = UUID() }
            }.padding(.horizontal)
            Divider()
            Group {
                if showsSplit { UISplitAdaptiveView() }
                else { UIAdaptiveFoundationsView() }
            }.id(generation)
        }
        .fullScreenCover(isPresented: $showsRegions) {
            UIDuoArrangementView()
                .safeAreaInset(edge: .top) {
                    HStack { Spacer(); Button("关闭区域实验") { showsRegions = false } }.padding()
                }
        }
    }
}

private struct UIAdaptiveFoundationsView: View {
    @State private var width = 280.0
    @State private var draft = "父级草稿"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("演示容器宽度：\(Int(width)) pt")
                Slider(value: $width, in: 180...300, step: 10)
                UIContainerEnvironmentView().frame(width: width).border(.orange)
                Text("ViewThatFits 先尝试完整候选")
                ViewThatFits(in: .horizontal) {
                    HStack { Text("保存当前正在编辑的全部内容"); Image(systemName: "checkmark.circle") }
                    Label("保存", systemImage: "checkmark.circle")
                }.frame(width: width, alignment: .leading).border(.orange)
                TextField("布局上层保存的草稿", text: $draft).textFieldStyle(.roundedBorder)
                Text("AnyLayout：子项自己的计数")
                let layout = width >= 240 ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
                layout {
                    UIAdaptiveLocalCounter(title: "A")
                    UIAdaptiveLocalCounter(title: "B")
                }.frame(width: width).border(.blue)
                Text("条件分支：另一组局部计数")
                if width >= 240 {
                    HStack { UIAdaptiveLocalCounter(title: "A"); UIAdaptiveLocalCounter(title: "B") }
                        .frame(width: width).border(.orange)
                } else {
                    VStack { UIAdaptiveLocalCounter(title: "A"); UIAdaptiveLocalCounter(title: "B") }
                        .frame(width: width).border(.orange)
                }
                Text("先给两组 A 加次数，再跨过 240 pt。父级草稿与子级计数分别观察。")
                    .font(.caption)
            }.padding()
        }
    }
}

private struct UIContainerEnvironmentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var diagnosticHeight = 104
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                Text("局部宽：\(Int(geometry.size.width)) pt")
                Text(verbatim: "size class: \(String(describing: sizeClass))")
                Text(verbatim: "type: \(typeSize)")
                Text("安全区域：上 \(Int(geometry.safeAreaInsets.top)) 下 \(Int(geometry.safeAreaInsets.bottom))")
                Text("前 \(Int(geometry.safeAreaInsets.leading)) 后 \(Int(geometry.safeAreaInsets.trailing))")
            }.font(.caption)
        }.frame(height: diagnosticHeight)
    }
}

private struct UIAdaptiveLocalCounter: View {
    let title: String
    @State private var count = 0
    var body: some View { Button("\(title)：\(count)") { count += 1 }.buttonStyle(.bordered) }
}

private struct UISplitAdaptiveView: View {
    @Environment(\.dynamicTypeSize) private var inheritedTypeSize
    @Environment(\.layoutDirection) private var inheritedDirection
    @State private var selectedID: String? = "layout"
    @State private var detailPath: [UIAdaptiveDestination] = []
    @State private var drafts = Dictionary(
        uniqueKeysWithValues: UIArticle.samples.map { ($0.id, $0.note) })
    @State private var largeText = false
    @State private var rtl = false
    @State private var inspector = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(UIArticle.samples) { article in
                    NavigationLink(value: article.id) { Text(article.title) }
                }
            }
            .navigationTitle("自适应条目")
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let id = selectedID,
                        let article = UIArticle.samples.first(where: { $0.id == id })
                    {
                        UIAdaptiveDetailView(
                            article: article,
                            draft: Binding(
                                get: { drafts[id] ?? "" }, set: { drafts[id] = $0 }
                            )
                        )
                        .navigationTitle(article.title)
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("检查布局", systemImage: "sidebar.right") { inspector.toggle() }
                            }
                            if #available(iOS 27.0, *) {
                                ToolbarOverflowMenu {
                                    Toggle("模拟辅助功能大字", isOn: $largeText)
                                    Toggle("模拟从右向左布局", isOn: $rtl)
                                }
                            } else {
                                ToolbarItem {
                                    Menu("布局选项", systemImage: "ellipsis.circle") {
                                        Toggle("模拟辅助功能大字", isOn: $largeText)
                                        Toggle("模拟从右向左布局", isOn: $rtl)
                                    }
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView("选择一个条目", systemImage: "sidebar.left")
                    }
                }
                .navigationDestination(for: UIAdaptiveDestination.self) { _ in
                    Text("继续深入的路径与列选择分别保存；改变宽度后观察返回关系。")
                        .padding().navigationTitle("详情内深入")
                }
            }
        }
        .inspector(isPresented: $inspector) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("状态归属").font(.headline)
                    Text("草稿按条目 ID 保存在分栏容器上层。改变列数、布局和选择不会提交或清空草稿。")
                    Text("当前选中：\(selectedID ?? "无")")
                    Text("详情深入层数：\(detailPath.count)")
                }.padding()
            }
        }
        .dynamicTypeSize(largeText ? .accessibility2 : inheritedTypeSize)
        .environment(\.layoutDirection, rtl ? .rightToLeft : inheritedDirection)
        .onChange(of: selectedID) { _, _ in detailPath.removeAll() }
    }
}

private enum UIAdaptiveDestination: Hashable { case notes }

private struct UIAdaptiveDetailView: View {
    let article: UIArticle
    @Binding var draft: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 650 && !typeSize.isAccessibilitySize
            let layout =
                wide
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 20))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            ScrollView {
                layout {
                    UIAdaptiveDraftView(draft: $draft)
                    UIAdaptiveContextView(width: geometry.size.width, sizeClass: sizeClass)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Text("草稿仅在本次实验内保留；切换实验会结束此状态。")
                .font(.caption).padding(8).frame(maxWidth: .infinity)
                .background(.regularMaterial)
        }
    }
}

private struct UIAdaptiveDraftView: View {
    @Binding var draft: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout notes", tableName: "UILayout", comment: "布局对照标题").font(.title2)
            TextField("编辑这份草稿后再改变窗口或折叠姿态", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("ui-adaptive-draft")
            NavigationLink("继续深入详情", value: UIAdaptiveDestination.notes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UIAdaptiveContextView: View {
    let width: CGFloat
    let sizeClass: UserInterfaceSizeClass?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前局部环境").font(.headline)
            Text("宽度：\(width, format: .number.precision(.fractionLength(0))) pt")
            Text(verbatim: "horizontalSizeClass: \(String(describing: sizeClass))")
            Text("650 pt 是本实验的内容断点。size class 表达较粗的环境类别，不等于精确宽度。")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct UIDuoArrangementView: View {
    @Environment(\.layoutDirection) private var inheritedDirection
    @State private var overlay = false
    @State private var note = "改变姿态和 arrangement 后核对这份文字。"
    @State private var includeInactive = false
    @State private var rtl = false

    var body: some View {
        VStack(spacing: 12) {
            Text("独立 Arrangement 实验").font(.headline)
            Toggle("使用 overlay arrangement", isOn: $overlay).padding(.horizontal)
            Toggle("连同非活动区域一起查询", isOn: $includeInactive).padding(.horizontal)
            Toggle("模拟 RTL", isOn: $rtl).padding(.horizontal)
            if #available(iOS 27.1, *) {
                UIDuoRegionsView(overlay: overlay, includeInactive: includeInactive, note: $note)
            } else {
                VStack(spacing: 20) {
                    UIArrangementPrimary(note: $note)
                    UIArrangementSecondary()
                }.padding()
                Text("分区 API 需要 iOS 27.1；当前使用纵向布局，编辑数据仍在父级。")
                    .font(.caption).padding()
            }
        }
        .environment(\.layoutDirection, rtl ? .rightToLeft : inheritedDirection)
    }
}

@available(iOS 27.1, *)
private struct UIDuoRegionsView: View {
    let overlay: Bool
    let includeInactive: Bool
    @Binding var note: String

    var body: some View {
        GeometryReader { geometry in
            let division = geometry.reservedRegions(kind: .division, options: includeInactive ? .includeInactive : [], layoutDirectionBehavior: .fixed)
            let occlusion = geometry.reservedRegions(kind: .occlusion, options: includeInactive ? .includeInactive : [], layoutDirectionBehavior: .fixed)
            VStack(spacing: 8) {
                Text("查询 division：\(division.count)，occlusion：\(occlusion.count)")
                    .font(.caption)
                    .accessibilityIdentifier("ui-region-count")
                if overlay {
                    ArrangementView {
                        UIArrangementPrimary(note: $note)
                    } secondary: {
                        UIArrangementSecondary()
                    }
                    .arrangementViewStyle(.overlay)
                } else {
                    ArrangementView {
                        UIArrangementPrimary(note: $note)
                    } secondary: {
                        UIArrangementSecondary()
                    }
                    .arrangementViewStyle(.split)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .overlay {
                Canvas { context, _ in
                    for region in division {
                        context.stroke(Path(region.frame), with: .color(region.isActive ? .orange : .gray), lineWidth: 3)
                    }
                    for region in occlusion {
                        context.stroke(Path(region.frame), with: .color(region.isActive ? .red : .gray), lineWidth: 3)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

private struct UIArrangementPrimary: View {
    @Binding var note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("主要内容").font(.title2)
            TextField("分区草稿", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Text("橙线：活动分割区域；红线：活动遮挡区域。零个区域也是有效结果。")
                .font(.caption)
            Spacer(minLength: 0)
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.blue.opacity(0.08))
    }
}

private struct UIArrangementSecondary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("辅助面板").font(.headline)
            Text("本页独立呈现，不嵌在分栏、列表或滚动容器中。")
            Spacer(minLength: 0)
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.green.opacity(0.12))
    }
}
