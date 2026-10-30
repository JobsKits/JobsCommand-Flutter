# `【WindowsOS】📱双击打开已实例化的鸿蒙模拟器.ps1`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、使用与支持范围](#jobs-toc-heading-2)
- [二、确认、副作用与日志](#jobs-toc-heading-3)
- [三、交付与验证边界](#jobs-toc-heading-4)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

仅列出并启动已有鸿蒙实例，不下载工具或镜像、不创建设备。空列表明确提示先初始化，取消不启动。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、使用与支持范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

双击同名 `.cmd`，或用 PowerShell 5.1+ 执行 `.ps1`；`Scripts/` 是完整本地运行快照，单独复制该功能目录时一并保留。

最低支持 Windows 10 64 位（x64），具体最低 build 未锁定；鸿蒙与 Android 模拟器不支持 Windows ARM / 32 位，x64 实机仍需单独验收。

`-Plan` 展示计划；`-Check` 只核对路径与随包模块，不调用 SDK。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、确认、副作用与日志 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

先展示固定自述，再回车确认；非空输入 / Ctrl+C / Esc 取消。列表优先使用 [**fzf**](https://formulae.brew.sh/formula/fzf) 上下选择与输入筛选。初始化流程可能下载数 GB 镜像、写入本用户工具缓存和新增实例；不会删除或覆盖现有设备，不改系统代理、全局 Flutter 或项目 FVM。

[**Android**](https://developer.android.com) 使用官方 SDK 仓库与 Adoptium JDK；[**HarmonyOS**](https://developer.huawei.com/consumer/cn/) 工具来源与许可在实际操作前展示。打开已有鸿蒙实例入口只查询与启动，工具缺失直接停止。运行 [**Flutter**](https://flutter.dev/) 可更新项目依赖和构建缓存，签名与插件兼容性沿用工程。日志精确位置由终端打印，macOS 位于系统临时目录，Windows 入口使用临时 Transcript，工具日志位于当前用户本地数据目录。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、交付与验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

完整功能目录可复制、改名后从其它工作目录执行；运行所需代码全部随包携带。静态语法和假工具回归不代表真实 SDK 下载、镜像创建、设备运行或 Windows 桌面已验收。

[返回运行目录](../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
