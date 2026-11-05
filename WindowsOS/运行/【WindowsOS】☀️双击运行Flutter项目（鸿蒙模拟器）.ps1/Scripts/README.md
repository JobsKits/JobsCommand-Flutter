# <span id="前言">模拟器入口本地运行依赖</span>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

`FlutterTools.psm1` 提供本功能入口的参数、确认、日志与派发；`SimulatorSessions.ps1` 提供鸿蒙实例选择、后台启动、SDK 门禁与设备有界等待。

本包只携带实际需要的 `Features/Harmony / Packager`；功能源码及 Common 辅助模块均在本目录，运行不访问仓库外路径。未调用的其它功能定义不会执行。

日志在系统临时目录与当前用户本地数据目录，具体位置由入口打印；`-Check` 只核对本入口所需文件。保留完整功能目录即可复制运行。

[返回功能说明](../README.md)。

**Flutter SDK网络预检：** 下载／首次Dart自举／precache前，随包网络模块以真实小Range验证来源、TLS、字节和吞吐并择优；显式storage、Pub和代理（含空值）保留，AUTO仅核验官方／CFUG同对象及当前已配置代理，不猜端口、不改系统代理或Git。当前任务短期复用；真实获取失败会降权坏路线、轮换其它已验证候选并持续重试。FVM按实际api context来源处理，能力允许时Git与Dart制品分阶段；用户fork不改源。原生BITS按真实WinINET通道衡量，PAC未能有界解析时保留既有通道并明确未测速。详细边界见[随包选路模块](./SdkDownloadRoute.ps1/README.md)。
