#!/bin/zsh

set -o pipefail
setopt NO_NOMATCH

# ---------- 基础路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

: > "$LOG_FILE"

# ---------- 彩色日志 ----------
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
warm_echo()      { log "\033[1;33m$1\033[0m"; }
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
err_echo()       { log "\033[1;31m$1\033[0m"; }
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }
underline_echo() { log "\033[4m$1\033[0m"; }

# ---------- 内置自述 ----------
jobs_cor_show_readme_and_wait() {
  clear 2>/dev/null || true
  cat <<'EOFREADME' | tee -a "$LOG_FILE"
============================================================
cor - 颜色转换 / 终端色块预览
============================================================

功能：
  转换 HEX / RGB / RGBA / 0xAARRGGBB，并在 macOS 终端直接显示色块。

支持输入：
  #D2D4DE
  D2D4DE
  #D2D4DE80
  D2D4DE80
  #ABC
  #ABCF
  rgb(210,212,222)
  rgba(210,212,222,0.5)
  0x80D2D4DE       按 0xAARRGGBB 解析
  0xD2D4DE         按 0xRRGGBB 解析

说明：
  - macOS Terminal.app / iTerm2 / VS Code 终端默认使用 24-bit True Color 预览。
  - 透明度无法由终端背景色真实呈现；色块预览按 RGB 原色显示，Alpha 只参与格式转换。
  - 日志路径：/tmp/cor.log
============================================================
EOFREADME

  if [[ -t 0 && "${JOBS_MAC_ENV_SKIP_README:-}" != "1" ]]; then
    log ""
    warm_echo "按回车继续执行 cor..."
    local _answer=""
    IFS= read -r _answer
  fi
}

# ---------- 基础工具 ----------
jobs_cor_supports_truecolor() {
  emulate -L zsh

  # macOS 自带 Terminal.app 常常不设置 COLORTERM，但支持 24-bit ANSI True Color。
  [[ "${COLORTERM:-}" == *truecolor* ]] && return 0
  [[ "${COLORTERM:-}" == *24bit* ]] && return 0
  [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] && return 0
  [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] && return 0
  [[ "${TERM_PROGRAM:-}" == "vscode" ]] && return 0
  [[ "${TERM_PROGRAM:-}" == "WezTerm" ]] && return 0
  [[ "${TERM:-}" == *truecolor* ]] && return 0
  [[ "${TERM:-}" == *24bit* ]] && return 0

  return 1
}

jobs_cor_title_color() {
  emulate -L zsh

  local esc=$'\033'
  if jobs_cor_supports_truecolor; then
    printf "%s" "${esc}[38;2;210;212;222m"
  else
    printf "%s" "${esc}[37m"
  fi
}

jobs_cor_to_hex() {
  emulate -L zsh
  printf "%02X" "$1"
}

jobs_cor_hex_to_dec() {
  emulate -L zsh
  printf "%d" "$(( 16#$1 ))"
}

jobs_cor_is_hex() {
  emulate -L zsh
  [[ "$1" =~ '^[0-9a-fA-F]+$' ]]
}

jobs_cor_expand_short_hex() {
  emulate -L zsh

  local hex="$1" out="" i c
  for (( i = 1; i <= ${#hex}; i++ )); do
    c="${hex[i]}"
    out+="${c}${c}"
  done
  print -r -- "$out"
}

jobs_cor_alpha_float_to_255() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 1) v = 1; printf("%d", (v * 255) + 0.5) }'
}

jobs_cor_alpha_255_to_float() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { printf("%.2f", v / 255) }'
}

jobs_cor_clamp_alpha_float() {
  emulate -L zsh
  awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 1) v = 1; printf("%.2f", v) }'
}

jobs_cor_sanitize_input() {
  emulate -L zsh
  print -r -- "$1" | tr -d '[:space:]' | tr -d '"' | tr -d "'"
}

jobs_cor_upper_hex() {
  emulate -L zsh
  print -r -- "$1" | tr '[:lower:]' '[:upper:]'
}

