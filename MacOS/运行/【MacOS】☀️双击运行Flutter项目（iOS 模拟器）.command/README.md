# `【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、功能覆盖](#jobs-toc-heading-2)
- [二、输入、选项与产物](#jobs-toc-heading-3)
- [三、运行方式](#jobs-toc-heading-4)
- [四、风险与能力边界](#jobs-toc-heading-5)
- [五、日志与核对](#jobs-toc-heading-6)
  - [Flutter SDK获取前置](#jobs-toc-heading-7)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

选择 iOS 模拟器并运行 [**Flutter**](https://flutter.dev/) 入口。入口：[同名脚本](<./【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 识别工程或 [**Dart**](https://dart.dev) 入口。
- 输入可选 flavor。
- 通过 [**fzf**](https://formulae.brew.sh/formula/fzf) 选择 debug、release、profile。
- 可选 pub get。
- 选择或创建模拟器。
- 执行 run，失败时尝试 pod install。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | 拖入工程或 Dart 文件；pub get 提示回车执行、其它输入跳过；构建模式交互选择 |
| 输出与作用位置 | 模拟器应用、工程构建文件及桌面启动入口 |
| 依赖 | [**Flutter**](https://flutter.dev/) 或 [**FVM**](https://fvm.app)、[**Xcode**](https://developer.apple.com/xcode)、[**CocoaPods**](https://cocoapods.org/)、[**fzf**](https://formulae.brew.sh/formula/fzf) |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

设备处理可能关闭已有 Simulator；自动 Pod 处理会改 ios 依赖。iOS 模拟器通常不能运行 release，所选模式仍受 [**Flutter**](https://flutter.dev/) 和运行时限制。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：模拟器应用、工程构建文件及桌面启动入口。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

**终端配色保护：** 独立运行时，在支持完整保存与恢复配色的交互终端中临时使用黑底白字及统一强调色；正常结束、失败或可捕获中断后恢复进入前的配色，不修改终端全局偏好或 Shell 启动配置。不支持完整保护、无交互终端、`NO_COLOR`、既有纯文本模式和 Sourcetree 场景不切换配色，并沿用纯文本输出约定。强制终止（如 `kill -9`）无法由脚本自身保证恢复，请使用运行时显示的独立恢复入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>


### <span id="jobs-toc-heading-7" data-jobs-toc="v2">Flutter SDK获取前置</span><!-- jobs-toc:heading-end -->

所有实际Flutter调用通过随包SDK适配器：首次Dart/engine补齐先检测来源和网络，失败持续退避重试至成功或用户中断；首个FVM调用也先校验其已确认的外部Dart运行时。明确的平台在build/run前单独预缓存，真实设备平台来自设备JSON；不改全局源、代理、Shell或Git配置。SDK获取重试只作用于前置阶段；原工程业务参数、诊断与恢复流程保持原设计，不由选路额外重放。请随入口保留完整Scripts目录。

原有run失败后的CocoaPods恢复保留；SDK自举/平台预缓存失败或取消会在首次run前结束，不触发这段业务恢复。
