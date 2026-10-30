# <span id="前言">WindowsOS [**Flutter**](https://flutter.dev/) 隔离验证</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行方式](#run)
- [二、范围](#scope)
- [三、验证边界](#validation)

</details>
<!-- jobs-toc:end -->

---

## 一、<span id="run">运行方式</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在此目录使用 [**PowerShell**](https://learn.microsoft.com/powershell/) 执行：

```powershell
powershell.exe `
  -NoLogo `
  -NoProfile `
  -ExecutionPolicy Bypass `
  -File .\Portable.Tests.ps1
```

使用 `-SkipEntrypoints` 只运行模块夹具；默认还启动独立 PowerShell 进程验证功能映射清单中的 46 个入口各自的 `-Plan` 和 `-Check`。执行策略参数只作用于本次测试进程，不修改用户或机器策略。

鸿蒙双产物业务隔离验证：

```powershell
powershell.exe `
  -NoLogo `
  -NoProfile `
  -ExecutionPolicy Bypass `
  -File .\HarmonyBuild.Tests.ps1
```

覆盖 HAP + APP 的命令顺序、缺 APP 能力停止、依赖或任一构建失败短路、缺失 / 空产物、SDK 路径 / FVM 边界及环境恢复；所有工具均由夹具替代，不执行真实 Flutter 或 DevEco。

`SimulatorEntries.Tests.ps1` 使用内存替身验证鸿蒙模拟器筛选、空列表停止、唯一新实例、已有实例与取消路径；不会调用真实 Emulator。

`Bootstrap.Tests.ps1` 使用临时 SDK 与下载 / 解压替身验证安装目录返回值、首次初始化的进程 PATH、已有 Dart 复用和取消路径；不访问网络，也不安装真实 SDK。运行方式与上例一致，将文件名替换为 `Bootstrap.Tests.ps1`。

## 二、<span id="scope">范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

只在本次唯一临时目录中创建工程和依赖夹具并清理。覆盖中文路径、[**Dart**](https://dart.dev) 引用、[**FVM**](https://fvm.app) 边界、[**Gradle**](https://gradle.org) namespace、配置保留、ZIP 与失败退出；ZIP 检查要求条目统一使用正斜杠、中文嵌套文件内容完整并保留空目录。不会调用真实 Flutter / [**Android**](https://developer.android.com) 工具链、下载软件、安装工具、改系统配置或清理用户缓存。

## 三、<span id="validation">验证边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

2026-10-26 按默认模式运行 `Portable.Tests.ps1`，以其终端 `PASS` 结果统计有效断言：

| 验证环境 | 断言数 | 结果 |
| --- | --- | --- |
| [**Windows 11**](https://www.microsoft.com/windows) ARM64 虚拟机，系统 build `26300.0`、Windows PowerShell `5.1.26100.9711` | 189 | 通过模块夹具与全部入口 `-Plan` / `-Check` |
| [**macOS**](https://www.apple.com/macos/)，`pwsh 7.6.8` | 190 | 同上，并包含仅在非 Windows 执行的 `/bin/sh` 非零退出夹具 |

这些结果不代表 Windows 10 x64、旧版 Windows、CMD 图形双击、真实 Flutter / Android 构建或设备业务已经验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
