# ExtractFlutterDependencies.dart

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [一、用途](#jobs-toc-heading-1)
- [二、调用](#jobs-toc-heading-2)
- [三、边界与验证](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

## <span id="jobs-toc-heading-1" data-jobs-toc="v2">一、用途</span><!-- jobs-toc:heading-end -->

供本项目提取入口调用；从 Pub 已解析的本地包路径复制依赖源码并输出清单，不执行依赖解析或联网下载。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">二、调用</span><!-- jobs-toc:heading-end -->

使用已有 Dart SDK 运行同目录 `ExtractFlutterDependencies.dart`，依次传入 `--project <Flutter目录> --destination <输出父目录>`。用户交互及运行环境检查由上层入口负责；该辅助程序保持参数调用协议，错误写入标准错误并返回非零状态。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">三、边界与验证</span><!-- jobs-toc:heading-end -->

只处理调用方指定的目录，拒绝未知输入、目录覆盖和外部或循环符号链接。源码、锁文件及现有许可证按既有实现保存。路径包装后应通过 Dart 解析和临时目录夹具验证；不以语法通过代表真实项目依赖提取已验。

<a id="🔚" href="#" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
