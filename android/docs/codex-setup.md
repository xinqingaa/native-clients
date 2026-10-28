# Codex 与 Android 官方 skills 配置

Android 官方 skills 将特定开发任务的指导打包为插件，帮助 Codex 按 Android Developers 的实践处理工程升级、Compose、平台能力和诊断。它们提供工作流与参考资料；构建、模拟器和设备验证仍依赖实际的 JDK、Android SDK、Gradle 和运行环境。

当前学习以 Swift / iOS 先行，Android 插件先安装到本机 Codex，随对应任务使用。本文于 2026-10-28 核对，已安装版本为 `android-skills` 1.0.18，包含 36 个 skills。

## 安装官方插件

先确认 Codex CLI 可运行：

```bash
codex_cli=codex
"$codex_cli" --version
```

本机 PATH 中的 npm CLI 因平台可执行文件缺失而报 `ENOENT`，此次改用桌面应用自带的 CLI：

```bash
codex_cli="/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
"$codex_cli" --version
```

其他机器应根据实际安装位置选择入口。下面沿用 `codex_cli` 变量。

按 [Android 官方仓库](https://github.com/android/skills)提供的 Codex 安装方式，添加市场并安装：

```bash
"$codex_cli" plugin marketplace add android/skills
"$codex_cli" plugin add android-skills@android-skills
"$codex_cli" plugin list --marketplace android-skills --json
```

安装器将市场和启用状态写入 Codex 用户配置，默认位于 `~/.codex/config.toml`：

```toml
[marketplaces.android-skills]
source_type = "git"
source = "https://github.com/android/skills.git"

[plugins."android-skills@android-skills"]
enabled = true
```

优先使用安装命令，让 Codex 同时管理插件缓存。仅手写以上配置不能证明插件内容已经下载。若自定义了 `CODEX_HOME`，应确认 CLI 与桌面应用使用同一配置位置。

## 使用与能力边界

Codex 会自动发现插件附带的 skills；若清单未更新，在下一轮检查，必要时重启桌面应用。可以要求 Codex 列出 Android Skills 中与当前任务有关的能力，例如 Compose 性能、测试设置或 AGP 升级。

本次插件包含 `jetpack-compose-performance`、`testing-setup`、`agp-9-upgrade`、`navigation-3`、`android-profiler`、`r8-analyzer`、`edge-to-edge` 等指导。官方仓库按特定任务补充 skills，并不保证提供每一个 Kotlin 语言主题。

插件安装不会自动安装 JDK、Android SDK、Gradle、Android CLI，也不会自动配置 IDE MCP。需要相关工具的 skill 被使用时，再核对其前提与当前授权范围。

JetBrains 提供的 IDE MCP 是另一种接入：它把正在运行的 IDE 能力提供给外部代理，需要在适配的 IDE 中启用服务，再将 IDE 给出的连接配置登记到 Codex。本次没有配置 JetBrains IDE MCP；本机仅确认安装了 Android Studio，不能用 IntelliJ IDEA 文档推定其具有完全相同的服务入口。

## 本次安装与验证结果

| 检查 | 实际结果 |
| --- | --- |
| 官方市场 | 已登记 `https://github.com/android/skills.git` |
| 插件状态 | `android-skills@android-skills` 1.0.18；`installed: true`、`enabled: true` |
| 插件内容 | 清单声明的 36 个 skills 均存在 `SKILL.md` |
| 本机缓存 | `~/.codex/plugins/cache/android-skills/android-skills/1.0.18` |
| skills 发现 | 后续对话已发现插件附带的 skills；本机 Codex app-server 的 `skills/list` 强制重新扫描也返回该插件的 36 个 skills |
| Android 工程验证 | 未执行；当前仓库没有可构建的 Android 工程 |

## 更新与移除

后续更新前先核对当前 CLI 的帮助与插件市场版本。市场管理命令可通过以下方式检查：

```bash
"$codex_cli" plugin marketplace --help
"$codex_cli" plugin add --help
```

移除插件可执行：

```bash
"$codex_cli" plugin remove android-skills@android-skills
```

Xcode MCP 和 Apple skills 的配置、连接验证及移除步骤见 [iOS 配置说明](../../ios/docs/codex-setup.md)。

## 官方参考

- [Android Developers：Overview of Android skills](https://developer.android.com/tools/agents/android-skills)
- [Android 官方 skills 仓库与 Codex 安装命令](https://github.com/android/skills)
- [Android Studio：Extend Agent Mode with skills](https://developer.android.com/studio/gemini/skills)
- [JetBrains：IntelliJ IDEA MCP Server](https://www.jetbrains.com/help/idea/mcp-server.html)
- [OpenAI：Codex plugins](https://developers.openai.com/codex/plugins/)
