# WindowsOS Flutter 脚本

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、运行与交付](#jobs-toc-heading-1)
- [二、参数与平台行为](#jobs-toc-heading-2)
- [三、逐功能映射](#jobs-toc-heading-3)
- [四、MacOS 专用排除项](#jobs-toc-heading-4)
- [五、确认、日志与恢复](#jobs-toc-heading-5)
- [六、验证与限制](#jobs-toc-heading-6)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、运行与交付</span><!-- jobs-toc:heading-end -->

此目录包含 46 个 Windows 原生 PowerShell 入口，每个配套同名 .cmd。双击 .cmd 后先读内置自述，回车继续，其它输入取消。使用 Windows PowerShell 5.1 或更新版本；.ps1 / .psm1 为 UTF-8 BOM，中文在 5.1 中可正确读取。.cmd 的 ExecutionPolicy Bypass 只作用于本次进程，不永久修改系统策略。

CMD 入口先关闭继承的延迟展开，保留路径和参数中的 `!`；企业组策略仍优先。

分发时保留完整 WindowsOS 目录，脚本按自身位置寻找 Scripts/FlutterTools.psm1，不依赖其它仓库或 OS@Extension 的运行文件。路径含空格、中文时用引号；批处理工具参数含 cmd 特殊字符时安全停止。失败返回非零退出码。

命令行提供 -Plan（仅展示功能）和 -Check（只核对入口资源与可选路径），均不调用 SDK、不联网、不安装、不清理。-Check 不表示 Android 工具链或真实设备已通过诊断。

新增运行入口见 [运行目录](./运行/README.md)：Android 初始化、鸿蒙初始化、已有鸿蒙实例打开、Flutter 鸿蒙模拟器运行。四个新包各携带本地 Scripts，可单独复制。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、参数与平台行为</span><!-- jobs-toc:heading-end -->

- -TargetPath：Flutter 工程根目录、安装父目录或所选目录；运行授权入口传单个普通文件。
- -SourcePath：资源源目录；环境变量入口传 JDK 根目录。
- -OutputPath：依赖收集为新 ZIP，录屏为新 GIF；第三方源码提取为已有输出父目录；-Version：项目 Flutter 版本。
- -Device：Android 设备序列号；模拟器启动入口传已有 AVD 名。Android 模拟器运行入口先启动所选 AVD，再选择 Flutter 设备。
- -Value：#RRGGBB / #AARRGGBB 或合法 namespace；-Seconds：1～180 秒录屏时长。
- 一键运行可用 -Mode Android / Web / Windows 选择目标；Web / Windows 不安装 Android 工具链，需已有浏览器或 Visual Studio 桌面组件。Android 启动可用 -Mode Create 新建 AVD。环境变量入口可用 -Mode Restore 核对后精确恢复用户变量。

Android 工具准备会使用 Google Android SDK 官方仓库与 Adoptium 官方 Temurin API，归档校验后补齐缺失组件，许可证交本人确认；选择工程 compileSdk 对应 Platform 与 Build Tools。已有 AVD、健康工具和镜像保留。Windows Android Emulator 功能限定官方支持的 x64 宿主。

Flutter SDK 安装读取官方 Windows 稳定发布清单、按 SHA-256 校验，拒绝覆盖已有 SDK。FVM 安装通过 pub.dev；绑定版本的 SDK 缺失时停止，避免悄悄换全局 Flutter。预下载只启用 Android / Web / Windows。Android 打包验证 APK / AAB 产物；真机运行只列 Android。

鸿蒙运行要求已有 ohos 平台、鸿蒙适配 Flutter SDK（可用 FLUTTER_OHOS_SDK）和 DevEco 工具链。它不自动下载鸿蒙 SDK 或接受签名许可；-Mode Create 可调用已存在 DevEco 与本地 Release 镜像创建鸿蒙模拟器，条款由本人确认。namespace 修复只修改所选工程 Android app 或本地 Flutter 插件的 Android Gradle，第三方 Pub 缓存不属于本入口的修改范围。清理入口只清所选工程；其它 SDK / Pub / Gradle 全局缓存不自动清除。

鸿蒙打包入口一次同时执行 HAP 与 APP 构建，默认 release，必须同时核验两种非空产物才完成；支持 `-HarmonyFlutterSdkPath`、`-Mode debug/profile`。`OHOS_BUILD_TARGET` 不改变双产物约定，签名沿用工程配置；未签名与缓存产物明确标记。工具环境仅作用于本进程及子进程，结束后恢复。详情见 [鸿蒙打包说明](<./打包相关/【WindowsOS】📦双击打包Flutter.Harmony.ps1/README.md>)。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、逐功能映射</span><!-- jobs-toc:heading-end -->

| MacOS 原入口 | WindowsOS 对应入口 | Windows 实现 |
| --- | --- | --- |
| [【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command](<../MacOS/【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command/【MacOS】⚙️Git拉取Flutter项目到本地以后的必要配置.command>) | [【WindowsOS】⚙️Git拉取Flutter项目到本地以后的必要配置.ps1](<./【WindowsOS】⚙️Git拉取Flutter项目到本地以后的必要配置.ps1/【WindowsOS】⚙️Git拉取Flutter项目到本地以后的必要配置.ps1>) | 恢复项目 FVM 版本、获取依赖并合并 VS Code SDK 路径 |
| [【MacOS】♻️修复Flutter项目中文路径.command](<../MacOS/小工具/【MacOS】♻️修复Flutter项目中文路径.command/【MacOS】♻️修复Flutter项目中文路径.command>) | [【WindowsOS】♻️修复Flutter项目中文路径.ps1](<./小工具/【WindowsOS】♻️修复Flutter项目中文路径.ps1/【WindowsOS】♻️修复Flutter项目中文路径.ps1>) | 将本项目 lib 内 import/export/part URI 的中文片段进行百分号转义 |
| [【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command](<../MacOS/小工具/【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command/【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command>) | [【WindowsOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.ps1](<./小工具/【WindowsOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.ps1/【WindowsOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.ps1>) | 按 Windows 安装位置准备 JDK、Android SDK 和 emulator 组件 |
| [【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command](<../MacOS/小工具/【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command/【MacOS】♻️当前脚本所在目录的快捷方式放到桌面.command>) | [【WindowsOS】♻️当前脚本所在目录的快捷方式放到桌面.ps1](<./小工具/【WindowsOS】♻️当前脚本所在目录的快捷方式放到桌面.ps1/【WindowsOS】♻️当前脚本所在目录的快捷方式放到桌面.ps1>) | 为指定目录创建桌面 .lnk 快捷方式 |
| [【MacOS】⚙️import =＞package💣.command](<../MacOS/小工具/【MacOS】⚙️import %3D＞package💣.command/【MacOS】⚙️import %3D＞package💣.command>) | [【WindowsOS】⚙️import =＞package💣.ps1](<./小工具/【WindowsOS】⚙️import %3D＞package💣.ps1/【WindowsOS】⚙️import %3D＞package💣.ps1>) | 将 lib 内相对 Dart 引用转换为本项目 package URI |
| [【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command](<../MacOS/小工具/【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command/【MacOS】⚙️保存系统环境配置（运行后输入jobs）.command>) | [【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1](<./小工具/【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1/【WindowsOS】⚙️保存系统环境配置（运行后输入jobs）.ps1>) | 在当前用户 PowerShell profile 中增加 jobs 环境摘要函数 |
| [【MacOS】⚙️双击显示隐藏文件.command](<../MacOS/小工具/【MacOS】⚙️双击显示隐藏文件.command/【MacOS】⚙️双击显示隐藏文件.command>) | [【WindowsOS】⚙️双击显示隐藏文件.ps1](<./小工具/【WindowsOS】⚙️双击显示隐藏文件.ps1/【WindowsOS】⚙️双击显示隐藏文件.ps1>) | 切换资源管理器普通隐藏文件显示 |
| [【MacOS】⚙️自动化替换Flutter图片资源.command](<../MacOS/小工具/【MacOS】⚙️自动化替换Flutter图片资源.command/【MacOS】⚙️自动化替换Flutter图片资源.command>) | [【WindowsOS】⚙️自动化替换Flutter图片资源.ps1](<./小工具/【WindowsOS】⚙️自动化替换Flutter图片资源.ps1/【WindowsOS】⚙️自动化替换Flutter图片资源.ps1>) | 备份并复制本地 assets，按项目声明运行图标与启动图生成器 |
| [【MacOS】⚙️运行授权.command](<../MacOS/小工具/【MacOS】⚙️运行授权.command/【MacOS】⚙️运行授权.command>) | [【WindowsOS】⚙️运行授权.ps1](<./小工具/【WindowsOS】⚙️运行授权.ps1/【WindowsOS】⚙️运行授权.ps1>) | 只解除单个普通文件的下载区域标记，不执行该文件 |
| [【MacOS】🌞颜色格式的转换.command](<../MacOS/小工具/【MacOS】🌞颜色格式的转换.command/【MacOS】🌞颜色格式的转换.command>) | [【WindowsOS】🌞颜色格式的转换.ps1](<./小工具/【WindowsOS】🌞颜色格式的转换.ps1/【WindowsOS】🌞颜色格式的转换.ps1>) | 转换十六进制颜色为 ARGB、CSS rgba 和 Flutter Color |
| [【MacOS】🎈切换Shell.command](<../MacOS/小工具/【MacOS】🎈切换Shell.command/【MacOS】🎈切换Shell.command>) | [【WindowsOS】🎈切换Shell.ps1](<./小工具/【WindowsOS】🎈切换Shell.ps1/【WindowsOS】🎈切换Shell.ps1>) | 选择并打开当前会话的 Windows Shell |
| [【MacOS】🎈双击打开当前路径终端.command](<../MacOS/小工具/【MacOS】🎈双击打开当前路径终端.command/【MacOS】🎈双击打开当前路径终端.command>) | [【WindowsOS】🎈双击打开当前路径终端.ps1](<./小工具/【WindowsOS】🎈双击打开当前路径终端.ps1/【WindowsOS】🎈双击打开当前路径终端.ps1>) | 在指定目录打开 Windows PowerShell |
| [【MacOS】🏥双击自检Flutter.command](<../MacOS/小工具/【MacOS】🏥双击自检Flutter.command/【MacOS】🏥双击自检Flutter.command>) | [【WindowsOS】🏥双击自检Flutter.ps1](<./小工具/【WindowsOS】🏥双击自检Flutter.ps1/【WindowsOS】🏥双击自检Flutter.ps1>) | 使用项目同源 Flutter SDK 运行版本与 doctor 诊断 |
| [【MacOS】🐦Flutter自动化生产代码.command](<../MacOS/小工具/【MacOS】🐦Flutter自动化生产代码.command/【MacOS】🐦Flutter自动化生产代码.command>) | [【WindowsOS】🐦Flutter自动化生产代码.ps1](<./小工具/【WindowsOS】🐦Flutter自动化生产代码.ps1/【WindowsOS】🐦Flutter自动化生产代码.ps1>) | 按项目依赖和配置运行可用生成器，冲突删除另行确认 |
| [【MacOS】🔍查询Flutter依赖版本.command](<../MacOS/小工具/【MacOS】🔍查询Flutter依赖版本.command/【MacOS】🔍查询Flutter依赖版本.command>) | [【WindowsOS】🔍查询Flutter依赖版本.ps1](<./小工具/【WindowsOS】🔍查询Flutter依赖版本.ps1/【WindowsOS】🔍查询Flutter依赖版本.ps1>) | 查询当前项目依赖的可用版本和约束 |
| [【MacOS】🛠️Android 模拟器一键检测与修复.command](<../MacOS/小工具/【MacOS】🛠️Android 模拟器一键检测与修复.command/【MacOS】🛠️Android 模拟器一键检测与修复.command>) | [【WindowsOS】🛠️Android 模拟器一键检测与修复.ps1](<./小工具/【WindowsOS】🛠️Android 模拟器一键检测与修复.ps1/【WindowsOS】🛠️Android 模拟器一键检测与修复.ps1>) | 诊断设备数据分区和安装位置，确认后恢复自动安装位置并重启 adb |
| [【MacOS】🛠️Flutter 插件 namespace 修复工具＂.command](<../MacOS/小工具/【MacOS】🛠️Flutter 插件 namespace 修复工具＂.command/【MacOS】🛠️Flutter 插件 namespace 修复工具＂.command>) | [【WindowsOS】🛠️Flutter 插件 namespace 修复工具＂.ps1](<./小工具/【WindowsOS】🛠️Flutter 插件 namespace 修复工具＂.ps1/【WindowsOS】🛠️Flutter 插件 namespace 修复工具＂.ps1>) | 只为本工程 Android app 补缺失 namespace，保留第三方缓存 |
| [【MacOS】🧪提取Flutter第三方依赖.command](<../MacOS/小工具/【MacOS】🧪提取Flutter第三方依赖.command/【MacOS】🧪提取Flutter第三方依赖.command>) | [【WindowsOS】🧪提取Flutter第三方依赖.ps1](<./小工具/【WindowsOS】🧪提取Flutter第三方依赖.ps1/【WindowsOS】🧪提取Flutter第三方依赖.ps1>) | 复用随包 Dart 核心提取已解析第三方 Pub 源码，排除 SDK、缓存与外部原生依赖 |
| [【MacOS】🧹Flutter清理维护工具.command](<../MacOS/小工具/【MacOS】🧹Flutter清理维护工具.command/【MacOS】🧹Flutter清理维护工具.command>) | [【WindowsOS】🧹Flutter清理维护工具.ps1](<./小工具/【WindowsOS】🧹Flutter清理维护工具.ps1/【WindowsOS】🧹Flutter清理维护工具.ps1>) | 确认 CLEAN 后执行本工程 flutter clean 与 pub get |
| [【MacOS】📹双击制作Android模拟器录屏Gif.command](<../MacOS/屏幕录制/【MacOS】📹双击制作Android模拟器录屏Gif.command/【MacOS】📹双击制作Android模拟器录屏Gif.command>) | [【WindowsOS】📹双击制作Android模拟器录屏Gif.ps1](<./屏幕录制/【WindowsOS】📹双击制作Android模拟器录屏Gif.ps1/【WindowsOS】📹双击制作Android模拟器录屏Gif.ps1>) | 通过 adb 录制指定 Android 设备并由 ffmpeg 转 GIF |
| [【MacOS】📦双击打包Flutter.Android.command](<../MacOS/打包相关/【MacOS】📦双击打包Flutter.Android.command/【MacOS】📦双击打包Flutter.Android.command>) | [【WindowsOS】📦双击打包Flutter.Android.ps1](<./打包相关/【WindowsOS】📦双击打包Flutter.Android.ps1/【WindowsOS】📦双击打包Flutter.Android.ps1>) | 选择 APK、AAB 或两者，使用现有 Windows Android 工具链构建并核验产物 |
| [【MacOS】📦双击打包Flutter.Harmony.command](<../MacOS/打包相关/【MacOS】📦双击打包Flutter.Harmony.command/【MacOS】📦双击打包Flutter.Harmony.command>) | [【WindowsOS】📦双击打包Flutter.Harmony.ps1](<./打包相关/【WindowsOS】📦双击打包Flutter.Harmony.ps1/【WindowsOS】📦双击打包Flutter.Harmony.ps1>) | 一次同时构建并核验 HAP 和 APP，默认 release，沿用工程签名 |
| [【MacOS】⬆️双击升级Flutter.SDK.command](<../MacOS/更新升级/【MacOS】⬆️双击升级Flutter.SDK.command/【MacOS】⬆️双击升级Flutter.SDK.command>) | [【WindowsOS】⬆️双击升级Flutter.SDK.ps1](<./更新升级/【WindowsOS】⬆️双击升级Flutter.SDK.ps1/【WindowsOS】⬆️双击升级Flutter.SDK.ps1>) | 升级当前工程选中的 Flutter SDK |
| [【MacOS】⬆️双击更新Flutter依赖.command](<../MacOS/更新升级/【MacOS】⬆️双击更新Flutter依赖.command/【MacOS】⬆️双击更新Flutter依赖.command>) | [【WindowsOS】⬆️双击更新Flutter依赖.ps1](<./更新升级/【WindowsOS】⬆️双击更新Flutter依赖.ps1/【WindowsOS】⬆️双击更新Flutter依赖.ps1>) | 升级工程约束允许的依赖并更新锁文件 |
| [【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command](<../MacOS/运行/【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command/【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command>) | [【WindowsOS】☀️双击运行Flutter项目（Android 模拟器） .ps1](<./运行/【WindowsOS】☀️双击运行Flutter项目（Android 模拟器） .ps1/【WindowsOS】☀️双击运行Flutter项目（Android 模拟器） .ps1>) | 启动所选 AVD 后选择 Android 设备运行 Flutter 工程 |
| [【MacOS】🎈双击真机运行项目.command](<../MacOS/运行/【MacOS】🎈双击真机运行项目.command/【MacOS】🎈双击真机运行项目.command>) | [【WindowsOS】🎈双击真机运行项目.ps1](<./运行/【WindowsOS】🎈双击真机运行项目.ps1/【WindowsOS】🎈双击真机运行项目.ps1>) | 只从已连接和授权的 Android 真机中选择设备运行工程 |
| [【MacOS】🚀双击启动Android模拟器.command](<../MacOS/运行/【MacOS】🚀双击启动Android模拟器.command/【MacOS】🚀双击启动Android模拟器.command>) | [【WindowsOS】🚀双击启动Android模拟器.ps1](<./运行/【WindowsOS】🚀双击启动Android模拟器.ps1/【WindowsOS】🚀双击启动Android模拟器.ps1>) | 启动已有 AVD，或用 -Mode Create 准备工具链并新建设备 |
| [【MacOS】⏬双击配置VSCode.command](<../MacOS/配置相关/【MacOS】VSCode.command/【MacOS】⏬双击配置VSCode.command/【MacOS】⏬双击配置VSCode.command>) | [【WindowsOS】⏬双击配置VSCode.ps1](<./配置相关/【WindowsOS】VSCode.ps1/【WindowsOS】⏬双击配置VSCode.ps1/【WindowsOS】⏬双击配置VSCode.ps1>) | 从已登记源合并工程与当前用户 VS Code 配置并分别备份 |
| [【MacOS】💉VSCode配置注入@全局.command](<../MacOS/配置相关/【MacOS】VSCode.command/【MacOS】💉VSCode配置注入@全局.command/【MacOS】💉VSCode配置注入@全局.command>) | [【WindowsOS】💉VSCode配置注入@全局.ps1](<./配置相关/【WindowsOS】VSCode.ps1/【WindowsOS】💉VSCode配置注入@全局.ps1/【WindowsOS】💉VSCode配置注入@全局.ps1>) | 从已登记源合并当前用户 VS Code 配置并备份旧目录 |
| [【MacOS】💉VSCode配置注入@当前Flutter项目.command](<../MacOS/配置相关/【MacOS】VSCode.command/【MacOS】💉VSCode配置注入@当前Flutter项目.command/【MacOS】💉VSCode配置注入@当前Flutter项目.command>) | [【WindowsOS】💉VSCode配置注入@当前Flutter项目.ps1](<./配置相关/【WindowsOS】VSCode.ps1/【WindowsOS】💉VSCode配置注入@当前Flutter项目.ps1/【WindowsOS】💉VSCode配置注入@当前Flutter项目.ps1>) | 从已登记源合并所选工程 VS Code 配置并备份旧目录 |
| [【MacOS】⏬下载配置系统环境变量.command](<../MacOS/配置相关/【MacOS】⏬下载配置系统环境变量.command/【MacOS】⏬下载配置系统环境变量.command>) | [【WindowsOS】⏬下载配置系统环境变量.ps1](<./配置相关/【WindowsOS】⏬下载配置系统环境变量.ps1/【WindowsOS】⏬下载配置系统环境变量.ps1>) | 配置已有 Android SDK 与 JDK 的当前用户变量，支持精确恢复 |
| [【MacOS】⏬双击下载SourceTree效率脚本.command](<../MacOS/配置相关/【MacOS】⏬双击下载SourceTree效率脚本.command/【MacOS】⏬双击下载SourceTree效率脚本.command>) | [【WindowsOS】⏬双击下载SourceTree效率脚本.ps1](<./配置相关/【WindowsOS】⏬双击下载SourceTree效率脚本.ps1/【WindowsOS】⏬双击下载SourceTree效率脚本.ps1>) | 克隆 SourceTree 效率脚本到新目录，不覆盖已有目录 |
| [【MacOS】⏬双击配置VSCode.command](<../MacOS/配置相关/【MacOS】⏬双击配置VSCode.command/【MacOS】⏬双击配置VSCode.command>) | [【WindowsOS】⏬双击配置VSCode.ps1](<./配置相关/【WindowsOS】⏬双击配置VSCode.ps1/【WindowsOS】⏬双击配置VSCode.ps1>) | 从已登记源合并工程与当前用户 VS Code 配置并分别备份 |
| [【MacOS】⚙️Flutter 项目组件预下载.command](<../MacOS/配置相关/【MacOS】⚙️Flutter 项目组件预下载.command/【MacOS】⚙️Flutter 项目组件预下载.command>) | [【WindowsOS】⚙️Flutter 项目组件预下载.ps1](<./配置相关/【WindowsOS】⚙️Flutter 项目组件预下载.ps1/【WindowsOS】⚙️Flutter 项目组件预下载.ps1>) | 预下载 Android、Web、Windows 所需 Flutter 引擎缓存 |
| [【MacOS】⚙️一键配置Flutter项目至运行.command](<../MacOS/配置相关/【MacOS】⚙️一键配置Flutter项目至运行.command/【MacOS】⚙️一键配置Flutter项目至运行.command>) | [【WindowsOS】⚙️一键配置Flutter项目至运行.ps1](<./配置相关/【WindowsOS】⚙️一键配置Flutter项目至运行.ps1/【WindowsOS】⚙️一键配置Flutter项目至运行.ps1>) | 选择 Android、Web 或 Windows，按需准备工具链与 FVM，获取依赖并运行所选目标 |
| [【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command](<../MacOS/配置相关/【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command/【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command>) | [【WindowsOS】⚙️一键配置Flutter／鸿蒙项目至运行.ps1](<./配置相关/【WindowsOS】⚙️一键配置Flutter／鸿蒙项目至运行.ps1/【WindowsOS】⚙️一键配置Flutter／鸿蒙项目至运行.ps1>) | 使用已有鸿蒙 Flutter SDK 和 DevEco 工具链校验并运行 ohos 工程 |
| [【MacOS】⚙️下载配置系统环境变量.command](<../MacOS/配置相关/【MacOS】⚙️下载配置系统环境变量.command/【MacOS】⚙️下载配置系统环境变量.command>) | [【WindowsOS】⚙️下载配置系统环境变量.ps1](<./配置相关/【WindowsOS】⚙️下载配置系统环境变量.ps1/【WindowsOS】⚙️下载配置系统环境变量.ps1>) | 配置已有 Android SDK 与 JDK 的当前用户变量，支持精确恢复 |
| [【MacOS】⚙️双击安装FVM.command](<../MacOS/配置相关/【MacOS】⚙️双击安装FVM.command/【MacOS】⚙️双击安装FVM.command>) | [【WindowsOS】⚙️双击安装FVM.ps1](<./配置相关/【WindowsOS】⚙️双击安装FVM.ps1/【WindowsOS】⚙️双击安装FVM.ps1>) | 安装当前用户 FVM 并按所选版本绑定现有工程 |
| [【MacOS】⚙️双击安装Flutter.SDK.command](<../MacOS/配置相关/【MacOS】⚙️双击安装Flutter.SDK.command/【MacOS】⚙️双击安装Flutter.SDK.command>) | [【WindowsOS】⚙️双击安装Flutter.SDK.ps1](<./配置相关/【WindowsOS】⚙️双击安装Flutter.SDK.ps1/【WindowsOS】⚙️双击安装Flutter.SDK.ps1>) | 从 Flutter 官方 Windows 清单下载稳定 SDK，验证 SHA-256 后安装到新目录 |
| [【MacOS】⚙️收集当前Flutter工程的依赖.command](<../MacOS/配置相关/【MacOS】⚙️收集当前Flutter工程的依赖.command/【MacOS】⚙️收集当前Flutter工程的依赖.command>) | [【WindowsOS】⚙️收集当前Flutter工程的依赖.ps1](<./配置相关/【WindowsOS】⚙️收集当前Flutter工程的依赖.ps1/【WindowsOS】⚙️收集当前Flutter工程的依赖.ps1>) | 导出当前工程解析到的 Dart 包源码和依赖声明，不复制整个系统缓存 |
| [【MacOS】⚙️配置Android Studio.command](<../MacOS/配置相关/【MacOS】⚙️配置Android Studio.command/【MacOS】⚙️配置Android Studio.command>) | [【WindowsOS】⚙️配置Android Studio.ps1](<./配置相关/【WindowsOS】⚙️配置Android Studio.ps1/【WindowsOS】⚙️配置Android Studio.ps1>) | 自动准备 Android SDK、JDK 与必要组件，许可证本人确认 |
| [【MacOS】🎈双击打开系统配置文件.command](<../MacOS/配置相关/【MacOS】🎈双击打开系统配置文件.command/【MacOS】🎈双击打开系统配置文件.command>) | [【WindowsOS】🎈双击打开系统配置文件.ps1](<./配置相关/【WindowsOS】🎈双击打开系统配置文件.ps1/【WindowsOS】🎈双击打开系统配置文件.ps1>) | 使用记事本打开已有当前用户 PowerShell profile，不自动执行未知配置 |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">四、MacOS 专用排除项</span><!-- jobs-toc:heading-end -->

下列 16 个原入口只在 MacOS 存在，WindowsOS 不建立同名空壳。iOS 模拟器的初始化、打开、运行和录屏全部排除。

| 原入口 | 原因 |
| --- | --- |
| [【MacOS】⚙️Pod_Install.command](<../MacOS/Cocoapods/【MacOS】⚙️Pod_Install.command/【MacOS】⚙️Pod_Install.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⚙️双击安装Cocoapods.command](<../MacOS/Cocoapods/【MacOS】⚙️双击安装Cocoapods.command/【MacOS】⚙️双击安装Cocoapods.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⚙️双击更换Cocoapods源\[-\]CDN\[+\]Github.command](<../MacOS/Cocoapods/【MacOS】⚙️双击更换Cocoapods源[-]CDN[+]Github.command/【MacOS】⚙️双击更换Cocoapods源[-]CDN[+]Github.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command](<../MacOS/Cocoapods/【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command/【MacOS】⚙️双击禁用沙盒保证Cocoapods构建流程.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⚙️双击任何来源安装.command](<../MacOS/小工具/【MacOS】⚙️双击任何来源安装.command/【MacOS】⚙️双击任何来源安装.command>) | macOS Gatekeeper / SIP 专用，WindowsOS 不全局关闭安全策略 |
| [【MacOS】⚙️双击卸载Homebrew.command](<../MacOS/小工具/【MacOS】⚙️双击卸载Homebrew.command/【MacOS】⚙️双击卸载Homebrew.command>) | Homebrew 管理专用；Windows 使用其原生工具安装机制 |
| [【MacOS】📹双击制作iOS模拟器录屏Gif.command](<../MacOS/屏幕录制/【MacOS】📹双击制作iOS模拟器录屏Gif.command/【MacOS】📹双击制作iOS模拟器录屏Gif.command>) | iOS 模拟器或 iOS 构建要求 MacOS + Xcode，WindowsOS 不提供入口 |
| [【MacOS】📦双击打包Flutter.iOS.command](<../MacOS/打包相关/【MacOS】📦双击打包Flutter.iOS.command/【MacOS】📦双击打包Flutter.iOS.command>) | iOS 模拟器或 iOS 构建要求 MacOS + Xcode，WindowsOS 不提供入口 |
| [【MacOS】⬆️Pod_Update.command](<../MacOS/更新升级/【MacOS】⬆️Pod_Update.command/【MacOS】⬆️Pod_Update.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⬆️双击升级Cocoapods.command](<../MacOS/更新升级/【MacOS】⬆️双击升级Cocoapods.command/【MacOS】⬆️双击升级Cocoapods.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⬆️双击更新CocoaPods本地仓库.command](<../MacOS/更新升级/【MacOS】⬆️双击更新CocoaPods本地仓库.command/【MacOS】⬆️双击更新CocoaPods本地仓库.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command](<../MacOS/运行/【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command/【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command>) | iOS 模拟器或 iOS 构建要求 MacOS + Xcode，WindowsOS 不提供入口 |
| [【MacOS】📱双击初始化iOS模拟器.command](<../MacOS/运行/【MacOS】📱双击初始化iOS模拟器.command/【MacOS】📱双击初始化iOS模拟器.command>) | iOS 模拟器或 iOS 构建要求 MacOS + Xcode，WindowsOS 不提供入口 |
| [【MacOS】📱双击打开已实例化的iOS模拟器.command](<../MacOS/运行/【MacOS】📱双击打开已实例化的iOS模拟器.command/【MacOS】📱双击打开已实例化的iOS模拟器.command>) | iOS 模拟器或 iOS 构建要求 MacOS + Xcode，WindowsOS 不提供入口 |
| [【MacOS】⚙️双击安装Cocoapods.command](<../MacOS/配置相关/【MacOS】⚙️双击安装Cocoapods.command/【MacOS】⚙️双击安装Cocoapods.command>) | CocoaPods / Xcode 构建专用，仅 MacOS |
| [【MacOS】⚙️双击安装（升级）Homebrew.command](<../MacOS/配置相关/【MacOS】⚙️双击安装（升级）Homebrew.command/【MacOS】⚙️双击安装（升级）Homebrew.command>) | Homebrew 管理专用；Windows 使用其原生工具安装机制 |

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">五、确认、日志与恢复</span><!-- jobs-toc:heading-end -->

所有真实操作先显示自述并回车确认。升级 SDK、改配置、资源覆盖等要求精确 YES；清理要求 CLEAN。本地文件覆盖前保存同级 .jobs-backup-时间戳-标识 副本，JSONC 配置不能安全合并时保留原文停止。VS Code 配置来源分别为 JobsKits/VScodeConfigByFlutter 与 JobsKits/JobsConfigByVSCode，克隆前显示完整地址和目标。

总会话日志在系统临时目录 JobsFlutter-功能-时间戳-标识.log；复用功能核心的补充日志在当前用户本地应用数据 JobsCommandFlutter/logs。环境变量只设置当前用户 ANDROID_HOME / ANDROID_SDK_ROOT / JAVA_HOME，首次保存精确快照；恢复前核对期间是否被其它工具修改，成功后归档快照。Path、系统代理与系统执行策略不做持久变更。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">六、验证与限制</span><!-- jobs-toc:heading-end -->

PowerShell 全树语法解析和 Tests/Portable.Tests.ps1 的临时夹具、全部 46 个入口 Plan / Check 可验证；包括中文与空格路径、FVM 缺失停止、URI 编码幂等、配置保留、namespace 不覆盖、依赖 ZIP、原生命令非零失败。Tests/HarmonyBuild.Tests.ps1 额外隔离验证双产物命令顺序、能力缺失、任一构建失败、空产物与环境恢复。MacOS 原脚本与现有资源的移动前后字节核对另行执行。

验证未进行真实网络下载、安装、用户环境写入、缓存清理、设备运行或构建；Windows PowerShell 5.1 与 Windows 实机尚需目标机验收。运行测试见 [Tests/README.md](./Tests/README.md)。
