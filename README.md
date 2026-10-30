# `JobsCommand@Flutter`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#jobs-toc-heading-1)
- [一、目录结构](#repository-layout)
- [二、脚本执行流程](#script-workflows)
  - [【MacOS】⚙️Pod\_Install.command](#jobs-toc-heading-4)
  - [【MacOS】⚙️双击安装Cocoapods.command](#jobs-toc-heading-5)
  - [【MacOS】⚙️双击更换Cocoapods源\[-\]CDN\[+\]Github.command](#jobs-toc-heading-6)
  - [【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command](#jobs-toc-heading-7)
  - [【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command](#jobs-toc-heading-8)
  - [【MacOS】♻️修复Flutter项目中文路径.command](#jobs-toc-heading-9)
  - [【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command](#jobs-toc-heading-10)
  - [【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command](#jobs-toc-heading-11)
  - [【MacOS】⚙️import =＞package💣.command](#jobs-toc-heading-12)
  - [【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command](#jobs-toc-heading-13)
  - [【MacOS】⚙️双击任何来源安装.command](#jobs-toc-heading-14)
  - [【MacOS】⚙️双击卸载Homebrew.command](#jobs-toc-heading-15)
  - [【MacOS】⚙️双击显示隐藏文件.command](#jobs-toc-heading-16)
  - [【MacOS】⚙️自动化替换Flutter图片资源.command](#jobs-toc-heading-17)
  - [【MacOS】⚙️运行授权.command](#jobs-toc-heading-18)
  - [【MacOS】🌞颜色格式的转换.command](#jobs-toc-heading-19)
  - [【MacOS】🎈切换Shell.command](#jobs-toc-heading-20)
  - [【MacOS】🎈双击打开当前路径终端.command](#jobs-toc-heading-21)
  - [【MacOS】🏥双击自检Flutter.command](#jobs-toc-heading-22)
  - [【MacOS】🐦Flutter自动化生产代码.command](#jobs-toc-heading-23)
  - [【MacOS】🔍查询Flutter依赖版本.command](#jobs-toc-heading-24)
  - [【MacOS】🛠️Android 模拟器一键检测与修复.command](#jobs-toc-heading-25)
  - [【MacOS】🛠️Flutter 插件 namespace 修复工具＂.command](#jobs-toc-heading-26)
  - [【MacOS】🧹Flutter清理维护工具.command](#jobs-toc-heading-27)
  - [【MacOS】📹双击制作Android模拟器录屏Gif.command](#jobs-toc-heading-28)
  - [【MacOS】📹双击制作iOS模拟器录屏Gif.command](#jobs-toc-heading-29)
  - [【MacOS】📦双击打包Flutter.Android.command](#jobs-toc-heading-30)
  - [【MacOS】📦双击打包Flutter.Harmony.command](#jobs-toc-heading-31)
  - [【MacOS】📦双击打包Flutter.iOS.command](#jobs-toc-heading-32)
  - [【MacOS】⬆️Pod\_Update.command](#jobs-toc-heading-33)
  - [【MacOS】⬆️双击升级Cocoapods.command](#jobs-toc-heading-34)
  - [【MacOS】⬆️双击升级Flutter.SDK.command](#jobs-toc-heading-35)
  - [【MacOS】⬆️双击更新CocoaPods本地仓库.command](#jobs-toc-heading-36)
  - [【MacOS】⬆️双击更新Flutter依赖.command](#jobs-toc-heading-37)
  - [【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command](#jobs-toc-heading-38)
  - [【MacOS】📱双击初始化Android模拟器.command](#jobs-toc-heading-39)
  - [【MacOS】📱双击初始化鸿蒙模拟器.command](#jobs-toc-heading-40)
  - [【MacOS】📱双击打开已实例化的鸿蒙模拟器.command](#jobs-toc-heading-41)
  - [【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command](#jobs-toc-heading-42)
  - [【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command](#jobs-toc-heading-43)
  - [【MacOS】🎈双击真机运行项目.command](#jobs-toc-heading-44)
  - [【MacOS】📱双击初始化iOS模拟器.command](#jobs-toc-heading-45)
  - [【MacOS】📱双击打开已实例化的iOS模拟器.command](#jobs-toc-heading-46)
  - [【MacOS】🚀双击启动Android模拟器.command](#jobs-toc-heading-47)
  - [【MacOS】⏬双击配置VSCode.command](#jobs-toc-heading-48)
  - [【MacOS】💉VSCode配置注入@全局.command](#jobs-toc-heading-49)
  - [【MacOS】💉VSCode配置注入@当前Flutter项目.command](#jobs-toc-heading-50)
  - [【MacOS】⏬下载配置系统环境变量.command](#jobs-toc-heading-51)
  - [【MacOS】⏬双击下载SourceTree效率脚本.command](#jobs-toc-heading-52)
  - [【MacOS】⚙️Flutter 项目组件预下载.command](#jobs-toc-heading-53)
  - [【MacOS】⚙️一键配置Flutter项目至运行.command](#jobs-toc-heading-54)
  - [【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command](#jobs-toc-heading-55)
  - [【MacOS】⚙️下载配置系统环境变量.command](#jobs-toc-heading-56)
  - [【MacOS】⚙️双击安装FVM.command](#jobs-toc-heading-57)
  - [【MacOS】⚙️双击安装Flutter.SDK.command](#jobs-toc-heading-58)
  - [【MacOS】⚙️双击安装（升级）Homebrew.command](#jobs-toc-heading-59)
  - [【MacOS】⚙️收集当前Flutter工程的依赖.command](#jobs-toc-heading-60)
  - [【MacOS】⚙️配置Android Studio.command](#jobs-toc-heading-61)
  - [【MacOS】🎈双击打开系统配置文件.command](#jobs-toc-heading-62)
  - [【MacOS】⚙️双击安装Cocoapods.command](#jobs-toc-heading-63)
  - [【MacOS】🧪提取Flutter第三方依赖.command](#jobs-toc-heading-64)
  - [【MacOS】⏬双击配置VSCode.command](#jobs-toc-heading-65)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">🔥 <font id=前言>前言</font></span><!-- jobs-toc:heading-end -->

[**Flutter**](https://flutter.dev/) 工程的安装、运行、打包和维护入口。 每个独立脚本按其内置自述和源码定位目标；先阅读流程，确认路径后再运行。

| 使用系统 | 真实入口 | 功能边界 |
| --- | --- | --- |
| [**MacOS**](https://www.apple.com/macos/) | [MacOS/README.md](./MacOS/README.md)，62 个 .command（同名包内主入口，2026-10-29） | 脚本、资源和功能说明同目录；iOS / Xcode / CocoaPods 仅位于此端。 |
| [**Windows**](https://www.microsoft.com/windows) | [WindowsOS/README.md](./WindowsOS/README.md)，46 个 .ps1 和同名 .cmd | 原生 PowerShell 5.1+ 实现 Flutter / Android / 鸿蒙双包打包 / 配置与工具；双击 .cmd，命令行可用 -Plan / -Check。 |

完整的逐入口对照与 16 个排除项见 [WindowsOS 功能映射](./WindowsOS/功能映射.json)。Windows 不提供 iOS 模拟器、iOS 打包、CocoaPods、Homebrew 或 Gatekeeper 入口。混合流程保留 Android、Web、Windows 缓存与鸿蒙工具链能力，项目缺少平台或 SDK 时明确停止。

MacOS 文件名使用可在 Windows 检出的全角字符；运行时请使用目录中实际名称。分发 Windows 工具时保留完整 WindowsOS 目录及随包模块。

上层 `JobsGenesis` 的实际登记如下，`path` 是本地目录，`url` 使用真实远端仓名：

```ini
[submodule "JobsCommand@Flutter"]
    path = JobsCommand@Flutter
    url = ../JobsCommand-Flutter.git
    branch = main
```

| 父仓线路 | 本仓解析地址 |
| --- | --- |
| `ssh://git@github.com/JobsKits/JobsGenesis.git` | `ssh://git@github.com/JobsKits/JobsCommand-Flutter.git` |
| `git@gitee.com:JobsGo/JobsGenesis.git` | `git@gitee.com:JobsGo/JobsCommand-Flutter.git` |

相对地址跟随父仓线路；目标平台必须已有本仓及父仓固定指针引用的提交。

| 分类 | 当前功能入口 |
| --- | --- |
| MacOS/打包相关 | [功能说明](<./MacOS/打包相关/README.md>) |
| MacOS/小工具 | [功能说明](<./MacOS/小工具/README.md>) |
| MacOS/屏幕录制 | [功能说明](<./MacOS/屏幕录制/README.md>) |
| MacOS/配置相关 | [功能说明](<./MacOS/配置相关/README.md>) |
| MacOS/运行 | [功能说明](<./MacOS/运行/README.md>) |
| MacOS/更新升级 | [功能说明](<./MacOS/更新升级/README.md>) |
| MacOS/Cocoapods | [功能说明](./MacOS/Cocoapods/README.md) |
| WindowsOS/打包相关 | [功能说明](<./WindowsOS/打包相关/README.md>) |
| WindowsOS/小工具 | [功能说明](<./WindowsOS/小工具/README.md>) |
| WindowsOS/屏幕录制 | [功能说明](<./WindowsOS/屏幕录制/README.md>) |
| WindowsOS/配置相关 | [功能说明](<./WindowsOS/配置相关/README.md>) |
| WindowsOS/运行 | [功能说明](<./WindowsOS/运行/README.md>) |
| WindowsOS/更新升级 | [功能说明](<./WindowsOS/更新升级/README.md>) |
| WindowsOS | [双端功能映射与运行说明](./WindowsOS/README.md)；42 个 PowerShell 主入口，不含公共模块与测试（当前目录，2026-10-28） |

## 一、<span id="repository-layout">目录结构</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

下面按当前磁盘第一层列出真实文件与目录；包内主脚本由下方完整名称直接进入。

~~~text
JobsCommand@Flutter/
├── README.md
├── MacOS/
│   ├── README.md
│   ├── Cocoapods/
│   ├── 小工具/
│   ├── 屏幕录制/
│   ├── 打包相关/
│   ├── 更新升级/
│   ├── 运行/
│   ├── 配置相关/
│   └── 【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command/
└── WindowsOS/
    ├── README.md
    ├── 功能映射.json
    ├── Scripts/
    ├── Tests/
    └── 与可移植 MacOS 功能对应的分类和脚本包/
~~~

## 二、<span id="script-workflows">脚本执行流程</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

MacOS 目录现有 58 个用户入口，WindowsOS 目录对应 42 个用户入口（同名包内主脚本计数，2026-10-28）。下面保留 MacOS 原功能说明；3 个 Git 通用操作链接到相邻 JobsCommand@Gits 仓库，独立下载本仓时可另行取得。独立子 Git、测试、函数库及打包资源模板不作为用户运行入口。按功能选择入口后核对该包的参数、产物与作用范围。

### <span id="jobs-toc-heading-4" data-jobs-toc="v2">[【MacOS】⚙️Pod_Install.command](<./MacOS/Cocoapods/【MacOS】⚙️Pod_Install.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 根据原生或 [**Flutter**](https://flutter.dev/) 项目结构安装 Pod 依赖。

- 初始化 UTF-8、工具路径与工程目录。
- 识别原生或 Flutter 工程，准备对应 Podfile 所在位置。
- 执行对应 pod install 流程，输出完成状态与日志。

### <span id="jobs-toc-heading-5" data-jobs-toc="v2">[【MacOS】⚙️双击安装Cocoapods.command](<./MacOS/配置相关/【MacOS】⚙️双击安装Cocoapods.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 交互选择 Ruby 与 CocoaPods 的安装方式。

- 先备份 Shell 配置。
- 准备 Homebrew 和 fzf。
- 菜单选择 Homebrew、rbenv、RVM 的 Ruby 路径。
- 按 IP 查询结果设置 Gem 源。
- 选择 Gem 或 Homebrew 安装 CocoaPods 并 pod setup。

### <span id="jobs-toc-heading-6" data-jobs-toc="v2">[【MacOS】⚙️双击更换Cocoapods源\[-\]CDN\[+\]Github.command](<./MacOS/Cocoapods/【MacOS】⚙️双击更换Cocoapods源[-]CDN[+]Github.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 将 CocoaPods 的 CDN Specs 源切换为 [**Git**](https://git-scm.com/) 源。

- 阅读源切换和本地缓存影响。
- 移除脚本指定的 CDN trunk 与缓存目录。
- 添加 Git Specs 源并输出源配置结果。

### <span id="jobs-toc-heading-7" data-jobs-toc="v2">[【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command](<./MacOS/Cocoapods/【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 关闭目标 Xcode 工程的用户脚本沙盒。

- 识别脚本目录下 Flutter 的 ios/ 或原生工程。
- 自动取第一份 .xcodeproj，缺失时提示拖入。
- 把 YES 改为 NO，缺字段时向 buildSettings 添加。

### <span id="jobs-toc-heading-8" data-jobs-toc="v2">[【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command](<./MacOS/【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 为拉取后的 Flutter 工程绑定项目级 FVM，并设置编辑器 SDK 路径。

- 从传入路径、当前目录、脚本目录向上寻找 pubspec.yaml 与 lib/。
- 检查 Homebrew，缺 FVM 时安装。
- 执行 fvm install 与 fvm use。
- 合并 .vscode/settings.json 的 dart.flutterSdkPath。

### <span id="jobs-toc-heading-9" data-jobs-toc="v2">[【MacOS】♻️修复Flutter项目中文路径.command](<./MacOS/小工具/【MacOS】♻️修复Flutter项目中文路径.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 还原 Dart import 路径中的 URI 编码中文。

- 识别工程与 Flutter/FVM。
- 检查 Perl 与 URI::Escape。
- 扫描 Dart 文件、备份到 .import_backup。
- 解码匹配 URI。
- 可选 analyze 与 SDK upgrade。

### <span id="jobs-toc-heading-10" data-jobs-toc="v2">[【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command](<./MacOS/小工具/【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 补齐 Android SDK 并让 Flutter 使用该目录。

- 识别工程/FVM。
- 下载固定 Command-line Tools。
- 安装基础 SDK 组件。
- 配置 android-sdk。
- 运行 licenses 与 doctor。
- 可选 pub get。

### <span id="jobs-toc-heading-11" data-jobs-toc="v2">[【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command](<./MacOS/小工具/【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 在桌面创建指向脚本当前目录的 Finder 替身。

- 计算脚本目录与别名名称。
- 用 AppleScript 在桌面建立 alias。

### <span id="jobs-toc-heading-12" data-jobs-toc="v2">[【MacOS】⚙️import =＞package💣.command](<./MacOS/小工具/【MacOS】⚙️import %3D＞package💣.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 按引用文件位置转换指向本项目 lib 的相对 import。

- 系统 Perl 词法扫描，跳过注释、字符串、第三方、生成文件和链接。
- `--check` / `--dry-run` 只列计划，普通运行输入 `YES` 后先备份再原子写回。
- 保留不支持或目标不明确的引用，按摘要核对实际转换结果。

### <span id="jobs-toc-heading-13" data-jobs-toc="v2">[【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command](<./MacOS/小工具/【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 注册 jobs 函数并重新加载常用 Shell 配置。

- 检查 zshrc 中 jobs 函数。
- 不存在时追加函数。
- 逐项 source bash_profile、bashrc、zshrc 与 Oh My Zsh 配置。
- 打印路径。

### <span id="jobs-toc-heading-14" data-jobs-toc="v2">[【MacOS】⚙️双击任何来源安装.command](<./MacOS/小工具/【MacOS】⚙️双击任何来源安装.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 检查 SIP 后打开 macOS 应用来源设置。

- 读取 csrutil status。
- 按源码执行应用来源限制命令。
- 打开安全与隐私设置供人工检查。

### <span id="jobs-toc-heading-15" data-jobs-toc="v2">[【MacOS】⚙️双击卸载Homebrew.command](<./MacOS/小工具/【MacOS】⚙️双击卸载Homebrew.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 卸载 Homebrew 并处理脚本列出的残留目录。

- 查看自述与卸载范围，按脚本要求再次确认。
- 运行官方卸载入口，再处理配置的残留路径。
- 核对终端结果；依赖 Homebrew 的工具可能随之不可用。

### <span id="jobs-toc-heading-16" data-jobs-toc="v2">[【MacOS】⚙️双击显示隐藏文件.command](<./MacOS/小工具/【MacOS】⚙️双击显示隐藏文件.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 让 Finder 显示隐藏文件。

- 写入 Finder 的 AppleShowAllFiles = YES。
- 按源码重载 Finder。

### <span id="jobs-toc-heading-17" data-jobs-toc="v2">[【MacOS】⚙️自动化替换Flutter图片资源.command](<./MacOS/小工具/【MacOS】⚙️自动化替换Flutter图片资源.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 复制本地品牌图片并重新生成 Flutter 平台资源。

- 校验随脚本资源目录。
- 定位工程。
- 复制 assets。
- 可选清除平台旧图标。
- 替换 iOS LaunchImage 图片并保留 Contents.json。
- 执行依赖与配置存在的图标/启动页生成器。

### <span id="jobs-toc-heading-18" data-jobs-toc="v2">[【MacOS】⚙️运行授权.command](<./MacOS/小工具/【MacOS】⚙️运行授权.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 为指定文件或目录增加执行权限。

- 回车授权脚本目录第一层 .command。
- 输入小写 yes 递归查找 .command。
- 拖入多个路径时逐个 chmod +x。

### <span id="jobs-toc-heading-19" data-jobs-toc="v2">[【MacOS】🌞颜色格式的转换.command](<./MacOS/小工具/【MacOS】🌞颜色格式的转换.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 在常见颜色数值表示之间转换。

- 输入颜色值或使用命令行参数。
- 识别十六进制、RGB 等受支持格式并计算对应表示。
- 输出转换结果，继续输入或按退出指令结束。

### <span id="jobs-toc-heading-20" data-jobs-toc="v2">[【MacOS】🎈切换Shell.command](<./MacOS/小工具/【MacOS】🎈切换Shell.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 从系统允许的 Shell 中选择并切换登录 Shell。

- 检查菜单工具并读取可用 Shell 列表。
- 选择目标 Shell，核对路径。
- 执行切换并显示结果；新终端会使用新的登录 Shell。

### <span id="jobs-toc-heading-21" data-jobs-toc="v2">[【MacOS】🎈双击打开当前路径终端.command](<./MacOS/小工具/【MacOS】🎈双击打开当前路径终端.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 在脚本所在目录打开系统终端。

- 读取脚本目录。
- 调用 AppleScript 打开 Terminal 并 cd 到目标。
- 按源码处理已有终端窗口。

### <span id="jobs-toc-heading-22" data-jobs-toc="v2">[【MacOS】🏥双击自检Flutter.command](<./MacOS/小工具/【MacOS】🏥双击自检Flutter.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 输出 Flutter 开发环境与项目分析结果。

- 展示系统、Flutter/FVM、Dart、Xcode、Java、Android SDK 和 PATH。
- 列设备。
- 执行 doctor -v 与 analyze。

### <span id="jobs-toc-heading-23" data-jobs-toc="v2">[【MacOS】🐦Flutter自动化生产代码.command](<./MacOS/小工具/【MacOS】🐦Flutter自动化生产代码.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 按固定顺序生成 Flutter 图标、启动页和本地化代码。

- 验证工程。
- 执行 flutter clean、pub get、flutter_launcher_icons:main、flutter_native_splash:create、flutter gen-l10n。

### <span id="jobs-toc-heading-24" data-jobs-toc="v2">[【MacOS】🔍查询Flutter依赖版本.command](<./MacOS/小工具/【MacOS】🔍查询Flutter依赖版本.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 从本地锁文件查询已解析的 Flutter 包版本。

- 自动查找或拖入工程。
- 循环输入一个或空格分隔多个包名。
- 用 awk 从 pubspec.lock 提取 version。
- 输入 exit 结束。

### <span id="jobs-toc-heading-25" data-jobs-toc="v2">[【MacOS】🛠️Android 模拟器一键检测与修复.command](<./MacOS/小工具/【MacOS】🛠️Android 模拟器一键检测与修复.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 检查并处理 Android 模拟器的安装空间问题。

- 选择 adb 设备。
- 检查安装位置与可用存储。
- 按确认卸载指定 App/常见大体积 App、清理运行缓存。
- 修改 AVD 数据分区配置。

### <span id="jobs-toc-heading-26" data-jobs-toc="v2">[【MacOS】🛠️Flutter 插件 namespace 修复工具＂.command](<./MacOS/小工具/【MacOS】🛠️Flutter 插件 namespace 修复工具＂.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 给 Pub 缓存中的 Android 插件补 namespace。

- 递归扫描当前用户 Pub hosted 缓存下 build.gradle/build.gradle.kts。
- 读取同目录 AndroidManifest.xml package。
- 给缺失 namespace 的 android 块插入对应语法。

### <span id="jobs-toc-heading-27" data-jobs-toc="v2">[【MacOS】🧹Flutter清理维护工具.command](<./MacOS/小工具/【MacOS】🧹Flutter清理维护工具.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 用菜单清理全局或工程 Flutter 开发缓存。

- 全局菜单打开/清理 Pub 缓存、清理 Gradle、repair 缓存。
- 载入工程后可 pub get、clean、major-versions 升级、清理 SDK 缓存及 iOS/DerivedData。

### <span id="jobs-toc-heading-28" data-jobs-toc="v2">[【MacOS】📹双击制作Android模拟器录屏Gif.command](<./MacOS/屏幕录制/【MacOS】📹双击制作Android模拟器录屏Gif.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 录制 Android 设备、分段视频并可转 GIF。

- 通过 adb 选择设备。
- 支持定时或交互停止。
- 超过单段上限时分段。
- 可用 FFmpeg 合并。
- 选择片段后用 gifski 转 GIF。

### <span id="jobs-toc-heading-29" data-jobs-toc="v2">[【MacOS】📹双击制作iOS模拟器录屏Gif.command](<./MacOS/屏幕录制/【MacOS】📹双击制作iOS模拟器录屏Gif.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 录制选中的 iOS 模拟器并可转换 GIF。

- fzf 选择设备。
- 必要时启动 Simulator。
- 使用 simctl recordVideo。
- 回车停止录制。
- 可选 FFmpeg 抽帧与 gifski 生成 GIF。
- 可选清理中间帧。

### <span id="jobs-toc-heading-30" data-jobs-toc="v2">[【MacOS】📦双击打包Flutter.Android.command](<./MacOS/打包相关/【MacOS】📦双击打包Flutter.Android.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 交互构建 Flutter 的 Android 产物。

- 识别工程和 FVM。
- 选择 APK/AAB、flavor、debug/release/profile。
- 检查或选择 JDK，处理 jenv/Android SDK。
- 执行构建并在失败时输出诊断。

### <span id="jobs-toc-heading-31" data-jobs-toc="v2">[【MacOS】📦双击打包Flutter.Harmony.command](<./MacOS/打包相关/【MacOS】📦双击打包Flutter.Harmony.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 使用已有鸿蒙适配 SDK，一次构建 HAP 安装包与 APP 发布包，默认 release。

- 校验所选 Flutter 鸿蒙工程与两种包型的工具链能力。
- 依次解析依赖、构建 HAP 与 APP，失败保留退出码并停止，不清理工程或改动签名。
- 核验两类非空产物并显示日志；Windows 对应入口见[鸿蒙打包说明](<./WindowsOS/打包相关/【WindowsOS】📦双击打包Flutter.Harmony.ps1/README.md>)，真实编译与签名按目标工程验收。

### <span id="jobs-toc-heading-32" data-jobs-toc="v2">[【MacOS】📦双击打包Flutter.iOS.command](<./MacOS/打包相关/【MacOS】📦双击打包Flutter.iOS.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 构建 release IPA 并打开产物目录。

- 识别工程或 Dart 入口。
- 选择全局/FVM。
- 检查 CocoaPods。
- 依次 clean、pub get、build ipa --release。
- 检查 IPA 后打开目录。

### <span id="jobs-toc-heading-33" data-jobs-toc="v2">[【MacOS】⬆️Pod_Update.command](<./MacOS/更新升级/【MacOS】⬆️Pod_Update.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 更新目标工程的 Pod 依赖。

- 识别原生或 Flutter 项目并定位 Podfile。
- 按项目类型准备依赖命令和运行目录。
- 执行 pod update 并显示结果；Podfile.lock 和解析版本可能改变。

### <span id="jobs-toc-heading-34" data-jobs-toc="v2">[【MacOS】⬆️双击升级Cocoapods.command](<./MacOS/更新升级/【MacOS】⬆️双击升级Cocoapods.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 用 RubyGems 更新 CocoaPods 到远端可用版本。

- 读取本地 pod 与远端 Gem 版本。
- 核对 Ruby 和 Gem 路径。
- 版本不同时卸载已有 cocoapods Gem 再安装最新版。
- 刷新环境并显示 pod 路径。

### <span id="jobs-toc-heading-35" data-jobs-toc="v2">[【MacOS】⬆️双击升级Flutter.SDK.command](<./MacOS/更新升级/【MacOS】⬆️双击升级Flutter.SDK.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 根据安装来源升级 Flutter SDK。

- 识别 FVM 转发、Homebrew Flutter 或普通 SDK。
- 检查 SDK Git 修改。
- 支持选择 stable、beta、main、master 通道。
- 按来源执行对应升级。

### <span id="jobs-toc-heading-36" data-jobs-toc="v2">[【MacOS】⬆️双击更新CocoaPods本地仓库.command](<./MacOS/更新升级/【MacOS】⬆️双击更新CocoaPods本地仓库.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 刷新 CocoaPods 本地仓库并安装工程依赖。

- 确定工程根目录并检查入口依赖。
- 按提示处理本地 Specs 更新及脚本授权。
- 执行对应 pod install 流程，检查日志中的更新与安装结果。

### <span id="jobs-toc-heading-37" data-jobs-toc="v2">[【MacOS】⬆️双击更新Flutter依赖.command](<./MacOS/更新升级/【MacOS】⬆️双击更新Flutter依赖.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择清空缓存重拉或逐依赖更新 Flutter 包。

- 识别工程与 FVM。
- 通过 fzf 选择清空 hosted/pub.dev 缓存并 pub get，或逐项查询过期依赖、修改约束后 pub get。
- 展示最后的 outdated 结果。

### <span id="jobs-toc-heading-38" data-jobs-toc="v2">[【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command](<./MacOS/运行/【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 准备 Android 工具链、模拟器并运行 Flutter 项目。

- 检查 Homebrew、jenv、JDK、Android SDK 与 build-tools。
- 选择或创建 AVD 并等待启动。
- 识别 FVM。
- 处理依赖和 clean。
- 按 flavor、模式和 Dart 入口运行。
- 输出诊断。

### <span id="jobs-toc-heading-39" data-jobs-toc="v2">[【MacOS】📱双击初始化Android模拟器.command](<./MacOS/运行/【MacOS】📱双击初始化Android模拟器.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择设备型号和本机架构匹配的系统映像，创建唯一 AVD 并启动。缺失 SDK / JDK / 命令行工具可按首屏授权补齐，SDK 许可由本人阅读确认；已有设备与健康组件保留。

- 先展示用途、影响和取消方式，回车确认后检查本机工具。
- 按入口完成初始化、已有设备选择或工程 SDK 与模拟器选择；取消不继续。
- 显示实际结果与日志位置，保留已有设备和工程配置。

### <span id="jobs-toc-heading-40" data-jobs-toc="v2">[【MacOS】📱双击初始化鸿蒙模拟器.command](<./MacOS/运行/【MacOS】📱双击初始化鸿蒙模拟器.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 准备官方 DevEco Emulator 与 Release 系统镜像，选择镜像后创建唯一鸿蒙实例，校验名称、设备类型与版本，再启动。缺工具采用固定 SDL 镜像快照并校验摘要，系统镜像由官方工具下载；许可须本人阅读确认。

- 先展示用途、影响和取消方式，回车确认后检查本机工具。
- 按入口完成初始化、已有设备选择或工程 SDK 与模拟器选择；取消不继续。
- 显示实际结果与日志位置，保留已有设备和工程配置。

### <span id="jobs-toc-heading-41" data-jobs-toc="v2">[【MacOS】📱双击打开已实例化的鸿蒙模拟器.command](<./MacOS/运行/【MacOS】📱双击打开已实例化的鸿蒙模拟器.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 仅列出并启动已有鸿蒙实例，不下载工具或镜像、不创建设备。空列表明确提示先初始化，取消不启动。

- 先展示用途、影响和取消方式，回车确认后检查本机工具。
- 按入口完成初始化、已有设备选择或工程 SDK 与模拟器选择；取消不继续。
- 显示实际结果与日志位置，保留已有设备和工程配置。

### <span id="jobs-toc-heading-42" data-jobs-toc="v2">[【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command](<./MacOS/运行/【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择已有鸿蒙实例；缺失时进入初始化，再等待 Flutter 发现受支持的鸿蒙模拟器，选择设备、执行 pub get 和 run。显式 SDK 优先，其次项目 FVM 与 PATH；缺失 FVM 绑定或没有 HAP 能力即停止，不自动换成普通 Flutter。

- 先展示用途、影响和取消方式，回车确认后检查本机工具。
- 按入口完成初始化、已有设备选择或工程 SDK 与模拟器选择；取消不继续。
- 显示实际结果与日志位置，保留已有设备和工程配置。

### <span id="jobs-toc-heading-43" data-jobs-toc="v2">[【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command](<./MacOS/运行/【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择 iOS 模拟器并运行 Flutter 入口。

- 识别工程或 Dart 入口。
- 输入可选 flavor。
- 通过 fzf 选择 debug、release、profile。
- 可选 pub get。
- 选择或创建模拟器。
- 执行 run，失败时尝试 pod install。

### <span id="jobs-toc-heading-44" data-jobs-toc="v2">[【MacOS】🎈双击真机运行项目.command](<./MacOS/运行/【MacOS】🎈双击真机运行项目.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 以 release 模式把 Flutter 工程运行到连接设备。

- 拖入工程或 Dart 文件。
- 识别旧格式 .fvm/fvm_config.json 以选择 fvm flutter。
- 执行 flutter run --release。

### <span id="jobs-toc-heading-45" data-jobs-toc="v2">[【MacOS】📱双击初始化iOS模拟器.command](<./MacOS/运行/【MacOS】📱双击初始化iOS模拟器.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择系统运行时并创建可用的 iOS 模拟器。

- 检查模拟器后台状态和菜单工具。
- 选择可用运行时、设备类型与设备名称。
- 创建并启动模拟器，等待就绪后按提示继续创建或退出。

### <span id="jobs-toc-heading-46" data-jobs-toc="v2">[【MacOS】📱双击打开已实例化的iOS模拟器.command](<./MacOS/运行/【MacOS】📱双击打开已实例化的iOS模拟器.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 打开系统 iOS Simulator 应用。

- 调用 open -a Simulator。
- 由 Simulator 恢复当前设备窗口。

### <span id="jobs-toc-heading-47" data-jobs-toc="v2">[【MacOS】🚀双击启动Android模拟器.command](<./MacOS/运行/【MacOS】🚀双击启动Android模拟器.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择或创建 Android AVD 并启动。

- 检查 emulator、sdkmanager、avdmanager 和菜单工具。
- 选择既有 AVD；缺失时按提示创建。
- 启动模拟器并等待设备可用。

### <span id="jobs-toc-heading-48" data-jobs-toc="v2">[【MacOS】⏬双击配置VSCode.command](<./MacOS/配置相关/【MacOS】⏬双击配置VSCode.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 下载并替换 Flutter 工程和 VS Code 全局配置。

- 下载 VSCodeConfigByFlutter 与 JobsConfigByVSCode。
- 已有非空目录先移动并压缩备份。
- 复制仓库内容并剔除仓库管理文件。
- 打开目标目录。

### <span id="jobs-toc-heading-49" data-jobs-toc="v2">[【MacOS】💉VSCode配置注入@全局.command](<./MacOS/配置相关/【MacOS】VSCode.command/【MacOS】💉VSCode配置注入%40全局.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 把预设配置仓库注入 VS Code 全局 User 目录。

- 先删除当前用户 VS Code User。
- 克隆 JobsConfigByVSCode 并复制配置。
- 去掉 .git 等文件。
- 打开目录并退出/重新启动 VS Code。

### <span id="jobs-toc-heading-50" data-jobs-toc="v2">[【MacOS】💉VSCode配置注入@当前Flutter项目.command](<./MacOS/配置相关/【MacOS】VSCode.command/【MacOS】💉VSCode配置注入%40当前Flutter项目.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 把 Flutter 编辑器配置写入脚本所在目录。

- 删除脚本目录的 .vscode。
- 克隆 VScodeConfigByFlutter。
- 复制配置并去掉 Git 管理文件。

### <span id="jobs-toc-heading-51" data-jobs-toc="v2">[【MacOS】⏬下载配置系统环境变量.command](<./MacOS/配置相关/【MacOS】⏬下载配置系统环境变量.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 下载预设的 macOS 环境变量配置仓库。

- 检查目标目录是否已存在。
- 按回答选择删除重建。
- 克隆源码配置的环境仓库。

### <span id="jobs-toc-heading-52" data-jobs-toc="v2">[【MacOS】⏬双击下载SourceTree效率脚本.command](<./MacOS/配置相关/【MacOS】⏬双击下载SourceTree效率脚本.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 下载 SourceTree 自定义动作脚本集合。

- 删除预设的本地 SourceTree.command 目录。
- 浅克隆 SourceTree.sh。
- 给其中 .sh 与 .command 添加执行权限。
- 打开结果目录。

### <span id="jobs-toc-heading-53" data-jobs-toc="v2">[【MacOS】⚙️Flutter 项目组件预下载.command](<./MacOS/配置相关/【MacOS】⚙️Flutter 项目组件预下载.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 备份 Flutter 引擎缓存并按平台预下载组件。

- 定位 Flutter 工程。
- 识别 FVM 或全局 SDK 的 bin/cache。
- 以 rsync 备份缓存。
- 通过 fzf 多选平台执行 precache。

### <span id="jobs-toc-heading-54" data-jobs-toc="v2">[【MacOS】⚙️一键配置Flutter项目至运行.command](<./MacOS/配置相关/【MacOS】⚙️一键配置Flutter项目至运行.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 为 Apple Silicon 工程准备 FVM 与 VS Code 的直接运行配置。

- 校验原生 ARM64 环境，定位含 pubspec.yaml 和 lib 的工程。
- 准备 FVM、选定 Flutter 版本与 iOS 缓存。
- 备份并写入 VS Code settings / launch 配置，提示重载编辑器后按 F5；脚本本身不启动 App。

### <span id="jobs-toc-heading-55" data-jobs-toc="v2">[【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command](<./MacOS/配置相关/【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 为现有 Flutter 工程准备鸿蒙适配 SDK、构建工具和设备，完成配置并按需运行。

- 先阅读内置自述并回车，拖入工程；固定鸿蒙 SDK 与项目 FVM，已有其它绑定须精确 `YES` 切换。
- 检查 Homebrew、Python、FVM、DevEco / CLT、JDK 17 和鸿蒙 SDK；缺失按提示准备，下载前显示来源与目标。
  - 模拟器复用官方 Emulator：工具包校验后安装，镜像本人确认许可后下载，可选创建并回读核验；真机可只准备工具。
- 保留已有 `ohos/` 与签名；缺平台目录须精确 `YES` 生成，安全合并编辑器环境并解析两侧依赖。
- 仅选择鸿蒙设备运行；无设备可重新加载或创建，失败保留日志与备份。`--help` / `--check` 不安装、不改工程。

### <span id="jobs-toc-heading-56" data-jobs-toc="v2">[【MacOS】⚙️下载配置系统环境变量.command](<./MacOS/配置相关/【MacOS】⚙️下载配置系统环境变量.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 下载预设的 macOS 环境变量配置仓库。

- 检查目标目录是否已存在。
- 按回答选择删除重建。
- 克隆源码配置的环境仓库。

### <span id="jobs-toc-heading-57" data-jobs-toc="v2">[【MacOS】⚙️双击安装FVM.command](<./MacOS/配置相关/【MacOS】⚙️双击安装FVM.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 安装 FVM 并为当前 Flutter 项目选择 SDK。

- 验证工程路径。
- 检查 Homebrew、jq、fzf。
- 提供官方、Homebrew、FVM 安装分支。
- 读取项目绑定与可用稳定版本。
- 执行 fvm install 和 use。

### <span id="jobs-toc-heading-58" data-jobs-toc="v2">[【MacOS】⚙️双击安装Flutter.SDK.command](<./MacOS/配置相关/【MacOS】⚙️双击安装Flutter.SDK.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择官方包、Homebrew 或 FVM 安装 Flutter SDK。

- 准备 Homebrew 与 fzf。
- 通过菜单选择官方 SDK 压缩包下载、Homebrew 安装/升级、FVM 安装/绑定。
- 处理对应环境配置并查看版本。

### <span id="jobs-toc-heading-59" data-jobs-toc="v2">[【MacOS】⚙️双击安装（升级）Homebrew.command](<./MacOS/配置相关/【MacOS】⚙️双击安装（升级）Homebrew.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 安装 Homebrew 并准备一组开发工具。

- 识别芯片与已有 Homebrew。
- 按选择路径安装或复用。
- 写入 Shell 环境。
- 可选执行 update、upgrade、cleanup、doctor。
- 安装源码清单中的命令与 Flutter Cask。

### <span id="jobs-toc-heading-60" data-jobs-toc="v2">[【MacOS】⚙️收集当前Flutter工程的依赖.command](<./MacOS/配置相关/【MacOS】⚙️收集当前Flutter工程的依赖.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 将工程实际解析的 Flutter 和原生依赖整理为可追溯压缩包。

- 定位 Flutter 工程，检查 SDK 和已有 package_config.json。
- 按所选范围读取实际包路径，复制依赖源码及关键工程清单。
- 写入收集说明并生成桌面 Zip，显示输出位置。

### <span id="jobs-toc-heading-61" data-jobs-toc="v2">[【MacOS】⚙️配置Android Studio.command](<./MacOS/配置相关/【MacOS】⚙️配置Android Studio.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 安装 Android 命令行工具并创建 API 34 模拟器。

- 下载固定版本 Command-line Tools。
- 设置当前进程 SDK 环境。
- 安装平台、构建工具和模拟器镜像。
- 创建 Pixel_5_API_34。
- 通过 fzf 启动 AVD 并等候就绪。

### <span id="jobs-toc-heading-62" data-jobs-toc="v2">[【MacOS】🎈双击打开系统配置文件.command](<./MacOS/配置相关/【MacOS】🎈双击打开系统配置文件.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 选择打开并加载已有 Shell 配置。

- 检查 Homebrew 与 fzf。
- 收集 bash_profile、bashrc、zshrc 和 Oh My Zsh 脚本。
- 多选后逐项 open 与 source。

### <span id="jobs-toc-heading-63" data-jobs-toc="v2">[【MacOS】⚙️双击安装Cocoapods.command](<./MacOS/Cocoapods/【MacOS】⚙️双击安装Cocoapods.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 准备 Ruby 工具链并安装 CocoaPods。

- 具体功能、选项、产物与运行步骤见相邻 README。

### <span id="jobs-toc-heading-64" data-jobs-toc="v2">[【MacOS】🧪提取Flutter第三方依赖.command](<./MacOS/小工具/【MacOS】🧪提取Flutter第三方依赖.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 双击同目录的 [【MacOS】🧪提取Flutter第三方依赖.command](<./MacOS/小工具/【MacOS】🧪提取Flutter第三方依赖.command/【MacOS】🧪提取Flutter第三方依赖.command>)，输入或拖入 [**Flutter**](https://flutter.dev/) 项目文件夹，再选择输出父目录。

- 具体功能、选项、产物与运行步骤见相邻 README。

### <span id="jobs-toc-heading-65" data-jobs-toc="v2">[【MacOS】⏬双击配置VSCode.command](<./MacOS/配置相关/【MacOS】VSCode.command/【MacOS】⏬双击配置VSCode.command/README.md>)</span><!-- jobs-toc:heading-end -->

> **目的：** 下载并替换 Flutter 工程和 VS Code 全局配置。

- 具体功能、选项、产物与运行步骤见相邻 README。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
