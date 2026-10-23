# WindowsOS Flutter 隔离验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行方式](#jobs-toc-heading-1)
- [二、范围](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、运行方式</span><!-- jobs-toc:heading-end -->

在此目录执行以下 PowerShell 命令：

    & ./Portable.Tests.ps1

使用 -SkipEntrypoints 只运行模块夹具；默认还启动独立 PowerShell 进程验证 41 个入口的 -Plan 和 -Check。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、范围</span><!-- jobs-toc:heading-end -->

只在本次唯一临时目录中创建工程和依赖夹具并清理。覆盖中文路径、Dart 引用、FVM 边界、Gradle namespace、配置保留、ZIP 与失败退出。不会调用真实 Flutter / Android、下载软件、安装工具、改系统配置或清理用户缓存。

macOS 可用 pwsh 运行该检查，但这不证明 Windows PowerShell 5.1、Windows cmd 双击、真实工具链或设备已验收。
