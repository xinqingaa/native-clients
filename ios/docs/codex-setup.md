# Codex 与 Xcode 官方工具配置

Swift / iOS 是当前学习的先行主线。Codex 需要同时获得两类支持：skills 提供按任务使用的官方指导，Xcode MCP 则让 Codex 访问正在运行的 IDE，查询工程、检索文档、构建、运行测试和渲染预览。安装 skills、登记 MCP、连接 IDE 和完成应用验证分别需要对应证据。

本文于 2026-10-28 在 Xcode 27.1（27A9275）、Apple Swift 6.4 和桌面应用附带的 Codex CLI 0.165.0-alpha.1.2 上核对。Android 官方插件的安装见 [Android 配置说明](../../android/docs/codex-setup.md)。

## 确认可用的命令入口

先检查当前选中的 Xcode 和 Codex CLI：

```bash
xcode-select -p
xcodebuild -version
swift --version
xcrun --find mcpbridge

codex_cli=codex
"$codex_cli" --version
```

`xcrun` 根据当前选中的开发者目录寻找工具。若 `mcpbridge` 不存在，先核对所选 Xcode 的路径和版本；本文的 skills 导出方式以 Xcode 27.1 的命令帮助为依据，不能假定所有旧版本都提供相同入口。

本机 PATH 中的 npm Codex 0.130.0 启动时报 `ENOENT`，其平台可执行文件缺失。本次使用桌面应用自带的可运行 CLI 完成配置，没有重装 npm 包。如果遇到同类问题，并且桌面应用安装在以下位置，可以在当前终端改用：

```bash
codex_cli="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
"$codex_cli" --version
```

这个路径是本机桌面应用的实际位置，其他安装位置或版本需要调整。下文沿用 `codex_cli` 变量，运行命令前应先完成以上选择。

Codex 的用户配置默认位于 `~/.codex/config.toml`，桌面应用和 CLI 共用该配置。若设置了 `CODEX_HOME`，应先确认它们指向同一位置。Xcode 内部启动的代理可能使用独立配置目录，不能用其配置代替外部 Codex 的配置。

## 安装 Xcode 官方 skills

本机 Xcode 自带官方 skills，可以直接导出到 Codex 的用户 skills 目录。按 2026-10-28 核对的 OpenAI 官方文档，手动安装的用户 skills 使用 `~/.agents/skills`。它们随 Xcode 分发，本步骤使用 Apple 自带的导出器：

```bash
xcrun agent skills export --help
mkdir -p "$HOME/.agents/skills"
xcrun agent skills export --output-dir "$HOME/.agents/skills"
```

本次导出了 10 个 skills：

| Skill | 作用 |
| --- | --- |
| `swiftui-specialist` | SwiftUI 实现指导 |
| `swiftui-whats-new-27` | 当前 Xcode 随附的 SwiftUI 新功能指导 |
| `app-intents-specialist` | App Intents 接入指导 |
| `app-intents-whats-new-27` | 当前 Xcode 随附的 App Intents 新功能指导 |
| `app-resizability` | 应用窗口与尺寸适配 |
| `building-document-based-swiftui-applications` | SwiftUI 文档型应用 |
| `device-interaction` | 设备交互工作流 |
| `modernize-tests` | 测试现代化工作流 |
| `audit-xcode-security-settings` | Xcode 安全配置检查 |
| `adopt-c-bounds-safety` | C 边界安全接入 |

目录内应存在对应的 `SKILL.md` 及随附资源，例如：

```bash
test -f "$HOME/.agents/skills/swiftui-specialist/SKILL.md"
```

这些内容辅助平台开发；语言与 API 结论仍需核对 Swift.org、Apple Developer 以及当前 SDK。名称带 `27` 的 skills 需要特别检查目标系统和 API 可用条件。

本机最初将这 10 个 skills 导出到 `~/.codex/skills`，当前已将它们的完整目录迁移到 `~/.agents/skills`，旧位置不再保留同名副本。Codex CLI 0.165.0-alpha.1.2 曾能发现旧路径，这是该版本在本机的实际观察；后续安装与更新统一使用本文的新路径。其他已有 skills、系统 skills、`~/.codex/config.toml` 和插件缓存保持原位。

迁移或重新导出前先检查目标目录，遇到同名 skill 时比较内容，保留必要的本地修改，再处理整个 skill 目录及随附资源。后续升级 Xcode 后需要重新导出以更新副本；只有确认覆盖范围后才使用导出器的 `--replace-existing` 选项。

Codex 会自动发现 skills 变更；如果对话中的清单仍显示旧路径，先在下一轮检查，必要时重启 Codex。可以要求它列出上述 skills 并确认路径位于 `~/.agents/skills`。文件存在、skill 被发现与具体任务中使用该 skill 分别需要对应证据。

## 配置官方 Xcode MCP

### 允许 Xcode 提供工具

打开 Xcode，进入 **Xcode → Settings → Intelligence → Model Context Protocol**，允许 **Allow External Agents to Use Xcode Tools**。本文环境中该项是下拉选项，本机原有值为 `Always`，本次没有更改；其他版本可能呈现为开关。

Xcode 是工具服务的提供者，需要保持运行。全局访问设置开启后，当前代理仍需取得具体工程及其目录的访问授权；操作工程前还需要在 Xcode 中打开对应 project、workspace 或 Swift Package。

### 登记到外部 Codex

执行 Apple 官方文档给出的接入方式：

```bash
"$codex_cli" mcp add xcode -- /usr/bin/xcrun mcpbridge
"$codex_cli" mcp get xcode --json
```

等价的用户配置为：

