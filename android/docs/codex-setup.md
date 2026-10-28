# Android 开发环境与 Codex 工具配置

本文提供 Android Studio、JDK、SDK、Emulator 和 Android skills 插件的手动配置步骤，并说明 IDE MCP 的可选接入。Codex CLI 的选择、安装和配置范围见[共用配置入口](../../shared/docs/codex-setup.md)。开始使用下文的 `codex_cli` 前，在同一个终端按该入口选择可运行的 CLI。

本文于 2026-10-28 核对 Android、OpenAI 和 JetBrains 官方资料，并用 Codex CLI 0.165.0-alpha.1.2 检查插件命令帮助。本轮未安装或更新插件，未修改 JDK、SDK 或 IDE 配置。

## 安装 Android Studio 与 SDK

1. 从 [Android Studio 官方下载页](https://developer.android.com/studio)安装与当前 macOS 和芯片架构匹配的版本，首次启动后完成 Setup Wizard。
2. 从欢迎页的 **More Actions → SDK Manager** 或 IDE 设置中的 **Android SDK** 入口检查实际 SDK Location。
3. 在 SDK Manager 中按后续工程需要安装 Android SDK Platform、Build-Tools、Platform-Tools；运行模拟器时再安装 Android Emulator 与所需 system image。需要终端管理 SDK 包时，安装 Android SDK Command-line Tools。

SDK Platform 和 Build-Tools 版本需与工程配置相符；当前没有应用工程，无需提前指定所有版本。Kotlin 编译器、Compose 插件和 AGP 后续由工程依赖管理，Gradle 使用工程自带的 Wrapper，不要求先装一份全局 Kotlin 或 Gradle。

需要从终端调用 SDK 工具时，先把下面的 SDK 路径改成 SDK Manager 显示的实际路径，再在终端执行：

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
adb --version
emulator -list-avds
```

这些 `export` 只影响当前终端。确认路径正确且需要长期使用后，将两行配置合并进自己的 `~/.zshrc`，重新打开终端检查；已有同类配置时直接调整原项。`cmdline-tools/latest/bin` 只在通过 SDK Manager 安装相应工具后存在。

## 选择 JDK 与核对 Gradle

Android Studio 随附 JetBrains Runtime（JBR），它是 JDK。先检查当前工程的 Gradle/AGP 要求与 JVM 选择机制：较新 Studio 的新工程可能使用 Gradle Daemon JVM criteria，已有工程也可能使用 Gradle JDK 设置。已有声明时遵循工程要求。

没有特定 JVM 声明且随附 JBR 满足兼容要求时，可先使用该 JDK。macOS 默认安装路径的检查示例为：

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" -version
```

需要让普通终端构建使用它时，在当前终端设置：

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
java -version
```

安装位置不同需要替换路径。IDE 中通过 **Settings → Build, Execution, Deployment → Build Tools → Gradle** 核对 Gradle JDK，或查看工程的 Daemon JVM criteria。比较 IDE 与终端最终使用的 JVM，避免只根据 `java -version` 推断 IDE 构建环境。

有 Gradle 工程后，在其根目录执行 `./gradlew --version`，再按工程入口构建与测试。当前仓库没有 Wrapper，这条工程验收留到工程建立后执行；独立 Kotlin/JVM 实验同样使用自身工程声明。

## 配置模拟器与设备

在欢迎页的 **More Actions → Virtual Device Manager**，或工程内的 **View → Tool Windows → Device Manager** 创建虚拟设备。选择与开发机适配的系统镜像和所需 API level，按界面下载、创建并启动。

启动后检查：

```bash
adb devices -l
```

能够列出 emulator 只证明设备连接正常，应用安装和运行需等待工程建立。使用真机时由学习者开启开发者选项与 USB 调试，并在设备上确认当前电脑的调试授权。

## 安装 Android 官方 skills 插件

按 [Android 官方仓库](https://github.com/android/skills)提供的 Codex 安装方式，先检查现有市场与插件状态：

```bash
"$codex_cli" plugin marketplace list
"$codex_cli" plugin list --marketplace android-skills --json
```

尚未登记市场或安装插件时，手动执行对应步骤：

```bash
"$codex_cli" plugin marketplace add android/skills
"$codex_cli" plugin add android-skills@android-skills
"$codex_cli" plugin list --marketplace android-skills --json
```

市场未登记时，前面的查询可能提示找不到该市场。已安装时先查看当前版本与启用状态，再决定是否更新。安装器管理插件下载、缓存及用户配置，相关配置片段为：

```toml
[marketplaces.android-skills]
source_type = "git"
source = "https://github.com/android/skills.git"

[plugins."android-skills@android-skills"]
enabled = true
```

仅手写以上片段不能证明插件内容已下载。在新 Codex 对话中检查相关 skills 是否被发现，未刷新时重启客户端。

早期配置记录使用 `android-skills` 1.0.18，包含 36 个 skills，如 `jetpack-compose-performance`、`testing-setup`、`agp-9-upgrade`、`navigation-3`、`android-profiler`、`r8-analyzer`、`edge-to-edge`。版本与数量以本次安装结果为准。这些是特定任务的指导，不保证覆盖全部 Kotlin 语言主题。

Android 官方还提供通过 Android CLI 安装 skills 的方式。本项目使用上面的 Codex 插件路径即可，不需要为同一份 skills 再安装 Android CLI。插件也不会替代 JDK、SDK、Gradle Wrapper 或自动配置 IDE MCP。

## 可选：接入 IDE MCP

JetBrains 文档说明 IntelliJ IDEA 提供 MCP Server，但不能据此推定所有 Android Studio 版本具有相同入口。先检查自己所用 IDE 是否实际提供 **Settings → Tools → MCP Server**，以及所需 MCP Server 插件是否可用。

有对应能力时，按当前 IDE 的说明手动操作：

1. 启用 MCP Server，打开需要学习的实际工程。
2. 使用 IDE 提供的 Codex 客户端配置入口，或复制其生成的连接配置并合并到 Codex 配置中。
3. 若使用 Codex 的 MCP servers 设置，按照 IDE 生成的传输方式填写命令与参数或服务 URL；端口、classpath 和启动参数使用 IDE 的实际值。
4. 重新连接 Codex，确认工具发现、工程访问以及一次实际查询；构建和测试另行验证。

如果当前 Android Studio 没有对应入口，可以先通过终端和 Gradle Wrapper 工作。本文未验证本机 Android Studio 的 MCP 服务，不提供推测的固定连接配置。

## 更新、移除与故障处理

需要更新时先查看当前 CLI 帮助，再刷新该市场并安装其当前插件版本：

```bash
"$codex_cli" plugin marketplace upgrade --help
"$codex_cli" plugin add --help
"$codex_cli" plugin marketplace upgrade android-skills
"$codex_cli" plugin add android-skills@android-skills
"$codex_cli" plugin list --marketplace android-skills --json
```

先确认已有插件是否包含本地修改；自定义工作流保留在独立位置。更新结果以实际安装输出和查询版本为准。

移除插件：

```bash
"$codex_cli" plugin remove android-skills@android-skills
```

- **找不到 `plugin` 子命令**：核对 CLI 入口、版本与命令帮助；共用入口说明了桌面应用自带 CLI 的选择方法。
- **插件启用但看不到 skills**：新建对话或重启客户端，并确认终端与桌面应用使用同一配置目录。
- **找不到 SDK 工具**：检查 SDK Location、实际安装的包和终端 PATH。
- **IDE 能构建而终端失败**：核对工程 JVM 选择、`JAVA_HOME`、SDK 路径及当前工作目录。
- **模拟器或设备未出现**：先在 Device Manager 或设备上检查运行与调试授权，再检查 `adb devices -l`。

## 验证边界

早期文档记录过插件安装与 skills 发现；后续审阅的可见环境未复现相同安装状态。当前就绪程度以手动查询、能力发现与工程验证为准。

本轮已核对官方资料与插件命令帮助，未执行安装、更新、模拟器操作或 IDE MCP 配置。当前仓库没有可构建的 Android 或 Kotlin/JVM 工程，构建、测试和设备行为未验证。

## 官方参考

- [Android Studio 下载](https://developer.android.com/studio)
- [Android：JDK 与 Gradle JVM 的选择](https://developer.android.com/build/jdks)
- [Android：SDK 环境变量](https://developer.android.com/tools/variables)
- [Android：创建与管理虚拟设备](https://developer.android.com/studio/run/managing-avds)
- [Android Developers：Overview of Android skills](https://developer.android.com/tools/agents/android-skills)
- [Android 官方 skills 仓库与 Codex 安装命令](https://github.com/android/skills)
- [JetBrains：IntelliJ IDEA MCP Server](https://www.jetbrains.com/help/idea/mcp-server.html)
- [OpenAI：Codex plugins](https://developers.openai.com/codex/plugins/)
