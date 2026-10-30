# Flutter 鸿蒙打包（HAP + APP）

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口与参数](#usage)
- [二、工程与工具链](#requirements)
- [三、执行、产物与失败](#outputs)
- [四、验证与关联入口](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

使用已有的鸿蒙适配 [**Flutter**](https://gitcode.com/CPF-Flutter/flutter_flutter) SDK，一次生成 `.hap` 安装包与 `.app` 发布包，默认 `release`。本包在 [**macOS**](https://www.apple.com/macos/) 独立运行，保留整个目录即可复制使用，不依赖右键扩展或 Sourcetree 仓库。

## 一、<span id="usage">入口与参数</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

双击[同名脚本](./【MacOS】📦双击打包Flutter.Harmony.command)，先阅读自述并回车，再输入或拖入 Flutter 鸿蒙工程根目录。Ctrl+C 或输入结束取消；不会扫描邻近工程。命令行也可显式指定：

```shell
/bin/zsh './【MacOS】📦双击打包Flutter.Harmony.command' \
  --project './你的Flutter工程' \
  --mode release \
  --flutter-sdk './你的鸿蒙FlutterSDK'
```

| 选项 | 默认与行为 |
| --- | --- |
| `--project` 或一个位置路径 | 未传时交互输入；只接受指定根目录自身 |
| `--mode release\|debug\|profile` | 默认 `release`，应用于两个构建命令 |
| `--flutter-sdk` | 显式 SDK 根目录；其次 `FLUTTER_OHOS_SDK`、项目 `.fvm/flutter_sdk`、当前 PATH |
| `--help` | 放在首参数；显示用法，不运行工具 |
| `--check --project <目录>` | 只读校验工程清单与参数，不联网、不运行 SDK、不创建日志 |
| `OPEN_AFTER_BUILD=0` | 关闭构建后 Finder 定位；默认定位产物 |

产物目标始终为 HAP + APP，不受 `BUILD_TARGET`、`OHOS_BUILD_TARGET` 或 `BUILD_MODE` 环境变量覆盖。已有 [**FVM**](https://fvm.app) 绑定损坏时停止，除非显式提供鸿蒙 SDK，不自动改用其它 SDK。

## 二、<span id="requirements">工程与工具链</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

工程须包含声明 `dependencies.flutter.sdk: flutter` 的普通 `pubspec.yaml`、`lib/`，以及非空 `ohos/build-profile.json5`、`ohos/oh-package.json5`。不接受根目录链接、链接清单或链接 `lib/`、`ohos/`，不生成缺失的平台工程。`--check` 验证清单存在与 Flutter 依赖，不能证明 JSON5 配置、工具链、插件或签名可用。

实际构建前逐项检查 [**DevEco Studio**](https://developer.huawei.com/consumer/cn/deveco-studio/) / 配套 SDK、[**Node.js**](https://nodejs.org/)、npm、ohpm、Hvigor、[**Java**](https://openjdk.org/)，以及 SDK 同时提供 `flutter build hap` 和 `flutter build app`。普通 Flutter SDK 不满足要求。

工具目录可由 `DEVECO_STUDIO_HOME` / `TOOL_HOME` 指定；未显式设置 SDK 时尝试常用应用目录，发现多份则停止要求明确选择。也可自行设置 `DEVECO_SDK_HOME`、`JAVA_HOME`、`NODE_HOME` 和 PATH。仅激活本进程环境，保留显式路径，不将 `OHOS_SDK_HOME` 当作 DevEco SDK 的同义路径。

## 三、<span id="outputs">执行、产物与失败</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

前置检查通过后依次执行 `flutter pub get`、`flutter build hap --release`、`flutter build app --release`；指定其它模式时两步保持一致。依赖沿用工程锁文件与既有软件源，构建及依赖缓存会写入。脚本不清理工程、不安装或升级工具链、不生成签名材料、不提交或推送。

逐步检查 Flutter 汇总目录 `build/ohos/`、`ohos/build/` 及 `ohos/*/build/` 内最终输出目录中的非空产物。每类至少有一个本轮写入的包才通过；已有旧包保留并明确提示，不计为本轮成功。因此增量构建若完全复用旧文件且没有更新产物时间，也会停止，请核对工具实际输出后重新构建。任一步失败保留其退出码并停止，第二步失败时保留已经生成的 HAP，整体不会报告成功。

文件名带 `-unsigned` 时明确提示未签名；其它文件名也不证明证书有效。真机安装与上架仍依赖工程中的签名、证书、Profile、产品配置及插件适配。未自动安装到设备或上传应用市场。构建命令与产物约定可参阅[上游适配说明](https://gitee.com/openharmony-sig/flutter_flutter/blob/3.7.12-ohos-1.0.4/README.md)，实际版本以所选 SDK 为准。

确认后在系统临时目录 `JobsFlutterHarmonyPackager.*` 创建私有会话日志，标准输出与错误输出同步落盘，日志路径在终端显示。

## 四、<span id="verification">验证与关联入口</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

隔离回归使用临时工程和假工具，覆盖双产物顺序、失败停止、缺包、旧包、损坏 FVM、中文空格路径及只读检查；不调用真实 Flutter 构建、签名或设备安装：

```shell
ruby './Tests/harmony_packaging_test.rb'
```

真实 DevEco 编译、证书与设备安装仍需在目标工程验收。Windows 对应入口见[双端打包目录](../../../WindowsOS/打包相关/README.md)；返回[本端打包说明](../README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
