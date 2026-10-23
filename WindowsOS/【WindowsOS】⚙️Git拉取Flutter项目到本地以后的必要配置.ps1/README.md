# `【WindowsOS】⚙️Git拉取Flutter项目到本地以后的必要配置.ps1`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、功能覆盖](#jobs-toc-heading-2)
- [二、选项与结果](#jobs-toc-heading-3)
- [三、运行方式](#jobs-toc-heading-4)
- [四、能力边界与恢复](#jobs-toc-heading-5)
- [五、结果核对](#jobs-toc-heading-6)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

为拉取后的 [**Flutter**](https://flutter.dev/) 工程准备 [**FVM**](https://fvm.app) 与编辑器 SDK 路径。入口：[PowerShell](<./【WindowsOS】⚙️Git拉取Flutter项目到本地以后的必要配置.ps1>)，随包核心：[FlutterTools.psm1](./../Scripts/FlutterTools.psm1)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 激活当前用户 FVM。
- 按版本安装并绑定工程。
- 执行 pub get。
- 合并 .vscode/settings.json 的 dart.flutterSdkPath。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、选项与结果 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 本功能输入 | -TargetPath 工程；-Version 可省略，先读取 .fvmrc，再询问版本 |
| 产物或影响 | 工程 .fvm/.fvmrc、.vscode/settings.json 与依赖锁文件 |
| 依赖 | [**Dart**](https://dart.dev)、FVM、Flutter、网络 |
| 只看计划 | -Plan：只输出动作 postclone 和目标，不运行 SDK |
| 入口检查 | -Check：只核对随包模块与可选目录，不联网、不启动 SDK，也不代表环境健康 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

使用 [**Windows**](https://www.microsoft.com/windows) [**PowerShell**](https://learn.microsoft.com/powershell/) 5.1 或更新版本。双击同名 `.cmd`，或在本目录运行：

```powershell
& './【WindowsOS】⚙️Git拉取Flutter项目到本地以后的必要配置.ps1' -TargetPath 'D:\Projects\Example' -Plan
```

删除 `-Plan` 才进入真实执行。主入口显示内置自述，回车继续，其它输入取消；具体写操作还有上文说明的确认。路径含空格或中文用引号。分发时保留整个 `WindowsOS/` 目录，不能只拷贝一个入口。`.cmd` 的执行策略参数仅作用于本次进程，不永久改变系统策略。

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、能力边界与恢复 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

不是 [**Git**](https://git-scm.com/) 拉取器，不创建工程；JSONC 无法安全解析时保留原文并停止，不能保证任意编辑器配置均能合并。

配置写入的相邻备份命名为 `.jobs-backup-时间戳-标识`；日志在系统临时目录，名称以 `JobsFlutter-postclone-` 开头。功能核心可能另有日志，以实际回显为准。函数返回非零状态或命令失败时停止；已有工程 FVM 声明但缺少对应 SDK 时停止，不悄悄切换全局版本。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、结果核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

完成后检查：工程 .fvm/.fvmrc、.vscode/settings.json 与依赖锁文件。结合当前功能的范围核对实际目标、命令输出与退出码；失败时保留备份和日志，检查停止阶段后再重试。`-Plan` / `-Check` 通过不代表真实工具链、设备或构建通过。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
