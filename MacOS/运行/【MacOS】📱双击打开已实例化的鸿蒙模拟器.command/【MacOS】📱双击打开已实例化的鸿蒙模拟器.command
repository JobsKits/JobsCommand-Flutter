#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】📱双击打开已实例化的鸿蒙模拟器.command
# - 核心用途：读取官方 DevEco 已有实例，选择一个鸿蒙模拟器并启动。
# - 影响范围：仅启动所选已有实例，不创建、下载镜像或安装工具，不修改全局环境。
# - 运行提示：先回车确认；fzf 上下选择、输入筛选，Esc / Ctrl+C 取消；--check 只读。

JOBS_ENTRY_SOURCE="${(%):-%x}"

# 解析入口参数并查询、选择和启动唯一已有实例。
jobs_open_harmony_run() {
  setopt NO_NOMATCH PIPE_FAIL
  local entry_dir="${${JOBS_ENTRY_SOURCE:A}:h}" answer=""
  [[ -f "$entry_dir/HarmonySimulator.zsh" ]] || { print -u2 '缺少随包 HarmonySimulator.zsh，请保留完整目录。'; return 1; }
  source "$entry_dir/HarmonySimulator.zsh" || return $?
  case "${1:-}" in
    --help|-h) print -r -- '用法：/bin/zsh 当前脚本 [--check | --help]；HARMONY_EMULATOR_BIN 指定官方工具。'; return 0 ;;
    --check) HS_CHECK=1 ;;
    '') ;;
    *) hs_error "未知参数：$1"; return 2 ;;
  esac
  (( $# <= 1 )) || return 2
  if (( ! HS_CHECK )); then
    hs_initialize_log || return $?
  fi
  hs_check_host || return $?
  hs_find_emulator || return $?
  hs_query_state || return $?
  (( ! HS_CHECK )) || { hs_log '只读检查完成；未启动、创建或下载。'; return 0; }
  jobs_harmony_select_and_start 0 # 只启动已有实例，空列表停止并显示初始化入口。
}

# 入口第一步展示用途与范围，确认前不加载工具或写日志。
jobs_open_harmony_intro() {
  jobs_entry_intro_line title '打开已实例化的鸿蒙模拟器'
  jobs_entry_intro_line body '1、只选择并启动已有 DevEco 鸿蒙实例，不创建、不下载、不安装工具。'
  jobs_entry_intro_line body '2、Apple Silicon 原生 macOS，fzf 选择；Esc / Ctrl+C 取消；日志位于临时目录 JobsHarmonySimulator.*。'
  [[ "${1:-}" != --check && "${1:-}" != --help && "${1:-}" != -h ]] || return 0
  [[ -t 0 ]] || { print -u2 '需要交互终端；只读检查用 --check。'; exit 1; }
  local answer=""
  IFS= read -r 'answer?按回车继续；非空输入取消：' || exit 130
  [[ -z "$answer" ]] || exit 130
}
# 仅处理自述颜色；日志仍使用后端自己的配色和纯文本策略。
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
  jobs_open_harmony_intro "$@" # 先展示内置说明并等待回车。
  jobs_open_harmony_run "$@" # 只读检查或选择、启动已有实例。
}
main "$@"
