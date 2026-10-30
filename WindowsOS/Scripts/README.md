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
