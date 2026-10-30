#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command
# - 核心用途：选择已有鸿蒙模拟器，缺失时初始化，再用工程适配的 Flutter SDK 运行。
# - 影响范围：按确认补齐模拟器工具、镜像和新实例；Flutter 解析工程依赖并生成构建缓存。
# - 运行提示：先回车确认；Esc / Ctrl+C 取消；--check 只校验工程；不切换全局 Flutter 或项目 FVM。

JOBS_ENTRY_SOURCE="${(%):-%x}"
JOBS_QUERY_PID=""

# 有界查询独立 argv，并在超时时停止本次进程及其子进程。
jobs_harmony_query() {
  local output="$1" limit="$2" elapsed=0 result=0
  shift 2
  ( exec "$@" ) > "$output" 2>&1 &
  JOBS_QUERY_PID=$!
  while kill -0 "$JOBS_QUERY_PID" 2>/dev/null; do
    if (( elapsed >= limit )); then
      jobs_harmony_stop_query "$JOBS_QUERY_PID"
      wait "$JOBS_QUERY_PID" 2>/dev/null
      JOBS_QUERY_PID=""
      return 124
    fi
    /bin/sleep 1
    (( elapsed++ ))
  done
  wait "$JOBS_QUERY_PID" || result=$?
  JOBS_QUERY_PID=""
  return "$result"
}

# 严格解析 Flutter machine JSON，仅保留受支持的鸿蒙模拟器。
jobs_harmony_device_rows() {
  /usr/bin/osascript -l JavaScript - "$1" <<'JXA'
ObjC.import('Foundation');
function run(argv) {
  var data = $.NSString.stringWithContentsOfFileEncodingError($(argv[0]), $.NSUTF8StringEncoding, null);
  if (!data) throw new Error('无法读取 Flutter 设备列表');
  var devices = JSON.parse(ObjC.unwrap(data)), seen = Object.create(null), rows = [];
  if (!Array.isArray(devices)) throw new Error('设备清单必须是数组');
  devices.forEach(function (d) {
    if (!d || typeof d !== 'object' || d.isSupported === false || d.emulator !== true) return;
    if (!/ohos|harmony/i.test(d.targetPlatform || d.platform || '')) return;
    if (typeof d.id !== 'string' || !d.id || /[\x00-\x20\x7f]/.test(d.id) || d.id.charAt(0) === '-') throw new Error('设备 ID 无效');
    if (seen[d.id]) throw new Error('设备 ID 重复');
    seen[d.id] = true;
    var name = typeof d.name === 'string' ? d.name.replace(/[\x00-\x1f\x7f]/g, ' ') : d.id;
    rows.push(d.id + '\t' + name + ' — 鸿蒙模拟器');
  });
  return rows.join('\n');
}
JXA
}

# 在同一总时限内查询设备；每次查询不超过剩余时间。
jobs_harmony_wait_device() {
  local start=$SECONDS timeout="${JOBS_HARMONY_DEVICE_TIMEOUT:-180}" rows="" selected="" query="$LOG_FILE.devices.json" result=0 remaining=0
  local -a choices=()
  [[ "$timeout" == <-> ]] && (( timeout >= 1 && timeout <= 600 )) || { hs_error 'JOBS_HARMONY_DEVICE_TIMEOUT 需为 1～600 秒。'; return 2; }
  while (( SECONDS - start < timeout )); do
    remaining=$(( timeout - (SECONDS - start) ))
    (( remaining <= 30 )) || remaining=30
    if jobs_harmony_query "$query" "$remaining" "${FLUTTER_CMD[@]}" devices --machine; then
      rows="$(jobs_harmony_device_rows "$query")" || { hs_error "Flutter 设备列表无法解析：$query"; return 1; }
      if [[ -n "$rows" ]]; then
        choices=("${(@f)rows}")
        selected="$(hs_choose '选择要运行的鸿蒙模拟器设备' "${choices[@]}")" || return $?
        JOBS_HARMONY_DEVICE="${selected%%$'\t'*}"
        return 0
      fi
    else
      hs_log "⚠ Flutter 设备查询未成功，诊断：$query"
    fi
    hs_log 'ℹ 等待鸿蒙模拟器出现在 Flutter 列表中…'
    /bin/sleep 2
  done
  hs_error "等待 ${timeout} 秒仍无受支持的鸿蒙模拟器；保留实例，检查 hdc / Flutter doctor 后重试。"
  return 1
}

