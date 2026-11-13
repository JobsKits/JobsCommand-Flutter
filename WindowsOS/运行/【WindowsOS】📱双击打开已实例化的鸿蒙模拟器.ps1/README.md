# `【WindowsOS】📱双击打开已实例化的鸿蒙模拟器.ps1`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、使用与支持范围](#jobs-toc-heading-2)
- [二、确认、副作用与日志](#jobs-toc-heading-3)
- [三、交付与验证边界](#jobs-toc-heading-4)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

仅列出并启动已有鸿蒙实例，不下载工具或镜像、不创建设备。空列表明确提示先初始化，取消不启动。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、使用与支持范围 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

双击同名 `.cmd`，或用 PowerShell 5.1+ 执行 `.ps1`；`Scripts/` 是完整本地运行快照，单独复制该功能目录时一并保留。

最低支持 Windows 10 64 位（x64），具体最低 build 未锁定；鸿蒙与 Android 模拟器不支持 Windows ARM / 32 位，x64 实机仍需单独验收。

`-Plan` 展示计划；`-Check` 只核对路径与随包模块，不调用 SDK。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、确认、副作用与日志 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

先展示固定自述，再回车确认；非空输入 / Ctrl+C / Esc 取消。列表优先使用 [**fzf**](https://formulae.brew.sh/formula/fzf) 上下选择与输入筛选。初始化流程可能下载数 GB 镜像、写入本用户工具缓存和新增实例；不会删除或覆盖现有设备，不改系统代理、全局 Flutter 或项目 FVM。

[**Android**](https://developer.android.com) 使用官方 SDK 仓库与 Adoptium JDK；[**HarmonyOS**](https://developer.huawei.com/consumer/cn/) 工具来源与许可在实际操作前展示。打开已有鸿蒙实例入口只查询与启动，工具缺失直接停止。运行 [**Flutter**](https://flutter.dev/) 可更新项目依赖和构建缓存，签名与插件兼容性沿用工程。日志精确位置由终端打印，macOS 位于系统临时目录，Windows 入口使用临时 Transcript，工具日志位于当前用户本地数据目录。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、交付与验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

完整功能目录可复制、改名后从其它工作目录执行；运行所需代码全部随包携带。静态语法和假工具回归不代表真实 SDK 下载、镜像创建、设备运行或 Windows 桌面已验收。

[返回运行目录](../README.md)。



<!-- JOBS_TERMINAL_STYLE_V1:BEGIN -->

> Windows 终端配色保护：支持完整颜色查询的交互控制台会先保存当前会话默认前景、背景与16色色表，再临时使用黑底白字和统一强调色；正常结束、业务失败及可捕获中断后恢复。用户运行中自行改动的颜色保留并提示，不修改用户主题、共享 Profile、注册表或全局策略。快照不包含进入前任意叠加的临时文字样式。非控制台、重定向、`NO_COLOR`、Sourcetree 及无法可靠保存／恢复颜色的环境保持原状态或降级为纯文本。

> `.cmd`／`.bat` 入口内嵌完整会话守护：黑底白字及强调色保护就绪或明确降级后才开始业务，全部退出路径同步等待恢复回执；同时核对父进程身份。原 PowerShell／Python 启动命令和业务参数不经过再次解析，保护初始化后恢复进入时的延迟扩展模式，原业务自己的 `setlocal` 保留；嵌套 PowerShell 复用同一会话保护。守护脚本只写入本轮系统临时目录，成功恢复后清理控制文件。

> 强制结束进程或终端崩溃无法保证自动恢复。恢复失败时保留并提示本轮 `%TEMP%\JobsTerminalStyle-<PID>-*.ps1` 恢复脚本，需在原控制台核对后运行；不要通过重置用户配置恢复。`-ExecutionPolicy Bypass` 如被入口使用，仅作用于本次子进程，不持久修改策略。

> 验证范围：已完成 PowerShell 语法、参数／退出与隔离生命周期核验；Windows 原生控制台的显示、按键与 `Ctrl+C` 实机验证尚未完成。

<!-- JOBS_TERMINAL_STYLE_V1:END -->

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
