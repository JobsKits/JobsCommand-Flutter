# Flutter 旧入口 SDK 前置回归

运行 `python3 test_sdk_entry_frontends.py`。从五个实际旧入口提取真实业务函数，连同随包命令适配器、SDK 重试/once 包装运行；仅物理网络与 SDK/设备/Pods 使用临时夹具。不会下载真实 SDK、构建、修改系统配置或执行真实 CocoaPods。

验证脚本自述头位置、资源可迁移、SDK 自举重试、明确平台预缓存、真实设备 JSON、原业务参数/Java/退出码、FVM 分派和取消阻断。保留原 iOS CocoaPods 恢复设计，SDK 前置取消不得触发此业务恢复。
