# `小工具`

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
| [【WindowsOS】♻️修复Flutter项目中文路径.ps1](<./【WindowsOS】♻️修复Flutter项目中文路径.ps1/README.md>) | 将本项目 lib 内 import/export/part URI 的中文片段进行百分号转义 |
| [【WindowsOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.ps1](<./【WindowsOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.ps1/README.md>) | 按 [**Windows**](https://www.microsoft.com/windows) 安装位置准备 JDK、[**Android**](https://developer.android.com) SDK 和 emulator 组件 |
| [【WindowsOS】♻️当前脚本所在目录的快捷方式放到桌面.ps1](<./【WindowsOS】♻️当前脚本所在目录的快捷方式放到桌面.ps1/README.md>) | 为指定目录创建桌面 .lnk 快捷方式 |
| [【WindowsOS】⚙️import =＞package💣.ps1](<./【WindowsOS】⚙️import %3D＞package💣.ps1/README.md>) | 将 lib 内相对 [**Dart**](https://dart.dev) 引用转换为本项目 package URI |
| [【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1](<./【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1/README.md>) | 在当前用户 [**PowerShell**](https://learn.microsoft.com/powershell/) profile 中增加 jobs 环境摘要函数 |
| [【WindowsOS】⚙️双击显示隐藏文件.ps1](<./【WindowsOS】⚙️双击显示隐藏文件.ps1/README.md>) | 切换资源管理器普通隐藏文件显示 |
| [【WindowsOS】⚙️自动化替换Flutter图片资源.ps1](<./【WindowsOS】⚙️自动化替换Flutter图片资源.ps1/README.md>) | 备份并复制本地 assets，按项目声明运行图标与启动图生成器 |
| [【WindowsOS】⚙️运行授权.ps1](<./【WindowsOS】⚙️运行授权.ps1/README.md>) | 只解除单个普通文件的下载区域标记，不执行该文件 |
| [【WindowsOS】🌞颜色格式的转换.ps1](<./【WindowsOS】🌞颜色格式的转换.ps1/README.md>) | 转换十六进制颜色为 ARGB、CSS rgba 和 [**Flutter**](https://flutter.dev/) Color |
| [【WindowsOS】🎈切换Shell.ps1](<./【WindowsOS】🎈切换Shell.ps1/README.md>) | 选择并打开当前会话的 Windows Shell |
| [【WindowsOS】🎈双击打开当前路径终端.ps1](<./【WindowsOS】🎈双击打开当前路径终端.ps1/README.md>) | 在指定目录打开 Windows PowerShell |
| [【WindowsOS】🏥双击自检Flutter.ps1](<./【WindowsOS】🏥双击自检Flutter.ps1/README.md>) | 使用项目同源 Flutter SDK 运行版本与 doctor 诊断 |
| [【WindowsOS】🐦Flutter自动化生产代码.ps1](<./【WindowsOS】🐦Flutter自动化生产代码.ps1/README.md>) | 按项目依赖和配置运行可用生成器，冲突删除另行确认 |
| [【WindowsOS】🔍查询Flutter依赖版本.ps1](<./【WindowsOS】🔍查询Flutter依赖版本.ps1/README.md>) | 查询当前项目依赖的可用版本和约束 |
| [【WindowsOS】🛠️Android 模拟器一键检测与修复.ps1](<./【WindowsOS】🛠️Android 模拟器一键检测与修复.ps1/README.md>) | 诊断设备数据分区和安装位置，确认后恢复自动安装位置并重启 adb |
| [【WindowsOS】🛠️Flutter 插件 namespace 修复工具＂.ps1](<./【WindowsOS】🛠️Flutter 插件 namespace 修复工具＂.ps1/README.md>) | 只为本工程 Android app 补缺失 namespace，保留第三方缓存 |
| [【WindowsOS】🧪提取Flutter第三方依赖.ps1](<./【WindowsOS】🧪提取Flutter第三方依赖.ps1/README.md>) | 复用随包 Dart 核心提取已解析第三方 Pub 源码，排除 SDK、缓存与外部原生依赖 |
| [【WindowsOS】🧹Flutter清理维护工具.ps1](<./【WindowsOS】🧹Flutter清理维护工具.ps1/README.md>) | 确认 CLEAN 后执行本工程 flutter clean 与 pub get |

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、运行与作用范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在选中的脚本包目录双击入口，或按它自己的命令示例运行；不要一次执行本目录所有脚本。目录清单仅为导航，不会自动安装、修复、清理或发布。

分类链接按主实现确定日志、确认方式与产物。运行前核对真实目标，已有输出和工程改动按对应说明保护。

[返回仓库说明](./../../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
