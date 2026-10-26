# `【MacOS】⚙️双击安装Flutter.SDK.command`

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

选择官方包、[**Homebrew**](https://brew.sh/) 或 [**FVM**](https://fvm.app) 安装 [**Flutter**](https://flutter.dev/) SDK。入口：[同名脚本](<./【MacOS】⚙️双击安装Flutter.SDK.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 准备 [**Homebrew**](https://brew.sh/) 与 [**fzf**](https://formulae.brew.sh/formula/fzf)。
- 通过菜单选择官方 SDK 压缩包下载、[**Homebrew**](https://brew.sh/) 安装/升级、[**FVM**](https://fvm.app) 安装/绑定。
- 处理对应环境配置并查看版本。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | 官方包分支输入目录；FVM 分支选择版本；具体流程由安装方式决定 |
| 输出与作用位置 | SDK 安装目录、Shell 环境或工程 FVM 配置 |
| 依赖 | [**Git**](https://git-scm.com/)、curl、unzip、[**Homebrew**](https://brew.sh/)、[**fzf**](https://formulae.brew.sh/formula/fzf)、[**FVM**](https://fvm.app)（选择时）、网络 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

安装方式使用 `fzf` 单选；FVM 的版本面板按 `←` 返回安装方式，`Enter` 确认版本，`Esc` / `Ctrl+C` 或空选取消整个安装流程。`stable` 是版本列表首项，只有确认选中才采用；取消不会自动安装 `stable` 或继续写入 Shell 环境。FVM 分支输入工程路径时，直接回车也返回安装方式。

列举 FVM 版本前可能需要先安装 FVM 命令；返回保留已完成的依赖准备，尚未执行 Flutter 版本安装 / 工程绑定。缺少 `fzf` 时尚不能使用它选择自身安装来源，因此依赖引导明确提供文本选项：`1` 使用 Homebrew，`2` 使用 Git，其它输入取消；安装后复检成功才进入业务菜单。

```shell
zsh './【MacOS】⚙️双击安装Flutter.SDK.command'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

官方压缩包地址和架构选择按源码固定规则，不能保证适用于所有芯片；会改工具环境或工程绑定，先核对目标。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：SDK 安装目录、Shell 环境或工程 FVM 配置。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
