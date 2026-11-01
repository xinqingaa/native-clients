import SwiftUI

enum UILabTopic: String, CaseIterable, Identifiable {
    case updates, layout, interaction, navigation, adaptive
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self {
        case .navigation: "导航与呈现"
        case .updates: "更新与列表"
        case .layout: "布局与绘制"
        case .interaction: "输入与动画"
        case .adaptive: "自适应与 Duo"
        }
    }
}

struct UILabView: View {
    @State private var topic = UILabTopic.updates

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    Picker("实验", selection: $topic) {
                        ForEach(UILabTopic.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                } label: {
                    Label("切换实验", systemImage: "list.bullet")
                }
                .accessibilityIdentifier("ui-lab-menu")
                Spacer()
                Text(topic.title).font(.headline)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
            switch topic {
            case .navigation: UINavigationLabView()
            case .updates: UIUpdatesLabView()
            case .layout: UILayoutLabView()
            case .interaction: UIInteractionLabView()
            case .adaptive: UIAdaptiveLabView()
            }
        }
    }
}
