# `【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command`

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

选择已有鸿蒙实例；缺失时进入初始化，再等待 Flutter 发现受支持的鸿蒙模拟器，选择设备、执行 pub get 和 run。显式 SDK 优先，其次项目 FVM 与 PATH；缺失 FVM 绑定或没有 HAP 能力即停止，不自动换成普通 Flutter。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、使用与支持范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

同名 `.command` 为入口；相邻 `.zsh` 是随包后端，不要单独双击。

Android 支持 Apple Silicon / Intel macOS，按本机架构选择镜像；鸿蒙本地模拟器只支持 Apple Silicon 原生 macOS，不支持 Intel / Rosetta。

`--help` 查看参数；`--check` 只读查询。 指定工程与鸿蒙 SDK：`--project <根目录> --flutter-sdk <SDK根目录>`；`--check` 仅校验工程清单。 也可设置 `FLUTTER_OHOS_SDK`；`JOBS_HARMONY_DEVICE_TIMEOUT` 控制设备等待秒数（默认 180，范围 1～600）。只显示 `emulator=true` 的鸿蒙设备，空列表轮询至超时并保留已创建实例。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、确认、副作用与日志 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

先展示固定自述，再回车确认；非空输入 / Ctrl+C / Esc 取消。列表优先使用 [**fzf**](https://formulae.brew.sh/formula/fzf) 上下选择与输入筛选。初始化流程可能下载数 GB 镜像、写入本用户工具缓存和新增实例；不会删除或覆盖现有设备，不改系统代理、全局 Flutter 或项目 FVM。

[**Android**](https://developer.android.com) 使用官方 SDK 仓库与 Adoptium JDK；[**HarmonyOS**](https://developer.huawei.com/consumer/cn/) 工具来源与许可在实际操作前展示。打开已有鸿蒙实例入口只查询与启动，工具缺失直接停止。运行 [**Flutter**](https://flutter.dev/) 可更新项目依赖和构建缓存，签名与插件兼容性沿用工程。日志精确位置由终端打印，macOS 位于系统临时目录，Windows 入口使用临时 Transcript，工具日志位于当前用户本地数据目录。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、交付与验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

完整功能目录可复制、改名后从其它工作目录执行；运行所需代码全部随包携带。静态语法和假工具回归不代表真实 SDK 下载、镜像创建、设备运行或 Windows 桌面已验收。

[返回运行目录](../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
