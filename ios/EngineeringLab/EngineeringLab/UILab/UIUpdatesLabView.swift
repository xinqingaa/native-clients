import Observation
import SwiftUI

@MainActor @Observable
final class UIReadModel {
    var score = 0
    var message = "尚未改变说明"
}

struct UIUpdatesLabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("更新：从状态到读取位置") {
                    NavigationLink("1. 局部状态与绑定") { UIStateBindingView() }
                    NavigationLink("2. 父级传值与子级读取") { UIReadExperimentView() }
                }
                Section("列表：身份、存续与位置") {
                    NavigationLink("3. 行身份与移除") { UIIdentityExperimentView() }
                    NavigationLink("4. 普通与按需内容") { UILazyExperimentView() }
                    NavigationLink("5. 滚动目标与筛选") { UIScrollTargetsView() }
                }
            }
            .navigationTitle("更新与列表")
        }
    }
}

struct UIStateBindingView: View {
    @State private var count = 0

    var body: some View {
        Form {
            Section("父级拥有 count") {
                Text("父级读到：\(count)")
                UICountEditor(count: $count)
                Button("复位") { count = 0 }
            }
        }
        .navigationTitle("局部状态与绑定")
    }
}

private struct UICountEditor: View {
    @Binding var count: Int
    var body: some View { Stepper("子控件读到：\(count)", value: $count) }
}

private struct UIReadExperimentView: View {
    @State private var model = UIReadModel()
    @State private var resetID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                UIReadActions(model: model)
                UIReadPanel(model: model)
                UIParentReadsView(model: model)
                UIConditionalReadView(model: model).id(resetID)
            }.padding()
        }
        .navigationTitle("读取位置")
        .toolbar {
            Button("复位") {
                model = UIReadModel()
                resetID = UUID()
            }
        }
    }
}

private struct UIReadActions: View {
    let model: UIReadModel
    var body: some View {
        HStack {
            Button("增加分数") { model.score += 1 }
            Button("改变说明") { model.message += "！" }
        }.buttonStyle(.bordered)
    }
}

private struct UIReadPanel: View {
    let model: UIReadModel
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        VStack(alignment: .leading, spacing: 8) {
            Text("子级各自读取属性").font(.headline)
            UIScoreView(model: model)
            UIMessageView(model: model)
        }
    }
}

private struct UIScoreView: View {
    let model: UIReadModel
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        Text("分数：\(model.score)")
    }
}

private struct UIMessageView: View {
    let model: UIReadModel
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        Text(model.message)
    }
}

private struct UIParentReadsView: View {
    let model: UIReadModel
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        VStack(alignment: .leading, spacing: 8) {
            Text("父级先读取，再传普通值").font(.headline)
            UIValueScoreView(score: model.score)
        }
    }
}

private struct UIValueScoreView: View {
    let score: Int
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        Text("值输入：\(score)")
    }
}

private struct UIConditionalReadView: View {
    let model: UIReadModel
    @State private var showsScore = true
    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        VStack(alignment: .leading, spacing: 8) {
            Toggle("条件读取分数", isOn: $showsScore)
            if showsScore {
                Text("当前读取 score：\(model.score)")
            } else {
                Text("当前只读取 message：\(model.message)")
            }
        }
    }
}

private struct UIDemoRowItem: Identifiable {
    let id: Int
    let title: String
}

private struct UIIdentityExperimentView: View {
    @State private var items = (1...12).map { UIDemoRowItem(id: $0, title: "条目 \($0)") }
    @State private var nextID = 13
    @State private var usePosition = false
    @State private var hideFirst = false
    @State private var savedCounts: [Int: Int] = [:]
    @State private var rowGeneration = UUID()

    private var visibleItems: [UIDemoRowItem] { hideFirst ? items.filter { $0.id != 1 } : items }

