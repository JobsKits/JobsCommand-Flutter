# 【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行方式与结果](#quickstart)
- [二、执行顺序与确认](#workflow)
- [三、版本、来源与环境范围](#materials)
- [四、工程文件与后续使用](#project-files)
- [五、签名、插件与常见失败](#limits)
- [六、文件、日志与验证](#files-validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

给**已有 [**Flutter**](https://flutter.dev/) 工程**准备 [**HarmonyOS**](https://developer.huawei.com/consumer/cn/) 适配 SDK、构建工具、模拟器或真机，然后选择设备运行。业务代码使用 [**Dart**](https://dart.dev)，鸿蒙平台由 CPF-Flutter 适配 SDK 支持。

这是独立鸿蒙入口，固定使用工程级 [**FVM**](https://fvm.app)，不需要原 Flutter 脚本包或 Finder 扩展。文件名使用全角 `／`，因为半角 `/` 是文件系统路径分隔符。**整个文件夹一起复制，不能只取其中的 `.command`。**

## 一、<span id="quickstart">运行方式与结果</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录双击主脚本，或者执行：

```shell
/bin/zsh './【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command'
```

也可把已有工程作为参数；相对路径按启动终端所在目录解释，交互支持 Finder 拖入的路径：

```shell
/bin/zsh './【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command' \
  './你的Flutter工程'
```

帮助与离线盘点无需交互，不安装、不联网、不写日志、不启动 Flutter SDK：

```shell
/bin/zsh './【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command' --help
/bin/zsh './【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command' \
  './你的Flutter工程' \
  --check
```

| 环节 | 行为与结果 |
| --- | --- |
| 自述 | 源码内固定说明；回车继续，任意非空输入或 EOF 取消，Ctrl+C 随时取消。 |
| 工程 | 必须已有 `pubspec.yaml`、`lib/` 且可写；空路径持续询问，不猜当前目录。 |
| SDK | 固定鸿蒙类型；已有鸿蒙版本默认保留，其它已有 FVM 绑定必须精确 `YES` 才切换。 |
| 工具 | 复用健康 Homebrew / Python / FVM / DevEco；缺失时按提示安装，安装失败停止。 |
| 设备类型 | 回车准备模拟器工具及镜像；输入 `device` 仅准备工具，供真机使用。 |
| 平台 | 保留已有 `ohos/`；缺目录只有精确 `YES` 才执行 `flutter create --platforms=ohos .`。 |
| 依赖 | 生成工程运行入口，执行 `doctor -v`、`pub get`、平台 `ohpm install` 与 Hvigor 健康检查。 |
| 运行 | 回车选择鸿蒙设备；非空输入仅完成配置。空设备列表可重新加载、创建模拟器或退出。 |
| 结果 | 只有实际 `run` 才进入构建、安装、调试；签名 / 插件错误返回失败，不把环境准备当成运行成功。 |

`--check` 仅盘点宿主、工具候选文件、可选工程的平台标记与 FVM 入口，缺项返回非零。它不执行候选工具，所以通过也不代表版本、JDK、许可、签名或运行已验收。

## 二、<span id="workflow">执行顺序与确认</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 阅读内置自述并回车，核对工程根目录。
- 检查 [**Homebrew**](https://brew.sh/) 和 [**Python**](https://www.python.org/) 3.11+；本包使用 Homebrew `python@3.13` 通道。健康 Homebrew 不自动更新、全量升级或清理。
  - 缺 Homebrew 时独立选择安装路径：精确 `YES` 选系统目录，其它输入选用户目录；官方系统安装器自行处理权限，失败不改走另一条路线。
  - 缺 Python 时回车安装 / 修复，任意非空输入取消。缺 Apple Command Line Tools 时需先完成系统安装后重试。
- 选择鸿蒙版本，检查 FVM，准备 DevEco / CLT、同包 Node / ohpm / Hvigor、HDC / ETS / native 和 JDK。
  - 缺 FVM 时回车通过 `btwld/fvm/fvm` 安装；已有坏版本停止并给出修复方向。
  - CLT 未附带 JDK 时，回车准备 Homebrew `openjdk@17`，或输入已有 JDK 目录；只激活当前进程 Java，不注册全局 JDK。
- 准备系统镜像；可选新建并启动模拟器。已有设备和镜像不删除。
- 核实 SDK 远端 ref / commit，展示来源、缓存与工程路径，回车后下载或复用，并用 FVM 自定义 SDK 机制绑定工程。
- 视需要生成 `ohos/`、合并编辑器环境、解析依赖。
  - 拒绝生成时只保存环境，不运行；已有不完整 `ohos/` 停止等待修复，不能以重新生成覆盖。
  - `doctor` 可能报告其它平台缺失，保留诊断；构建链单项失败和实际运行失败仍会停止。
- 只列出 `targetPlatform` 以 `ohos` 开头且未被标为不支持的设备。选择后 `flutter run -d ID`，可用 `r` 热重载、`q` 结束会话。

## 三、<span id="materials">版本、来源与环境范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

截至 2026-10-23 核对的基线；不是未来版本自动兼容保证。版本可在交互中改选明确 tag / 分支，每次按远端真实 commit 固定缓存。

| 组件 | 基线与来源 |
| --- | --- |
| Flutter OH | [**CPF-Flutter 官方仓库**](https://gitcode.com/CPF-Flutter/flutter_flutter)，`3.35.7+ohos-1.0.5`，commit `04d2008b35eae67162f0f11d2fd8e2453092c891`。旧 OpenHarmony-SIG 仓库已迁移。 |
| FVM | [自定义 SDK 官方机制](https://fvm.app/documentation/advanced/custom-version)：完整 SDK 放入隔离缓存，以 `custom_jobs_ohos_<commit>` 执行 `use --skip-setup --skip-pub-get`。 |
| DevEco | [**DevEco Studio 下载中心**](https://developer.huawei.com/consumer/cn/download/)；也可复用已安装完整 Studio 的配套工具。 |
| 独立 CLT | [**SDL 第三方下载镜像**](https://libsdl.org/harmonyos-devtools/commandline-tools-mac-arm64-6.1.1.280.zip)，Mac ARM64 `6.1.1.280`，`2025336267` 字节。 |
| CLT 校验 | SHA-256 `47d0e558b8285e1452f4d3611863027ec0d1135642761bef23402434e22382d4`。这是已核对 SDL 快照摘要，**不是华为官方公布的摘要**。 |
| 镜像 / 实例 | [华为官方 Emulator CLI](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-command-line)，仅选择 Release 镜像；CLT ZIP 不含可启动镜像。 |
| Java | 优先 `JAVA_HOME`，其次工具随附 JDK，再找本机 JDK 17；缺失可准备 `openjdk@17`。同时核对 `java` 与 `javac` 的 17 主版本。 |

本入口采用 **Apple Silicon 原生 macOS** 路径。Rosetta 启动时切换原生 arm64 后重新展示自述；Intel Mac 不使用 ARM64 CLT 或本地鸿蒙模拟器。

SDK 缓存在用户缓存目录的 `JobsFlutter/fvm/harmony/versions/`。已有 SDK 仅在来源、commit 与源码干净状态均匹配时复用，不覆盖脏缓存。SDK 下载及 FVM 绑定失败或收到 INT / TERM / HUP 时恢复之前的绑定（含 `.fvm/versions` 的版本链接）；恢复失败保留完整临时快照，日志打印位置。

来源输出示例（目标路径按运行环境解析）：

```text
━━━━━━━━━━ 来源 ━━━━━━━━━━
对象：Flutter OH 3.35.7+ohos-1.0.5
来源地址：https://gitcode.com/CPF-Flutter/flutter_flutter.git
目标位置：用户缓存目录中的 JobsFlutter/fvm/harmony
核实 commit：04d2008b35eae67162f0f11d2fd8e2453092c891
```

| 环境变量 | 当前进程 / 工程内含义 |
| --- | --- |
| `TOOL_HOME` | DevEco 的 `Contents` 或独立 CLT 根目录。 |
| `DEVECO_SDK_HOME` / `HOS_SDK_HOME` / `OHOS_SDK_HOME` / `OHOS_HOME` | 所选工具根目录中的 `sdk`。 |
| `HDC_HOME` | `sdk/default/openharmony/toolchains`。 |
| `JAVA_HOME` / `PATH` | 经检查的 JDK、同包 Node / ohpm / Hvigor、HDC。 |
| `FVM_CACHE_PATH` / `FVM_FLUTTER_URL` | SDK 准备进程与 `.fvmrc` 使用相同隔离缓存和官方适配仓库。 |
| `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` / `PUB_CACHE` | 只保留调用方已明确设置的值，不猜鸿蒙 Engine 镜像。 |

不设置 `fvm global`，不调用 Flutter 全局 `config`，不改代理、全局 Git、用户 npm / ohpm registry。新装 Homebrew 可能写入自己的 shellenv 块，旧配置有备份；鸿蒙环境保存在工程内，不写 Shell 启动文件。

模拟器路径可通过 `HARMONY_EMULATOR_BIN`、`DEVECO_STUDIO_HOME` 或 `TOOL_HOME` 明确指定；错误路径停止。`HARMONY_CLT_ARCHIVE` 可以复用同版本 ZIP，仍核对大小和摘要。

## 四、<span id="project-files">工程文件与后续使用</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 工程路径 | 内容 |
| --- | --- |
| `.fvmrc`、`.fvm/flutter_sdk` | 鸿蒙 SDK 版本、来源、当前机器缓存与 FVM 链接。保留无关字段。 |
| `.jobs-flutter/sdk.json` | ref、commit、工具路径与受管编辑器环境记录。 |
| `.jobs-flutter/env.zsh` | 工程专用工具链环境。 |
| `.jobs-flutter/flutter` | 自动进入工程、加载环境，再执行当前 FVM 链接的 SDK；链接失效停止。 |
| `.vscode/settings.json`、`.vscode/launch.json` | 合并 Flutter SDK 与环境，保留其它配置；JSONC 或不可安全合并内容保留原样，另生成建议文件。 |
| `.gitignore` | 增量忽略 `.fvm/`、`.jobs-flutter/` 和配置备份。 |
| `ohos/`、锁文件与构建缓存 | 本人确认生成的平台、依赖解析及运行产物；遵循工程原有签名与 API 配置。 |

改配置前保留带时间戳的备份，相同内容不重复写入。`.jobs-flutter/` 和 `.fvmrc` 的缓存路径包含本机信息，换机须重新配置。SDK 绑定恢复不等于撤销 `pub get`、平台生成、工具下载或已创建设备。

在目标工程内使用：

```shell
.jobs-flutter/flutter doctor -v
.jobs-flutter/flutter devices
.jobs-flutter/flutter run
.jobs-flutter/flutter build hap --debug
```

## 五、<span id="limits">签名、插件与常见失败</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- **签名失败：** 在 DevEco 打开工程 `ohos/`，按官方流程完成开发者登录和 Signing Configs，再用工程入口重试。脚本不生成证书或保存签名秘密。
- **原生插件不兼容：** 逐项检查所用插件的鸿蒙适配、版本、来源及许可。纯 Dart 依赖与含 Android / iOS 原生代码的插件不能作相同假设。
- **SDK 路径被旧配置覆盖：** 本工程会覆盖继承的 `OHOS_HOME` 等变量；若本人曾通过 Flutter 全局 `config --ohos-sdk` 固定另一套 SDK，需先核对 `doctor -v` 的实际路径并自行处理冲突，脚本不改这项全局设置。
- **API / 工具不匹配：** 核对 `compatibleSdkVersion`、`compileSdkVersion`、设备系统 API、Hvigor 插件版本和 Flutter OH 版本；新镜像不一定适合旧工程。
- **找不到设备：** 在空列表回车重载，或输入 `s` 创建模拟器；已有模拟器需先启动，真机需启用并授权调试。Emulator 启动返回成功不等于系统启动完成。
- **缺少本地镜像：** 工具显示随附许可原文，本人回车同意后查询官方镜像并下载。账号、网络或地区要求由官方工具处理。
- **下载失败：** 日志先看实际来源、版本和目标；校验失败不解压或执行。首次 SDK 完整历史、Engine、CLT、镜像可能分别占用数 GB 空间。

依据：[环境搭建指导](https://gitcode.com/CPF-Flutter/flutter_samples/blob/master/ohos/docs/03_environment/OpenHarmony-flutter环境搭建指导.md)、[已有 Flutter 应用接入指导](https://gitcode.com/CPF-Flutter/flutter_samples/blob/master/ohos/docs/04_development/Flutter应用接入鸿蒙平台指导文档.md)。

## 六、<span id="files-validation">文件、日志与验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
本目录/
├── 【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command
├── README.md
├── Scripts/
│   ├── README.md
│   ├── harmony_workflow.zsh
│   ├── project_config.py
│   └── CreateHarmonySimulator.zsh
└── Tests/
    ├── test_harmony_setup.py
    ├── test_binding_versions.py
    └── CreateHarmonySimulatorTests.rb
```

主日志为系统临时目录 `JobsFlutterHarmonySetup.*/setup.log`，运行交互另存同目录 `run.typescript`；后者是保留终端显示和热重载能力的原始终端记录，可能包含控制字符。模拟器独立日志在系统临时目录 `JobsHarmonySimulator.*/CreateHarmonySimulator.log`。

模拟器核心从用户指定的 `OS@Extension/MacOS@Extension/JobsHarmonySimulatorCreator` 复制，参考源码 SHA-256 为 `6d3f23f6eb32c4b045b5c17da82d693dc271d5a45ef31ffcf0881f6efb4957af`；只把入口改为可被 `source`，业务保持一致。运行时不依赖外部参考目录。

```shell
/bin/zsh -n './【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command'
/bin/zsh -n './Scripts/harmony_workflow.zsh'
/bin/zsh -n './Scripts/CreateHarmonySimulator.zsh'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
/usr/bin/ruby './Tests/CreateHarmonySimulatorTests.rb'
```

2026-10-23 验证：主流程与配置保护 **57 项测试通过**，模拟器核心 **58 组 / 457 个断言通过**；三份 zsh 语法检查通过。

离线验证使用临时工程与假工具，不安装真实 SDK、CLT 或镜像，也不改真实工程。真实 HAP 编译、签名、设备安装及热重载仍需在目标工程完成；仓库 ref 的联网核实不替代运行验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
