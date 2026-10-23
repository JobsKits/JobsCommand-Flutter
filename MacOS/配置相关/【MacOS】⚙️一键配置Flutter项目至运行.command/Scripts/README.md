# `Flutter 配置运行 / Scripts`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、职责与调用](#jobs-toc-heading-2)
- [二、输入输出与边界](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录承载[主入口](../README.md)的工程配置、SDK 绑定、工具准备与设备运行模块。日常使用主入口完成确认与编排，分发时保留本目录，不从其它仓库动态读取实现。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、职责与调用 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 文件 | 当前职责 |
| --- | --- |
| [flutter_workflow.zsh](./flutter_workflow.zsh) | 选择工程、官方/鸿蒙 SDK、项目 FVM 或显式全局模式；检查依赖、准备平台与设备，运行工作流；被 source 时只定义函数 |
| [project_config.py](./project_config.py) | 读取/校验 JSON 和路径；生成工程环境、编辑器配置与启动器；备份/恢复 FVM 绑定；从标准输入筛选设备 |
| [vendor/CreateHarmonySimulator.zsh](./vendor/CreateHarmonySimulator.zsh) | 随包鸿蒙模拟器快照，提供工具/镜像发现、许可、实例创建与启动；由工作流调用 |

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入输出与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

工程根目录由主入口校验，须有 `pubspec.yaml` 与 `lib/`。SDK 默认通过 [**FVM**](https://fvm.app) 仅绑定工程；全局模式另需精确 `YES`。工具依赖、版本、下载来源、许可和真实设备限制见[主说明](../README.md)。

[**Python**](https://www.python.org) 模块接受明确 action 与参数（`current`、`fvm`、`runtime`、`profile`、`binding-save`、`binding-restore`、`devices`），数据通过参数或标准输入传递；它是内部调用接口，不单独替代主入口授权。配置输出位于目标工程的 `.fvmrc`、`.jobs-flutter/`、`.vscode/` 与 `.gitignore`；已有配置写前留备份，不能安全解析时保留原文件。

`profile` 会持久修改调用方授权的 Shell 配置；`runtime` 生成工程专属环境与启动器，不能把它当全局环境配置器。检查结果需分别核对 SDK、doctor、依赖、设备与实际 App 运行，缺工具或创建成功均不代表已构建运行。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