jobs_cor_rel_luma() {
  emulate -L zsh
  awk -v r="$1" -v g="$2" -v b="$3" 'BEGIN { printf("%.0f", 0.2126 * r + 0.7152 * g + 0.0722 * b) }'
}

jobs_cor_pick_fg_rgb() {
  emulate -L zsh

  local l
  l="$(jobs_cor_rel_luma "$1" "$2" "$3")"
  if (( l > 186 )); then
    print -r -- "0;0;0"
  else
    print -r -- "255;255;255"
  fi
}

jobs_cor_pick_fg_code() {
  emulate -L zsh

  local l
  l="$(jobs_cor_rel_luma "$1" "$2" "$3")"
  if (( l > 186 )); then
    print -r -- "30"
  else
    print -r -- "97"
  fi
}

jobs_cor_rgb_to_ansi256() {
  emulate -L zsh

  local r="$1" g="$2" b="$3"
  if (( r == g && g == b )); then
    if (( r < 8 )); then
      print -r -- 16
      return 0
    elif (( r > 248 )); then
      print -r -- 231
      return 0
    else
      print -r -- $(( 232 + ((r - 8) * 24 / 247) ))
      return 0
    fi
  fi

  local rc=$(( r * 5 / 255 ))
  local gc=$(( g * 5 / 255 ))
  local bc=$(( b * 5 / 255 ))
  print -r -- $(( 16 + 36 * rc + 6 * gc + bc ))
}

jobs_cor_set_globals_from_hex() {
  emulate -L zsh

  local hex="$1" mode="${2:-RRGGBB_OR_RRGGBBAA}" rr gg bb aa
  hex="$(jobs_cor_upper_hex "$hex")"

  case "$mode" in
    AARRGGBB)
      (( ${#hex} == 8 )) || return 1
      aa="${hex[1,2]}"
      rr="${hex[3,4]}"
      gg="${hex[5,6]}"
      bb="${hex[7,8]}"
      ;;
    RRGGBB)
      (( ${#hex} == 6 )) || return 1
      rr="${hex[1,2]}"
      gg="${hex[3,4]}"
      bb="${hex[5,6]}"
      aa="FF"
      ;;
    *)
      case "${#hex}" in
        3|4)
          hex="$(jobs_cor_expand_short_hex "$hex")"
          ;;
      esac

      case "${#hex}" in
        6)
          rr="${hex[1,2]}"
          gg="${hex[3,4]}"
          bb="${hex[5,6]}"
          aa="FF"
          ;;
        8)
          rr="${hex[1,2]}"
          gg="${hex[3,4]}"
          bb="${hex[5,6]}"
          aa="${hex[7,8]}"
          ;;
        *)
          return 1
          ;;
      esac
      ;;
  esac

  typeset -g JOBS_COR_R="$(jobs_cor_hex_to_dec "$rr")"
  typeset -g JOBS_COR_G="$(jobs_cor_hex_to_dec "$gg")"
  typeset -g JOBS_COR_B="$(jobs_cor_hex_to_dec "$bb")"
  typeset -g JOBS_COR_AA_HEX="$aa"
  typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_alpha_255_to_float "$(jobs_cor_hex_to_dec "$aa")")"
  return 0
}

# ---------- 色块输出 ----------
jobs_cor_show_block_line() {
  emulate -L zsh

  local rr="$1" gg="$2" bb="$3" label="$4" fg_rgb fg_code idx

  if jobs_cor_supports_truecolor; then
    fg_rgb="$(jobs_cor_pick_fg_rgb "$rr" "$gg" "$bb")"
    printf "\033[48;2;%d;%d;%dm" "$rr" "$gg" "$bb"
    printf "\033[38;2;%sm" "$fg_rgb"
  else
    idx="$(jobs_cor_rgb_to_ansi256 "$rr" "$gg" "$bb")"
    fg_code="$(jobs_cor_pick_fg_code "$rr" "$gg" "$bb")"
    printf "\033[48;5;%sm" "$idx"
    printf "\033[%sm" "$fg_code"
  fi

  printf "  %-30s  " "$label"
  printf "\033[0m\n"
}

