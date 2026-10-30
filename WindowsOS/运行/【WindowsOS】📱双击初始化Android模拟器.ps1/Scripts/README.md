# <span id="前言">模拟器入口本地运行依赖</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

`FlutterTools.psm1` 提供本功能入口的参数、确认、日志与派发；`SimulatorSessions.ps1` 提供鸿蒙实例选择、后台启动、SDK 门禁与设备有界等待。

本包只携带实际需要的 `Features/Android`；功能源码及 Common 辅助模块均在本目录，运行不访问仓库外路径。未调用的其它功能定义不会执行。

日志在系统临时目录与当前用户本地数据目录，具体位置由入口打印；`-Check` 只核对本入口所需文件。保留完整功能目录即可复制运行。

[返回功能说明](../README.md)。
