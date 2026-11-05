# 生成的工程SDK入口回归

执行 `python3 test_generated_sdk_launcher.py`。保留真实SDK适配器与重试/once包装，只用替身截断网络准备，SDK与设备均为临时夹具；验证迁移资源、SDK持续获取、取消130、明确平台预缓存、业务仅一次与显式空配置。无真实下载、构建或系统注册。