jobs_cor_show_block() {
  emulate -L zsh

  local rr="$1" gg="$2" bb="$3" hex="$4"
  printf "\n"
  jobs_cor_show_block_line "$rr" "$gg" "$bb" "${hex}"
  jobs_cor_show_block_line "$rr" "$gg" "$bb" "RGB ${rr}, ${gg}, ${bb}"
  jobs_cor_show_block_line "$rr" "$gg" "$bb" "终端色块预览"
  printf "\n"
  if jobs_cor_supports_truecolor; then
    printf "前景色预览：\033[38;2;%d;%d;%dm%s\033[0m\n" "$rr" "$gg" "$bb" "${hex} 文字颜色"
  else
    local idx
    idx="$(jobs_cor_rgb_to_ansi256 "$rr" "$gg" "$bb")"
    printf "前景色预览：\033[38;5;%sm%s\033[0m\n" "$idx" "${hex} 文字颜色"
  fi
}

# ---------- 解析输入 ----------
jobs_cor_parse_rgb_parts() {
  emulate -L zsh

  local body="$1" R G B A A255
  local -a parts
  parts=("${(@s:,:)body}")

  R="${parts[1]:-}"
  G="${parts[2]:-}"
  B="${parts[3]:-}"
  A="${parts[4]:-1}"

  [[ -n "$R" && -n "$G" && -n "$B" ]] || return 1
  (( ${#parts} == 3 || ${#parts} == 4 )) || return 1

  R="${R%%.*}"
  G="${G%%.*}"
  B="${B%%.*}"

  if ! [[ "$R" =~ '^[0-9]+$' && "$G" =~ '^[0-9]+$' && "$B" =~ '^[0-9]+$' ]]; then
    return 1
  fi

  if (( R < 0 || R > 255 || G < 0 || G > 255 || B < 0 || B > 255 )); then
    return 1
  fi

  if ! [[ "$A" =~ '^([0-9]+([.][0-9]+)?|[.][0-9]+)$' ]]; then
    return 1
  fi

  typeset -g JOBS_COR_R="$R"
  typeset -g JOBS_COR_G="$G"
  typeset -g JOBS_COR_B="$B"
  typeset -g JOBS_COR_A_FLOAT="$(jobs_cor_clamp_alpha_float "$A")"
  A255="$(jobs_cor_alpha_float_to_255 "$JOBS_COR_A_FLOAT")"
  typeset -g JOBS_COR_AA_HEX="$(jobs_cor_to_hex "$A255")"
  return 0
}

jobs_cor_parse_input() {
  emulate -L zsh

  local raw="$1" input hex body
  input="$(jobs_cor_sanitize_input "$raw")"
  [[ -n "$input" ]] || return 1

  # 0xAARRGGBB / 0xRRGGBB
  if [[ "$input" =~ '^0[xX][0-9a-fA-F]{6}$' ]]; then
    hex="${input[3,-1]}"
    jobs_cor_set_globals_from_hex "$hex" "RRGGBB"
    return $?
  fi

  if [[ "$input" =~ '^0[xX][0-9a-fA-F]{8}$' ]]; then
    hex="${input[3,-1]}"
    jobs_cor_set_globals_from_hex "$hex" "AARRGGBB"
    return $?
  fi

  # #RGB / #RGBA / #RRGGBB / #RRGGBBAA
  if [[ "$input" == \#* ]]; then
    hex="${input[2,-1]}"
    jobs_cor_is_hex "$hex" || return 1
    jobs_cor_set_globals_from_hex "$hex"
    return $?
  fi

  # 裸 HEX：RGB / RGBA / RRGGBB / RRGGBBAA
  if jobs_cor_is_hex "$input"; then
    jobs_cor_set_globals_from_hex "$input"
    return $?
  fi

  # rgb(...) / rgba(...)
  if [[ "$input" =~ '^rgb\(.+\)$' ]]; then
    body="$(print -r -- "$input" | sed -E 's/^rgb\((.*)\)$/\1/')"
    jobs_cor_parse_rgb_parts "$body"
    return $?
  fi

  if [[ "$input" =~ '^rgba\(.+\)$' ]]; then
    body="$(print -r -- "$input" | sed -E 's/^rgba\((.*)\)$/\1/')"
    jobs_cor_parse_rgb_parts "$body"
    return $?
  fi

  return 1
}

# ---------- 输出 ----------
jobs_cor_format_and_print_all() {
  emulate -L zsh

  local raw="$1" RR GG BB AA HEX6 HEX8
  RR="$(jobs_cor_to_hex "$JOBS_COR_R")"
  GG="$(jobs_cor_to_hex "$JOBS_COR_G")"
  BB="$(jobs_cor_to_hex "$JOBS_COR_B")"
  AA="$JOBS_COR_AA_HEX"
  HEX6="#${RR}${GG}${BB}"
  HEX8="#${RR}${GG}${BB}${AA}"

  printf "\n\033[1m输入：%s\033[0m\n" "$raw"
  printf "%s\n" "----------------------------------------"
  printf "HEX（不透明）:  %s\n" "$HEX6"
  printf "HEX（含透明） :  %s\n" "$HEX8"
  printf "RGB           :  rgb(%d, %d, %d)\n" "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B"
  printf "RGBA          :  rgba(%d, %d, %d, %.2f)\n" "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B" "$JOBS_COR_A_FLOAT"
  printf "0xAARRGGBB    :  0x%s%s%s%s\n" "$AA" "$RR" "$GG" "$BB"
  if jobs_cor_supports_truecolor; then
    printf "终端支持      :  24-bit True Color\n"
  else
    printf "终端支持      :  ANSI 256 色近似\n"
  fi
  jobs_cor_show_block "$JOBS_COR_R" "$JOBS_COR_G" "$JOBS_COR_B" "$HEX6"
  printf "\n"
}

jobs_cor_print_title() {
  emulate -L zsh

  local c reset=$'\033[0m'
  c="$(jobs_cor_title_color)"
  printf "%b================== 颜色格式转换器 ==================%b\n" "$c" "$reset"
  printf "%b支持：#RGB / #RRGGBB / #RRGGBBAA / rgb() / rgba() / 0xAARRGGBB%b\n" "$c" "$reset"
  printf "%b输出：HEX / RGB / RGBA / 0x，并显示终端色块预览%b\n" "$c" "$reset"
  printf "\n"
}

jobs_cor_convert_once() {
  emulate -L zsh

  local user_input="$1"
  if jobs_cor_parse_input "$user_input"; then
    jobs_cor_format_and_print_all "$user_input"
  else
    print -P "%F{red}❌ 无法识别：$user_input%f"
    print -r -- "示例：#D2D4DE、D2D4DE、#ABC、rgb(210,212,222)、rgba(210,212,222,0.5)、0x80D2D4DE"
    return 1
  fi
}

jobs_cor_interactive_loop() {
  emulate -L zsh

  local user_input
  while true; do
    read -r "user_input?请输入颜色值（q 退出）： " || {
      printf "\n"
      break
    }

    [[ -z "$user_input" ]] && continue

    case "$user_input" in
      q|Q|quit|QUIT|exit|EXIT)
        print -P "%F{green}✅ 已退出 cor%f"
        break
        ;;
    esac

    jobs_cor_convert_once "$user_input"
  done
}

cor() {
  emulate -L zsh

  jobs_cor_print_title

  if (( $# > 0 )); then
    local failed=0 user_input
    for user_input in "$@"; do
      jobs_cor_convert_once "$user_input" || failed=1
    done
    return "$failed"
  fi

  jobs_cor_interactive_loop
}

# ---------- 主流程统一收口 ----------
jobs_cor_main() {
  jobs_cor_show_readme_and_wait
  cor "$@"
}

if [[ "${JOBS_MAC_ENV_SOURCE_MODE:-}" != "1" ]]; then
  jobs_cor_main "$@"
fi
