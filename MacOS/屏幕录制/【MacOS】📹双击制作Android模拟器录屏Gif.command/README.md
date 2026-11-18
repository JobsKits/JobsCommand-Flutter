# `【MacOS】📹双击制作Android模拟器录屏Gif.command`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、功能覆盖](#jobs-toc-heading-2)
- [二、输入、选项与产物](#jobs-toc-heading-3)
- [三、运行方式](#jobs-toc-heading-4)
- [四、风险与能力边界](#jobs-toc-heading-5)
- [五、日志与核对](#jobs-toc-heading-6)
- [六、运行规则补充（脚本统一）](#jobs-toc-heading-7)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

录制 [**Android**](https://developer.android.com) 设备、分段视频并可转 GIF。入口：[同名脚本](<./【MacOS】📹双击制作Android模拟器录屏Gif.command>)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、功能覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 通过 adb 选择设备。
- 支持定时或交互停止。
- 超过单段上限时分段。
- 可用 [**FFmpeg**](https://ffmpeg.org) 合并。
- 选择片段后用 [**gifski**](https://gif.ski) 转 GIF。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输入、选项与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 项目 | 当前行为 |
| --- | --- |
| 输入与默认值 | -d 秒数；-i 交互；-s 分辨率；-b 比特率默认 8000000；-o 输出目录默认桌面；-S 设备；-m 合并；-h 帮助 |
| 输出与作用位置 | 所选目录中的 MP4、可选合并视频和 GIF |
| 依赖 | adb、[**Android**](https://developer.android.com) screenrecord、[**fzf**](https://formulae.brew.sh/formula/fzf)；合并/转换需 [**FFmpeg**](https://ffmpeg.org) 与 [**gifski**](https://gif.ski) |

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、运行方式 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本 README 所在目录打开终端，也可双击同名 `.command`。先阅读内置自述，确认显示的目标再继续；`Ctrl+C` 可取消。

```shell
zsh './【MacOS】📹双击制作Android模拟器录屏Gif.command'
```

定时录屏示例：

```shell
zsh './【MacOS】📹双击制作Android模拟器录屏Gif.command' -d 30 -b 8000000 -o './Recordings'
```

## <span id="jobs-toc-heading-5" data-jobs-toc="v2">四、风险与能力边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

设备临时视频使用 /sdcard/tmp_record.mp4 并清理；单段限制 180 秒。先确认设备序列号和目标文件，音频不在此入口能力范围。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">五、日志与核对 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

运行状态输出到终端；日志由脚本的 `LOG_FILE` 指定，通常位于系统临时目录、以脚本名去扩展名后加 `.log` 命名。部分业务阶段会重新设置日志，请以实际回显为准。

完成后核对：所选目录中的 MP4、可选合并视频和 GIF。核对实际目标、终端输出和退出状态；发现错误时保留日志，先确认停止阶段与现存产物再重试。

**终端配色保护：** 独立运行时，在支持完整保存与恢复配色的交互终端中临时使用黑底白字及统一强调色；正常结束、失败或可捕获中断后恢复进入前的配色，不修改终端全局偏好或 Shell 启动配置。不支持完整保护、无交互终端、`NO_COLOR`、既有纯文本模式和 Sourcetree 场景不切换配色，并沿用纯文本输出约定。强制终止（如 `kill -9`）无法由脚本自身保证恢复，请使用运行时显示的独立恢复入口。

## <span id="jobs-toc-heading-7" data-jobs-toc="v2">六、运行规则补充（脚本统一） <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

本轮按所选职责准备必要依赖；健康工具直接复用，缺失/损坏才条件获取并刷新当前进程路径后复检。临时网络失败持续重试，Ctrl+C/EOF 或确定的本地、版本、许可错误停止；只读、未选及卸载不因检查触发安装。原生GUI安装、系统权限、目标SDK构建与设备流程尚待对应系统实机验证。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
