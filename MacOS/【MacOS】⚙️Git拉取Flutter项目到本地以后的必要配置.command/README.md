# `【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command`

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
  - [SDK网络与获取](#jobs-toc-heading-7)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

为拉取后的 [**Flutter**](https://flutter.dev/) 工程绑定项目级 [**FVM**](https://fvm.app)，并设置编辑器 SDK 路径。入口：[同名脚本](<./【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 从传入路径、当前目录、脚本目录向上寻找 pubspec.yaml 与 lib/。
- 检查 [**Homebrew**](https://brew.sh/)，缺 [**FVM**](https://fvm.app) 时安装。
- 执行 fvm install 与 fvm use。
- 合并 .vscode/settings.json 的 dart.flutterSdkPath。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | .command 的位置参数可传工程或文件路径；未传则自动探测。绑定通道默认 stable |
| 输出与作用位置 | 工程 .fvm 配置和 .vscode/settings.json；已有 settings.json 留时间戳备份 |
| 依赖 | [**Git**](https://git-scm.com/)、[**Homebrew**](https://brew.sh/)、[**FVM**](https://fvm.app)、[**Python**](https://www.python.org)；需要下载 SDK 的网络 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command'
```

传入项目路径示例（先把示例路径替换为真实工程）：

```shell
zsh './【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command' './ExampleProject'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

会改变该工程 SDK 绑定；不创建 [**Flutter**](https://flutter.dev/) 工程，也不负责设备启动或构建。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：工程 .fvm 配置和 .vscode/settings.json；已有 settings.json 留时间戳备份。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

**终端配色保护：** 独立运行时，在支持完整保存与恢复配色的交互终端中临时使用黑底白字及统一强调色；正常结束、失败或可捕获中断后恢复进入前的配色，不修改终端全局偏好或 Shell 启动配置。不支持完整保护、无交互终端、`NO_COLOR`、既有纯文本模式和 Sourcetree 场景不切换配色，并沿用纯文本输出约定。强制终止（如 `kill -9`）无法由脚本自身保证恢复，请使用运行时显示的独立恢复入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

### <span id="jobs-toc-heading-7" data-jobs-toc="v2">SDK网络与获取</span><!-- jobs-toc:heading-end -->

SDK获取前按实际目标/供应商进行网络检测，SDK失败持续重试，Ctrl+C/终止信号取消；FVM保留原仓库并分离Git与SDK自举，官方归档按真实版本/架构校验SHA256，Brew保留原始下载URL和摘要。SDK环境先准备，构建与run只执行一次，失败保留原码。模块仅修改当前任务子进程环境；移动此包需保留完整Scripts目录。
