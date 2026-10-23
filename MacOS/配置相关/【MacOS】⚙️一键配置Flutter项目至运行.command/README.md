# 【MacOS】⚙️一键配置Flutter项目至运行.command

用于给**现有 Flutter 工程**准备 SDK、依赖和项目编辑器配置，支持官方 Flutter，以及 CPF-Flutter 的鸿蒙适配版。选择鸿蒙时可下载工具链和系统镜像、创建模拟器，最后按需选择设备运行工程。

**Flutter SDK 默认全部由 FVM 管理。只有在安装方式提示中精确输入大写 `YES`，才启用当前用户的全局 Flutter。** 回车、`yes`、`Yes`、带空格的 `YES ` 以及其它输入全部进入项目 FVM。FVM 模式不运行 `fvm global`，不把 Flutter / Dart PATH 写入 Shell 配置，也不改系统已有 Flutter。

## 运行和交互

保留整个目录一起复制；入口依赖相邻 `Scripts/`，不再是单文件脚本。可以双击 `.command`，也可以运行：

```sh
/bin/zsh './【MacOS】⚙️一键配置Flutter项目至运行.command'
/bin/zsh './【MacOS】⚙️一键配置Flutter项目至运行.command' '/绝对路径/Flutter工程'
/bin/zsh './【MacOS】⚙️一键配置Flutter项目至运行.command' --help
```

正常流程：

1. 阅读自述并确认。非交互输入不能授权安装；`--help` 不安装、不更新。
2. 选择项目 FVM / 全局 Flutter。全局模式仍由 FVM 保存 SDK，只额外设置 `fvm global` 和 `~/.zprofile` 的受管 PATH 块。这是**当前用户的全局环境**，不会向 `/etc` 写配置，也不会为所有用户安装 Flutter。
3. 拖入 / 输入现有工程根目录，或使用命令行明确传入的目录。须有 `pubspec.yaml`、`lib/` 且可写。空白、无效路径会持续询问；连续回车不会跳过，也不会猜当前目录。`Ctrl+C` / EOF 取消。
4. 准备 Homebrew Python 和独立 FVM。已有健康工具复用；不执行全量 `brew upgrade`、`brew cleanup`，不安装系统 Flutter 来引导 FVM。
5. 选择官方 Flutter / 鸿蒙适配版及版本。默认保留能识别的工程版本；新工程官方默认 `stable`，鸿蒙默认下表中的固定 tag。官方 `stable` / `beta` 使用 FVM `--pin` 固定到具体版本。
6. 鸿蒙模式单独确认工具准备。回车准备工具及 Release 镜像；`device` 只准备工具，适用于已有真机。创建并启动新模拟器是独立可选操作，回车跳过。下载 / 启动需要阅读并确认工具随附协议。
7. SDK 下载前再次展示来源、版本、模式和缓存位置，回车确认，非空输入取消。鸿蒙 tag / 分支先解析远端 commit；官方与鸿蒙缓存分开。
8. 鸿蒙工程缺 `ohos/` 时，只有再次输入精确 `YES` 才执行 `flutter create --platforms=ohos .`。保留现有 `ohos/`，不覆盖签名。跳过时明确报告“仅环境准备”，不声称能运行。
9. 官方版按需预缓存 `ios` / `android` / `macos` / `web`；鸿蒙版由适配 SDK 按实际命令下载所需产物。执行 `doctor -v` 和 `pub get`，写入工程配置。
10. 可选选择已连接设备并 `run`。鸿蒙仅列出 `ohos` 目标设备；不再固定 iOS 模拟器 UUID。

SDK 绑定失败会恢复操作前的 `.fvmrc`、`.fvm/flutter_sdk` 链接及 FVM 的 `version`、`release`、`fvm_config.json` 元数据。SDK 准备中收到 Ctrl+C / INT / TERM / HUP，会恢复后以 130 退出，不继续后续流程。若恢复失败，会打印并保留 `$TMPDIR/JobsFlutterBinding.*/` 完整恢复快照；不要删除该目录。`pub get`、工程生成、已创建的模拟器及已经确认生效的全局模式不会自动回滚。

