# `【MacOS】🧹Flutter清理维护工具.command`

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

用菜单清理全局或工程 [**Flutter**](https://flutter.dev/) 开发缓存。入口：[同名脚本](<./【MacOS】🧹Flutter清理维护工具.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 全局菜单打开/清理 Pub 缓存、清理 Gradle、repair 缓存。
- 载入工程后可 pub get、clean、major-versions 升级、清理 SDK 缓存及 iOS/DerivedData。
- 系统菜单与工程菜单可往返切换；工程菜单按 `←` 左方向键或选“返回上级菜单”回到系统菜单，保留仍有效的查询及菜单位置，返回本身不执行清理。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | fzf 选择动作；工程需 pubspec.yaml 与 lib/；部分删除提示直接回车执行 |
| 输出与作用位置 | 工程依赖/锁文件、Pub/Gradle/SDK 缓存及 Xcode DerivedData |
| 依赖 | [**Flutter**](https://flutter.dev/)/[**FVM**](https://fvm.app)、[**fzf**](https://formulae.brew.sh/formula/fzf)、[**Homebrew**](https://brew.sh/) |

系统菜单回车选择，`Esc` 取消整个流程；选择“加载 Flutter 项目”后拖入目录，直接回车返回系统菜单，输入结束取消流程。工程菜单 header 明示 `← 返回系统菜单`，`Esc` 取消；没有匹配项时按左键仍可返回。取消、空选和选择器失败都不会进入清理分支；切换工程后重新选择工程动作，路径输入保留文本输入方式。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】🧹Flutter清理维护工具.command'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

清理可能跨工程并触发后续大量下载；项目清理包含 major-versions 更新，iOS 清理包含锁文件。各分支并未统一精确 YES，先核对菜单具体范围。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：工程依赖/锁文件、Pub/Gradle/SDK 缓存及 Xcode DerivedData。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

菜单导航已做隔离验证及真实 fzf 按键验证；未实际执行清理、依赖升级或安装。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
