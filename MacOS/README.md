# <span id="前言">MacOS Flutter 脚本</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、用途与入口](#jobs-toc-heading-1)
- [二、平台边界与风险](#jobs-toc-heading-2)
- [三、对照与验证](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、用途与入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

本目录提供 Flutter SDK/FVM、工程配置、依赖、设备运行、打包、录屏和维护功能。先按下方分类选择入口，再阅读脚本包中的 README。

| 分类 | 功能 |
| --- | --- |
| 打包相关 | [查看当前能力](<./打包相关/README.md>) |
| 小工具 | [查看当前能力](<./小工具/README.md>) |
| 屏幕录制 | [查看当前能力](<./屏幕录制/README.md>) |
| 配置相关 | [查看当前能力](<./配置相关/README.md>) |
| 运行 | [查看当前能力](<./运行/README.md>) |
| 更新升级 | [查看当前能力](<./更新升级/README.md>) |
| Cocoapods | [查看当前能力](./Cocoapods/README.md) |

运行目录包含独立 Android 初始化、鸿蒙初始化、已有鸿蒙实例打开与 Flutter 鸿蒙模拟器运行入口；完整功能包可单独复制，后端随包携带。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、平台边界与风险 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

需要 macOS 对应开发工具；iOS 模拟器、Xcode、CocoaPods、Homebrew 与 Gatekeeper 脚本保留在本端。脚本会先显示内置自述；按其确认提示决定是否继续。不同入口可能安装工具、下载依赖、修改项目配置、清理产物或启动设备，日志位置以该脚本实际输出为准。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、对照与验证 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

Windows 对应能力和排除项见 [双端映射](../WindowsOS/README.md)。脚本的静态语法检查与辅助测试不代表目标设备运行通过。真实工具安装、设备运行和构建需要在目标工程另行验收。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
