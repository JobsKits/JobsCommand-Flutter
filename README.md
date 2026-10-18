# `JobsCommand@Flutter`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

[**Flutter**](https://flutter.dev/) 工程的安装、运行、打包和维护入口。 每个独立脚本按其内置自述和源码定位目标；先阅读流程，确认路径后再运行。

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

## 一、<span id="repository-layout">目录结构</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

下面按当前磁盘第一层列出真实文件与目录；包内主脚本由下方完整名称直接进入。

```text
JobsCommand@Flutter/
├── README.md
├── Cocoapods/  # 4 个入口
├── Git操作/  # 3 个入口
├── 【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command/  # 1 个入口
├── 小工具/  # 19 个入口
├── 屏幕录制/  # 2 个入口
├── 打包相关/  # 2 个入口
├── 更新升级/  # 5 个入口
├── 运行/  # 6 个入口
└── 配置相关/  # 16 个入口
```

## 二、<span id="script-workflows">脚本执行流程</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本仓共有 58 个用户入口。这里只列本仓维护的主入口；独立子 Git、测试、函数库及打包资源模板不作为用户运行入口。步骤来自静态源码与配套说明，未执行安装、清理、构建或 Git 写操作。

### [【MacOS】⚙️Pod_Install.command](./Cocoapods/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8FPod_Install.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8FPod_Install.command)

> **目的：** 根据原生或 [**Flutter**](https://flutter.dev/) 项目结构安装 Pod 依赖。

- 初始化 UTF-8、工具路径与工程目录。
- 识别原生或 Flutter 工程，准备对应 Podfile 所在位置。
- 执行对应 pod install 流程，输出完成状态与日志。


### [【MacOS】⚙️双击安装Cocoapods.command](./Cocoapods/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85Cocoapods.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85Cocoapods.command)

> **目的：** 准备 [**Ruby**](https://www.ruby-lang.org/) 环境并安装 [**CocoaPods**](https://cocoapods.org/)。

- 备份相关 Shell 配置，检查 [**Homebrew**](https://brew.sh/)、Ruby 与交互工具。
- 选择 Ruby / CocoaPods 安装方式并处理 gem 源。
- 安装并校验 pod 命令，按提示决定是否初始化本地 Specs 仓库。


### [【MacOS】⚙️双击更换Cocoapods源[-]CDN[+]Github.command](./Cocoapods/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%9B%B4%E6%8D%A2Cocoapods%E6%BA%90%5B-%5DCDN%5B%2B%5DGithub.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%9B%B4%E6%8D%A2Cocoapods%E6%BA%90%5B-%5DCDN%5B%2B%5DGithub.command)

> **目的：** 将 CocoaPods 的 CDN Specs 源切换为 [**Git**](https://git-scm.com/) 源。

- 阅读源切换和本地缓存影响。
- 移除脚本指定的 CDN trunk 与缓存目录。
- 添加 Git Specs 源并输出源配置结果。


### [【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command](./Cocoapods/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E7%A6%81%E7%94%A8%E6%B2%99%E7%9B%92%E4%BF%9D%E8%AF%81Cocoapods%E6%9E%84%E5%BB%BA%E6%B5%81%E7%A8%8B.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E7%A6%81%E7%94%A8%E6%B2%99%E7%9B%92%E4%BF%9D%E8%AF%81Cocoapods%E6%9E%84%E5%BB%BA%E6%B5%81%E7%A8%8B.command)

> **目的：** 修改目标 [**Xcode**](https://developer.apple.com/xcode/) 工程的用户脚本沙盒设置。

- 定位工程目录，查找或手工指定 .xcodeproj。
- 检查 project.pbxproj 中的脚本沙盒配置。
- 将对应设置改为禁用并报告结果；构建仍需在项目中验证。


### [【MacOS】♻️双击Git（识别子Git） 提交回退.command](./Git%E6%93%8D%E4%BD%9C/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E5%8F%8C%E5%87%BBGit%EF%BC%88%E8%AF%86%E5%88%AB%E5%AD%90Git%EF%BC%89%20%E6%8F%90%E4%BA%A4%E5%9B%9E%E9%80%80.command/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E5%8F%8C%E5%87%BBGit%EF%BC%88%E8%AF%86%E5%88%AB%E5%AD%90Git%EF%BC%89%20%E6%8F%90%E4%BA%A4%E5%9B%9E%E9%80%80.command)

> **目的：** 为选中的 Git 仓库选择历史目标并执行回退。

- 定位当前仓库或子仓，检查可用的历史记录。
- 选择回退目标与模式，核对即将影响的提交和工作区。
- 按脚本确认后执行回退并打印状态。
  - 如果选择 hard，工作区修改可能丢失；先核对备份和确认提示。


### [【MacOS】🔍Git依据提交日志关键字查找.command](./Git%E6%93%8D%E4%BD%9C/%E3%80%90MacOS%E3%80%91%F0%9F%94%8DGit%E4%BE%9D%E6%8D%AE%E6%8F%90%E4%BA%A4%E6%97%A5%E5%BF%97%E5%85%B3%E9%94%AE%E5%AD%97%E6%9F%A5%E6%89%BE.command/%E3%80%90MacOS%E3%80%91%F0%9F%94%8DGit%E4%BE%9D%E6%8D%AE%E6%8F%90%E4%BA%A4%E6%97%A5%E5%BF%97%E5%85%B3%E9%94%AE%E5%AD%97%E6%9F%A5%E6%89%BE.command)

> **目的：** 按提交说明关键词定位历史记录。

- 确定目标 Git 仓库并输入搜索关键词。
- 筛选提交记录，在列表中选择要查看的提交。
- 显示提交号、作者、时间与标题，按提示继续查询。


### [【MacOS】🔍Git寻找分支最近的一次原始切点.command](./Git%E6%93%8D%E4%BD%9C/%E3%80%90MacOS%E3%80%91%F0%9F%94%8DGit%E5%AF%BB%E6%89%BE%E5%88%86%E6%94%AF%E6%9C%80%E8%BF%91%E7%9A%84%E4%B8%80%E6%AC%A1%E5%8E%9F%E5%A7%8B%E5%88%87%E7%82%B9.command/%E3%80%90MacOS%E3%80%91%F0%9F%94%8DGit%E5%AF%BB%E6%89%BE%E5%88%86%E6%94%AF%E6%9C%80%E8%BF%91%E7%9A%84%E4%B8%80%E6%AC%A1%E5%8E%9F%E5%A7%8B%E5%88%87%E7%82%B9.command)

> **目的：** 找出两条分支最近的共同历史起点。

- 确定 Git 仓库并列出可比较的分支。
- 选择两条分支，计算共同祖先或分叉起点。
- 输出提交信息，并按提示继续下一轮比较。


### [【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command](./%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8FGit%E6%8B%89%E5%8F%96Flutter%E9%A1%B9%E7%9B%AE%E5%88%B0%E6%9C%AC%E5%9C%B0%E4%BB%A5%E5%90%8E%E7%9A%84%E5%BF%85%E8%A6%81%E9%85%8D%E7%BD%AE.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8FGit%E6%8B%89%E5%8F%96Flutter%E9%A1%B9%E7%9B%AE%E5%88%B0%E6%9C%AC%E5%9C%B0%E4%BB%A5%E5%90%8E%E7%9A%84%E5%BF%85%E8%A6%81%E9%85%8D%E7%BD%AE.command)

> **目的：** 在新拉取的 Flutter 工程中补齐运行前配置。

- 确认项目根目录与全局 / [**FVM**](https://fvm.app/) 工具链。
- 按交互检查环境、依赖及平台配置。
- 依次执行选定准备动作，并输出运行或排错提示。


### [【MacOS】♻️修复Flutter项目中文路径.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E4%BF%AE%E5%A4%8DFlutter%E9%A1%B9%E7%9B%AE%E4%B8%AD%E6%96%87%E8%B7%AF%E5%BE%84.command/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E4%BF%AE%E5%A4%8DFlutter%E9%A1%B9%E7%9B%AE%E4%B8%AD%E6%96%87%E8%B7%AF%E5%BE%84.command)

> **目的：** 将 Dart package 路径中的 URI 编码中文还原为正常字符。

- 识别项目与 Flutter 环境，检查所需解码工具。
- 扫描 Dart 指令，备份并替换匹配的 URI 编码路径。
- 输出变更数量，按提示决定是否继续分析或升级。


### [【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E5%8F%8C%E5%87%BB%E4%BF%AE%E5%A4%8D%EF%BC%9A%E6%89%BE%E4%B8%8D%E5%88%B0%20Android%20SDK%20%E6%88%96%20platforms%20%E7%9B%AE%E5%BD%95%E4%B8%BA%E7%A9%BA.command/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E5%8F%8C%E5%87%BB%E4%BF%AE%E5%A4%8D%EF%BC%9A%E6%89%BE%E4%B8%8D%E5%88%B0%20Android%20SDK%20%E6%88%96%20platforms%20%E7%9B%AE%E5%BD%95%E4%B8%BA%E7%A9%BA.command)

> **目的：** 补齐 Android SDK 命令行工具和核心组件。

- 识别 FVM 或全局 Flutter 并确定 SDK 目录。
- 下载或检查 cmdline-tools，安装所需 platforms 等组件。
- 配置 Flutter 的 Android SDK 路径，运行 doctor 并按提示决定是否 pub get。


### [【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E5%BD%93%E5%89%8D%E8%84%9A%E6%9C%AC%E6%89%80%E5%9C%A8%E7%9B%AE%E5%BD%95%E7%9A%84%E5%BF%AB%E6%8D%B7%E6%96%B9%E5%BC%8F%E6%94%BE%E5%88%B0%E6%A1%8C%E9%9D%A2.command/%E3%80%90MacOS%E3%80%91%E2%99%BB%EF%B8%8F%E5%BD%93%E5%89%8D%E8%84%9A%E6%9C%AC%E6%89%80%E5%9C%A8%E7%9B%AE%E5%BD%95%E7%9A%84%E5%BF%AB%E6%8D%B7%E6%96%B9%E5%BC%8F%E6%94%BE%E5%88%B0%E6%A1%8C%E9%9D%A2.command)

> **目的：** 在桌面建立脚本当前目录的快捷入口。

- 读取脚本所在的真实目录。
- 通过 [**Finder**](https://support.apple.com/guide/mac-help/mchlp2605/mac) / AppleScript 创建桌面快捷方式。
- 检查桌面目标是否指向预期目录。


### [【MacOS】⚙️import =>package💣.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8Fimport%20%3D%3Epackage%F0%9F%92%A3.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8Fimport%20%3D%3Epackage%F0%9F%92%A3.command)

> **目的：** 将工程内 Dart 相对 import 改为 package 引用。

- 确认包含 pubspec.yaml 和 lib 的项目目录。
- 读取包名并扫描 Dart 文件中的 import。
- 按包内路径替换匹配引用，输出处理结果。


### [【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E4%BF%9D%E5%AD%98%E7%B3%BB%E7%BB%9F%E7%8E%AF%E5%A2%83%E9%85%8D%E7%BD%AE%EF%BC%88%E8%BF%90%E8%A1%8C%E5%90%8E%E8%BE%93%E5%85%A5jobs%EF%BC%89.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E4%BF%9D%E5%AD%98%E7%B3%BB%E7%BB%9F%E7%8E%AF%E5%A2%83%E9%85%8D%E7%BD%AE%EF%BC%88%E8%BF%90%E8%A1%8C%E5%90%8E%E8%BE%93%E5%85%A5jobs%EF%BC%89.command)

> **目的：** 注册 jobs 便捷命令并加载现有 Shell 配置。

- 检查 .zshrc 中是否已有 jobs 函数。
- 缺失时写入函数，再依次加载脚本列出的配置文件。
- 输出配置路径；之后可在终端输入 jobs。


### [【MacOS】⚙️双击任何来源安装.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E4%BB%BB%E4%BD%95%E6%9D%A5%E6%BA%90%E5%AE%89%E8%A3%85.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E4%BB%BB%E4%BD%95%E6%9D%A5%E6%BA%90%E5%AE%89%E8%A3%85.command)

> **目的：** 调整 macOS 应用来源限制并打开安全设置。

- 阅读系统安全设置影响并继续。
- 检查 SIP 状态，执行脚本中的应用来源设置命令。
- 打开系统设置，人工核对“任何来源”是否可用。


### [【MacOS】⚙️双击卸载Homebrew.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%8D%B8%E8%BD%BDHomebrew.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%8D%B8%E8%BD%BDHomebrew.command)

> **目的：** 卸载 Homebrew 并处理脚本列出的残留目录。

- 查看自述与卸载范围，按脚本要求再次确认。
- 运行官方卸载入口，再处理配置的残留路径。
- 核对终端结果；依赖 Homebrew 的工具可能随之不可用。


### [【MacOS】⚙️双击显示隐藏文件.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%98%BE%E7%A4%BA%E9%9A%90%E8%97%8F%E6%96%87%E4%BB%B6.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%98%BE%E7%A4%BA%E9%9A%90%E8%97%8F%E6%96%87%E4%BB%B6.command)

> **目的：** 切换 Finder 的隐藏文件显示状态。

- 读取 Finder 当前的隐藏文件设置。
- 切换 AppleShowAllFiles 配置。
- 重启 Finder，使新显示状态生效。


### [【MacOS】⚙️自动化替换Flutter图片资源.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E8%87%AA%E5%8A%A8%E5%8C%96%E6%9B%BF%E6%8D%A2Flutter%E5%9B%BE%E7%89%87%E8%B5%84%E6%BA%90.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E8%87%AA%E5%8A%A8%E5%8C%96%E6%9B%BF%E6%8D%A2Flutter%E5%9B%BE%E7%89%87%E8%B5%84%E6%BA%90.command)

> **目的：** 替换工程图标与启动图并重新生成资源。

- 检查预设图片来源、工程资源目录和生成配置。
- 复制图标或启动图到目标位置，清理被替换的旧资源。
- 执行依赖拉取及图标、启动图生成，打开结果目录。


### [【MacOS】⚙️运行授权.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E8%BF%90%E8%A1%8C%E6%8E%88%E6%9D%83.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E8%BF%90%E8%A1%8C%E6%8E%88%E6%9D%83.command)

> **目的：** 为指定脚本或目录中的入口补执行权限。

- 阅读影响范围，输入或拖入待授权目标。
- 选择单项或递归扫描范围并执行 chmod。
  - 如果选择递归，会处理该目标下匹配的脚本；先确认目录范围。
- 输出成功与失败结果，按提示继续或退出。


### [【MacOS】🌞颜色格式的转换.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%8C%9E%E9%A2%9C%E8%89%B2%E6%A0%BC%E5%BC%8F%E7%9A%84%E8%BD%AC%E6%8D%A2.command/%E3%80%90MacOS%E3%80%91%F0%9F%8C%9E%E9%A2%9C%E8%89%B2%E6%A0%BC%E5%BC%8F%E7%9A%84%E8%BD%AC%E6%8D%A2.command)

> **目的：** 在常见颜色数值表示之间转换。

- 输入颜色值或使用命令行参数。
- 识别十六进制、RGB 等受支持格式并计算对应表示。
- 输出转换结果，继续输入或按退出指令结束。


### [【MacOS】🎈切换Shell.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%88%87%E6%8D%A2Shell.command/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%88%87%E6%8D%A2Shell.command)

> **目的：** 从系统允许的 Shell 中选择并切换登录 Shell。

- 检查菜单工具并读取可用 Shell 列表。
- 选择目标 Shell，核对路径。
- 执行切换并显示结果；新终端会使用新的登录 Shell。


### [【MacOS】🎈双击打开当前路径终端.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%8F%8C%E5%87%BB%E6%89%93%E5%BC%80%E5%BD%93%E5%89%8D%E8%B7%AF%E5%BE%84%E7%BB%88%E7%AB%AF.command/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%8F%8C%E5%87%BB%E6%89%93%E5%BC%80%E5%BD%93%E5%89%8D%E8%B7%AF%E5%BE%84%E7%BB%88%E7%AB%AF.command)

> **目的：** 在脚本对应目录打开系统终端。

- 读取脚本目录并核对需要进入的位置。
- 通过 AppleScript 打开 [**Terminal**](https://support.apple.com/guide/terminal/welcome/mac) 并执行 cd。
- 在新终端继续操作；以脚本中实际窗口处理逻辑为准。


### [【MacOS】🏥双击自检Flutter.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%8F%A5%E5%8F%8C%E5%87%BB%E8%87%AA%E6%A3%80Flutter.command/%E3%80%90MacOS%E3%80%91%F0%9F%8F%A5%E5%8F%8C%E5%87%BB%E8%87%AA%E6%A3%80Flutter.command)

> **目的：** 检查 Flutter、Dart、Xcode 和 Android 开发环境。

- 识别全局或 FVM 工具链并显示版本。
- 检查 Java、SDK、环境变量与可用设备。
- 运行 doctor 和工程分析，输出环境诊断结果。


### [【MacOS】🐦Flutter自动化生产代码.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%90%A6Flutter%E8%87%AA%E5%8A%A8%E5%8C%96%E7%94%9F%E4%BA%A7%E4%BB%A3%E7%A0%81.command/%E3%80%90MacOS%E3%80%91%F0%9F%90%A6Flutter%E8%87%AA%E5%8A%A8%E5%8C%96%E7%94%9F%E4%BA%A7%E4%BB%A3%E7%A0%81.command)

> **目的：** 按工程配置生成 Flutter 代码与资源。

- 定位工程并读取生成工具配置。
- 按入口顺序清理、拉取依赖并执行已配置的代码或资源生成器。
- 显示生成结果；涉及生成源码与资源时需审查工作区差异。


### [【MacOS】🔍查询Flutter依赖版本.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%94%8D%E6%9F%A5%E8%AF%A2Flutter%E4%BE%9D%E8%B5%96%E7%89%88%E6%9C%AC.command/%E3%80%90MacOS%E3%80%91%F0%9F%94%8D%E6%9F%A5%E8%AF%A2Flutter%E4%BE%9D%E8%B5%96%E7%89%88%E6%9C%AC.command)

> **目的：** 查询 Flutter 工程依赖的版本信息。

- 识别或输入 Flutter 项目目录。
- 输入需要查询的依赖名并读取相关版本信息。
- 显示结果并继续查询，按提示退出。


### [【MacOS】🛠️Android 模拟器一键检测与修复.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%9B%A0%EF%B8%8FAndroid%20%E6%A8%A1%E6%8B%9F%E5%99%A8%E4%B8%80%E9%94%AE%E6%A3%80%E6%B5%8B%E4%B8%8E%E4%BF%AE%E5%A4%8D.command/%E3%80%90MacOS%E3%80%91%F0%9F%9B%A0%EF%B8%8FAndroid%20%E6%A8%A1%E6%8B%9F%E5%99%A8%E4%B8%80%E9%94%AE%E6%A3%80%E6%B5%8B%E4%B8%8E%E4%BF%AE%E5%A4%8D.command)

> **目的：** 检查 Android 模拟器安装失败、存储或设备状态问题。

- 选择设备或 AVD，检查 adb 与模拟器状态。
- 按提示选择卸载旧应用、调整存储等修复动作。
- 执行选定动作并给出重试 flutter run 的提示。


### [【MacOS】🛠️Flutter 插件 namespace 修复工具".command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%9B%A0%EF%B8%8FFlutter%20%E6%8F%92%E4%BB%B6%20namespace%20%E4%BF%AE%E5%A4%8D%E5%B7%A5%E5%85%B7%22.command/%E3%80%90MacOS%E3%80%91%F0%9F%9B%A0%EF%B8%8FFlutter%20%E6%8F%92%E4%BB%B6%20namespace%20%E4%BF%AE%E5%A4%8D%E5%B7%A5%E5%85%B7%22.command)

> **目的：** 补齐缓存中 Flutter 插件的 Android namespace。

- 确认将检查的 pub-cache 插件范围。
- 扫描 Gradle 文件，定位缺少 namespace 的插件并推导名称。
- 写入修复并输出结果；这些缓存修改可能被后续依赖下载替换。


### [【MacOS】🧹Flutter清理维护工具.command](./%E5%B0%8F%E5%B7%A5%E5%85%B7/%E3%80%90MacOS%E3%80%91%F0%9F%A7%B9Flutter%E6%B8%85%E7%90%86%E7%BB%B4%E6%8A%A4%E5%B7%A5%E5%85%B7.command/%E3%80%90MacOS%E3%80%91%F0%9F%A7%B9Flutter%E6%B8%85%E7%90%86%E7%BB%B4%E6%8A%A4%E5%B7%A5%E5%85%B7.command)

> **目的：** 按菜单刷新 Flutter 依赖或清理不同层级缓存。

- 选择工程并识别全局或 FVM SDK。
- 选择刷新依赖、项目清理、SDK 缓存或 iOS 缓存清理。
- 按所选项执行清理或依赖更新。
  - 如果删除 lock、Pods 或全局 DerivedData，依赖解析与其它工程缓存也可能受影响。


### [【MacOS】📹双击制作Android模拟器录屏Gif.command](./%E5%B1%8F%E5%B9%95%E5%BD%95%E5%88%B6/%E3%80%90MacOS%E3%80%91%F0%9F%93%B9%E5%8F%8C%E5%87%BB%E5%88%B6%E4%BD%9CAndroid%E6%A8%A1%E6%8B%9F%E5%99%A8%E5%BD%95%E5%B1%8FGif.command/%E3%80%90MacOS%E3%80%91%F0%9F%93%B9%E5%8F%8C%E5%87%BB%E5%88%B6%E4%BD%9CAndroid%E6%A8%A1%E6%8B%9F%E5%99%A8%E5%BD%95%E5%B1%8FGif.command)

> **目的：** 录制 Android 设备画面并可合并视频、生成 GIF。

- 选择 adb 设备并检查录制与转换工具。
- 启动分段录制，停止后拉取视频到本机。
- 按提示选择合并、GIF 尺寸帧率和临时帧清理，打开产物。


### [【MacOS】📹双击制作iOS模拟器录屏Gif.command](./%E5%B1%8F%E5%B9%95%E5%BD%95%E5%88%B6/%E3%80%90MacOS%E3%80%91%F0%9F%93%B9%E5%8F%8C%E5%87%BB%E5%88%B6%E4%BD%9CiOS%E6%A8%A1%E6%8B%9F%E5%99%A8%E5%BD%95%E5%B1%8FGif.command/%E3%80%90MacOS%E3%80%91%F0%9F%93%B9%E5%8F%8C%E5%87%BB%E5%88%B6%E4%BD%9CiOS%E6%A8%A1%E6%8B%9F%E5%99%A8%E5%BD%95%E5%B1%8FGif.command)

> **目的：** 录制选定 iOS 模拟器并按需生成 GIF。

- 检查录制与转换工具，选择模拟器并等待启动。
- 开始录制，按提示停止并保存视频。
- 选择是否转换 GIF，填写尺寸与帧率后转换。
  - 如果不转换，保留已生成的视频。
- 打开录制或转换产物。


### [【MacOS】📦双击打包Flutter.Android.command](./%E6%89%93%E5%8C%85%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%F0%9F%93%A6%E5%8F%8C%E5%87%BB%E6%89%93%E5%8C%85Flutter.Android.command/%E3%80%90MacOS%E3%80%91%F0%9F%93%A6%E5%8F%8C%E5%87%BB%E6%89%93%E5%8C%85Flutter.Android.command)

> **目的：** 为选定 Flutter 工程构建 Android 产物。

- 识别项目入口、FVM 与 Java 环境，输出构建前诊断。
- 按提示决定 clean、pub get 及插件依赖准备。
- 选择构建模式与 APK / AAB 后执行构建，打开产物目录。


### [【MacOS】📦双击打包Flutter.iOS.command](./%E6%89%93%E5%8C%85%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%F0%9F%93%A6%E5%8F%8C%E5%87%BB%E6%89%93%E5%8C%85Flutter.iOS.command/%E3%80%90MacOS%E3%80%91%F0%9F%93%A6%E5%8F%8C%E5%87%BB%E6%89%93%E5%8C%85Flutter.iOS.command)

> **目的：** 构建 Flutter 的 iOS 归档与 IPA。

- 选择项目和 Dart 入口并检查构建环境。
- 按所选配置执行 Flutter iOS 构建与导出。
- 核验 IPA 输出，打开目录并显示耗时。


### [【MacOS】⬆️Pod_Update.command](./%E6%9B%B4%E6%96%B0%E5%8D%87%E7%BA%A7/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8FPod_Update.command/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8FPod_Update.command)

> **目的：** 更新目标工程的 Pod 依赖。

- 识别原生或 Flutter 项目并定位 Podfile。
- 按项目类型准备依赖命令和运行目录。
- 执行 pod update 并显示结果；Podfile.lock 和解析版本可能改变。


### [【MacOS】⬆️双击升级Cocoapods.command](./%E6%9B%B4%E6%96%B0%E5%8D%87%E7%BA%A7/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%8D%87%E7%BA%A7Cocoapods.command/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%8D%87%E7%BA%A7Cocoapods.command)

> **目的：** 比较并升级 CocoaPods 版本。

- 检查 Ruby、gem 与当前 pod 版本。
- 查询可用版本并判断是否需要更新。
- 按确认执行升级，再显示版本与命令位置。


### [【MacOS】⬆️双击升级Flutter.SDK.command](./%E6%9B%B4%E6%96%B0%E5%8D%87%E7%BA%A7/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%8D%87%E7%BA%A7Flutter.SDK.command/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%8D%87%E7%BA%A7Flutter.SDK.command)

> **目的：** 升级全局或工程关联的 Flutter SDK。

- 识别 SDK 来源、当前版本及项目环境。
- 按提示选择需要执行的升级动作。
- 执行更新并显示版本或 doctor 结果；工程依赖兼容性需再验证。


### [【MacOS】⬆️双击更新CocoaPods本地仓库.command](./%E6%9B%B4%E6%96%B0%E5%8D%87%E7%BA%A7/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%9B%B4%E6%96%B0CocoaPods%E6%9C%AC%E5%9C%B0%E4%BB%93%E5%BA%93.command/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%9B%B4%E6%96%B0CocoaPods%E6%9C%AC%E5%9C%B0%E4%BB%93%E5%BA%93.command)

> **目的：** 刷新 CocoaPods 本地仓库并安装工程依赖。

- 确定工程根目录并检查入口依赖。
- 按提示处理本地 Specs 更新及脚本授权。
- 执行对应 pod install 流程，检查日志中的更新与安装结果。


### [【MacOS】⬆️双击更新Flutter依赖.command](./%E6%9B%B4%E6%96%B0%E5%8D%87%E7%BA%A7/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%9B%B4%E6%96%B0Flutter%E4%BE%9D%E8%B5%96.command/%E3%80%90MacOS%E3%80%91%E2%AC%86%EF%B8%8F%E5%8F%8C%E5%87%BB%E6%9B%B4%E6%96%B0Flutter%E4%BE%9D%E8%B5%96.command)

> **目的：** 更新工程依赖并处理依赖文件检查。

- 定位项目并识别全局或 FVM Flutter。
- 检查当前依赖状态，按提示选择更新动作。
- 执行依赖拉取或升级，核对 pubspec.lock 与分析输出。


### [【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command](./%E8%BF%90%E8%A1%8C/%E3%80%90MacOS%E3%80%91%E2%98%80%EF%B8%8F%E5%8F%8C%E5%87%BB%E8%BF%90%E8%A1%8CFlutter%E9%A1%B9%E7%9B%AE%EF%BC%88Android%20%E6%A8%A1%E6%8B%9F%E5%99%A8%EF%BC%89%20.command/%E3%80%90MacOS%E3%80%91%E2%98%80%EF%B8%8F%E5%8F%8C%E5%87%BB%E8%BF%90%E8%A1%8CFlutter%E9%A1%B9%E7%9B%AE%EF%BC%88Android%20%E6%A8%A1%E6%8B%9F%E5%99%A8%EF%BC%89%20.command)

> **目的：** 启动 Android 模拟器并运行 Flutter 工程。

- 识别 SDK 与入口，选择或启动 Android 设备。
- 检查 Java、Android 构建环境并处理缺失 namespace。
- 准备依赖后执行 flutter run，查看终端日志。


### [【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command](./%E8%BF%90%E8%A1%8C/%E3%80%90MacOS%E3%80%91%E2%98%80%EF%B8%8F%E5%8F%8C%E5%87%BB%E8%BF%90%E8%A1%8CFlutter%E9%A1%B9%E7%9B%AE%EF%BC%88iOS%20%E6%A8%A1%E6%8B%9F%E5%99%A8%EF%BC%89.command/%E3%80%90MacOS%E3%80%91%E2%98%80%EF%B8%8F%E5%8F%8C%E5%87%BB%E8%BF%90%E8%A1%8CFlutter%E9%A1%B9%E7%9B%AE%EF%BC%88iOS%20%E6%A8%A1%E6%8B%9F%E5%99%A8%EF%BC%89.command)

> **目的：** 启动 iOS 模拟器并运行 Flutter 工程。

- 定位工程、入口及 SDK，拉取项目依赖。
- 检查模拟器后台，选择或创建目标设备并启动。
- 执行 flutter run，并按脚本规则建立桌面快捷入口。


### [【MacOS】🎈双击真机运行项目.command](./%E8%BF%90%E8%A1%8C/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%8F%8C%E5%87%BB%E7%9C%9F%E6%9C%BA%E8%BF%90%E8%A1%8C%E9%A1%B9%E7%9B%AE.command/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%8F%8C%E5%87%BB%E7%9C%9F%E6%9C%BA%E8%BF%90%E8%A1%8C%E9%A1%B9%E7%9B%AE.command)

> **目的：** 在选定真实设备上运行 Flutter 工程。

- 定位项目与 Dart 入口，识别全局或 FVM SDK。
- 读取可用真机并选择目标设备。
- 执行 flutter run，保留运行日志供交互调试。


### [【MacOS】📱双击初始化iOS模拟器.command](./%E8%BF%90%E8%A1%8C/%E3%80%90MacOS%E3%80%91%F0%9F%93%B1%E5%8F%8C%E5%87%BB%E5%88%9D%E5%A7%8B%E5%8C%96iOS%E6%A8%A1%E6%8B%9F%E5%99%A8.command/%E3%80%90MacOS%E3%80%91%F0%9F%93%B1%E5%8F%8C%E5%87%BB%E5%88%9D%E5%A7%8B%E5%8C%96iOS%E6%A8%A1%E6%8B%9F%E5%99%A8.command)

> **目的：** 选择系统运行时并创建可用的 iOS 模拟器。

- 检查模拟器后台状态和菜单工具。
- 选择可用运行时、设备类型与设备名称。
- 创建并启动模拟器，等待就绪后按提示继续创建或退出。


### [【MacOS】📱双击打开已实例化的iOS模拟器.command](./%E8%BF%90%E8%A1%8C/%E3%80%90MacOS%E3%80%91%F0%9F%93%B1%E5%8F%8C%E5%87%BB%E6%89%93%E5%BC%80%E5%B7%B2%E5%AE%9E%E4%BE%8B%E5%8C%96%E7%9A%84iOS%E6%A8%A1%E6%8B%9F%E5%99%A8.command/%E3%80%90MacOS%E3%80%91%F0%9F%93%B1%E5%8F%8C%E5%87%BB%E6%89%93%E5%BC%80%E5%B7%B2%E5%AE%9E%E4%BE%8B%E5%8C%96%E7%9A%84iOS%E6%A8%A1%E6%8B%9F%E5%99%A8.command)

> **目的：** 打开已有的 iOS 模拟器应用。

- 阅读入口自述并继续。
- 调用系统 Simulator 应用。
- 在模拟器中选择或使用已经存在的设备。


### [【MacOS】🚀双击启动Android模拟器.command](./%E8%BF%90%E8%A1%8C/%E3%80%90MacOS%E3%80%91%F0%9F%9A%80%E5%8F%8C%E5%87%BB%E5%90%AF%E5%8A%A8Android%E6%A8%A1%E6%8B%9F%E5%99%A8.command/%E3%80%90MacOS%E3%80%91%F0%9F%9A%80%E5%8F%8C%E5%87%BB%E5%90%AF%E5%8A%A8Android%E6%A8%A1%E6%8B%9F%E5%99%A8.command)

> **目的：** 选择或创建 Android AVD 并启动。

- 检查 emulator、sdkmanager、avdmanager 和菜单工具。
- 选择既有 AVD；缺失时按提示创建。
- 启动模拟器并等待设备可用。


### [【MacOS】⏬双击配置VSCode.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91VSCode.command/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E5%8F%8C%E5%87%BB%E9%85%8D%E7%BD%AEVSCode.command/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E5%8F%8C%E5%87%BB%E9%85%8D%E7%BD%AEVSCode.command)

> **目的：** 下载并配置 [**VS Code**](https://code.visualstudio.com/) 设置与扩展。

- 选择目标配置范围并核对现有配置。
- 按提示备份或处理旧目录，再下载配置仓库。
- 复制配置与处理扩展，打开结果或 VS Code。


### [【MacOS】💉VSCode配置注入@全局.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91VSCode.command/%E3%80%90MacOS%E3%80%91%F0%9F%92%89VSCode%E9%85%8D%E7%BD%AE%E6%B3%A8%E5%85%A5@%E5%85%A8%E5%B1%80.command/%E3%80%90MacOS%E3%80%91%F0%9F%92%89VSCode%E9%85%8D%E7%BD%AE%E6%B3%A8%E5%85%A5@%E5%85%A8%E5%B1%80.command)

> **目的：** 将仓库配置写入 VS Code 的用户设置目录。

- 确认全局配置目录及覆盖影响。
- 下载配置仓库并替换目标设置内容，清除不需要的仓库文件。
- 打开配置位置并重启 VS Code；原用户设置会受替换影响。


### [【MacOS】💉VSCode配置注入@当前Flutter项目.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91VSCode.command/%E3%80%90MacOS%E3%80%91%F0%9F%92%89VSCode%E9%85%8D%E7%BD%AE%E6%B3%A8%E5%85%A5@%E5%BD%93%E5%89%8DFlutter%E9%A1%B9%E7%9B%AE.command/%E3%80%90MacOS%E3%80%91%F0%9F%92%89VSCode%E9%85%8D%E7%BD%AE%E6%B3%A8%E5%85%A5@%E5%BD%93%E5%89%8DFlutter%E9%A1%B9%E7%9B%AE.command)

> **目的：** 将仓库配置写入当前 Flutter 项目的 .vscode。

- 确认项目根目录与目标 .vscode。
- 下载配置到临时目录，再替换项目设置内容。
- 清理临时内容并报告结果；运行前保留已有自定义设置。


### [【MacOS】⏬下载配置系统环境变量.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E4%B8%8B%E8%BD%BD%E9%85%8D%E7%BD%AE%E7%B3%BB%E7%BB%9F%E7%8E%AF%E5%A2%83%E5%8F%98%E9%87%8F.command/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E4%B8%8B%E8%BD%BD%E9%85%8D%E7%BD%AE%E7%B3%BB%E7%BB%9F%E7%8E%AF%E5%A2%83%E5%8F%98%E9%87%8F.command)

> **目的：** 下载脚本指定的系统环境配置仓库。

- 读取源码中的仓库地址和目标目录。
- 检查已有目标并按提示决定是否继续。
  - 如果确认替换，会删除该目标旧目录；先保留自有内容。
- 克隆配置仓库并输出后续配置位置。


### [【MacOS】⏬双击下载SourceTree效率脚本.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E5%8F%8C%E5%87%BB%E4%B8%8B%E8%BD%BDSourceTree%E6%95%88%E7%8E%87%E8%84%9A%E6%9C%AC.command/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E5%8F%8C%E5%87%BB%E4%B8%8B%E8%BD%BDSourceTree%E6%95%88%E7%8E%87%E8%84%9A%E6%9C%AC.command)

> **目的：** 取得可本地运行的 [**Sourcetree**](https://www.sourcetreeapp.com/) 脚本库。

- 检查 Git 和脚本声明的下载位置。
- 按提示处理已有目标，再从配置的远端克隆脚本库。
- 给下载入口补执行权限并打开输出目录。


### [【MacOS】⏬双击配置VSCode.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E5%8F%8C%E5%87%BB%E9%85%8D%E7%BD%AEVSCode.command/%E3%80%90MacOS%E3%80%91%E2%8F%AC%E5%8F%8C%E5%87%BB%E9%85%8D%E7%BD%AEVSCode.command)

> **目的：** 下载并配置 VS Code 设置与扩展。

- 选择目标配置范围并核对现有配置。
- 按提示备份或处理旧目录，再下载配置仓库。
- 复制配置与处理扩展，打开结果或 VS Code。


### [【MacOS】⚙️Flutter 项目组件预下载.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8FFlutter%20%E9%A1%B9%E7%9B%AE%E7%BB%84%E4%BB%B6%E9%A2%84%E4%B8%8B%E8%BD%BD.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8FFlutter%20%E9%A1%B9%E7%9B%AE%E7%BB%84%E4%BB%B6%E9%A2%84%E4%B8%8B%E8%BD%BD.command)

> **目的：** 预先下载工程需要的 Flutter 平台构建组件。

- 验证工程并识别 FVM / 全局 SDK 的缓存目录。
- 备份现有缓存，选择全部或指定平台。
- 执行 precache，显示并可打开缓存目录。


### [【MacOS】⚙️一键配置Flutter项目至运行.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E4%B8%80%E9%94%AE%E9%85%8D%E7%BD%AEFlutter%E9%A1%B9%E7%9B%AE%E8%87%B3%E8%BF%90%E8%A1%8C.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E4%B8%80%E9%94%AE%E9%85%8D%E7%BD%AEFlutter%E9%A1%B9%E7%9B%AE%E8%87%B3%E8%BF%90%E8%A1%8C.command)

> **目的：** 为 Apple Silicon 工程准备 FVM 与 VS Code 的直接运行配置。

- 校验原生 ARM64 环境，定位含 pubspec.yaml 和 lib 的工程。
- 准备 FVM、选定 Flutter 版本与 iOS 缓存。
- 备份并写入 VS Code settings / launch 配置，提示重载编辑器后按 F5；脚本本身不启动 App。


### [【MacOS】⚙️下载配置系统环境变量.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E4%B8%8B%E8%BD%BD%E9%85%8D%E7%BD%AE%E7%B3%BB%E7%BB%9F%E7%8E%AF%E5%A2%83%E5%8F%98%E9%87%8F.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E4%B8%8B%E8%BD%BD%E9%85%8D%E7%BD%AE%E7%B3%BB%E7%BB%9F%E7%8E%AF%E5%A2%83%E5%8F%98%E9%87%8F.command)

> **目的：** 下载脚本指定的系统环境配置仓库。

- 读取源码中的仓库地址和目标目录。
- 检查已有目标并按提示决定是否继续。
  - 如果确认替换，会删除该目标旧目录；先保留自有内容。
- 克隆配置仓库并输出后续配置位置。


### [【MacOS】⚙️双击安装Cocoapods.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85Cocoapods.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85Cocoapods.command)

> **目的：** 准备 Ruby 环境并安装 CocoaPods。

- 备份相关 Shell 配置，检查 Homebrew、Ruby 与交互工具。
- 选择 Ruby / CocoaPods 安装方式并处理 gem 源。
- 安装并校验 pod 命令，按提示决定是否初始化本地 Specs 仓库。


### [【MacOS】⚙️双击安装FVM.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85FVM.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85FVM.command)

> **目的：** 安装 FVM 并为工程选择 Flutter 版本。

- 检查 Homebrew、Dart 和版本选择工具。
- 查询并选择版本，写入 .fvmrc 等工程配置并安装选定 SDK。
- 检查工程状态与重复依赖，按选择执行 clean、get、doctor 或 analyze。


### [【MacOS】⚙️双击安装Flutter.SDK.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85Flutter.SDK.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85Flutter.SDK.command)

> **目的：** 选择官方包、Homebrew 或 FVM 安装 Flutter SDK。

- 检查基础工具和安装菜单。
- 选择安装方式、版本与路径，下载并安装 SDK。
- 补充必要环境配置，运行 doctor 并展示安装目录。


### [【MacOS】⚙️双击安装（升级）Homebrew.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85%EF%BC%88%E5%8D%87%E7%BA%A7%EF%BC%89Homebrew.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E5%8F%8C%E5%87%BB%E5%AE%89%E8%A3%85%EF%BC%88%E5%8D%87%E7%BA%A7%EF%BC%89Homebrew.command)

> **目的：** 准备 Homebrew 并按选择安装开发工具。

- 检查已有 Homebrew；缺失时按提示选择安装位置。
- 配置当前 Shell 的 Homebrew 环境，已有安装按提示选择是否升级。
- 依次处理源码列出的工具安装项并输出结果。


### [【MacOS】⚙️收集当前Flutter工程的依赖.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E6%94%B6%E9%9B%86%E5%BD%93%E5%89%8DFlutter%E5%B7%A5%E7%A8%8B%E7%9A%84%E4%BE%9D%E8%B5%96.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E6%94%B6%E9%9B%86%E5%BD%93%E5%89%8DFlutter%E5%B7%A5%E7%A8%8B%E7%9A%84%E4%BE%9D%E8%B5%96.command)

> **目的：** 将工程实际解析的 Flutter 和原生依赖整理为可追溯压缩包。

- 定位 Flutter 工程，检查 SDK 和已有 package_config.json。
- 按所选范围读取实际包路径，复制依赖源码及关键工程清单。
- 写入收集说明并生成桌面 Zip，显示输出位置。


### [【MacOS】⚙️配置Android Studio.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E9%85%8D%E7%BD%AEAndroid%20Studio.command/%E3%80%90MacOS%E3%80%91%E2%9A%99%EF%B8%8F%E9%85%8D%E7%BD%AEAndroid%20Studio.command)

> **目的：** 安装 Android 命令行组件并创建可启动的 AVD。

- 检查基础工具并准备 SDK 路径。
- 安装 cmdline-tools、SDK 组件并设置当前进程环境。
- 创建并启动 AVD，显示需要持久化的环境配置。


### [【MacOS】🎈双击打开系统配置文件.command](./%E9%85%8D%E7%BD%AE%E7%9B%B8%E5%85%B3/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%8F%8C%E5%87%BB%E6%89%93%E5%BC%80%E7%B3%BB%E7%BB%9F%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6.command/%E3%80%90MacOS%E3%80%91%F0%9F%8E%88%E5%8F%8C%E5%87%BB%E6%89%93%E5%BC%80%E7%B3%BB%E7%BB%9F%E9%85%8D%E7%BD%AE%E6%96%87%E4%BB%B6.command)

> **目的：** 选择并打开用户环境配置文件。

- 检查菜单工具，列出支持的配置文件。
- 选择要查看的文件并调用默认编辑器打开。
- 按脚本逻辑 source 所选配置，让其中命令在当前进程执行。


<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
