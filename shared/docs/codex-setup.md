# Codex 手动安装与配置入口

本文组织本项目共用的 Codex 配置，平台工具的具体操作分别见 [iOS 配置](../../ios/docs/codex-setup.md)与 [Android 配置](../../android/docs/codex-setup.md)。安装和本机配置由学习者手动执行，文中的命令用于操作指导；正文更新不代表这些操作已经执行。

AI 工具用于资料核验、解释、实现与验证，投入随原生客户端学习需要确定。仓库的 AGENTS 维护长期协作规则，SPEC 维护成果标准，WORKFLOW 维护执行过程；skills 承载按任务使用的指导，MCP 提供外部工具与信息访问，编译和运行仍需要对应的平台工具链。

## 按当前学习需要选择工具

| 工具 | 何时需要 | 手动配置入口 |
| --- | --- | --- |
| Xcode、Swift 与 iOS Simulator | Swift 语言实验、iOS 应用运行与调试 | [iOS 开发环境](../../ios/docs/codex-setup.md#安装与选择-xcode) |
| Android Studio、JDK、SDK 与 Emulator | Kotlin/JVM 实验、Android 应用运行与调试 | [Android 开发环境](../../android/docs/codex-setup.md#安装-android-studio-与-sdk) |
| Node.js | 开展共享 mock 服务实验 | [Node 环境准备](../services/docs/README.md#nodejs-环境准备) |
| Apple skills、Android skills 插件 | 需要相关原生开发指导时 | 对应平台配置文档 |
| Xcode MCP、可用的 Android IDE MCP | 希望 Codex 通过运行中的 IDE 查询、构建或测试时 | 对应平台配置文档 |

可以只配置当前主题需要的部分。skills 和 IDE MCP 都是辅助能力；平台构建入口也可以通过终端使用。后续工程建立后分别核对工程版本要求和实际操作入口。

## 确认可运行的 Codex CLI

先在自己的终端检查：

```bash
command -v codex
codex --version
```

如果命令可用，在后续操作使用的同一个终端中定义：

```bash
codex_cli=codex
"$codex_cli" --version
```

如果已安装桌面应用而 PATH 中没有可运行的 CLI，可以使用应用自带的入口。本机已核对的路径为：

```bash
codex_cli="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
"$codex_cli" --version
```

其他安装位置需要替换路径。已有入口可运行时无需再安装一份 CLI。若出现 `ENOENT`，先用 `command -v codex` 确定实际入口，检查对应可执行文件；旧安装的失败不代表桌面应用自带的 CLI 也不可用。

新机器需要独立安装 CLI 时，可按 [OpenAI 官方 CLI 安装页](https://learn.chatgpt.com/docs/codex/cli)选择安装方式。该页在 2026-10-28 提供的 macOS/Linux 安装命令为：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

安装后重新打开终端，执行 `codex --version`，再运行 `codex` 按提示登录。独立 CLI 与桌面应用附带的 CLI 可能具有不同版本；遇到不支持的子命令，先检查正在使用的入口与 `--help`。

## 配置位置与作用范围

| 内容 | 默认位置与说明 |
| --- | --- |
| Codex 用户配置 | `~/.codex/config.toml`；同一 Codex host 上的桌面应用、CLI 与 IDE 扩展共享 MCP 配置 |
| 用户手动安装的 skills | `~/.agents/skills/<skill-name>/SKILL.md`，随附资源保留在同一 skill 目录 |
| 仓库 skills | 仓库中的 `.agents/skills/`；需要团队共用工作流时再增加 |
| 插件 | 使用插件安装命令管理下载、缓存与启用状态 |

如果设置了 `CODEX_HOME`，先确认终端和桌面应用使用同一配置目录。项目级配置、不同执行主机和 Xcode 内启动的代理可能具有各自作用范围，需要分别核对。

手动编辑用户配置前先保留现有内容或备份，按项合并。各平台文档中的 TOML 是配置片段，不是整个配置文件。用户配置和登录信息保留在本机，仓库保存操作说明。

## 安装后的验证

1. 检查安装文件或插件状态，确认内容已落盘。
2. 在新对话或重新连接后确认相关 skill、插件或 MCP 工具可以被发现；未刷新时重启客户端再检查。
3. MCP 需要另外确认服务正在运行、目标工程可访问，以及当前代理取得所需授权。
4. 有工程后执行一次对应的查询、构建或测试，按实际结果记录完成范围。

文件存在、配置登记、能力被发现、工程可访问与应用验证分别提供不同证据。当前仓库尚无可构建工程，应用构建和设备行为需在对应工程建立后验证。

本文于 2026-10-28 核对官方文档，并使用桌面应用附带的 Codex CLI 0.165.0-alpha.1.2 检查相关命令帮助；本轮未执行安装、插件更新、MCP 登记或本机配置修改。

## 官方参考

- [OpenAI：Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
- [OpenAI：Skills 与发现目录](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI：MCP 配置](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
- [OpenAI：Plugins](https://developers.openai.com/codex/plugins/)
