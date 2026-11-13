# `【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command`

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

补齐 [**Android**](https://developer.android.com) SDK 并让 [**Flutter**](https://flutter.dev/) 使用该目录。入口：[同名脚本](<./【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 识别工程/[**FVM**](https://fvm.app)。
- 下载固定 Command-line Tools。
- 安装基础 SDK 组件。
- 配置 android-sdk。
- 运行 licenses 与 doctor。
- 可选 pub get。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | 拖入工程或 Dart 入口；SDK 固定在用户 Library/Android/sdk；pub get 回车执行 |
| 输出与作用位置 | Android SDK、本机 Flutter SDK 路径设置与工程依赖 |
| 依赖 | curl、unzip、JDK、[**Flutter**](https://flutter.dev/)/[**FVM**](https://fvm.app)、sdkmanager 与网络 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

会下载工具并改变 [**Flutter**](https://flutter.dev/) [**Android**](https://developer.android.com) SDK 设置；许可证需本人阅读接受。固定工具版本不保证覆盖所有当前项目的 API 需求。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：Android SDK、本机 Flutter SDK 路径设置与工程依赖。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

**终端配色保护：** 独立运行时，在支持完整保存与恢复配色的交互终端中临时使用黑底白字及统一强调色；正常结束、失败或可捕获中断后恢复进入前的配色，不修改终端全局偏好或 Shell 启动配置。不支持完整保护、无交互终端、`NO_COLOR`、既有纯文本模式和 Sourcetree 场景不切换配色，并沿用纯文本输出约定。强制终止（如 `kill -9`）无法由脚本自身保证恢复，请使用运行时显示的独立恢复入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>


### <span id="jobs-toc-heading-7" data-jobs-toc="v2">Flutter SDK获取前置</span><!-- jobs-toc:heading-end -->

所有实际Flutter调用通过随包SDK适配器：首次Dart/engine补齐先检测来源和网络，失败持续退避重试至成功或用户中断；首个FVM调用也先校验其已确认的外部Dart运行时。明确的平台在build/run前单独预缓存，真实设备平台来自设备JSON；不改全局源、代理、Shell或Git配置。SDK获取重试只作用于前置阶段；原工程业务参数、诊断与恢复流程保持原设计，不由选路额外重放。请随入口保留完整Scripts目录。