```toml
[mcp_servers.xcode]
command = "/usr/bin/xcrun"
args = ["mcpbridge"]
```

已有 `xcode` 配置时先检查内容，避免直接覆盖自定义参数。使用 `/usr/bin/xcrun` 的绝对路径可以减少桌面应用和终端 PATH 差异的影响。

保存配置后，在 Codex 中重新连接 MCP 或启动新对话；若工具仍未出现，重启桌面应用以重新读取配置。`mcp get` 或 `mcp list` 能证明配置已登记，实际连接需完成 MCP 初始化并取得工具列表。

### 验证服务与工程授权

先检查本机 Xcode MCP 服务：

```bash
xcrun mcp-server status
```

本机本次实际输出为：

```text
Permission: enabled
mcp-server: running
Open workspaces: none
```

这些结果分别表示全局访问已启用、服务正在运行、没有打开的工程。当前代理的工程授权还需要通过实际工具调用确认。本次 Codex 对话已加载 Xcode MCP 工具，但调用 `XcodeListWorkspaces` 返回 `This agent isn't approved to use Xcode's tools yet`，提示先通过 `XcodeOpenWorkspace` 或 `XcodeNewProject` 请求工程及目录访问授权。

后续已有目标工程时，让当前代理调用 `XcodeOpenWorkspace` 打开其实际路径，并按 Xcode 提示处理授权，再查询 workspace。例如：

```text
用 XcodeOpenWorkspace 打开本次目标工程，处理 Xcode 的工程访问授权后，
用 XcodeListWorkspaces 确认当前代理可以查询该工程。
```

本仓库尚无 Swift Package 或 iOS 应用工程，本次没有为触发授权而新建工程。配置登记、工具加载、服务状态、工程授权和工程构建分别验证；构建、测试和预览需要在工程可访问后继续调用相应工具。

## 本次安装与验证结果

| 检查 | 实际结果 |
| --- | --- |
| Xcode CLI 与桥接程序 | Xcode 27.1；`xcrun --find mcpbridge` 成功 |
| Apple skills 目录 | 10 个 skills 已迁移至 `~/.agents/skills`；84 个文件迁移前后内容校验一致，旧位置无同名副本 |
| Apple skills 发现 | 使用本机 Codex app-server 的 `skills/list` 强制重新扫描；10 个 skills 均从新路径发现，作用域为 `user` 且已启用 |
| Codex 用户配置 | 新增并启用 `xcode` MCP，保留原有配置 |
| Xcode 访问设置 | 在设置界面确认原有值为 `Always` |
| MCP 初始化与工具发现 | 通过本机 STDIO 桥接完成 `initialize` 和 `tools/list`；服务名 `xcode-tools`，返回 54 个工具 |
| 当前 Codex 对话 | 已加载 Xcode MCP 工具，并实际调用 `XcodeListWorkspaces` |
| Xcode MCP 服务 | `xcrun mcp-server status` 返回全局权限启用、服务运行、无打开的工程 |
| 当前代理的工程授权 | 查询返回尚未批准当前代理访问，提示先打开或创建工程；工程访问尚未验证通过 |
| 应用构建、测试与预览 | 未执行；本仓库尚无 Swift Package 或 iOS 应用工程 |

工具列表包含 `DocumentationSearch`、`BuildProject`、`RunAllTests`、`RenderPreview`、`XcodeListWorkspaces` 等。本次完成了连接与工具发现，并尝试只读查询；查询受到工程授权限制。没有调用构建或项目修改工具，工具数量也不应作为未来版本的固定断言。

安装前已备份用户配置。本机备份文件位于 `~/.codex/config.toml.before-native-tools.20261028T094730Z`，保存在仓库之外。

## 常见问题与移除

- **终端 Codex 报 `spawn ... ENOENT`**：先检查实际启动入口和平台可执行文件，使用本机可运行的桌面 CLI 完成本次配置；npm 安装损坏需要单独修复。
- **已登记但未出现工具**：检查 Xcode 是否运行、MCP 访问是否允许，以及 Codex 是否已重新连接。
- **工具已加载但提示代理尚未批准**：检查 `xcrun mcp-server status`，再按[工程授权步骤](#验证服务与工程授权)通过当前代理打开目标工程。全局权限开启和工具可见不能单独证明当前代理已获得工程访问授权。
- **有工具但找不到工程**：在 Xcode 打开本次需要操作的工程，再查询 workspace；仓库目录的存在不能证明应用工程已建立。
- **多个 Xcode 实例或版本**：先核对 `xcode-select -p`。桥接器支持 `MCP_XCODE_PID` 指定实例，具体用法以 `xcrun mcpbridge --help` 为准。
- **skills 已存在**：检查同名目录及本地修改，再决定更新方式。

移除 MCP 登记可执行：

```bash
"$codex_cli" mcp remove xcode
```

这不会删除 Xcode 或已导出的 skills。移除 skills 时逐项确认目录归属，仅处理本次导出的内容；恢复旧配置前应比较后续新增设置，避免用备份覆盖后来有效的修改。

## 官方参考

- [Apple：Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)
- [Apple：Extending and customizing agents](https://developer.apple.com/documentation/xcode/extending-and-customizing-agents)
- [OpenAI：Codex MCP 配置](https://developers.openai.com/codex/mcp/)
- [OpenAI：Skills 与用户目录](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI：Codex app-server](https://learn.chatgpt.com/docs/app-server)
- [OpenAI：Codex plugins](https://developers.openai.com/codex/plugins/)

skills 导出命令另经本机 Apple 工具 `xcrun agent skills export --help` 核对。
