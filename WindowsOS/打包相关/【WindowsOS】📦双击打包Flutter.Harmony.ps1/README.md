# `【WindowsOS】📦双击打包Flutter.Harmony.ps1`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、功能覆盖](#features)
- [二、参数与工具链](#options)
- [三、运行示例](#usage)
- [四、结果与排查](#results)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

为已有 [**Flutter**](https://flutter.dev/) 鸿蒙工程一次构建 HAP 安装包和 APP 发布包。入口：[PowerShell 脚本](<./【WindowsOS】📦双击打包Flutter.Harmony.ps1>)、[CMD 双击入口](<./【WindowsOS】📦双击打包Flutter.Harmony.cmd>)；随包核心：[FlutterTools.psm1](./../../Scripts/FlutterTools.psm1)。使用 [**Windows**](https://www.microsoft.com/windows) [**PowerShell**](https://learn.microsoft.com/powershell/) 5.1 或更新版本，分发时保留整个 `WindowsOS/` 目录。

## 一、<span id="features">功能覆盖</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 仅处理指定根目录，要求同层 `pubspec.yaml` 明确声明 `dependencies.flutter.sdk: flutter`，并已有 `lib/`、`ohos/`、`ohos/build-profile.json5`、`ohos/oh-package.json5`。不扫描子工程，不生成或改造平台。
- 默认依次执行 `flutter pub get`、`flutter build hap --release`、`flutter build app --release`；可显式改为 `debug` 或 `profile`。两种构建结束后再次核对已确认的两类文件仍存在且非空，全部成功才完成；APP 构建删掉 HAP 也判失败，中途失败保留已经生成的文件供排查。
- 先验证所选 SDK 确实同时提供 `flutter build hap` 和 `flutter build app`，以及现有 [**DevEco Studio**](https://developer.huawei.com/consumer/cn/deveco-studio/) 工具链；缺工具或普通官方 SDK 会停止，不自动下载或切换全局 Flutter。
- 扫描 `build/ohos/`、`ohos/build/` 及 `ohos/各模块/build/` 的 `outputs`，要求同时存在非空 `.hap` 和 `.app` 文件，跳过链接和中间缓存；`-unsigned.hap` / `-unsigned.app` 会明确标记为未签名。构建成功但产物时间早于本次命令时明确显示“现存鸿蒙产物”，不把缓存写成新生成结果。

## 二、<span id="options">参数与工具链</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 参数或环境变量 | 当前行为 |
| --- | --- |
| `-TargetPath` / `-ProjectPath` | 已有 Flutter 鸿蒙工程根目录；未提供时提示输入 |
| `-HarmonyFlutterSdkPath` | 已有鸿蒙适配 SDK 根目录；默认读取 `FLUTTER_OHOS_SDK` |
| SDK 回退顺序 | 显式参数 / 环境变量 → 工程 `.fvm/flutter_sdk` → PATH；工程声明了 [**FVM**](https://fvm.app) 但 SDK 不完整时停止 |
| `-Mode` | 默认 `release`，可设 `debug` / `profile`；此入口不读取 `BUILD_MODE` 代替默认值 |
| `OHOS_BUILD_TARGET` | 此入口固定同时构建 HAP + APP，不允许该环境变量缩减产物 |
| `DEVECO_STUDIO_HOME` / `TOOL_HOME` | 现有 DevEco Studio 或 command-line-tools 根目录，可自动发现标准安装位置 |
| `DEVECO_SDK_HOME` / `HOS_SDK_HOME` | 已有 HarmonyOS SDK；不将 `OHOS_SDK_HOME` 当作同义路径 |
| `JAVA_HOME` / `NODE_HOME` | 可选的现有工具根目录；工具链还需可运行的 `npm`、`ohpm`、`hvigorw` |
| `FLAVOR` | 暂不支持，非空时停止，避免不同鸿蒙 SDK 静默采用 default 产品 |
| `-Plan` / `-Check` | 只展示动作 / 核对随包模块和可选目标路径；不运行 SDK，不表示环境健康或构建通过 |

SDK 需与工程平台、插件及 [**HarmonyOS**](https://developer.huawei.com/consumer/cn/) SDK 版本匹配。打包沿用工程已有签名配置，不生成证书、不自动签署许可、不上传商店、不安装到设备。未签名 HAP 不能直接等同于可安装包，需先在 DevEco 完成签名和目标设备授权。

## 三、<span id="usage">运行示例</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录运行，只检查入口：

```powershell
& './【WindowsOS】📦双击打包Flutter.Harmony.ps1' `
  -TargetPath 'D:\Projects\鸿蒙 Demo' `
  -Check
```

一次构建 release HAP + APP，路径需替换为本机已有目录：

```powershell
$env:DEVECO_STUDIO_HOME = 'C:\Program Files\Huawei\DevEco Studio'
& './【WindowsOS】📦双击打包Flutter.Harmony.ps1' `
  -TargetPath 'D:\Projects\鸿蒙 Demo' `
  -HarmonyFlutterSdkPath 'D:\SDKs\flutter_ohos' `
  -Mode release
```

显示自述后回车继续，其它输入取消；运行中 `Ctrl+C` 终止。只把工具环境用于当前进程及其构建子进程，结束后恢复；不持久修改用户 PATH、代理或执行策略。`.cmd` 的 `ExecutionPolicy Bypass` 仅作用于本次 PowerShell。

## 四、<span id="results">结果与排查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

日志在系统临时目录 `JobsFlutter-build-harmony-时间戳-标识.log`，包含工具链检查、构建输出与最终 HAP / APP 路径。构建命令非零时停止并保留日志和工程现场，入口传递可用的构建退出码；缺平台、缺工具或任一类没有非空产物均以非零退出。排查时核对 SDK 能力、`ohos` 工程签名、插件适配和产物路径，不以 `-Plan` / `-Check` 代替实际编译、签名与设备安装验证。

[返回打包目录](./../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
