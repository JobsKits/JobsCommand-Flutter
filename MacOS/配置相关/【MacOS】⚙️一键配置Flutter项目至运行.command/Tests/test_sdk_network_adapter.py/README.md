# Flutter SDK 网络适配隔离验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

通过 Python 标准库 unittest 启动系统 zsh，真实加载本包网络适配和选路模块，仅替换网络探测边界和 SDK 命令，不进行真实下载。

## 一、运行与覆盖

从任意工作目录运行 `python3 -B <本目录>/test_sdk_network_adapter.py`。覆盖失败重新探测、Git 源与 ref、鸿蒙能力及预缓存、取消退出码、父进程环境恢复、带空格中文路径和随包移动；工作流另覆盖失败 Git 尝试的 stdout 隔离及已有冲突缓存立即停止。测试只在临时目录写日志与缓存，结束清理自身夹具。

<!-- jobs-language-terminal-style-v1 -->

**终端配色保护：** `test_sdk_network_adapter.py` 直接运行时，在可可靠保存与恢复配色的交互终端中临时使用黑底白字和统一强调色；正常退出、失败及可捕获中断后恢复进入前的配色，保留原业务清理和退出状态。导入本文件不接管终端；无法可靠保护、纯文本模式或无交互终端时按纯文本约定降级。运行中另行修改的颜色会保留并报告冲突，强制终止后可按运行提示使用独立恢复入口。 模块启动等无法安全重复初始化的场景不重启原程序。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
