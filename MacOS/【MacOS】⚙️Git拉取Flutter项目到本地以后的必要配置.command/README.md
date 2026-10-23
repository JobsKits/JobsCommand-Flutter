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

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
