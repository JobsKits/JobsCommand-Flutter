# `【MacOS】⚙️import =＞package💣.command`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、功能覆盖](#jobs-toc-heading-2)
- [二、参数与运行](#jobs-toc-heading-3)
- [三、产物、依赖与边界](#jobs-toc-heading-4)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

这是 [**Flutter**](https://flutter.dev/) 项目的 import 修复工具：把实际指向当前项目 `lib/` 的 [**Dart**](https://dart.dev) 相对引用改为 **`package:包名/路径`**。包名读取当前项目的 `pubspec.yaml`，路径按每个引用文件的位置解析。

例如，项目包名为 `my_app`，引用文件位于 `lib/features/home/home_page.dart`：

```dart
// 执行前：目标为 lib/models/user.dart
import '../../models/user.dart';

// 执行后：目标文件保持一致
import 'package:my_app/models/user.dart';
```

| 引用文件 | 原引用 | 转换结果 |
| --- | --- | --- |
| `lib/features/home/home_page.dart` | `../../models/user.dart` | `package:my_app/models/user.dart` |
| `lib/features/home/home_page.dart` | `widgets/header.dart` | `package:my_app/features/home/widgets/header.dart` |
| `test/home_test.dart` | `../lib/features/home/home_page.dart` | `package:my_app/features/home/home_page.dart` |

以上为使用说明示例，各目标文件实际存在时才转换。**先预览逐条计划，精确输入 `YES` 才备份并写入；直接回车、其它输入或输入结束均取消。**

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 校验唯一 `name`、`dependencies.flutter.sdk: flutter` 与普通 `pubspec.yaml` / `lib/`，不接受链接工程。
- 用系统 Perl 做词法扫描，只转换真实 `import` 及其条件 URI；跳过注释、普通字符串中的伪 import，保留引号、BOM、换行和其它正文。
- 按引用文件位置解析相对 URI；只把实际存在且位于本工程 `lib/` 的普通 Dart 目标改为 `package:包名/路径`。
- 跳过第三方、构建/缓存目录、嵌套包、生成文件、链接、多硬链接及明确其他作者声明；不处理 `export` / `part`。
- 逐条展示计划；输入精确 `YES` 才先备份全部原文，再逐文件原子写回。写前检查并发变化，失败仅恢复仍等于工具结果的文件，保留需要人工恢复的现场。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、参数与运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 参数 | 行为 |
| --- | --- |
| `--project 目录` | 明确指定一个 Flutter 工程 |
| `--check` / `--dry-run` | 只读列计划；不写项目、日志、备份，有待转换项仍返回 0 |
| `--help` / `-h` | 查看帮助 |
| 无参数 | 输入/拖入目录，回车使用调用时当前目录 |

```shell
zsh './【MacOS】⚙️import =＞package💣.command' --project './ExampleProject' --check
```

去掉 `--check` 后，先回车查看计划，精确输入 `YES` 才应用。非空首屏输入或 `Ctrl+C` 可取消；无交互终端只允许只读/帮助模式。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、产物、依赖与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

仅依赖系统已有 `/usr/bin/perl` 与标准模块，不联网安装 Homebrew、Flutter SDK 或其它工具。普通运行在系统临时目录创建独立 `jobs-flutter-imports.*`，日志为 `imports.log`，备份按工程相对路径存入其中 `backup/`。只读模式不创建这些文件。

URI 包含不可安全解析的片段、目标缺失或位于 `lib/` 外时保留；不改路径本身，不移动文件，也不保证所有 Dart 语言特性均受支持。变更后检查计划中的 `package:` 路径确实可解析，再运行当前工程分析与构建。

返回码：`0` 表示完成、无需修改、只读预览或用户取消；`1` 表示校验/执行失败；`2` 表示参数错误。因此不能只凭返回 0 推断发生了转换，应核对摘要里的转换文件数。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