# 核对工程和鸿蒙 SDK，启动或初始化模拟器后运行工程。
jobs_run_harmony_run() {
  setopt NO_NOMATCH PIPE_FAIL
  local entry_dir="${${JOBS_ENTRY_SOURCE:A}:h}" answer="" check=0 help_text="" candidate=""
  [[ -f "$entry_dir/HarmonySimulator.zsh" && -f "$entry_dir/FlutterHarmonyTools.zsh" ]] || { print -u2 '缺少随包后端，请保留完整目录。'; return 1; }
  source "$entry_dir/FlutterHarmonyTools.zsh" || return $?
  source "$entry_dir/HarmonySimulator.zsh" || return $?
  if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    print -r -- '用法：/bin/zsh 当前脚本 [--check] [--project 工程根目录] [--flutter-sdk 鸿蒙FlutterSDK根目录]'
    return 0
  fi
  [[ "${1:-}" != --check ]] || { check=1; shift; }
  parse_build_options "$@" || return $?
  if (( ! check )); then
    [[ -n "$BUILD_BASE" ]] || IFS= read -r 'BUILD_BASE?输入或拖入 Flutter 鸿蒙工程根目录：' || return 130
  fi
  resolve_flutter_project || return $?
  (( ! check )) || { hs_log '工程清单检查通过；未运行 SDK、初始化或启动设备。'; return 0; }
  SCRIPT_BASENAME="${JOBS_ENTRY_SOURCE:t:r}"
  initialize_script_runtime || return $?
  choose_flutter_sdk || return $?
  if ! jobs_harmony_query "$LOG_FILE.hap-help" 60 "${FLUTTER_CMD[@]}" build hap --help; then
    hs_error "当前 Flutter SDK 未确认支持 HAP；不替换工程 SDK。诊断：$LOG_FILE.hap-help"; return 1
  fi
  /usr/bin/grep -Fq 'flutter build hap' "$LOG_FILE.hap-help" || { hs_error '当前 SDK 不具备鸿蒙 HAP 能力；请指定鸿蒙适配 SDK。'; return 1; }
  hs_check_host || return $?
  hs_initialize_log || return $?
  if hs_find_emulator; then hs_query_state || return $?; else hs_prepare_environment || return $?; fi
  jobs_harmony_select_and_start 1 || return $?
  candidate="${HS_BIN:h:h}/sdk"
  [[ -n "${DEVECO_SDK_HOME:-}" || ! -d "$candidate" ]] || export DEVECO_SDK_HOME="$candidate"
  prepare_deveco_environment || return $?
  trap '[[ -z "$JOBS_QUERY_PID" ]] || jobs_harmony_stop_query "$JOBS_QUERY_PID"; exit 130' INT TERM HUP
  cd "$PROJECT_ROOT" || return 1
  jobs_harmony_wait_device || return $?
  run_step 'Flutter 解析依赖' "${FLUTTER_CMD[@]}" pub get || return $?
  run_step 'Flutter 运行到鸿蒙模拟器' "${FLUTTER_CMD[@]}" run -d "$JOBS_HARMONY_DEVICE"
}

# 递归只收集本次查询的子进程，先终止后代再回收主进程。
jobs_harmony_stop_query() {
  local query_pid="$1" child=""
  local -a descendants=()
  for child in ${(@f)$(/usr/bin/pgrep -P "$query_pid" 2>/dev/null)}; do
    [[ "$child" == <-> ]] || continue
    jobs_harmony_stop_query "$child"
  done
  kill -TERM "$query_pid" 2>/dev/null
  kill -KILL "$query_pid" 2>/dev/null
}
# 第一屏固定自述与回车确认；帮助和只读检查不要求交互。
jobs_run_harmony_intro() {
  jobs_entry_intro_line title '运行 Flutter 项目（鸿蒙模拟器）'
  jobs_entry_intro_line body '1、选择已有鸿蒙模拟器；没有时初始化。下载、创建与许可逐项确认，保留既有实例。'
  jobs_entry_intro_line body '2、使用工程适配的鸿蒙 Flutter SDK，核验 HAP 能力；缺失 FVM 绑定停止，不替换全局 SDK。'
  jobs_entry_intro_line body '3、解析依赖并生成工程构建缓存；不改代理和签名；日志位于临时目录 JobsFlutterHarmonyPackager.*。'
  jobs_entry_intro_line body '4、fzf 选择，Esc / Ctrl+C 取消；--check 仅校验工程清单，不调用 SDK。'
  [[ "${1:-}" != --check && "${1:-}" != --help && "${1:-}" != -h ]] || return 0
  [[ -t 0 ]] || { print -u2 '需要交互终端；只读检查用 --check --project。'; exit 1; }
  local answer=""
  IFS= read -r 'answer?按回车继续；非空输入取消：' || exit 130
  [[ -z "$answer" ]] || exit 130
}
# 自述标题红色粗体、正文蓝色；无颜色终端保持纯文本。
jobs_entry_intro_line() {
  local color='0;34'
  [[ "$1" != title ]] || color='1;31'
  if [[ -t 1 && -n "${TERM:-}" && "$TERM" != dumb && -z "${NO_COLOR+x}" ]]; then
    printf '\033[%sm%s\033[0m\n' "$color" "$2"
  else
    print -r -- "$2"
  fi
}
main() {
  jobs_run_harmony_intro "$@" # 首先打印内置说明并等待回车。
  jobs_run_harmony_run "$@" # 核验工程与 SDK，再启动模拟器并运行项目。
}
main "$@"