## FVM、工程配置与环境范围

[FVM 官方自定义 SDK 文档](https://fvm.app/documentation/advanced/custom-version)支持把完整 SDK 放入版本缓存并以 `custom_` 名称绑定。这里对鸿蒙采用该机制：完整克隆指定仓库、检出核实的 commit，保存为 `custom_jobs_ohos_<40位commit>`，再执行 `fvm use ... --skip-setup --skip-pub-get`。不注册或修改全局 fork 别名，不修改 FVM 的全局仓库 URL，也不使用并不存在的 `fvm install --ohos` 参数。

| 位置 | 内容 / 范围 |
| --- | --- |
| `~/Library/Caches/JobsFlutter/fvm/official/versions/` | FVM 管理的官方 Flutter SDK |
| `~/Library/Caches/JobsFlutter/fvm/harmony/versions/` | FVM 管理的鸿蒙 SDK；同一 commit 可在多个工程复用 |
| 工程 `.fvmrc` | 版本、对应来源与缓存路径；保留原有 flavors 等无关字段 |
| 工程 `.fvm/flutter_sdk` | FVM 创建的 SDK 链接；后续业务检查链接归属，不回退到系统 Flutter |
| 工程 `.jobs-flutter/sdk.json` | 本次 ref、commit、工具链路径和受管编辑器环境记录 |
| 工程 `.jobs-flutter/env.zsh` | 仅针对本工程的鸿蒙工具链 / 显式镜像环境 |
| 工程 `.jobs-flutter/flutter` | 自动进入工程、加载环境，每次按当前 `.fvm/flutter_sdk` 链接执行；跟随 FVM 切换版本，链接失效则停止 |
| 工程 `.vscode/settings.json` | 合并 `dart.flutterSdkPath`、`dart.env`，移除冲突的 `dart.sdkPath` |
| 工程 `.vscode/launch.json` | 合并名为 `Jobs Flutter` 的调试配置，保留用户其它配置；设备运行时选择 |
| 工程 `.gitignore` | 追加 `/.fvm/`、`/.jobs-flutter/`、`*.bak.*` |
| `~/.zprofile` | **仅全局模式**添加 / 更新 `Jobs Flutter global` 块；备份后写入，保留其它内容 |

配置修改前生成带时间戳的备份，重复相同内容不重复写入。VS Code JSONC（注释、尾逗号）或无法安全合并的文件会原样保留，建议内容放在 `.jobs-flutter/*.suggested.json`，需要手工合并。切回官方 SDK 时，只清除本脚本上次写入且未被用户修改的鸿蒙编辑器变量。

`.fvmrc` 中的 `cachePath` 是本机绝对路径。团队可提交版本 / 来源约定，但跨电脑使用时需重新运行本入口重设路径，或按团队约定调整该字段。`.jobs-flutter` 含本机路径，不应提交。已有自定义 fork / 不可识别的 FVM 版本（包括丢失本机 ref 记录的 custom SDK）必须输入 `1` 或 `2` 明确选择 SDK 类型；连续回车不会默认迁到官方 stable。

日常使用：

```sh
# 在目标工程内；推荐鸿蒙使用此入口，确保工具链环境一起加载
.jobs-flutter/flutter doctor -v
.jobs-flutter/flutter devices
.jobs-flutter/flutter run
.jobs-flutter/flutter build hap --debug

# 手动使用 FVM 时，先在当前终端加载工程环境
source .jobs-flutter/env.zsh
fvm flutter doctor -v
```

修改环境文件会影响显式 source 它的当前终端，不会修改启动文件。VS Code 使用配置内的项目环境。通过 FVM 切换同类型 SDK 后，工程命令入口会跟随新链接；跨官方 / 鸿蒙类型切换时需重新运行本脚本更新工具链环境，并重载编辑器窗口。鸿蒙调试还取决于所用 Dart / Flutter 扩展对该适配 SDK 的支持，命令行入口始终保留。

## 第三方物料与同步配置

以下为 **2026-10-23 核对的实现基线**，不是未来版本的“自动兼容”保证。

| 物料 | 本次实现 / 来源 | 同步更新要求 |
| --- | --- | --- |
| 官方 Flutter | [flutter/flutter](https://github.com/flutter/flutter.git)，新工程默认 `stable` 并 pin | 工程 `.fvmrc` 的版本，Dart 约束、插件、iOS / Android 原生依赖需要一起核对 |
| 鸿蒙 Flutter | [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter)，默认 `3.35.7+ohos-1.0.5`；核实 commit `04d2008b35eae67162f0f11d2fd8e2453092c891` | 修改 `Scripts/flutter_workflow.zsh` 的 `JOBS_HARMONY_REPO` / `JOBS_HARMONY_REF`；可在交互中选其它 tag / 分支，运行时再次核实 commit |
| FVM | [官方安装说明](https://fvm.app/documentation/getting-started/installation)，缺失时 `brew install btwld/fvm/fvm`；本机接口验证为 4.3.2 | 旧版需支持 `.fvmrc`、custom SDK、`--skip-setup`、`--skip-pub-get`；安装 / 升级 FVM 不等于安装全局 Flutter |
| Python / Homebrew | [Python](https://www.python.org/)、[Homebrew](https://brew.sh/)；内嵌预检选择 `python@3.13`，最低 3.11 | Python 模块负责安全处理 JSON / 路径。首屏确认后更新 Homebrew 索引，Python 不健康时另行确认安装 / 修复 |
| 鸿蒙 CLT | [SDL 第三方镜像](https://libsdl.org/harmonyos-devtools/commandline-tools-mac-arm64-6.1.1.280.zip)，Mac ARM64 `6.1.1.280` | 版本、URL、大小、SHA-256 必须一起更新，不能只替换 URL |
| CLT 大小 / SHA-256 | `2025336267` 字节；`47d0e558b8285e1452f4d3611863027ec0d1135642761bef23402434e22382d4` | 摘要来自参考工程验证的 **SDL 快照**，不是华为公布的官方摘要 |
| SDK / Node / ohpm / Hvigor / HDC | 复用所选 DevEco / CLT 中的配套物料 | 检查 SDK 的 ETS、native、HDC，以及同包 Node、ohpm、Hvigor；不能用 Android emulator / adb 代替 |
| Java | 优先既有 `JAVA_HOME`，其次 DevEco 随附运行时，再查本机 JDK 17 | 要有 `java` 和 `javac`。CLT 未必包含 JDK；缺失则持续询问已安装 JDK 目录，不擅自修改全局 Java |
| 模拟器系统镜像 | 通过[官方 Emulator CLI](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-command-line)查询 / 下载 Release 镜像 | CLT ZIP **不包含可启动镜像**；许可、账号 / 地区要求由官方处理，下载后必须在本地清单复检 |
| DevEco Studio | [官方下载中心](https://developer.huawei.com/consumer/cn/download/) | 签名、工程原生调试、SDK API 管理仍可能需要完整 Studio；CLT 不替代所有 IDE 能力 |

上游公告已将 Flutter OH 仓库迁移至 CPF-Flutter；旧 `openharmony-sig` / `openharmony-tpc` 地址不作为默认下载源，详见[仓库迁移说明和版本策略](https://gitcode.com/CPF-Flutter/flutter_flutter)。选分支时本次运行也固定到查得的 commit；再次运行选择同分支可能得到新 commit，应查看确认信息。

### 鸿蒙环境变量

这些变量仅写入当前进程及工程配置，不写 `~/.zshrc` / `~/.zprofile`：

| 变量 | 配置 |
| --- | --- |
| `TOOL_HOME` | 所选 DevEco `Contents` 或独立 CLT 根目录 |
| `DEVECO_SDK_HOME`、`HOS_SDK_HOME`、`OHOS_SDK_HOME` | `$TOOL_HOME/sdk` |
| `HDC_HOME` | `$TOOL_HOME/sdk/default/openharmony/toolchains` |
| `JAVA_HOME` | 经 `java` / `javac` 检查的 JDK 目录 |
| 当前 / 工程 `PATH` | 同包 Node、ohpm、Hvigor、HDC 和 JDK 的 bin 目录 |
| `FVM_CACHE_PATH`、`FVM_FLUTTER_URL`、`FVM_USE_GIT_CACHE` | SDK 准备进程使用；与工程 `.fvmrc` 一致，不保存为全局环境变量 |

模拟器定位参数沿用参考脚本：

- `HARMONY_EMULATOR_BIN`：指定官方 Emulator 完整路径。
- `DEVECO_STUDIO_HOME` / `TOOL_HOME`：指定 DevEco `.app`、`Contents` 或 CLT 根目录。
- `HARMONY_CLT_ARCHIVE`：复用本地同版本 ZIP，仍校验大小和 SHA-256。

自动发现标准 DevEco 位置及 `~/Library/Application Support/JobsHarmonySimulator/clt-*`。显式路径错误或多个候选时要求明确选择；健康工具复用，缺失工具新增独立目录，不覆盖旧版本。该集成的鸿蒙准备路径使用 **Apple Silicon 原生 macOS**；Intel Mac 可以使用官方 Flutter 路径，但不使用本脚本的 ARM64 CLT / 本地鸿蒙模拟器路径。

### 下载源、包源与缓存

脚本不修改全局代理、Git 全局配置、`~/.npmrc`、`~/.ohpmrc` 或 Flutter 全局 SDK 配置。不调用 `flutter config --ohos-sdk` 来覆盖其它工程。

- Dart 包默认由 SDK 的 pub 配置处理；显式设置的 `PUB_HOSTED_URL`、`PUB_CACHE` 会保留到工程环境。国内包镜像可按团队要求配置为 `https://pub.flutter-io.cn`。
- `FLUTTER_STORAGE_BASE_URL` 仅在调用方已显式设置时保存。鸿蒙 Engine 和 Dart 产物必须与所选适配版本匹配，不能盲目把官方 Flutter 镜像套给所有鸿蒙版本。默认让所选 SDK 自行决定产物源，不自动删除已有缓存。
- ohpm、npm、Hvigor 的 registry / 插件依赖由所选工具及工程配置决定。如需定制，应按对应版本文档配置项目级 `.npmrc`、`.ohpmrc` 或 Hvigor 配置；不在脚本里统一改用户级 registry。
- Homebrew 自身缺失时仍有独立路径提示：精确 `YES` 选择系统标准目录，其它输入 / 回车选用户目录。**这次 YES 只授权 Homebrew 路径，与 Flutter 全局模式的 YES 相互独立。** 新装 Homebrew 会保存自身 shellenv，已有健康 Homebrew 仅在当前进程激活。

## 鸿蒙模拟器逻辑的复用与维护

来源：`OS@Extension/MacOS@Extension/JobsHarmonySimulatorCreator/Scripts/CreateHarmonySimulator.zsh`，同步日期 2026-10-23。参考来源为本仓上层 OS@Extension 中的同名工程。

已将源码快照放入 `Scripts/vendor/CreateHarmonySimulator.zsh`，运行时不依赖该绝对路径，也不需要安装 Finder 扩展。上游快照 SHA-256：`6d3f23f6eb32c4b045b5c17da82d693dc271d5a45ef31ffcf0881f6efb4957af`。

本地仅改两处集成接口：`main` 改名 `hs_main`；增加“被 source 时不自动运行”的入口判断。工具发现、校验、许可、下载、实例核验和独立 CLT 的 `sdkPath` 修正保持参考实现。对应回归测试复制到 `Tests/CreateHarmonySimulatorTests.rb`，只调整被测脚本路径。

后续参考脚本升级时：同步快照 → 保留上述两个接口调整 → 同步物料常量和本 README → 跑两套回归。不要在两个工程分别修改同一套下载规则却不记录差异。

## 当前配置与失败处理

| 场景 | 当前行为 |
| --- | --- |
| SDK 选择 | 明确 SDK 选择，默认保留已有版本，按目标准备缓存 |
| 工程路径无效 | 路径持续询问，支持 Finder 引号 / 反斜杠转义，不执行路径文本 |
| 路径与设备 JSON | 独立 Python 模块；参数和标准输入传数据 |
| 配置合并 | 备份、合并、JSONC 保留并生成建议文件 |
| 设备发现 | 优先读取 Flutter 的 `targetPlatform`，按当前连接设备选择 |
| Rosetta 转译 | 用 `sysctl.proc_translated` 检查并在任何安装前切换原生 arm64 |
| 阶段执行 | 拆分职责，去除未使用的全量升级路径，错误逐层返回 |
| SDK 下载或绑定失败 | 恢复旧 `.fvmrc` 和 SDK 链接，保留诊断及缓存 |
| 结果判定 | 分别报告环境、doctor、平台目录、依赖、设备与实际运行结果 |

仍需按工程核对的事项：

- 鸿蒙插件适配不是安装 SDK 就会自动完成。检查 `pubspec.yaml` 中每个原生插件的 OH 支持、依赖来源、版本和许可证；脚本不批量替换依赖。
- `compatibleSdkVersion`、`compileSdkVersion`、设备系统 API、Hvigor 插件版本和 Flutter OH 版本必须匹配；最新模拟器镜像不保证适合旧工程。
- 包名、应用签名、开发者账号、真机授权和证书需要在 DevEco / 官方流程中完成；脚本不生成或提交签名秘密，也不替用户接受许可。
- iOS 仍需正确 Xcode、许可、模拟器 runtime 和 CocoaPods；Android 仍需 Android SDK、JDK、许可及设备。`doctor` 的其它平台告警需结合实际目标判断。
- 下载可能占用数 GB 到更多磁盘空间；首次完整克隆鸿蒙 Flutter（含版本历史）、Engine 缓存、CLT 和镜像分别占用空间。

## 日志与验证

主流程阶段日志：`$TMPDIR/JobsFlutterSetup.*/setup.log`；工具自身的详细输出留在终端。鸿蒙工具日志：`$TMPDIR/JobsHarmonySimulator.*/CreateHarmonySimulator.log`。失败保留已有 SDK、工具、镜像、设备及带时间戳的配置备份。

```sh
/bin/zsh -n './【MacOS】⚙️一键配置Flutter项目至运行.command'
/bin/zsh -n Scripts/flutter_workflow.zsh
/bin/zsh -n Scripts/vendor/CreateHarmonySimulator.zsh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
/usr/bin/ruby Tests/CreateHarmonySimulatorTests.rb
```

验证基线（2026-10-23）：主流程 **35 项测试通过**；复用模拟器脚本 **58 组 / 457 个断言通过**；zsh / Python 语法检查及 `git diff --check` 通过。

隔离测试覆盖取消、中断返回码、FVM 元数据与恢复失败、配置类型、入口权限、Git 状态检查、配置块标记，以及真实子进程 Ctrl+C。临时 FVM 绑定测试仅在已有 FVM 时运行。

隔离测试使用临时工程、假的下载 / FVM / Emulator，不安装真实物料。另用本机 FVM 4.3.2 在临时缓存验证 `custom_` SDK 的 `use --skip-setup --skip-pub-get` 能创建正确链接。真实仓库 ref 已通过 `git ls-remote` 核对。该验证范围不包含真实下载 Flutter SDK、CLT 或系统镜像，没有创建真实设备或为真实工程执行构建；实际 HAP 编译、签名与运行仍需在目标工程上验证。
