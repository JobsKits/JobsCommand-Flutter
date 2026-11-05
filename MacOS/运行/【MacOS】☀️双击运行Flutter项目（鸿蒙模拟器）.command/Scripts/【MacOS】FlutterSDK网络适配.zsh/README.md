# Flutter SDK 网络适配

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

由本包入口加载，依赖 macOS 系统 zsh 和相邻的 [网络选路模块](../【MacOS】FlutterSDK网络选路.zsh/README.md)。模块本身只声明函数，不执行安装。

`jobs_command_fvm_runtime` 只为依赖 Flutter Dart shim 的 FVM 先补齐管理器运行时；独立 FVM 和健康缓存直接复用。`jobs_command_sdk` 获取 Dart / 引擎，`jobs_command_sdk_git` 检查原 Git 来源，`jobs_command_sdk_platform` 预下载已选平台。SDK 获取失败持续重试至成功或 Ctrl+C；业务依赖解析、构建和运行由原入口执行一次。源和代理仅作用于下载子进程，显式配置保留，日志沿用调用方 LOG_FILE。

完整复制功能包（含 Scripts）后可移至其他目录，不依赖仓库位置。隔离验证见本包 Tests 中 SDK 网络适配测试，不下载真实 SDK。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
