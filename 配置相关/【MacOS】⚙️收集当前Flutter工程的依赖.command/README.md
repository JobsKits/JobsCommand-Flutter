# `【MacOS】⚙️收集当前Flutter工程的依赖.command`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#jobs-toc-heading-1)
- [一、适用场景](#jobs-toc-heading-2)
- [二、目录结构](#jobs-toc-heading-3)
- [三、执行前检查](#jobs-toc-heading-4)
- [四、运行方式](#jobs-toc-heading-5)
  - [4.1、双击运行](#jobs-toc-heading-6)
  - [4.2、终端运行](#jobs-toc-heading-7)
  - [4.3、参数说明](#jobs-toc-heading-8)
- [五、执行流程](#jobs-toc-heading-9)
- [六、压缩包内容](#jobs-toc-heading-10)
- [七、交互与风险说明](#jobs-toc-heading-11)
- [八、日志文件](#jobs-toc-heading-12)
- [九、常见问题](#jobs-toc-heading-13)
  - [9.1、提示未找到 Flutter](#jobs-toc-heading-14)
  - [9.2、提示缺少 package\_config.json](#jobs-toc-heading-15)
  - [9.3、--select 无法使用](#jobs-toc-heading-16)
- [十、验证边界](#jobs-toc-heading-17)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">🔥 <font id=前言>前言</font></span><!-- jobs-toc:heading-end -->

`【MacOS】⚙️收集当前Flutter工程的依赖.command` 用于收集当前 [**Flutter**](https://flutter.dev/) / [**Dart**](https://dart.dev) 工程已经解析到的依赖源码、原生依赖和关键清单文件，并在 MacOS 桌面生成带时间戳的 Zip 压缩包。

脚本只读取依赖和工程配置，不会自动执行 `pod install`，也不会复制整个 `~/.gradle/caches`。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、适用场景 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 归档当前工程实际使用的 Dart / Flutter 包源码。
- 携带工程现有的 [**CocoaPods**](https://cocoapods.org/) `Pods`、SwiftPM 输出和依赖锁定文件。
- 排查离线环境、依赖版本或本地路径包问题。
- 使用 [**fzf**](https://formulae.brew.sh/formula/fzf) 从依赖清单中多选部分 Dart / Flutter 包。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、目录结构 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```text
【MacOS】⚙️收集当前Flutter工程的依赖.command/
├── 【MacOS】⚙️收集当前Flutter工程的依赖.command
└── README.md
```

脚本与 `README.md` 必须保持在同一目录。双击脚本后会先展示本文件，按回车才会继续，按 `Ctrl+C` 可以取消。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、执行前检查 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 系统必须是 MacOS，并可使用系统命令 `zsh`、`rsync` 和 `ditto`。
- 工程根目录必须存在 `pubspec.yaml`。
- 必须能找到一种 Flutter 命令，优先级如下：

  1. 工程内 `.fvm/flutter_sdk/bin/flutter`。
  2. [**fvm**](https://fvm.app) 管理的 `fvm flutter`。
  3. 环境变量中的全局 `flutter`。

- 必须存在 [**Ruby**](https://www.ruby-lang.org)，用于解析 `.dart_tool/package_config.json`。
- 使用 `--select` 时必须提前安装 `fzf`：

  ```shell
  brew install fzf
  ```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

### <span id="jobs-toc-heading-6" data-jobs-toc="v2">4.1、双击运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在 Finder 中双击 `【MacOS】⚙️收集当前Flutter工程的依赖.command`。脚本会从自身目录向上查找 `pubspec.yaml`；如果没有找到，会提示输入或拖入 Flutter 工程根目录。

### <span id="jobs-toc-heading-7" data-jobs-toc="v2">4.2、终端运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```shell
cd "~/Downloads/【MacOS】⚙️收集当前Flutter工程的依赖.command"
./【MacOS】⚙️收集当前Flutter工程的依赖.command
```

### <span id="jobs-toc-heading-8" data-jobs-toc="v2">4.3、参数说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 参数 | 作用 |
| --- | --- |
| `<path-to>/app` | 指定 Flutter / Dart 工程根目录 |
| `-s`、`--select` | 使用 `fzf` 多选 Dart / Flutter 依赖 |
| `--no-pub-get` | 不询问执行 `flutter pub get`，直接使用现有解析文件 |
| `-h`、`--help` | 显示命令行帮助 |

示例：

```shell
./【MacOS】⚙️收集当前Flutter工程的依赖.command "<flutter-root>_app"
./【MacOS】⚙️收集当前Flutter工程的依赖.command --select "<flutter-root>_app"
./【MacOS】⚙️收集当前Flutter工程的依赖.command --no-pub-get "<flutter-root>_app"
```

## <span id="jobs-toc-heading-9" data-jobs-toc="v2">五、执行流程 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

```mermaid
flowchart TD
    A[展示 README 并等待确认] --> B[定位 pubspec.yaml]
    B --> C[选择 FVM 或全局 Flutter]
    C --> D{是否主动执行 pub get}
    D -->|执行| E[刷新 package_config.json]
    D -->|跳过| F[复用现有 package_config.json]
    E --> G[提取实际依赖根目录]
    F --> G
    G --> H{是否启用 fzf 多选}
    H -->|是| I[生成选中依赖清单]
    H -->|否| J[使用完整依赖清单]
    I --> K[复制依赖与工程清单]
    J --> K
    K --> L[使用 ditto 生成桌面 Zip]
```

## <span id="jobs-toc-heading-10" data-jobs-toc="v2">六、压缩包内容 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 目录 | 内容 |
| --- | --- |
| `dart_packages/` | `.dart_tool/package_config.json` 实际解析到的包源码 |
| `native/` | 工程现有的 Pods、旧版插件 symlink 和 SwiftPM 输出 |
| `project_files/` | `pubspec.yaml`、锁定文件、Podfile、Gradle 声明等 |
| `manifest/` | 包清单、Flutter 版本、`pub deps` 输出与复制路径映射 |

压缩包默认输出到：

```text
~/Desktop/工程名_flutter_deps_时间戳.zip
```

## <span id="jobs-toc-heading-11" data-jobs-toc="v2">七、交互与风险说明 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- `flutter pub get` 可能更新 `.dart_tool` 和依赖解析结果，因此不会默认执行：直接回车跳过，输入任意字符后回车才执行。
- 如果跳过 `flutter pub get`，工程必须已经存在 `.dart_tool/package_config.json`，否则脚本会停止并给出提示。
- 脚本可能复制大量依赖文件，压缩耗时和结果体积取决于工程规模及现有 `Pods`、SwiftPM 输出。
- 临时目录仅创建在 `$TMPDIR` 下，脚本退出时只清理本次创建的临时目录。
- 不执行 `pod install`，不复制整个 Gradle 缓存，不修改依赖源码。

## <span id="jobs-toc-heading-12" data-jobs-toc="v2">八、日志文件 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

终端输出会同步写入：

```text
$TMPDIR/pack_flutter_deps_macos.log
```

脚本每次启动都会清空旧日志。失败时优先查看日志中的 `✖` 错误信息和对应路径。

## <span id="jobs-toc-heading-13" data-jobs-toc="v2">九、常见问题 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

### <span id="jobs-toc-heading-14" data-jobs-toc="v2">9.1、提示未找到 Flutter <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

确认工程内 FVM SDK、系统 `fvm` 或全局 `flutter` 至少有一种可用：

```shell
flutter --version
fvm flutter --version
```

### <span id="jobs-toc-heading-15" data-jobs-toc="v2">9.2、提示缺少 package_config.json <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

重新运行脚本，在询问 `flutter pub get` 时输入任意字符后回车执行；也可以先在工程目录手动运行：

```shell
flutter pub get
```

### <span id="jobs-toc-heading-16" data-jobs-toc="v2">9.3、`--select` 无法使用 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

确认 `fzf` 已安装并能被当前终端找到：

```shell
command -v fzf
```

## <span id="jobs-toc-heading-17" data-jobs-toc="v2">十、验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

脚本可以通过 `zsh -n` 做静态语法检查；依赖复制和压缩结果仍应在目标 Flutter 工程中实际运行后确认。本说明不代表已经对任意具体工程执行过真实打包。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
