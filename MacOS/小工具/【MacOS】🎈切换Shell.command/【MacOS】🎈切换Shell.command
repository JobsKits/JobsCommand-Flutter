#!/bin/zsh
# shell: zsh
# 切换当前用户的默认登录 Shell，并安装桌面 / Finder 空白处右键入口。
# 安装菜单不会修改默认 Shell；实际切换前必须选择并确认。

SCRIPT_DIR="${${(%):-%x}:A:h}"
SCRIPT_PATH="${${(%):-%x}:A}"
LOG_FILE="${TMPDIR:-/tmp}/JobsShellSwitcher.log"
typeset -gaU available_shells=()

log_message() {
  local color="$1" message="$2"
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    print -r -- $'\e['"${color}m${message}"$'\e[0m'
  else
    print -r -- "$message"
  fi
  print -r -- "$message" >> "$LOG_FILE"
}
info_echo() { log_message 34 "ℹ $*"; }
success_echo() { log_message 32 "✔ $*"; }
error_echo() { log_message 31 "✖ $*" >&2; }

show_help() {
  cat <<'HELP'
切换 Shell：桌面和 Finder 文件夹空白处右键 → 🎈 切换 Shell…

无参数运行：显示功能菜单。
  --install-finder-menu    安装 / 更新当前用户的右键菜单
  --uninstall-finder-menu  卸载本工具的右键菜单
  --finder-menu-status     查看扩展的安装、启用状态
  --switch-shell          选择并确认后切换默认登录 Shell
  --help                  显示帮助

切换只影响当前用户之后启动的登录 Shell，不改变已打开的终端。
右键菜单安装需要 macOS Command Line Tools；Shell 选择使用已安装的 fzf。
HELP
}

require_terminal() {
  [[ -t 0 && -t 1 ]] || {
    error_echo '请在可交互终端运行；未执行 Shell 切换。'
    return 1
  }
}

