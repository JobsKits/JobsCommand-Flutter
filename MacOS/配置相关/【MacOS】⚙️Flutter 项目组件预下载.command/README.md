# `【MacOS】⚙️Flutter 项目组件预下载.command`

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
  - [Flutter SDK网络获取](#jobs-toc-heading-7)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

备份 [**Flutter**](https://flutter.dev/) 引擎缓存并按平台预下载组件。入口：[同名脚本](<./【MacOS】⚙️Flutter 项目组件预下载.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 定位 [**Flutter**](https://flutter.dev/) 工程。
- 识别 [**FVM**](https://fvm.app) 或全局 SDK 的 bin/cache。
- 以 rsync 备份缓存。
- 通过 [**fzf**](https://formulae.brew.sh/formula/fzf) 多选平台执行 precache。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | 拖入项目目录；平台通过多选菜单决定 |
| 输出与作用位置 | SDK bin/cache 与当前用户 .flutter_cache_backups 中按工程命名的备份 |
| 依赖 | [**Flutter**](https://flutter.dev/) 或 [**FVM**](https://fvm.app)、[**fzf**](https://formulae.brew.sh/formula/fzf)、coreutils、rsync、[**Homebrew**](https://brew.sh/) 与网络 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】⚙️Flutter 项目组件预下载.command'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

预下载可能占用大量磁盘；rsync --delete 会同步覆盖同名工程的备份目录，不能当无限历史版本。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：SDK bin/cache 与当前用户 .flutter_cache_backups 中按工程命名的备份。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

**终端配色保护：** 独立运行时，在支持完整保存与恢复配色的交互终端中临时使用黑底白字及统一强调色；正常结束、失败或可捕获中断后恢复进入前的配色，不修改终端全局偏好或 Shell 启动配置。不支持完整保护、无交互终端、`NO_COLOR`、既有纯文本模式和 Sourcetree 场景不切换配色，并沿用纯文本输出约定。强制终止（如 `kill -9`）无法由脚本自身保证恢复，请使用运行时显示的独立恢复入口。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

### <span id="jobs-toc-heading-7" data-jobs-toc="v2">Flutter SDK网络获取</span><!-- jobs-toc:heading-end -->

SDK首次自举和预缓存使用随包Scripts检测实际来源与连接路线，获取失败自动重测重试，Ctrl+C/终止信号取消；已有健康SDK复用。原工程pub/run/analyze等业务仅执行一次，失败不会换全局SDK再执行第二次。源与代理只作用于当前任务子进程，显式设置含空值保持；移动此包时保留完整Scripts目录。
