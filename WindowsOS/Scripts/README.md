# WindowsOS Flutter 实现模块

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、职责](#jobs-toc-heading-1)
- [二、复用边界](#jobs-toc-heading-2)
- [三、验证](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、职责</span><!-- jobs-toc:heading-end -->

FlutterTools.psm1 编排入口自述、确认、路径验证、日志、精确备份和 Windows 功能。Features 下是由 Jobs 自维护 OS@Extension Windows 功能核心取得的本地副本，覆盖 Android、Flutter doctor、代码生成、打包与鸿蒙工具链；源码随本目录分发，不使用仓库外路径。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、复用边界</span><!-- jobs-toc:heading-end -->

Action.psm1 和辅助源码保留 Jobs 作者声明。Common.psm1 的日志根定位调整为当前用户本地应用数据 JobsCommandFlutter，避免依赖 Explorer 扩展安装元数据。入口只调用本工具需要的私有功能，不安装右键菜单、不生成扩展程序。Windows 主入口不暴露 iOS 功能。

`build-harmony` 由 `FlutterTools.psm1` 转交 Packager 的 `Invoke-JobsPackagerHarmonyBuild -Type all`，固定一次同时生成 HAP + APP，默认 release。SDK 显式参数优先，其次项目 FVM 与 PATH；缺失绑定停止。两类能力在 `pub get` 前核验，构建失败或任一非空产物缺失均停止，既有签名与全局 SDK 保持不变。

`SimulatorSessions.ps1` 提供独立鸿蒙初始化 / 已有实例打开 / Flutter 鸿蒙模拟器运行所需流程：创建回读、许可确认、后台启动、有界设备查询与仅模拟器筛选。四个新增运行包按真实依赖携带本地快照；Android 只带 Android 核心，鸿蒙只带 Harmony / Packager，不含无关 doctor 或代码生成业务。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、验证</span><!-- jobs-toc:heading-end -->

从 WindowsOS 目录执行 Tests/Portable.Tests.ps1；默认在临时夹具中验证文件行为并遍历所有入口 Plan / Check。真实业务仅在 Windows 允许执行。

`Tests/HarmonyBuild.Tests.ps1` 使用内存工具探测和本次临时工程模拟 HAP / APP 构建，核对顺序、失败短路和进程环境恢复，不执行真实工具链。

**Flutter SDK网络预检：** 下载／首次Dart自举／precache前，随包网络模块以真实小Range验证来源、TLS、字节和吞吐并择优；显式storage、Pub和代理（含空值）保留，AUTO仅核验官方／CFUG同对象及当前已配置代理，不猜端口、不改系统代理或Git。当前任务短期复用；真实获取失败会降权坏路线、轮换其它已验证候选并持续重试。FVM按实际api context来源处理，能力允许时Git与Dart制品分阶段；用户fork不改源。原生BITS按真实WinINET通道衡量，PAC未能有界解析时保留既有通道并明确未测速。详细边界见[随包选路模块](./SdkDownloadRoute.ps1/README.md)。


<!-- JOBS_TERMINAL_STYLE_V1:BEGIN -->

> Windows 终端配色保护：支持完整颜色查询的交互控制台会先保存当前会话默认前景、背景与16色色表，再临时使用黑底白字和统一强调色；正常结束、业务失败及可捕获中断后恢复。用户运行中自行改动的颜色保留并提示，不修改用户主题、共享 Profile、注册表或全局策略。快照不包含进入前任意叠加的临时文字样式。非控制台、重定向、`NO_COLOR`、Sourcetree 及无法可靠保存／恢复颜色的环境保持原状态或降级为纯文本。

> 强制结束进程或终端崩溃无法保证自动恢复。恢复失败时保留并提示本轮 `%TEMP%\JobsTerminalStyle-<PID>-*.ps1` 恢复脚本，需在原控制台核对后运行；不要通过重置用户配置恢复。`-ExecutionPolicy Bypass` 如被入口使用，仅作用于本次子进程，不持久修改策略。

> 验证范围：已完成 PowerShell 语法、参数／退出与隔离生命周期核验；Windows 原生控制台的显示、按键与 `Ctrl+C` 实机验证尚未完成。

<!-- JOBS_TERMINAL_STYLE_V1:END -->
