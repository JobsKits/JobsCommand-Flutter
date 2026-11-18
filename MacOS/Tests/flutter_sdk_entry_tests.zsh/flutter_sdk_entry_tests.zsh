#!/bin/zsh
# 脚本自述：仅提取五个Jobs入口的SDK调用函数，验证参数和失败传播；不运行主流程或真实SDK。
setopt NO_NOMATCH
MAC_ROOT="${${(%):-%x}:A:h:h:h}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp/}JobsCommandSdkEntry.XXXXXXXX")" || exit 1
TEST_FAILURES=0
TEST_COUNT=0
# 测试退出或取消时回收本用例拥有的临时夹具。
TRAPEXIT() { (( ZSH_SUBSHELL == 0 )) || return 0; [[ -d "$TEST_ROOT" && "${TEST_ROOT:t}" == JobsCommandSdkEntry.* ]] && /bin/rm -r -- "$TEST_ROOT"; }
# 仅source精确函数体，原脚本的菜单、删除与安装入口均不执行。
load_function() {
  local source_file="$1" name="$2" output="$TEST_ROOT/function.zsh"
  /usr/bin/awk -v name="$name" '$0 ~ "^[ ]*" name "\\(\\) \\{$" {show=1;match($0,/[^ ]/);prefix=substr($0,1,RSTART-1)} show {print} show && $0 == prefix "}" {exit}' "$source_file" > "$output"
  [[ -s "$output" ]] || return 1
  source "$output"
}
# 建立当前用例独占目录和命令替身，不运行真实 SDK。
fixture() {
  export TEST_TRACE="$TEST_ROOT/trace-$TEST_COUNT"
  : > "$TEST_TRACE"
  /bin/mkdir -p "$TEST_ROOT/project" "$TEST_ROOT/case-$TEST_COUNT/project"
  builtin cd "$TEST_ROOT/case-$TEST_COUNT/project" || return 1
  # 为当前隔离用例提供 jobs_flutter_sdk_command 替身，只记录或模拟约定结果。
  function jobs_flutter_sdk_command() { print -r -- "sdk|${(j:|:)@}" >> "$TEST_TRACE"; return 7; }
  # 为当前隔离用例提供 info_echo 替身，只记录或模拟约定结果。
  function info_echo() { :; }
  # 为当前隔离用例提供 highlight_echo 替身，只记录或模拟约定结果。
  function highlight_echo() { :; }
  # 为当前隔离用例提供 success_echo 替身，只记录或模拟约定结果。
  function success_echo() { :; }
  # 为当前隔离用例提供 warn_echo 替身，只记录或模拟约定结果。
  function warn_echo() { :; }
  # 为当前隔离用例提供 note_echo 替身，只记录或模拟约定结果。
  function note_echo() { :; }
  # 将当前隔离断言标记为失败并保留上下文。
  function fail() { return 1; }
}
# 验证SDK 失败不重复执行清理业务。
test_cleanup_business_once() {
  local file=("$MAC_ROOT"/小工具/*清理维护*/*.command(N)) result=0
  load_function "$file[1]" jobs_command_flutter_once || return 1
  # 为当前隔离用例提供 jobs_flutter_sdk_command 替身，只记录或模拟约定结果。
  function jobs_flutter_sdk_command() {
    print -r -- "sdk|${(j:|:)@}" >> "$TEST_TRACE"
    [[ "$2" != --version ]] || return 0
    return 7
  }
  jobs_command_flutter_once pub get || result=$?
  [[ "$result" == 7 && "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 2 ]] &&
    /usr/bin/grep -Fxq 'sdk|flutter|pub|get' "$TEST_TRACE"
}
# 验证SDK 取消不触发备用命令。
test_cleanup_sdk_cancel_does_not_fallback() {
  local file=("$MAC_ROOT"/小工具/*清理维护*/*.command(N)) result=0
  load_function "$file[1]" jobs_command_flutter_once || return 1
  /bin/mkdir -p .fvm/flutter_sdk/bin
  print -r -- '#!/bin/zsh' > .fvm/flutter_sdk/bin/flutter
  /bin/chmod +x .fvm/flutter_sdk/bin/flutter
  # 为当前隔离用例提供 jobs_flutter_sdk_command 替身，只记录或模拟约定结果。
  function jobs_flutter_sdk_command() { print -r -- "sdk|${(j:|:)@}" >> "$TEST_TRACE"; return 143; }
  jobs_command_flutter_once pub get || result=$?
  [[ "$result" == 143 && "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 1 ]] && ! /usr/bin/grep -Fq 'sdk|flutter|' "$TEST_TRACE"
}
# 验证保留原非 SDK 失败恢复分支。
test_cleanup_non_sdk_recovery_preserved() {
  local file=("$MAC_ROOT"/小工具/*清理维护*/*.command(N)) result=0
  load_function "$file[1]" jobs_command_flutter_once || return 1
  /bin/mkdir -p .fvm/flutter_sdk/bin
  print -r -- '#!/bin/zsh' > .fvm/flutter_sdk/bin/flutter
  /bin/chmod +x .fvm/flutter_sdk/bin/flutter
  # 为当前隔离用例提供 jobs_flutter_sdk_command 替身，只记录或模拟约定结果。
  function jobs_flutter_sdk_command() {
    print -r -- "sdk|${(j:|:)@}" >> "$TEST_TRACE"
    [[ "$2" != --version ]] || return 0
    return 7
  }
  jobs_command_flutter_once pub get || result=$?
  [[ "$result" == 7 && "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 4 ]] && /usr/bin/grep -Fxq 'sdk|flutter|pub|get' "$TEST_TRACE"
}
# 验证doctor 失败后不继续 analyze。
test_doctor_failure_stops_analyze() {
  local file=("$MAC_ROOT"/小工具/*自检Flutter*/*.command(N)) result=0
  load_function "$file[1]" run_flutter_doctor || return 1
  flutter_cmd=(fvm flutter)
  run_flutter_doctor || result=$?
  [[ "$result" == 7 && "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 1 ]] &&
    /usr/bin/grep -Fxq 'sdk|fvm|flutter|doctor|-v' "$TEST_TRACE"
}
# 验证带中文空格的 SDK 路径保持单一参数。
test_chinese_path_quoted() {
  local file=("$MAC_ROOT"/小工具/*中文路径*/*.command(N)) result=0
  load_function "$file[1]" ask_flutter_upgrade || return 1
  FLUTTER_CMD="$TEST_ROOT/中文 空格/bin/flutter"
  # 为当前隔离用例提供 read 替身，只记录或模拟约定结果。
  function read() { REPLY=yes; return 0; }
  ask_flutter_upgrade || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fxq "sdk|$FLUTTER_CMD|upgrade" "$TEST_TRACE"
}
# 验证组件预取参数原样透传且不使用 eval。
test_precache_arguments() {
  local file=("$MAC_ROOT"/配置相关/*项目组件预下载*/*.command(N)) result=0
  load_function "$file[1]" run_precache || return 1
  PRECACHE_FLUTTER=(fvm flutter)
  # 为当前隔离用例提供 read 替身，只记录或模拟约定结果。
  function read() { mode=2; return 0; }
  # 为当前隔离用例提供 fzf 替身，只记录或模拟约定结果。
  function fzf() { print -r -- $'  --ios\n  --web'; }
  run_precache || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fxq 'sdk|fvm|flutter|precache|--ios|--web' "$TEST_TRACE" &&
    ! /usr/bin/grep -Fq 'eval "${CMD_PREFIX}flutter precache' "$file[1]"
}
# 验证依赖收集失败状态返回调用方。
test_collect_failure_preserved() {
  local file=("$MAC_ROOT"/配置相关/*收集当前Flutter*/*.command(N)) result=0
  load_function "$file[1]" prepare_package_config || return 1
  RUN_PUB_GET=1
  FLUTTER_CMD=(fvm flutter)
  LOG_FILE="$TEST_ROOT/collect.log"
  PACKAGE_CONFIG="$TEST_ROOT/package_config.json"
  : > "$PACKAGE_CONFIG"
  # 为当前隔离用例提供 ask_any_to_run 替身，只记录或模拟约定结果。
  function ask_any_to_run() { return 0; }
  prepare_package_config || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fxq 'sdk|fvm|flutter|pub|get' "$TEST_TRACE"
}
# 验证官方下载失败后不解压不发布。
test_official_download_failure_stops_extract() {
  local file=("$MAC_ROOT"/配置相关/*安装Flutter.SDK*/*.command(N)) result=0
  load_function "$file[1]" install_official || return 1
  # 为当前隔离用例提供 read 替身，只记录或模拟约定结果。
  function read() { target_dir="$TEST_ROOT/install-target"; return 0; }
  # 为当前隔离用例提供 unzip 替身，只记录或模拟约定结果。
  function unzip() { print unzip >> "$TEST_TRACE"; return 0; }
  install_official || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fq 'sdk|--official-archive|stable|' "$TEST_TRACE" && ! /usr/bin/grep -Fxq unzip "$TEST_TRACE"
}
# 验证Homebrew SDK 经供应商包装器调用。
test_brew_sdk_uses_supplier_wrapper() {
  local file=("$MAC_ROOT"/配置相关/*安装Flutter.SDK*/*.command(N)) result=0
  load_function "$file[1]" install_brew || return 1
  # 为当前隔离用例提供 brew 替身，只记录或模拟约定结果。
  function brew() { :; }
  # 为当前隔离用例提供 ask_run 替身，只记录或模拟约定结果。
  function ask_run() { return 0; }
  install_brew || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fq 'sdk|--brew-cask|brew|' "$TEST_TRACE" && [[ "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 1 ]]
}
# 验证FVM 失败不修改工程 SDK 绑定。
test_fvm_failure_does_not_bind() {
  local file=("$MAC_ROOT"/配置相关/*安装FVM*/*.command(N)) result=0
  load_function "$file[1]" install_flutter_version || return 1
  install_flutter_version 3.38.4 || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fxq 'sdk|fvm|install|3.38.4' "$TEST_TRACE" && [[ "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 1 ]]
}
# 验证Git 配置失败不绑定 SDK。
test_git_config_failure_does_not_bind() {
  local file=("$MAC_ROOT"/*Git拉取Flutter项目*/*.command(N)) result=0
  load_function "$file[1]" setup_fvm_for_project || return 1
  setup_fvm_for_project "$TEST_ROOT/project" || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fxq 'sdk|fvm|install|stable' "$TEST_TRACE" && [[ "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 1 ]]
}
# 验证升级仅采用本地可验证 SDK 根。
test_upgrade_root_discovery_is_local() {
  local file=("$MAC_ROOT"/更新升级/*升级Flutter.SDK*/*.command(N)) root=''
  load_function "$file[1]" get_sdk_path_from_system || return 1
  /bin/mkdir -p "$TEST_ROOT/local-sdk/bin"
  print -r -- '#!/bin/zsh' > "$TEST_ROOT/local-sdk/bin/flutter"
  /bin/chmod +x "$TEST_ROOT/local-sdk/bin/flutter"
  export PATH="$TEST_ROOT/local-sdk/bin:$PATH"
  rehash
  command -v flutter >/dev/null || return 1
  root="$(get_sdk_path_from_system)" || return 1
  [[ "$root" == "${TEST_ROOT:A}/local-sdk" && ! -s "$TEST_TRACE" ]]
}
# 验证通道选择失败不继续升级。
test_upgrade_channel_failure_stops_upgrade() {
  local file=("$MAC_ROOT"/更新升级/*升级Flutter.SDK*/*.command(N)) result=0
  load_function "$file[1]" perform_upgrade || return 1
  /bin/mkdir -p "$TEST_ROOT/upgrade-sdk/bin"
  print -r -- '#!/bin/zsh' > "$TEST_ROOT/upgrade-sdk/bin/flutter"
  /bin/chmod +x "$TEST_ROOT/upgrade-sdk/bin/flutter"
  # 为当前隔离用例提供 cecho 替身，只记录或模拟约定结果。
  function cecho() { :; }
  # 为当前隔离用例提供 check_sdk_git_changes 替身，只记录或模拟约定结果。
  function check_sdk_git_changes() { return 1; }
  # 为当前隔离用例提供 select_channel 替身，只记录或模拟约定结果。
  function select_channel() { print beta; }
  perform_upgrade 'fvm flutter' "$TEST_ROOT/upgrade-sdk" || result=$?
  [[ "$result" == 7 ]] && /usr/bin/grep -Fxq "sdk|$TEST_ROOT/upgrade-sdk/bin/flutter|channel|beta" "$TEST_TRACE" && [[ "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 1 ]]
}
# 验证固定 SDK 升级不切换物理根路径。
test_upgrade_pinned_physical_sdk_stays_fixed() {
  local file=("$MAC_ROOT"/更新升级/*升级Flutter.SDK*/*.command(N)) result=0
  load_function "$file[1]" perform_upgrade || return 1
  /bin/mkdir -p "$TEST_ROOT/fvm/versions/3.38.4/bin"
  print -r -- '#!/bin/zsh' > "$TEST_ROOT/fvm/versions/3.38.4/bin/flutter"
  /bin/chmod +x "$TEST_ROOT/fvm/versions/3.38.4/bin/flutter"
  # 为当前隔离用例提供 cecho 替身，只记录或模拟约定结果。
  function cecho() { :; }
  perform_upgrade flutter "$TEST_ROOT/fvm/versions/3.38.4" || result=$?
  [[ "$result" == 2 && ! -s "$TEST_TRACE" ]]
}
# 验证Android 安装成功必须具备实际平台文件。
test_android_install_requires_real_files() {
  local file=("$MAC_ROOT"/运行/*Android*/*.command(N)) result=0
  load_function "$file[1]" jobs_command_android_install_once || return 1
  /bin/mkdir -p "$TEST_ROOT/android-tools" "$TEST_ROOT/android-sdk"
  printf '%s\n' '#!/bin/zsh' 'exit 0' > "$TEST_ROOT/android-tools/sdkmanager"
  /bin/chmod +x "$TEST_ROOT/android-tools/sdkmanager"
  export PATH="$TEST_ROOT/android-tools:$PATH"
  jobs_command_android_install_once "$TEST_ROOT/android-sdk" 'build-tools;34.0.0' "$TEST_ROOT/android.log" || result=$?
  [[ "$result" != 0 ]] || return 1
  /bin/mkdir -p "$TEST_ROOT/android-sdk/build-tools/34.0.0"
  print -r -- '#!/bin/zsh' > "$TEST_ROOT/android-sdk/build-tools/34.0.0/aapt2"
  /bin/chmod +x "$TEST_ROOT/android-sdk/build-tools/34.0.0/aapt2"
  jobs_command_android_install_once "$TEST_ROOT/android-sdk" 'build-tools;34.0.0' "$TEST_ROOT/android.log" || return 1
  result=0
  jobs_command_android_install_once "$TEST_ROOT/android-sdk" 'platforms;android-34' "$TEST_ROOT/android.log" || result=$?
  [[ "$result" != 0 ]] || return 1
  /bin/mkdir -p "$TEST_ROOT/android-sdk/platforms/android-34"
  : > "$TEST_ROOT/android-sdk/platforms/android-34/android.jar"
  jobs_command_android_install_once "$TEST_ROOT/android-sdk" 'platforms;android-34' "$TEST_ROOT/android.log"
}
# 验证Android 运行失败仍保留原恢复顺序。
test_android_run_preserves_original_recovery() {
  local file=("$MAC_ROOT"/运行/*Android*/*.command(N)) result=0
  load_function "$file[1]" run_flutter || return 1
  flutter_cmd=(flutter)
  device_id=fake-device
  entry_file='lib/中文 main.dart'
  FLAVOR=''
  BUILD_MODE=debug
  # 为当前隔离用例提供 replace_connectivity_dependency 替身，只记录或模拟约定结果。
  function replace_connectivity_dependency() { return 0; }
  # 为当前隔离用例提供 read 替身，只记录或模拟约定结果。
  function read() { confirm=yes; run_mode=''; return 0; }
  # 为当前隔离用例提供 jobs_flutter_sdk_command 替身，只记录或模拟约定结果。
  function jobs_flutter_sdk_command() {
    print -r -- "sdk|${(j:|:)@}" >> "$TEST_TRACE"
    [[ " $* " != *' run '* ]] || return 7
    return 0
  }
  flutter_project_root="$TEST_ROOT/project"
  # 为当前隔离用例提供 rm 替身，只记录或模拟约定结果。
  function rm() { print -r -- "recover-cleanup|${(j:|:)@}" >> "$TEST_TRACE"; return 0; }
  run_flutter || result=$?
  [[ "$result" == 7 && "$(/usr/bin/grep -c 'sdk|flutter|run|' "$TEST_TRACE")" == 2 ]] && [[ "$(/usr/bin/grep -c '^sdk|' "$TEST_TRACE")" == 6 ]]
}
# 隔离运行单个用例并累计失败，保留可诊断 trace。
run_test() {
  (( TEST_COUNT++ ))
  if (fixture && "$1"); then print -r -- "PASS $1"; else (( TEST_FAILURES++ )); print -u2 -r -- "FAIL $1"; /bin/cat "$TEST_ROOT/trace-$TEST_COUNT" >&2; fi
}
# 展示自动化回归的用途与作用范围，保留原有测试调用协议。
show_script_intro_and_wait() {
  print -r -- '脚本自述：执行隔离回归并汇总断言结果。'
  print -r -- '影响：仅使用原测试声明的临时夹具；不运行真实安装或系统清理。'
  print -r -- '运行策略：保留原自动化参数与退出码；Ctrl+C 取消。'
}
# 执行既有夹具与回归用例，并保留失败汇总结果。
run_regression_cases() {
  local test
  for test in test_cleanup_business_once test_cleanup_sdk_cancel_does_not_fallback test_cleanup_non_sdk_recovery_preserved test_doctor_failure_stops_analyze test_chinese_path_quoted test_precache_arguments test_collect_failure_preserved test_official_download_failure_stops_extract test_brew_sdk_uses_supplier_wrapper test_fvm_failure_does_not_bind test_git_config_failure_does_not_bind test_upgrade_root_discovery_is_local test_upgrade_channel_failure_stops_upgrade test_upgrade_pinned_physical_sdk_stays_fixed test_android_install_requires_real_files test_android_run_preserves_original_recovery; do run_test "$test"; done
  print -r -- "结果：${TEST_COUNT}项，失败${TEST_FAILURES}。"
  (( TEST_FAILURES==0 ))
}
# 编排固定说明与当前入口的高层职责。
main() {
  show_script_intro_and_wait # 展示自动化测试用途、隔离范围和取消方式。
  run_regression_cases "$@" # 执行既有夹具与回归用例，并保留失败汇总结果。
}
main "$@"
