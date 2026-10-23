# `【WindowsOS】⚙️配置Android Studio.ps1`

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

准备 JDK 与 [**Android**](https://developer.android.com) SDK 必需组件。入口：[PowerShell](<./【WindowsOS】⚙️配置Android Studio.ps1>)，随包核心：[FlutterTools.psm1](./../../Scripts/FlutterTools.psm1)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 发现或准备 Java 和 Command-line Tools。
- 校验归档与组件健康。
- 从官方清单选择稳定 Platform 和 Build Tools。
- 交互显示许可并安装所选组件。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、选项与结果 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 本功能输入 | 无需 [**Flutter**](https://flutter.dev/) 工程；SDK 优先 ANDROID_HOME、ANDROID_SDK_ROOT，否则使用当前用户本地应用数据 Android/Sdk |
| 产物或影响 | JDK、Android SDK、platform-tools、emulator 与选中的编译平台/构建工具 |
| 依赖 | 网络、Google Android 官方仓库、[**Adoptium**](https://adoptium.net/) Temurin 来源 |
| 只看计划 | -Plan：只输出动作 androidprepare 和目标，不运行 SDK |
| 入口检查 | -Check：只核对随包模块与可选目录，不联网、不启动 SDK，也不代表环境健康 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

使用 [**Windows**](https://www.microsoft.com/windows) [**PowerShell**](https://learn.microsoft.com/powershell/) 5.1 或更新版本。双击同名 `.cmd`，或在本目录运行：

```powershell
& './【WindowsOS】⚙️配置Android Studio.ps1'  -Plan
```

删除 `-Plan` 才进入真实执行。主入口显示内置自述，回车继续，其它输入取消；具体写操作还有上文说明的确认。路径含空格或中文用引号。分发时保留整个 `WindowsOS/` 目录，不能只拷贝一个入口。`.cmd` 的执行策略参数仅作用于本次进程，不永久改变系统策略。

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、能力边界与恢复 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

此入口不安装 Android Studio GUI；SDK 许可本人阅读接受，宿主模拟器限官方支持的 x64 Windows，缺虚拟化时不会静默修改系统。

配置写入的相邻备份命名为 `.jobs-backup-时间戳-标识`；日志在系统临时目录，名称以 `JobsFlutter-androidprepare-` 开头。功能核心可能另有日志，以实际回显为准。函数返回非零状态或命令失败时停止；已有工程 [**FVM**](https://fvm.app) 声明但缺少对应 SDK 时停止，不悄悄切换全局版本。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、结果核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

完成后检查：JDK、Android SDK、platform-tools、emulator 与选中的编译平台/构建工具。结合当前功能的范围核对实际目标、命令输出与退出码；失败时保留备份和日志，检查停止阶段后再重试。`-Plan` / `-Check` 通过不代表真实工具链、设备或构建通过。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