    var body: some View {
        List {
            Section("先给条目 1 加次数，再改变数据") {
                Toggle("用位置作为行身份（错误对照）", isOn: $usePosition)
                Toggle("移除条目 1", isOn: $hideFirst)
                Button("头部插入") {
                    items.insert(UIDemoRowItem(id: nextID, title: "新条目 \(nextID)"), at: 0)
                    nextID += 1
                }
                Button("倒序") { items.reverse() }
                Button("明确重建行身份") { rowGeneration = UUID() }
                Text("行内次数随行身份存续；外部次数按条目 ID 保存在列表拥有者。")
                    .font(.caption)
            }
            Section("同一行中的两种存储") {
                if usePosition {
                    // 隔离的错误对照：插入和筛选会改变位置与业务对象的对应。
                    ForEach(Array(visibleItems.enumerated()), id: \.offset) { entry in
                        UICounterRow(title: entry.element.title, savedCount: countBinding(entry.element.id))
                            .id("\(entry.offset)-\(rowGeneration)")
                    }
                } else {
                    ForEach(visibleItems) { item in
                        UICounterRow(title: item.title, savedCount: countBinding(item.id))
                            .id("\(item.id)-\(rowGeneration)")
                    }
                }
            }.id("\(usePosition)-\(rowGeneration)")
        }
        .navigationTitle("身份与存续")
        .toolbar {
            Button("复位") {
                items = (1...12).map { UIDemoRowItem(id: $0, title: "条目 \($0)") }
                nextID = 13
                hideFirst = false
                savedCounts = [:]
                usePosition = false
                rowGeneration = UUID()
            }
        }
    }

    private func countBinding(_ id: Int) -> Binding<Int> {
        Binding(get: { savedCounts[id, default: 0] }, set: { savedCounts[id] = $0 })
    }
}

private struct UICounterRow: View {
    let title: String
    @Binding var savedCount: Int
    @State private var count = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Button("行内次数：\(count)") { count += 1 }
            Button("外部次数：\(savedCount)") { savedCount += 1 }
        }.buttonStyle(.borderless)
    }
}

private struct UILazyExperimentView: View {
    @State private var lazy = true
    @State private var generation = UUID()
    var body: some View {
        VStack {
            Toggle("使用 LazyVStack", isOn: $lazy).padding(.horizontal)
            Text("在控制台比较 [UI03 lazy] build 与 appear。滚动后再比较；不以次数推算内存。")
                .font(.caption).padding(.horizontal)
            ScrollView {
                if lazy {
                    LazyVStack { ForEach(0..<120) { UILazyRow(index: $0) } }
                } else {
                    VStack { ForEach(0..<120) { UILazyRow(index: $0) } }
                }
            }.id(generation)
        }
        .navigationTitle("普通与按需内容")
        .toolbar { Button("重新建立") { generation = UUID() } }
    }
}

private struct UILazyRow: View {
    let index: Int
    var body: some View {
        #if DEBUG
        let _ = print("[UI03 lazy] build \(index)")
        #endif
        Text("条目 \(index)")
            .frame(maxWidth: .infinity, minHeight: 60)
            .onAppear {
                #if DEBUG
                print("[UI03 lazy] appear \(index)")
                #endif
            }
    }
}

private struct UIScrollTargetsView: View {
    @State private var ids = Array(1...60)
    @State private var nextID = 0
    @State private var target: Int?
    @State private var onlyEven = false
    var visibleIDs: [Int] { onlyEven ? ids.filter { $0.isMultiple(of: 2) } : ids }

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { actions }
                VStack { actions }
            }
            Toggle("只看偶数", isOn: $onlyEven).padding(.horizontal)
            Text("当前目标：\(target.map(String.init) ?? "无")").font(.caption)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(visibleIDs, id: \.self) { id in
                        Text("滚动条目 \(id)")
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .id(id)
                    }
                }.scrollTargetLayout().padding(.horizontal)
            }.scrollPosition(id: $target, anchor: .top)
        }
        .navigationTitle("滚动目标")
        .toolbar {
            Button("复位") { ids = Array(1...60); nextID = 0; onlyEven = false; target = 1 }
        }
    }

    @ViewBuilder private var actions: some View {
        Button("定位第 20 项") { target = 20 }
        Button("定位第 21 项") { target = 21 }
        Button("头部插入") { ids.insert(nextID, at: 0); nextID -= 1 }
    }
}
