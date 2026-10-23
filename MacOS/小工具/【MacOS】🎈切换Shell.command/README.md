# `【MacOS】🎈切换Shell.command`

为 **macOS 桌面空白处**和 **Finder 打开的文件夹空白处**添加原生右键菜单 **「🎈 切换 Shell…」**。点击后在系统终端使用 **fzf 模糊搜索选择**当前用户的默认登录 Shell，输入 `YES` 确认后才调用 `chsh`。

此功能修改的是当前用户的默认登录 Shell，与右键所在目录无关。已打开的终端不受影响；Terminal 若配置了自定义启动命令，应同时检查其设置。

## 安装和使用

双击 `【MacOS】🎈切换Shell.command`，选择 `1` 安装 / 更新右键菜单；选择 `2` 可以直接切换 Shell。

也可以在本目录运行：

```zsh
./【MacOS】🎈切换Shell.command --install-finder-menu
```

安装到 `~/Applications/JobsShellSwitcher.app`，仅作用于当前用户。安装过程不修改默认 Shell，不调用 `sudo`，不自动安装或升级 Homebrew / fzf，不更新其它软件，也不强制重启 Finder。

完成后，在桌面或 Finder 文件夹**空白区域**右键，点击 **🎈 切换 Shell…**，在 fzf 中输入关键字筛选、用上下方向键移动、按 Enter 选中，再输入 `YES` 确认。fzf 中按 Esc / Ctrl+C 取消；确认时回车、输入结束或未输入 `YES` 均取消修改。选择当前默认 Shell 不会重复执行 `chsh`。系统可能要求输入当前账户密码，由 `chsh` 在终端处理。

每次打开 fzf，都会重新读取账户的当前默认 Shell，将它去重后放到初始列表第一项并默认选中，**不搜索、不移动选择而直接回车，就保持当前默认设置**。筛选结果保持输入顺序；只有主动选择其它 Shell 并输入 `YES` 才会修改。无法读取当前默认 Shell，或它不在系统允许列表中时停止，不回退到其它默认选择。

## 菜单覆盖范围

| 位置 | 行为 |
| --- | --- |
| 桌面空白处 | 显示「🎈 切换 Shell…」 |
| Finder 普通文件夹空白处 | 显示同一入口，支持中文、空格等目录名 |
| 已挂载的外置磁盘或网络卷中的文件夹 | 注册卷根目录，新挂载时刷新覆盖范围 |
| 文件 / 文件夹图标、侧边栏右键 | 不额外添加此入口 |
| 最近使用、搜索结果等虚拟视图或第三方文件管理器 | 由系统 / 应用决定，不保证出现 |

通过 Finder Sync 的 `contextualMenuForContainer` 接口提供空白处菜单，注册 `/`、当前用户桌面与已挂载卷。扩展不递归扫描文件，不添加角标。右键操作不传入文件路径，因此不会把目录名拼接为 Shell 命令。参见 [Apple 的菜单接口说明](https://developer.apple.com/documentation/findersync/fimenukind/contextualmenuforcontainer?language=objc)和[管理目录说明](https://developer.apple.com/documentation/findersync/fifindersynccontroller/directoryurls)。

## 依赖与启用

- Shell 选择器需要 fzf。本机已有安装时直接复用，优先查找 PATH，然后查找 Apple Silicon / Intel Homebrew、用户目录 Homebrew 和 `~/.fzf/bin/fzf`。缺少时提示安装，例如 `brew install fzf`；不退回编号选择。
- macOS 10.15 或更高版本；安装时需要 Xcode 或 Command Line Tools 中的 `clang` 与 macOS SDK。缺失时先运行 `xcode-select --install`，完成后重新安装。
- 安装器为当前机器架构编译，默认使用本机 ad-hoc 签名，不需要开发者账号。生成的 App 供本机使用；跨机器分发应另行处理签名和公证。
- 若系统需要用户启用扩展，在“系统设置”中搜索“扩展”，找到 Finder 扩展并启用“切换 Shell”。不同 macOS 版本的设置位置可能不同。
- 如菜单尚未出现，先关闭右键菜单再重新打开，或新开一个 Finder 窗口；必要时退出登录后重新登录。受管设备仍须遵守其系统策略。
- 安装包包含切换脚本副本，安装后移动或删除源码目录不影响右键入口。修改源码后需重新运行安装才能更新已安装版本。

## 管理命令

```zsh
# 查看安装和启用状态；pluginkit 的 + 表示启用，- 表示停用
./【MacOS】🎈切换Shell.command --finder-menu-status

# 不安装菜单，直接运行 Shell 选择器
./【MacOS】🎈切换Shell.command --switch-shell

# 仅卸载本工具的菜单和 App，不恢复或改动账户默认 Shell
./【MacOS】🎈切换Shell.command --uninstall-finder-menu

# 帮助
./【MacOS】🎈切换Shell.command --help
```

Shell 选择器只列出 `/etc/shells` 中存在且可执行的文件；执行前再次校验允许列表。`chsh` 返回失败或修改后读取的 `UserShell` 不匹配时，报告失败，不显示成功。日志保存到 `${TMPDIR:-/tmp}/JobsShellSwitcher.log`，不记录密码。

## 源码与验证

- `【MacOS】🎈切换Shell.command`：命令入口、fzf 模糊搜索选择、确认和账户结果核验。
- `FinderMenu/FinderSync.m`：桌面 / Finder 空白处菜单和挂载卷覆盖。
- `FinderMenu/Launcher.m`：定位内置脚本并交由系统 Terminal 打开。
- `FinderMenu/install.zsh`：暂存编译、签名校验、安装更新、注册、状态查询和卸载。安装替换失败时恢复旧 App；同名非本工具应用不会被覆盖。
- `tests/shell_switcher.zsh`：使用替身验证 fzf 取消 / 故障 / 非法输出、确认取消、非法目标、重复选择、`chsh` 失败、结果核验和成功路径，**不执行真实账户修改**。

```zsh
/bin/zsh -n ./【MacOS】🎈切换Shell.command
/bin/zsh -n FinderMenu/install.zsh
/bin/zsh tests/shell_switcher.zsh
```

端到端验证应包含桌面右键、普通文件夹空白处右键、点击后显示 fzf Shell 选择器，以及取消后账户默认 Shell 保持不变。
