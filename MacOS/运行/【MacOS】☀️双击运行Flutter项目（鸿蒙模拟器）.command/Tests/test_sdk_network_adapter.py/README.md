# Flutter SDK 网络适配隔离验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

通过 Python 标准库 unittest 启动系统 zsh，真实加载本包网络适配和选路模块，仅替换网络探测边界和 SDK 命令，不进行真实下载。

## 一、运行与覆盖

从任意工作目录运行 `python3 -B <本目录>/test_sdk_network_adapter.py`。覆盖失败重新探测、Git 源与 ref、鸿蒙能力及预缓存、取消退出码、父进程环境恢复、带空格中文路径和随包移动。测试只在临时目录写日志与缓存，结束清理自身夹具。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
