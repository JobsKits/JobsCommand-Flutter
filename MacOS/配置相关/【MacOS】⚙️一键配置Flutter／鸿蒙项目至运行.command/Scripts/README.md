# Flutter／鸿蒙配置运行模块

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、模块职责](#modules)
- [二、模拟器快照与运行边界](#simulator)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录只服务[主入口](../【MacOS】⚙️一键配置Flutter／鸿蒙项目至运行.command)，请保留整个包。固定使用鸿蒙适配 [**Flutter**](https://gitcode.com/CPF-Flutter/flutter_flutter) 与工程级 [**FVM**](https://fvm.app)；Homebrew / Python 预检完整封装在主脚本内。

## 一、<span id="modules">模块职责</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

| 文件 | 职责与入口 |
| --- | --- |
| [harmony_workflow.zsh](./harmony_workflow.zsh) | 仅供主入口加载；工程选择、鸿蒙 SDK ref 核实、FVM 原子绑定与失败恢复、构建工具检查、依赖准备和设备运行。 |
| [project_config.py](./project_config.py) | [**Python**](https://www.python.org/) 3.11+ 标准库模块；安全合并配置、留存备份、恢复绑定、生成工程命令入口和解析设备 JSON。 |
| [CreateHarmonySimulator.zsh](./CreateHarmonySimulator.zsh) | 用户指定参考核心快照；独立可运行，也可由 workflow 加载以发现 / 下载 CLT、准备镜像、核验并创建实例。 |

配置模块由 workflow 传入参数，不把工程路径或 JSON 拼成源码。仅供加载的 workflow 不单独运行，不在加载时安装或读写工程。

## 二、<span id="simulator">模拟器快照与运行边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

模拟器使用 [**DevEco 官方 Emulator CLI**](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-command-line)，本地模拟器限 Apple Silicon Mac。依赖 macOS 自带 zsh、JXA、curl、unzip、shasum；CLT 从固定 SDL 第三方镜像取得且核对大小 / 摘要，系统镜像由官方工具处理。

独立使用时仍先显示内置自述，创建入口回车授权；许可单独展示原文并由本人同意：

```shell
/bin/zsh './CreateHarmonySimulator.zsh' --help
/bin/zsh './CreateHarmonySimulator.zsh' --check
/bin/zsh './CreateHarmonySimulator.zsh' --prepare
```

此处模拟器 `--check` 会执行只读 CLI 查询，与主入口不执行候选工具的离线 `--check` 范围不同。`--prepare` 会准备工具及镜像，不创建实例。具体物料、环境变量、项目文件、日志及取消恢复边界见[包说明](../README.md)。

参考升级时对照业务差异，保留 `hs_main` 和被 source 时不自动运行的接口，并同步固定下载信息、README 和两套隔离回归。主流程日志与运行原始终端记录在系统临时目录 `JobsFlutterHarmonySetup.*`；模拟器日志在 `JobsHarmonySimulator.*`。不为验证执行真实安装、创建或签名构建。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