read_available_shells() {
  local candidate
  available_shells=()
  while IFS= read -r candidate; do
    [[ "$candidate" == /* && -x "$candidate" && ! -d "$candidate" ]] && available_shells+=("$candidate")
  done < <(/usr/bin/awk '
    { sub(/#.*/, ""); gsub(/^[ \t]+|[ \t]+$/, "") }
    /^\// { print }
  ' /etc/shells)
  (( ${#available_shells} )) || { error_echo '没有找到 /etc/shells 中可执行的 Shell。'; return 1; }
  return 0
}

current_login_shell() {
  /usr/bin/dscl /Search -read "/Users/$(/usr/bin/id -un)" UserShell 2>/dev/null |
    /usr/bin/awk '$1 == "UserShell:" { print $2 }'
}

# 独立封装，测试时可以替换本函数，绝不在验证过程中修改真实账户。
change_login_shell() {
  /usr/bin/chsh -s "$1"
}

apply_selected_shell() {
  local selected="$1" current actual
  # 临执行重新校验系统允许列表；不接受任意路径或过期的选择。
  read_available_shells || return 1
  if (( ! ${available_shells[(Ie)$selected]} )); then
    error_echo "Shell 不在系统允许列表中或不可执行：$selected"
    return 1
  fi
  current="$(current_login_shell)"
  if [[ "$current" == "$selected" ]]; then
    info_echo "当前默认 Shell 已经是 $selected，无需修改。"
    return 0
  fi
  info_echo "正在修改当前用户的默认登录 Shell：$selected"
  if ! change_login_shell "$selected"; then
    error_echo 'chsh 执行失败，默认 Shell 未确认修改成功。'
    return 1
  fi
  actual="$(current_login_shell)"
  if [[ "$actual" != "$selected" ]]; then
    error_echo "修改后核验失败，账户返回：${actual:-无法读取}"
    return 1
  fi
  success_echo "默认 Shell 已更新为 $actual；重新打开终端后生效。"
}

find_fzf() {
  local candidate
  for candidate in "$(command -v fzf 2>/dev/null)" /opt/homebrew/bin/fzf /usr/local/bin/fzf \
    "$HOME/.local/homebrew/bin/fzf" "$HOME/.homebrew/bin/fzf" "$HOME/.fzf/bin/fzf"; do
    if [[ -n "$candidate" && -x "$candidate" && ! -d "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  error_echo '未找到 fzf，请先安装（例如：brew install fzf），再运行切换 Shell。'
  return 2
}

select_shell_with_fzf() {
  local fzf_bin current="${1:-}"
  local -aU ordered_shells
  # 无法确定当前默认值时停止，不能让回车误选列表中的其它 Shell。
  if [[ -z "$current" ]] || (( ! ${available_shells[(Ie)$current]} )); then
    error_echo '无法确认可用的当前默认 Shell，已停止选择，未修改设置。'
    return 2
  fi
  # 当前默认值置顶并去重；其余项目保持 /etc/shells 的顺序。
  ordered_shells=("$current" "${available_shells[@]}")
  fzf_bin="$(find_fzf)" || return 2
  # 固定为单选，避免用户全局的 --expect / --print-query / --multi 改变输出格式。
  print -rl -- "${ordered_shells[@]}" |
    FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE=/dev/null "$fzf_bin" \
      --height=40% --layout=reverse --border --no-multi --no-sort \
      --prompt='Shell ➜ ' --header="当前默认：$current（首项，直接回车保持不变） | ↑↓ 选择 · Esc 取消"
}

switch_shell() {
  require_terminal || return 1
  local current answer selected selection_result=0
  read_available_shells || return 1
  current="$(current_login_shell)"
  print -r -- '===================== 切换默认登录 Shell ====================='
  info_echo "当前账户默认 Shell：${current:-无法读取}"
  print -r -- '此设置对当前用户生效，与右键所在文件夹无关。'
  print -r -- '通过 fzf 选择 /etc/shells 中可执行的 Shell；Esc 或 Ctrl+C 取消。'
  print -r -- '当前默认 Shell 始终排在初始列表第一项；直接回车保持不变。'
  selected="$(select_shell_with_fzf "$current")" || selection_result=$?
  case "$selection_result" in
    0) ;;
    1|130) info_echo '已取消，没有修改默认 Shell。'; return 0 ;;
    *) error_echo "fzf 无法完成选择（退出码 $selection_result）。"; return 1 ;;
  esac
  [[ -n "$selected" ]] || { info_echo '未选择 Shell，已取消。'; return 0; }
  if (( ! ${available_shells[(Ie)$selected]} )); then
    error_echo 'fzf 返回的选择不在系统允许列表中，未修改默认 Shell。'
    return 1
  fi
  if [[ "$selected" == "$current" ]]; then
    info_echo '所选 Shell 已经是默认值，无需修改。'
    return 0
  fi
  print -r -- "即将把当前用户的默认登录 Shell 改为：$selected"
  IFS= read -r 'answer?➤ 输入 YES 确认；其它输入取消：' || return 0
  [[ "$answer" == YES ]] || { info_echo '已取消，没有修改默认 Shell。'; return 0; }
  apply_selected_shell "$selected"
}

manage_finder_menu() {
  [[ -f "$SCRIPT_DIR/FinderMenu/install.zsh" ]] || {
    error_echo '缺少 FinderMenu 源码目录，请从完整仓库运行安装。'
    return 1
  }
  /bin/zsh "$SCRIPT_DIR/FinderMenu/install.zsh" "$1"
}

main() {
  [[ "$(/usr/bin/uname -s)" == Darwin ]] || { print -u2 '此工具仅支持 macOS。'; return 1; }
  (( $# <= 1 )) || { show_help; return 2; }
  local action="${1:-}" choice
  case "$action" in
    --help|-h) show_help; return 0 ;;
    --finder-menu-status) manage_finder_menu status; return $? ;;
    --install-finder-menu) manage_finder_menu install; return $? ;;
    --uninstall-finder-menu) manage_finder_menu uninstall; return $? ;;
    --switch-shell) switch_shell; return $? ;;
    '') ;;
    *) print -u2 -r -- "未知参数：$action"; show_help; return 2 ;;
  esac
  require_terminal || return 1
  show_help
  print -r -- $'\n1) 安装 / 更新右键菜单\n2) 立即切换默认 Shell\n3) 查看右键菜单状态\n4) 卸载右键菜单\n回车或 q 退出'
  IFS= read -r 'choice?➤ 请选择：' || return 0
  case "$choice" in
    1) manage_finder_menu install ;;
    2) switch_shell ;;
    3) manage_finder_menu status ;;
    4) manage_finder_menu uninstall ;;
    ''|q|Q) return 0 ;;
    *) error_echo '无效选择。'; return 2 ;;
  esac
}

# source 仅载入函数，供无副作用的回归验证使用。
if [[ "$ZSH_EVAL_CONTEXT" == toplevel ]]; then
  main "$@"
fi
