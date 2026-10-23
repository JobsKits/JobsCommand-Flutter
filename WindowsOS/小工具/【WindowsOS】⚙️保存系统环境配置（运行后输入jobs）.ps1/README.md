# `【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1`

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

向 [**PowerShell**](https://learn.microsoft.com/powershell/) profile 添加 jobs 环境摘要函数。入口：[PowerShell](<./【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1>)，随包核心：[FlutterTools.psm1](./../../Scripts/FlutterTools.psm1)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 读取当前用户 AllHosts profile。
- 检查已有 jobs 函数以避免覆盖。
- 追加显示 profile 与 flutter/dart/git/java/adb 路径的函数。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、选项与结果 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 本功能输入 | 无需 -TargetPath；精确 YES 后写入 |
| 产物或影响 | 当前用户 PowerShell profile 与备份 |
| 依赖 | PowerShell 用户 profile |
| 只看计划 | -Plan：只输出动作 jobsfunction 和目标，不运行 SDK |
| 入口检查 | -Check：只核对随包模块与可选目录，不联网、不启动 SDK，也不代表环境健康 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

使用 [**Windows**](https://www.microsoft.com/windows) PowerShell 5.1 或更新版本。双击同名 `.cmd`，或在本目录运行：

```powershell
& './【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1'  -Plan
```

删除 `-Plan` 才进入真实执行。主入口显示内置自述，回车继续，其它输入取消；具体写操作还有上文说明的确认。路径含空格或中文用引号。分发时保留整个 `WindowsOS/` 目录，不能只拷贝一个入口。`.cmd` 的执行策略参数仅作用于本次进程，不永久改变系统策略。

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、能力边界与恢复 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

不会自动 source 未知 profile；新终端加载配置后才得到函数。与 [**macOS**](https://www.apple.com/macos/) jobs 函数的加载多份配置行为不同。

配置写入的相邻备份命名为 `.jobs-backup-时间戳-标识`；日志在系统临时目录，名称以 `JobsFlutter-jobsfunction-` 开头。功能核心可能另有日志，以实际回显为准。函数返回非零状态或命令失败时停止；已有工程 [**FVM**](https://fvm.app) 声明但缺少对应 SDK 时停止，不悄悄切换全局版本。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、结果核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

完成后检查：当前用户 PowerShell profile 与备份。结合当前功能的范围核对实际目标、命令输出与退出码；失败时保留备份和日志，检查停止阶段后再重试。`-Plan` / `-Check` 通过不代表真实工具链、设备或构建通过。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
