# iOS 开发环境与 Codex 工具配置

本文提供 Xcode、Swift、Simulator、Apple skills 和 Xcode MCP 的手动配置步骤。Codex CLI 的选择、安装和配置范围见[共用配置入口](../../shared/docs/codex-setup.md)。开始使用下文的 `codex_cli` 前，在同一个终端按该入口选择可运行的 CLI。

本文于 2026-10-28 对照 Apple、OpenAI 官方资料，并在 Xcode 27.1（27A9275）与 Codex CLI 0.165.0-alpha.1.2 上核对命令帮助。本轮只核对资料与只读入口，安装、导出、配置修改及工程验证由学习者按需执行。

## 安装与选择 Xcode

1. 通过 [Mac App Store](https://apps.apple.com/app/xcode/id497799835)或 [Apple Developer 下载页](https://developer.apple.com/download/)安装适配当前 macOS 的 Xcode。
2. 首次启动 Xcode，按界面完成许可和所需组件安装。仅安装 Command Line Tools 不能替代完整 Xcode 的 iOS 开发能力。
3. 在 Xcode 设置中下载所需 iOS Simulator runtime；具体菜单名称随版本变化。无需提前下载所有系统版本。

在终端检查当前选择：

```bash
xcode-select -p
xcodebuild -version
swift --version
xcrun simctl list runtimes
xcrun simctl list devices available
```

如果 `xcode-select -p` 指向独立 Command Line Tools 或另一份 Xcode，在确认目标安装路径后手动切换，例如：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

切换后重新检查上述命令。Swift 语言实验可使用 Xcode 自带工具链；本项目不要求另装一套全局 Swift。后续工程仍需分别记录编译器、Swift language mode、SDK 和最低运行系统版本。

## 安装 Apple 官方 skills

较新 Xcode 提供 skills 导出器，先核对本机命令是否存在及支持的选项：

```bash
xcrun --find mcpbridge
xcrun agent skills export --help
```

确认目标目录中已有内容后，手动导出到 Codex 的用户 skills 目录：

```bash
mkdir -p "$HOME/.agents/skills"
xcrun agent skills export --output-dir "$HOME/.agents/skills"
```

该命令会写入用户目录。遇到同名 skill 时，先比较并保留本地修改；确认需要覆盖时，才在导出命令中增加 `--replace-existing`。升级 Xcode 后需要重新导出以更新副本。

仓库早期配置记录中的 Xcode 27.1 包含以下 10 个 skills，实际名称与数量以当前导出结果为准：

| Skill | 作用 |
| --- | --- |
| `swiftui-specialist` | SwiftUI 实现指导 |
| `swiftui-whats-new-27` | 对应版本的 SwiftUI 新功能指导 |
| `app-intents-specialist` | App Intents 接入指导 |
| `app-intents-whats-new-27` | 对应版本的 App Intents 新功能指导 |
| `app-resizability` | 窗口与尺寸适配 |
| `building-document-based-swiftui-applications` | SwiftUI 文档型应用 |
| `device-interaction` | 设备交互工作流 |
| `modernize-tests` | 测试现代化工作流 |
| `audit-xcode-security-settings` | Xcode 安全配置检查 |
| `adopt-c-bounds-safety` | C 边界安全接入 |

检查实际导出文件，例如：

```bash
test -f "$HOME/.agents/skills/swiftui-specialist/SKILL.md"
```

目录内需保留随附资源。若旧位置 `~/.codex/skills` 中存在同名副本，先比较整个目录再处理，避免重复发现或丢失修改；新手动安装统一使用 `~/.agents/skills`。

在新 Codex 对话中检查能否发现这些 skills，必要时重启客户端。可以要求 Codex 列出与当前任务相关的 Apple skills 及其路径。它们按任务提供指导，不替代 Swift、Apple API 依据或运行验证；带版本号的内容需要另外核对 API 可用条件。

## 配置官方 Xcode MCP

### 允许 Xcode 提供工具

打开 Xcode，进入 **Xcode → Settings → Intelligence → Model Context Protocol**，允许 **Allow external agents to use Xcode tools**。该项可能是开关或下拉选项，按当前版本选择所需访问策略。

Xcode 提供工具服务，连接时需要保持运行。全局访问设置、当前代理的工程授权与具体工程是否打开分别检查。

### 登记到 Codex

先检查是否已有同名配置：

```bash
"$codex_cli" mcp list
```

没有 `xcode` 项时执行：

```bash
"$codex_cli" mcp add xcode -- /usr/bin/xcrun mcpbridge
"$codex_cli" mcp get xcode --json
```

已有该项时先查看其内容，再决定是否调整。等价的 TOML 片段为：

```toml
[mcp_servers.xcode]
command = "/usr/bin/xcrun"
args = ["mcpbridge"]
```

也可以在 Codex 桌面应用的 MCP servers 设置中手动添加：名称 `xcode`，传输方式 STDIO，命令 `/usr/bin/xcrun`，参数 `mcpbridge`。CLI、设置界面与 TOML 是登记同一配置的不同入口，选择一种即可。

保存后按客户端提供的入口重新连接 MCP 或重启客户端，再检查活动工具。

### 验证服务与工程访问

在终端检查：

```bash
xcrun mcp-server status
```

允许访问且服务运行时，应看到对应的 permission 与 running 状态；具体字段随版本变化。`Open workspaces: none` 只表示未打开工程。若服务未运行，先启动 Xcode，再检查其 MCP 设置与客户端连接。

目标工程建立后，在 Xcode 中打开实际 project、workspace 或 Swift Package，再让 Codex 查询 workspace。若提示 `This agent isn't approved to use Xcode's tools yet`，按提示通过 `XcodeOpenWorkspace` 打开该工程，并由学习者处理 Xcode 的目录与工程访问授权，再查询一次。

有工程且可访问后，再调用构建、测试或预览工具。仓库早期记录曾发现 54 个工具，包括 `DocumentationSearch`、`BuildProject`、`RunAllTests`、`RenderPreview` 和 workspace 查询；工具名称与数量以当前发现结果为准。

## 常见问题、更新与移除

- **找不到 skills 导出器或 `mcpbridge`**：核对当前选择的完整 Xcode 路径及版本，并查看本机帮助；不能把本文命令假定为所有旧版本都有。
- **登记了配置却没有工具**：检查 Xcode 是否运行、访问是否允许，以及 Codex 是否重新连接。`mcp list` 只证明登记状态。
- **有工具却没有工程或没有授权**：按[工程访问步骤](#验证服务与工程访问)处理；无需为验证工具登记而提前创建应用。
- **存在多个 Xcode 实例**：先核对 `xcode-select -p`；需要指定实例时查阅 `xcrun mcpbridge --help` 中的 `MCP_XCODE_PID`。
- **skills 内容过旧**：升级 Xcode 后检查导出帮助，再比较并更新用户目录中的副本。

移除 MCP 登记：

```bash
"$codex_cli" mcp remove xcode
```

这会移除 Codex 的登记，Apple skills 与 Xcode 由各自安装位置单独管理。恢复配置备份前比较后续改动，避免覆盖有效设置。

## 验证边界

早期配置记录报告过 Apple skills 导出与迁移、MCP 工具发现，工程访问当时尚未通过授权。后续审阅的可见环境未复现相同安装状态，因此这些记录保留为版本参考，当前可用性按本文步骤重新验收。

2026-10-28 的工具准备已检查 `xcodebuild -version`、`xcrun --find mcpbridge`、skills 导出与桥接器的 `--help`，未执行安装、导出或 MCP 配置修改。该次工具准备尚未验证工程构建、测试、预览和设备行为。

2026-10-29 开始工程基础学习后，已通过 Xcode MCP 建立 EngineeringLab、打开并查询工程，接入本地 Swift Package，并开展构建和模拟器调试。当前工程验证范围、截图和 runtime 状态统一见 [工程基础实验](engineering-foundations.md#实际验证与限制)，不将它扩展为所有 MCP 工具、测试或真机能力均已验证。

## 官方参考

- [Apple：Xcode](https://developer.apple.com/xcode/)
- [Apple：Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)
- [Apple：Extending and customizing agents](https://developer.apple.com/documentation/xcode/extending-and-customizing-agents)
- [OpenAI：Codex MCP 配置](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
- [OpenAI：Skills 与用户目录](https://learn.chatgpt.com/docs/build-skills)

skills 导出命令另经本机 `xcrun agent skills export --help` 核对。
