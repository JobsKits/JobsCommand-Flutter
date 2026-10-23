# `【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command`

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

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

准备 [**Android**](https://developer.android.com) 工具链、模拟器并运行 [**Flutter**](https://flutter.dev/) 项目。入口：[同名脚本](<./【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 检查 [**Homebrew**](https://brew.sh/)、jenv、JDK、[**Android**](https://developer.android.com) SDK 与 build-tools。
- 选择或创建 AVD 并等待启动。
- 识别 [**FVM**](https://fvm.app)。
- 处理依赖和 clean。
- 按 flavor、模式和 [**Dart**](https://dart.dev) 入口运行。
- 输出诊断。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | 拖入工程或 Dart 入口；通过菜单选择模拟器、构建模式和可选动作 |
| 输出与作用位置 | Android AVD、SDK 缓存、工程依赖/构建产物、桌面快捷入口 |
| 依赖 | [**Flutter**](https://flutter.dev/) 或 [**FVM**](https://fvm.app)、[**Android**](https://developer.android.com) SDK、adb、JDK、[**fzf**](https://formulae.brew.sh/formula/fzf)、[**Homebrew**](https://brew.sh/)、网络 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

会安装工具、配置 Java、清理和更新工程依赖；不是纯启动器。实际选中设备、命令及 Java 版本必须以终端回显核对。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：Android AVD、SDK 缓存、工程依赖/构建产物、桌面快捷入口。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
