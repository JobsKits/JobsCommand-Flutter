# shell: zsh
# 脚本自述：
# - 脚本名称：【MacOS】FlutterSDK网络适配.zsh
# - 核心用途：把本包 SDK 获取接入临时网络检测及持续重试。
# - 影响范围：子进程下载源、缓存与操作日志；不改系统网络。
# - 运行提示：由已确认的业务入口 source，Ctrl+C 结束当前获取。
# SDK 网络只作用于本次子进程；业务调用方在 SDK 就绪后单独执行。
typeset -g JOBS_COMMAND_SDK_MODULE="${${(%):-%x}:A:h:h}/【MacOS】FlutterSDK网络选路.zsh/【MacOS】FlutterSDK网络选路.zsh"
jobs_command_sdk_load() {
  (( $+functions[jobs_flutter_sdk_retry] )) && return 0
  [[ -r "$JOBS_COMMAND_SDK_MODULE" ]] || { print -u2 -r -- "缺少随包 SDK 网络模块：$JOBS_COMMAND_SDK_MODULE"; return 1; }
  source "$JOBS_COMMAND_SDK_MODULE"
}
jobs_command_sdk() {
  local title="$1" sdk="$2" version="$3" sdk_log="${LOG_FILE:-}"; shift 3
  jobs_command_sdk_load || return $?
  [[ -n "$sdk_log" ]] || sdk_log="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/JobsFlutterSdkNetwork.XXXXXX")" || return 1
  JOBS_SDK_LOG_REPLACED=0 JOBS_FLUTTER_ROUTE_CAPTURE_OUTPUT=1 jobs_flutter_sdk_retry "$title" "$sdk_log" "$sdk" "$version" "$@"
}
# Git 预检只报告原仓库连通性；源码落地后的 Dart / 引擎另行测路。
jobs_command_sdk_git() {
  JOBS_FLUTTER_ROUTE_MODE=git JOBS_FLUTTER_ROUTE_SOURCE_URL="$JOBS_SDK_REPO" \
    JOBS_FLUTTER_ROUTE_GIT_REF="${JOBS_SDK_GIT_REF:-HEAD}" jobs_command_sdk "$@"
}
jobs_command_sdk_platform() {
  local sdk="$1" version="$2" flutter="$3" platform="$4" help_text=""
  if [[ "$platform" == ohos ]]; then
    help_text="$("$flutter" precache --help)" || return $?
    print -r -- "$help_text" | /usr/bin/grep -Eq -- '--(\[no-\])?ohos' || {
      print -u2 -r -- '当前适配 SDK 未确认支持 precache --ohos；请使用支持此命令的 SDK。'; return 1
    }
  fi
  JOBS_FLUTTER_ROUTE_MODE=platform jobs_command_sdk "Flutter $platform 平台资源" "$sdk" "$version" "$flutter" precache "--$platform"
}
# 仅Pub式FVM实际依赖的Flutter Dart shim需要先补齐，独立FVM不引入联网。
jobs_command_fvm_runtime() {
  local sdk_log="${LOG_FILE:-}"
  jobs_command_sdk_load || return $?
  [[ -n "$sdk_log" ]] || sdk_log="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/JobsFvmRuntime.XXXXXX")" || return 1
  JOBS_SDK_LOG_REPLACED=0 jobs_flutter_fvm_runtime 'FVM 管理器 Dart 运行时' "$sdk_log" "$1"
}
