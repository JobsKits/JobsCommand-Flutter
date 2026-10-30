# `运行`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、功能入口](#jobs-toc-heading-2)
- [二、运行与作用范围](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录按当前能力划分入口。先从下面选择具体功能，再阅读相邻说明核对输入、默认选项、产物和风险。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 功能说明 | 当前覆盖 |
| --- | --- |
| [【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command](<./【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command/README.md>) | 准备 [**Android**](https://developer.android.com) 工具链、模拟器并运行 [**Flutter**](https://flutter.dev/) 项目 |
| [【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command](<./【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command/README.md>) | 选择 iOS 模拟器并运行 Flutter 入口 |
| [【MacOS】🎈双击真机运行项目.command](<./【MacOS】🎈双击真机运行项目.command/README.md>) | 以 release 模式把 Flutter 工程运行到连接设备 |
| [【MacOS】📱双击初始化iOS模拟器.command](<./【MacOS】📱双击初始化iOS模拟器.command/README.md>) | 这是一份双击脚本外部 README，面向运行前阅读；脚本运行后还会打印内置自述并等待确认，README 不替代脚本自身的防误触提示 |
| [【MacOS】📱双击打开已实例化的iOS模拟器.command](<./【MacOS】📱双击打开已实例化的iOS模拟器.command/README.md>) | 打开系统 iOS Simulator 应用 |
| [【MacOS】🚀双击启动Android模拟器.command](<./【MacOS】🚀双击启动Android模拟器.command/README.md>) | 正常自检示例（路径和版本以本机为准）： |
| [【MacOS】📱双击初始化Android模拟器.command](<./【MacOS】📱双击初始化Android模拟器.command/README.md>) | 选择设备型号和本机架构匹配的系统映像，创建唯一 AVD 并启动。缺失 SDK / JDK / 命令行工具可按首屏授权补齐，SDK 许可由本人阅读确认；已有设备与健康组件保留。 |
| [【MacOS】📱双击初始化鸿蒙模拟器.command](<./【MacOS】📱双击初始化鸿蒙模拟器.command/README.md>) | 准备官方 DevEco Emulator 与 Release 系统镜像，选择镜像后创建唯一鸿蒙实例，校验名称、设备类型与版本，再启动。缺工具采用固定 SDL 镜像快照并校验摘要，系统镜像由官方工具下载；许可须本人阅读确认。 |
| [【MacOS】📱双击打开已实例化的鸿蒙模拟器.command](<./【MacOS】📱双击打开已实例化的鸿蒙模拟器.command/README.md>) | 仅列出并启动已有鸿蒙实例，不下载工具或镜像、不创建设备。空列表明确提示先初始化，取消不启动。 |
| [【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command](<./【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command/README.md>) | 选择已有鸿蒙实例；缺失时进入初始化，再等待 Flutter 发现受支持的鸿蒙模拟器，选择设备、执行 pub get 和 run。显式 SDK 优先，其次项目 FVM 与 PATH；缺失 FVM 绑定或没有 HAP 能力即停止，不自动换成普通 Flutter。 |

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、运行与作用范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在选中的脚本包目录双击入口，或按它自己的命令示例运行；不要一次执行本目录所有脚本。目录清单仅为导航，不会自动安装、修复、清理或发布。

分类链接按主实现确定日志、确认方式与产物。运行前核对真实目标，已有输出和工程改动按对应说明保护。

[返回仓库说明](./../../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
