#!/bin/zsh

# >>> Jobs terminal style protection v1 >>>
# 临时保护当前终端配色，业务进程自行管理原有退出清理。
jobs_terminal_style_run() {
    # 无法可靠保存原色时，沿用脚本已有的纯文本约定。
    jobs_terminal_style_plain() {
        PLAIN_OUTPUT=1
        NO_COLOR=1
        FORCE_COLOR=0
        CLICOLOR=0
        ANSI_COLORS_DISABLED=1
        npm_config_color=false
        export PLAIN_OUTPUT NO_COLOR FORCE_COLOR CLICOLOR ANSI_COLORS_DISABLED npm_config_color
        if "$@"; then
            jobs_style_exit_status=0
        else
            jobs_style_exit_status=$?
        fi
        exit "$jobs_style_exit_status"
    }
    if [ ! -t 0 ] || [ ! -t 1 ] || [ -z "${TERM:-}" ] ||
       [ "${TERM:-}" = dumb ] || [ "${NO_COLOR+x}" = x ] ||
       [ "${PLAIN_OUTPUT:-0}" = 1 ] || [ "${IS_SOURCETREE_RUNTIME:-0}" = 1 ] ||
       env | LC_ALL=C grep -qiE '^(SOURCETREE|SOURCE_TREE)'; then
        if "$@"; then
            jobs_style_exit_status=0
        else
            jobs_style_exit_status=$?
        fi
        exit "$jobs_style_exit_status"
    fi
    if [ -n "${TMUX:-}${STY:-}" ]; then
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_tty=$(tty 2>/dev/null) || jobs_terminal_style_plain "$@"
    if ! ps -o pgid= -o tpgid= -p "$$" 2>/dev/null |
         LC_ALL=C awk 'NF == 2 && $1 == $2 && $1 > 0 { foreground = 1 } END { exit !foreground }'; then
        jobs_terminal_style_plain "$@"
    fi
    case ${JOBS_TERMINAL_STYLE_OWNER:-} in
        ''|*[!0-9]*) ;;
        *)
            if [ "${JOBS_TERMINAL_STYLE_TTY:-}" = "$jobs_style_tty" ] &&
               kill -0 "$JOBS_TERMINAL_STYLE_OWNER" 2>/dev/null; then
                if "$@"; then
                    jobs_style_exit_status=0
                else
                    jobs_style_exit_status=$?
                fi
                exit "$jobs_style_exit_status"
            fi
            ;;
    esac
    jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_terminal_style_plain "$@"
    jobs_style_saved=''
    jobs_style_saved_rows=''
    jobs_style_applied_rows=''
    jobs_style_changed=0
    jobs_style_applied_complete=0
    jobs_style_query_active=0
    jobs_style_recovery=''
    jobs_style_exit_status=0
    jobs_style_esc=$(printf '\033')
    jobs_style_bel=$(printf '\007')
    # 只接受本次请求对应的 RGB 响应；非协议输入使本次探测失败。
    jobs_terminal_style_query() {
        jobs_style_query_key=$1
        printf '\033]%s;?\007' "$jobs_style_query_key" > /dev/tty || return 1
        jobs_style_reply=''
        for jobs_style_attempt in 1 2 3; do
            jobs_style_piece=$(dd bs=256 count=1 2>/dev/null < /dev/tty)
            jobs_style_reply=$jobs_style_reply$jobs_style_piece
            case $jobs_style_reply in
                *"$jobs_style_bel"|*"$jobs_style_esc\\") break ;;
                '') ;;
                "$jobs_style_esc"*) ;;
                *) break ;;
            esac
        done
        case $jobs_style_reply in
            "$jobs_style_esc]$jobs_style_query_key;rgb:"*"$jobs_style_bel")
                jobs_style_rgb=${jobs_style_reply#"$jobs_style_esc]$jobs_style_query_key;rgb:"}
                jobs_style_rgb=${jobs_style_rgb%"$jobs_style_bel"}
                ;;
            "$jobs_style_esc]$jobs_style_query_key;rgb:"*"$jobs_style_esc\\")
                jobs_style_rgb=${jobs_style_reply#"$jobs_style_esc]$jobs_style_query_key;rgb:"}
                jobs_style_rgb=${jobs_style_rgb%"$jobs_style_esc\\"}
                ;;
            *) return 1 ;;
        esac
        jobs_style_normalized=$(printf '%s\n' "$jobs_style_rgb" | LC_ALL=C awk -F/ '
            NF != 3 { exit 1 }
            {
                for (i = 1; i <= 3; i++) {
                    h = tolower($i)
                    if (length(h) < 1 || length(h) > 4 || h ~ /[^0-9a-f]/) exit 1
                    n = 0
                    for (j = 1; j <= length(h); j++) n = n * 16 + index("0123456789abcdef", substr(h, j, 1)) - 1
                    value[i] = int(n * 65535 / (16 ^ length(h) - 1) + 0.5)
                }
                printf "%d/%d/%d", value[1], value[2], value[3]
            }
        ') || return 1
        [ -n "$jobs_style_normalized" ]
    }
    # 查询可用不代表终端允许改色，按目标值核对实际生效结果。
    jobs_terminal_style_accepts_target() {
        jobs_style_requested_hex=''
        case $1 in
            10|12) jobs_style_requested_hex=ffffff ;;
            11) jobs_style_requested_hex=000000 ;;
            '4;'*)
                jobs_style_requested_index=0
                for jobs_style_requested_color in 000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff; do
                    if [ "4;$jobs_style_requested_index" = "$1" ]; then
                        jobs_style_requested_hex=$jobs_style_requested_color
                        break
                    fi
                    jobs_style_requested_index=$((jobs_style_requested_index + 1))
                done
                ;;
        esac
        [ -n "$jobs_style_requested_hex" ] || return 1
        printf '%s|%s\n' "$jobs_style_normalized" "$jobs_style_requested_hex" | LC_ALL=C awk -F'|' '
            function hexbyte(h) {
                return (index("0123456789abcdef", substr(h, 1, 1)) - 1) * 16 + index("0123456789abcdef", substr(h, 2, 1)) - 1
            }
            {
                if (split($1, actual, "/") != 3 || length($2) != 6) exit 1
                for (i = 1; i <= 3; i++) {
                    difference = actual[i] - hexbyte(substr($2, i * 2 - 1, 2)) * 257
                    if (difference < -255 || difference > 255) exit 1
                }
            }
        '
    }
    # 检测到后续改色时只恢复仍由本次保护持有的项，保留独立恢复入口。
    jobs_terminal_style_cleanup() {
        jobs_style_result=$1
        trap '' HUP INT TERM
        if [ "$jobs_style_query_active" = 1 ]; then
            stty "$jobs_style_stty" 2>/dev/null < /dev/tty || :
            jobs_style_query_active=0
        fi
        if [ "$jobs_style_changed" = 1 ]; then
            jobs_style_cleanup_ok=0
            jobs_style_conflicts=''
            jobs_style_restore_safe=''
            if [ "$jobs_style_applied_complete" = 1 ]; then
                jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_style_stty=''
                if [ -n "$jobs_style_stty" ] && stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
                    jobs_style_query_active=1
                    jobs_style_cleanup_ok=1
                    while IFS='|' read -r jobs_style_key jobs_style_expected jobs_style_original; do
                        [ -n "$jobs_style_key" ] || continue
                        if ! jobs_terminal_style_query "$jobs_style_key"; then
                            jobs_style_cleanup_ok=0
                            break
                        fi
                        if [ "$jobs_style_normalized" = "$jobs_style_expected" ]; then
                            jobs_style_restore_safe=$jobs_style_restore_safe$jobs_style_original
                        else
                            jobs_style_conflicts="$jobs_style_conflicts $jobs_style_key"
                        fi
                    done <<JOBS_STYLE_APPLIED
$jobs_style_applied_rows
JOBS_STYLE_APPLIED
                    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || jobs_style_cleanup_ok=0
                    jobs_style_query_active=0
                fi
            fi
            if [ "$jobs_style_cleanup_ok" = 1 ] && printf '%s\033[0m' "$jobs_style_restore_safe" > /dev/tty; then
                if [ -z "$jobs_style_conflicts" ]; then
                    rm -f "$jobs_style_recovery"
                    rmdir "${jobs_style_recovery%/*}" 2>/dev/null || :
                else
                    printf '检测到运行期间的配色变更，已保留这些项：%s\n' "$jobs_style_conflicts" >&2
                    printf '确认要覆盖后续改色时才使用恢复入口：sh "%s"\n' "$jobs_style_recovery" >&2
                    [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
                fi
            else
                printf '终端配色未能安全自动恢复；确认覆盖当前配色后可运行：sh "%s"\n' "$jobs_style_recovery" >&2
                [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
            fi
        fi
        if [ "${2:-}" = continue ]; then
            jobs_style_cleanup_status=$jobs_style_result
            return 0
        fi
        exit "$jobs_style_result"
    }
    trap 'jobs_terminal_style_cleanup "$jobs_style_exit_status"' 0
    trap 'jobs_style_exit_status=129; exit 129' HUP
    trap 'jobs_style_exit_status=130; exit 130' INT
    trap 'jobs_style_exit_status=143; exit 143' TERM
    if ! stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_query_active=1
    jobs_style_probe_ok=1
    for jobs_style_key in 10 11 12 '4;0' '4;1' '4;2' '4;3' '4;4' '4;5' '4;6' '4;7' '4;8' '4;9' '4;10' '4;11' '4;12' '4;13' '4;14' '4;15'; do
        if ! jobs_terminal_style_query "$jobs_style_key"; then
            jobs_style_probe_ok=0
            break
        fi
        jobs_style_saved=$jobs_style_saved$jobs_style_reply
        jobs_style_saved_rows="$jobs_style_saved_rows$jobs_style_key|$jobs_style_reply
"
    done
    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=0
    if [ "$jobs_style_probe_ok" != 1 ]; then
        printf '%s\n' '终端不支持完整配色保存，或启动时收到其它输入；保留原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_recovery_dir=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/jobs-terminal-style.XXXXXX") || jobs_terminal_style_plain "$@"
    jobs_style_recovery=$jobs_style_recovery_dir/restore.sh
    if ! (umask 077; {
        printf '#!/bin/sh\n'
        printf '[ -t 0 ] && [ "$(tty)" = '\''%s'\'' ] || { printf '\''请在原终端运行恢复入口。\\n'\'' >&2; exit 1; }\n' "$jobs_style_tty"
        printf 'printf '\''本操作会覆盖此终端当前配色。确认恢复脚本启动前的配色，请输入 YES：'\'' >&2\n'
        printf 'IFS= read -r jobs_restore_choice\n[ "$jobs_restore_choice" = YES ] || exit 1\n'
        printf 'printf '\''%%s\\033[0m'\'' '\''%s'\'' > /dev/tty\n' "$jobs_style_saved"
    } > "$jobs_style_recovery"); then
        printf '%s\n' '无法保存终端配色恢复入口；保留原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    printf '正在准备本次终端临时配色；强退后恢复入口：sh "%s"\n' "$jobs_style_recovery" >&2
    jobs_style_changed=1
    printf '\033]10;#ffffff\007\033]11;#000000\007\033]12;#ffffff\007' > /dev/tty
    jobs_style_index=0
    for jobs_style_color in 000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff; do
        printf '\033]4;%s;#%s\007' "$jobs_style_index" "$jobs_style_color" > /dev/tty
        jobs_style_index=$((jobs_style_index + 1))
    done
    printf '\033[0m' > /dev/tty
    jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || { jobs_style_exit_status=1; exit 1; }
    stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=1
    jobs_style_probe_ok=1
    jobs_style_targets_ok=1
    while IFS='|' read -r jobs_style_key jobs_style_original; do
        [ -n "$jobs_style_key" ] || continue
        if ! jobs_terminal_style_query "$jobs_style_key"; then
            jobs_style_probe_ok=0
            break
        fi
        jobs_style_applied_rows="$jobs_style_applied_rows$jobs_style_key|$jobs_style_normalized|$jobs_style_original
"
        if ! jobs_terminal_style_accepts_target "$jobs_style_key"; then
            jobs_style_targets_ok=0
        fi
    done <<JOBS_STYLE_ORIGINAL
$jobs_style_saved_rows
JOBS_STYLE_ORIGINAL
    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=0
    if [ "$jobs_style_probe_ok" != 1 ]; then
        printf '%s\n' '无法核实本次临时配色，已停止启动业务。' >&2
        jobs_style_exit_status=1
        exit 1
    fi
    jobs_style_applied_complete=1
    if [ "$jobs_style_targets_ok" != 1 ]; then
        jobs_terminal_style_cleanup 0 continue
        jobs_style_changed=0
        if [ "$jobs_style_cleanup_status" != 0 ]; then
            jobs_style_exit_status=1
            exit 1
        fi
        trap 'jobs_style_exit_status=129; exit 129' HUP
        trap 'jobs_style_exit_status=130; exit 130' INT
        trap 'jobs_style_exit_status=143; exit 143' TERM
        printf '%s\n' '终端未接受本次配色，已恢复原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    printf '%s\n' '本次终端已临时使用黑底白字。' >&2
    JOBS_TERMINAL_STYLE_TTY=$jobs_style_tty
    JOBS_TERMINAL_STYLE_OWNER=$$
    export JOBS_TERMINAL_STYLE_TTY JOBS_TERMINAL_STYLE_OWNER
    if "$@"; then
        jobs_style_exit_status=0
    else
        jobs_style_exit_status=$?
    fi
    exit "$jobs_style_exit_status"
}
# 仅监督直接执行的入口；被 source 时不切换配色、不重新执行业务。
jobs_terminal_style_bootstrap() {
    jobs_style_bootstrap_script=$1
    shift
    if [ -n "${ZSH_VERSION:-}" ]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file|*:file:*) return 0 ;;
        esac
    elif [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE:-$jobs_style_bootstrap_script}" != "$jobs_style_bootstrap_script" ]; then
        return 0
    fi
    if [ "${JOBS_TERMINAL_STYLE_REEXEC:-}" = "$jobs_style_bootstrap_script" ]; then
        unset JOBS_TERMINAL_STYLE_REEXEC
        return 0
    fi
    if [ ! -t 0 ] || [ ! -t 1 ] || [ -z "${TERM:-}" ] ||
       [ "${TERM:-}" = dumb ] || [ "${NO_COLOR+x}" = x ] ||
       [ "${PLAIN_OUTPUT:-0}" = 1 ] || [ "${IS_SOURCETREE_RUNTIME:-0}" = 1 ] ||
       [ -n "${TMUX:-}${STY:-}" ] ||
       env | LC_ALL=C grep -qiE '^(SOURCETREE|SOURCE_TREE)'; then
        return 0
    fi
    case ${JOBS_TERMINAL_STYLE_OWNER:-} in
        ''|*[!0-9]*) ;;
        *)
            if kill -0 "$JOBS_TERMINAL_STYLE_OWNER" 2>/dev/null &&
               [ "${JOBS_TERMINAL_STYLE_TTY:-}" = "$(tty 2>/dev/null)" ]; then
                return 0
            fi
            ;;
    esac
    JOBS_TERMINAL_STYLE_REEXEC=$jobs_style_bootstrap_script
    export JOBS_TERMINAL_STYLE_REEXEC
    jobs_terminal_style_run /bin/zsh "$jobs_style_bootstrap_script" "$@"
    jobs_style_bootstrap_result=$?
    exit "$jobs_style_bootstrap_result"
}
jobs_terminal_style_bootstrap "$0" "$@"
# <<< Jobs terminal style protection v1 <<<



# 仅渲染自述：标题红色加粗，编号正文蓝色常规字重；非彩色终端输出纯文本。
# JOBS_FLUTTER_NETWORK_ADAPTER_BEGIN
# 捕获真实入口参数；后续切换工程目录不影响随包模块定位。
# JOBS_INPUT_CHOICE_STYLE_BEGIN
# 只展示提示选项；不读取答案、不改变默认值、返回码或业务环境。
jobs_prompt_color_ready() {
  [ -z "${NO_COLOR+x}" ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
    [ "${PLAIN_OUTPUT:-0}" != 1 ] && [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]
}
# 原生 awk 分段着色；任意/非空输入优先，括号内外沿用同一个选项。
jobs_prompt_format() {
  /usr/bin/awk -v color="${1:-0}" -v lines="${2:-0}" -v keep="${3:-0}" '
    function typedEnter(value, start, prefix) {
      prefix = substr(value, 1, start - 1)
      gsub(/[“”‘’「」『』"]/, "", prefix)
      gsub(sprintf("%c", 39), "", prefix)
      if (prefix ~ /(空格|[Ss][Pp][Aa][Cc][Ee])[[:space:]]*(后|再|并|[Tt][Hh][Ee][Nn])?[[:space:]]*$/) return 1
      return prefix ~ /(输入|键入|填写|[Tt]ype)[^；;|]*[[:alnum:]_+-]+[[:space:]]*(后|再|并)?[[:space:]]*$/
    }
    function greenPosition(value, token, start) {
      if (match(value, /(直接|仅|只需|只|按下|按)?[[:space:]]*(回车|回車)/)) {
        start = RSTART
        return typedEnter(value, start) ? 0 : start
      }
      if (!match(value, /(^|[^[:alnum:]_])([Ee][Nn][Tt][Ee][Rr]|[Rr][Ee][Tt][Uu][Rr][Nn])([^[:alnum:]_]|$)/)) return 0
      start = RSTART
      token = substr(value, RSTART, RLENGTH)
      match(token, /[Ee][Nn][Tt][Ee][Rr]|[Rr][Ee][Tt][Uu][Rr][Nn]/)
      start += RSTART - 1
      return typedEnter(value, start) ? 0 : start
    }
    function segment(value, inherited, start, kind, prefix, body, red, green, connector, left, right, splitAt) {
      if (value == "") return value
      kind = inherited
      start = 1
      if (!kind) {
        if (match(value, /(输入)?(任意|任何)(非空)?(字符|内容|输入|键)|非空(字符|内容|输入)?|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key/)) {
          red = RSTART
        }
        green = greenPosition(value)
        if (red && green && green < red) {
          left = substr(value, 1, red - 1)
          right = substr(value, red)
          connector = ""
          if (match(left, /(或者|或)[[:space:]]*$/)) {
            connector = substr(left, RSTART)
            left = substr(left, 1, RSTART - 1)
          }
          return segment(left, 0) connector segment(right, 31)
        }
        if (red && green && red < green && match(value, /或[[:space:]]*(直接|仅|只需|只|按下|按)?(回车|回車)/)) {
          splitAt = RSTART
          return segment(substr(value, 1, splitAt - 1), 31) "或" segment(substr(value, splitAt + length("或")), 0)
        }
        if (red) {
          kind = 31
          start = red
        } else if (green) {
          kind = 32
          start = green
        }
      }
      if (!kind || !color) return value
      prefix = substr(value, 1, start - 1)
      body = substr(value, start)
      return prefix esc "[1;" kind "m" body esc "[0m"
    }
    function render(value, output, part, boundary, inherited, kind, consumed, depth, original) {
      original = value
      gsub(esc "\\[[0-9;]*m", "", value)
      if (color && keep && !greenPosition(value) && value !~ /(任意|任何|非空|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key)/) return original
      output = ""
      inherited = 0
      depth = 0
      while (match(value, /[；;\/|，,、？?：:=＝（）()\[\]【】]/)) {
        part = substr(value, 1, RSTART - 1)
        boundary = substr(value, RSTART, RLENGTH)
        consumed = RSTART + RLENGTH
        output = output segment(part, inherited) boundary
        if (boundary ~ /[（(\[【]/) {
          depth++
          if (part ~ /(任意|任何|非空|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key)/) inherited = 31
          else if (greenPosition(part)) inherited = 32
        } else if (boundary ~ /[）)\]】]/) {
          if (depth) depth--
        } else if (boundary ~ /[：:=＝]/) {
          if (!inherited) {
            if (part ~ /(任意|任何|非空|其它输入|其他输入)/) inherited = 31
            else if (greenPosition(part)) inherited = 32
          }
        } else if (!depth) inherited = 0
        value = substr(value, consumed)
      }
      return output segment(value, inherited)
    }
    BEGIN { esc = sprintf("%c", 27); first = 1 }
    {
      if (lines == 2) {
        if (!first) printf "%s\n", render(pending)
        pending = $0
        first = 0
        next
      }
      if (!lines && !first) printf "\n"
      printf "%s", render($0)
      if (lines) printf "\n"
      first = 0
    }
    END {
      if (lines == 2 && !first) {
        sub(sprintf("%c", 1) "$", "", pending)
        printf "%s", render(pending)
      }
    }
  '
}
# read 的命令替换会使 stdout 成为管道，按输入与提示所在 stderr 判断终端。
jobs_prompt_render() {
  local jobs_prompt_color=0
  if [ -t 0 ] && [ -t 2 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  printf "%s" "$1" | jobs_prompt_format "$jobs_prompt_color" 0
}
# 仅放在显示链末端；tee 在此函数之前接收纯文本，不把 ANSI 写入日志。
jobs_prompt_stream() {
  local jobs_prompt_color=0
  if [ -t 1 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  jobs_prompt_format "$jobs_prompt_color" 1 1
}
# 显示管道保留原末尾换行；只删除本轮追加的最后一个结束标记。
jobs_prompt_filter() {
  local jobs_prompt_color=0
  if [ -t 1 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  { /bin/cat; printf '\001'; } | jobs_prompt_format "$jobs_prompt_color" 2 1
}
# 仅包装原 printf/echo/print 展示，原参数、尾换行与显示命令退出码保持不变。
jobs_prompt_output() {
  local jobs_prompt_status=0 jobs_prompt_stderr=0 jobs_prompt_arg="" jobs_prompt_previous=""
  if [ "${1:-}" = print ]; then
    for jobs_prompt_arg in "$@"; do
      case "$jobs_prompt_arg" in -?*u2*|-u2) jobs_prompt_stderr=1 ;; esac
      if [ "$jobs_prompt_previous" = -u ] && [ "$jobs_prompt_arg" = 2 ]; then jobs_prompt_stderr=1; fi
      jobs_prompt_previous="$jobs_prompt_arg"
      [ "$jobs_prompt_arg" != -- ] || break
    done
  fi
  if [ -n "${ZSH_VERSION:-}" ]; then
    if [ "$jobs_prompt_stderr" = 1 ]; then
      "$@" 2>&1 | jobs_prompt_filter >&2
      jobs_prompt_status=$(( ${pipestatus[1]} != 0 ? ${pipestatus[1]} : ${pipestatus[2]} ))
    else
      "$@" | jobs_prompt_filter
      jobs_prompt_status=$(( ${pipestatus[1]} != 0 ? ${pipestatus[1]} : ${pipestatus[2]} ))
    fi
  elif [ -n "${BASH_VERSION:-}" ]; then
    "$@" | jobs_prompt_filter
    jobs_prompt_status=$(( ${PIPESTATUS[0]} != 0 ? ${PIPESTATUS[0]} : ${PIPESTATUS[1]} ))
  else
    "$@" | jobs_prompt_filter
    jobs_prompt_status=$?
  fi
  return "$jobs_prompt_status"
}
# 仅替换日志 primitive 的 tee：磁盘同步追加纯文，终端保留非选项原色。
jobs_prompt_tee() {
  local jobs_prompt_log="$1" jobs_prompt_line="" jobs_prompt_newline=0
  while :; do
    jobs_prompt_line=""
    if IFS= read -r jobs_prompt_line; then jobs_prompt_newline=1; else jobs_prompt_newline=0; [ -n "$jobs_prompt_line" ] || break; fi
    if [ "$jobs_prompt_newline" = 1 ]; then
      { printf '%s\n' "$jobs_prompt_line"; printf '\001'; } | jobs_prompt_format 0 2 >> "$jobs_prompt_log" || return $?
      printf '%s\n' "$jobs_prompt_line" | jobs_prompt_filter || return $?
    else
      { printf '%s' "$jobs_prompt_line"; printf '\001'; } | jobs_prompt_format 0 2 >> "$jobs_prompt_log" || return $?
      printf '%s' "$jobs_prompt_line" | jobs_prompt_filter || return $?
    fi
  done
}
# JOBS_INPUT_CHOICE_STYLE_END

JOBS_FLUTTER_NETWORK_ENTRY_FILE=$0
JOBS_FLUTTER_NETWORK_ENTRY_BASE=$PWD
JOBS_FLUTTER_NETWORK_TASK_CACHE=
JOBS_FLUTTER_NETWORK_TASK_LOG=
# 只把SDK命令交给随包子进程，不把代理或源写回当前Shell。
jobs_flutter_sdk_command() {
    local entry=$JOBS_FLUTTER_NETWORK_ENTRY_FILE link= directory= adapter= network= count=0
    case "$entry" in
        /*) ;;
        *) entry=$JOBS_FLUTTER_NETWORK_ENTRY_BASE/$entry ;;
    esac
    while [ -L "$entry" ]; do
        count=$((count + 1))
        [ "$count" -lt 40 ] || return 1
        link=$(readlink "$entry") || return 1
        case "$link" in
            /*) entry=$link ;;
            *) entry=$(dirname -- "$entry")/$link ;;
        esac
    done
    directory=$(CDPATH= cd -P -- "$(dirname -- "$entry")" && pwd) || return 1
    adapter=$directory/Scripts/【MacOS】FlutterSDK命令适配.sh/【MacOS】FlutterSDK命令适配.sh
    network=$directory/Scripts/【MacOS】FlutterSDK网络选路.zsh/【MacOS】FlutterSDK网络选路.zsh
    [ -f "$adapter" ] && [ -f "$network" ] || {
        printf '%s\n' '✖ 缺少随包SDK网络资源；请保留入口旁完整Scripts目录。' >&2
        return 1
    }
    if [ -z "$JOBS_FLUTTER_NETWORK_TASK_CACHE" ]; then
        JOBS_FLUTTER_NETWORK_TASK_CACHE=$(/bin/zsh "$network" --cache-dir) || return $?
        JOBS_FLUTTER_NETWORK_TASK_LOG=$JOBS_FLUTTER_NETWORK_TASK_CACHE/entry-network.log
    fi
    JOBS_FLUTTER_ROUTE_CACHE_DIR="$JOBS_FLUTTER_NETWORK_TASK_CACHE" \
    JOBS_FLUTTER_ROUTE_LOG="$JOBS_FLUTTER_NETWORK_TASK_LOG" \
        /bin/sh "$adapter" "$@"
}
# 既有选择值仅接受原来的两个Flutter执行器，不eval用户字符串。
jobs_flutter_sdk_selected() {
    local selected=$1
    shift
    case "$selected" in
        'fvm flutter') jobs_flutter_sdk_command fvm flutter "$@" ;;
        flutter) jobs_flutter_sdk_command flutter "$@" ;;
        *) printf '%s\n' '✖ 未识别原Flutter执行器，未执行任何SDK或业务。' >&2; return 2 ;;
    esac
}
# JOBS_FLUTTER_NETWORK_ADAPTER_END

jobs_intro_style() {
  local intro_color=0
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
     [ -z "${NO_COLOR+x}" ] && [ "${PLAIN_OUTPUT:-0}" != 1 ] &&
     [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]; then
    intro_color=1
  fi
  /usr/bin/awk -v color="$intro_color" -v role="${1:-body}" '
    BEGIN { esc = sprintf("%c", 27) }
    {
      gsub(esc "\\[[0-9;]*m", "")
      gsub(/\\(033|e|x1[bB])\[[0-9;]*m/, "")
      if (!color || $0 ~ /^[[:space:]]*$/) { print; next }
      numbered = ($0 ~ /^[[:space:]➤ℹ🔹✔⚠]*([0-9]+[、.)）]|[0-9]+️⃣|[-•])/)
      heading = ($0 ~ /^[[:space:]]*#{1,6}[[:space:]]/ || $0 ~ /[：:][[:space:]]*$/ || $0 ~ /^[[:space:]]*[=━─-]{3}/)
      title = (!numbered && (role == "title" || heading))
      if (role == "auto" && !seen && !numbered) title = 1
      if ($0 !~ /^[[:space:]]*[=━─-]+[[:space:]]*$/) seen = 1
      printf "%s%s%s\n", esc (title ? "[1;31m" : "[0;34m"), $0, esc "[0m"
    }
  '
}
set -euo pipefail
setopt NO_NOMATCH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME="$(basename "$0" | sed 's/\.[^.]*$//')"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE"

SELECT_MODE=0
RUN_PUB_GET=1
INPUT_PROJECT=""
PROJECT_ROOT=""
PROJECT_NAME=""
FLUTTER_CMD=()
PACKAGE_CONFIG=""
ZIP_PATH=""
TMP_PARENT=""
STAGE_NAME=""
STAGE=""
ALL_DEPS_TSV=""
SELECTED_DEPS_TSV=""
TOTAL_COUNT=0
SELECTED_COUNT=0

# 同步输出终端信息与日志文件。
log()            { print -r -- "$1" | jobs_prompt_tee "$LOG_FILE"; }
# 输出普通绿色信息。
color_echo()     { log "\033[1;32m$1\033[0m"; }
# 输出蓝色提示信息。
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
# 输出绿色成功信息。
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
# 输出黄色警告信息。
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
# 输出黄色温馨提示。
warm_echo()      { log "\033[1;33m$1\033[0m"; }
# 输出紫色说明信息。
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
# 输出红色错误信息。
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
# 输出红色纯文本信息。
err_echo()       { log "\033[1;31m$1\033[0m"; }
# 输出紫色调试信息。
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
# 输出青色高亮信息。
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
# 输出灰色次要信息。
gray_echo()      { log "\033[0;90m$1\033[0m"; }
# 输出加粗信息。
bold_echo()      { log "\033[1m$1\033[0m"; }
# 输出下划线信息。
underline_echo() { log "\033[4m$1\033[0m"; }

# 输出错误并终止脚本。
fail() {
  error_echo "$1"
  exit 1
}

# 展示命令行参数说明。
usage() {
  cat <<'USAGE' | jobs_prompt_filter
用法：
  ./pack_flutter_deps_macos.command
  ./pack_flutter_deps_macos.command --select
  ./pack_flutter_deps_macos.command /path/to/app
  ./pack_flutter_deps_macos.command --no-pub-get

参数：
  -s, --select       使用 fzf 多选 Dart / Flutter 依赖
  --no-pub-get       不询问执行 flutter pub get，直接使用现有解析文件
  -h, --help         显示帮助
USAGE
}

# 解析命令行参数并拒绝未知或重复的项目路径。
parse_arguments() {
  while (( $# > 0 )); do
    case "$1" in
      -s|--select)
        SELECT_MODE=1
        shift
        ;;
      --no-pub-get)
        RUN_PUB_GET=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        [[ $# -le 1 ]] || fail "-- 后只能传入一个 Flutter 项目路径。"
        [[ $# -eq 0 ]] || INPUT_PROJECT="$1"
        break
        ;;
      -*)
        fail "不支持的参数：$1（可使用 --help 查看帮助）"
        ;;
      *)
        [[ -z "$INPUT_PROJECT" ]] || fail "参数过多：$1"
        INPUT_PROJECT="$1"
        shift
        ;;
    esac
  done
}

# 展示脚本内置自述，并等待用户确认后执行。
show_script_intro_and_wait() {
  [[ -t 1 && -n "${TERM:-}" && "${TERM:-}" != "dumb" ]] && clear

  echo "" | jobs_intro_style body

  if [[ -t 0 ]]; then
    read -r "?$(jobs_prompt_render "👉 已阅读脚本说明，按回车继续执行；按 Ctrl+C 取消：")" _
  else
    fail "当前标准输入不可交互，无法完成执行前确认。"
  fi
}

# 清理终端拖入路径的首尾引号、换行和常见转义字符。
normalize_input_path() {
  local path_value="$1"
  path_value="${path_value%$'\r'}"
  path_value="${path_value%$'\n'}"
  path_value="${path_value#\"}"
  path_value="${path_value%\"}"
  path_value="${path_value#\'}"
  path_value="${path_value%\'}"
  [[ "$path_value" == '~/'* ]] && path_value="$HOME/${path_value#\~/}"
  path_value="${path_value//\\ / }"
  path_value="${path_value//\\(/(}"
  path_value="${path_value//\\)/)}"
  path_value="${path_value//\\[/[}"
  path_value="${path_value//\\]/]}"
  path_value="${path_value//\\&/&}"
  path_value="${path_value//\\;/;}"
  [[ "$path_value" == "/" ]] || path_value="${path_value%/}"
  print -r -- "$path_value"
}

# 从指定目录逐级向上查找最近的 pubspec.yaml。
find_pubspec_upwards() {
  local current_dir="$1"
  current_dir="$(cd "$current_dir" 2>/dev/null && pwd -P)" || return 1

  while true; do
    [[ -f "$current_dir/pubspec.yaml" ]] && { print -r -- "$current_dir"; return 0; }
    [[ "$current_dir" == "/" ]] && break
    current_dir="$(dirname "$current_dir")"
  done
  return 1
}

# 将用户输入解析成包含 pubspec.yaml 的工程根目录。
resolve_project_root_from_input() {
  local input_path=""
  input_path="$(normalize_input_path "$1")"

  [[ -f "$input_path" && "$(basename "$input_path")" == "pubspec.yaml" ]] && input_path="$(dirname "$input_path")"
  [[ -d "$input_path" && -f "$input_path/pubspec.yaml" ]] || return 1
  (cd "$input_path" && pwd -P)
}

# 循环接收用户路径，直到找到合法的 Flutter / Dart 工程。
ask_project_root_until_valid() {
  local raw_path=""
  local resolved_root=""

  while true; do
    echo "" >&2
    read -r "?没有自动找到 pubspec.yaml，请输入或拖入 Flutter 项目根目录：" raw_path
    if resolved_root="$(resolve_project_root_from_input "$raw_path")"; then
      print -r -- "$resolved_root"
      return 0
    fi
    warn_echo "该目录下没有 pubspec.yaml，请重新输入。" >&2
  done
}

# 根据参数、脚本目录或手动输入确定工程根目录。
resolve_project_root() {
  if [[ -n "$INPUT_PROJECT" ]]; then
    if PROJECT_ROOT="$(resolve_project_root_from_input "$INPUT_PROJECT")"; then
      return 0
    fi
    warn_echo "传入路径不是合法工程根目录：$INPUT_PROJECT"
    PROJECT_ROOT="$(ask_project_root_until_valid)"
  elif PROJECT_ROOT="$(find_pubspec_upwards "$SCRIPT_DIR")"; then
    return 0
  else
    PROJECT_ROOT="$(ask_project_root_until_valid)"
  fi
}

# 检查工程类型并初始化工程相关路径。
prepare_project_context() {
  cd "$PROJECT_ROOT"
  PROJECT_NAME="$(basename "$PROJECT_ROOT")"
  PACKAGE_CONFIG="$PROJECT_ROOT/.dart_tool/package_config.json"
  info_echo "Flutter 工程根目录：$PROJECT_ROOT"

  if ! grep -Eq '^[[:space:]]*flutter:' "$PROJECT_ROOT/pubspec.yaml"; then
    warn_echo "pubspec.yaml 中未检测到 flutter: 配置，将按 Dart 工程继续处理。"
  fi
}

# 按项目 FVM、系统 FVM、全局 Flutter 的顺序选择命令。
resolve_flutter_command() {
  if [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER_CMD=("$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter")
    info_echo "使用项目内 FVM Flutter。"
  elif command -v fvm >/dev/null 2>&1 && { [[ -f "$PROJECT_ROOT/.fvmrc" ]] || [[ -d "$PROJECT_ROOT/.fvm" ]]; }; then
    FLUTTER_CMD=(fvm flutter)
    info_echo "使用系统 FVM Flutter。"
  elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD=(flutter)
    info_echo "使用全局 Flutter。"
  else
    fail "未找到 Flutter。请先安装 Flutter 或把 flutter 加入 PATH。"
  fi
}

# 询问是否执行普通安装或更新动作，直接回车表示跳过。
ask_any_to_run() {
  local answer=""
  read -r "?$(jobs_prompt_render "$1（直接回车跳过；输入任意字符后回车执行）：")" answer
  [[ -n "$answer" ]]
}

# 按交互结果刷新依赖解析文件，或复用工程现有文件。
prepare_package_config() {
  if (( RUN_PUB_GET == 1 )); then
    if ask_any_to_run "是否执行 flutter pub get 以刷新依赖解析文件？"; then
      info_echo "正在执行 flutter pub get..."
      jobs_flutter_sdk_command "${FLUTTER_CMD[@]}" pub get 2>&1 | tee -a "$LOG_FILE"
      local sdk_status=${pipestatus[1]}
      (( sdk_status == 0 )) || return "$sdk_status"
      success_echo "flutter pub get 执行完成。"
    else
      note_echo "已跳过 flutter pub get。"
    fi
  else
    note_echo "已通过 --no-pub-get 跳过 flutter pub get。"
  fi

  [[ -f "$PACKAGE_CONFIG" ]] || fail "未找到 ${PACKAGE_CONFIG}。请重新运行并选择执行 flutter pub get。"
}

# 检查本次执行所需的系统命令和可选工具。
check_environment() {
  command -v ruby >/dev/null 2>&1 || fail "未找到 Ruby，无法解析 package_config.json。"
  command -v rsync >/dev/null 2>&1 || fail "未找到 rsync，无法复制依赖目录。"
  command -v ditto >/dev/null 2>&1 || fail "未找到 macOS ditto，当前脚本仅支持 macOS。"
  if (( SELECT_MODE == 1 )) && ! command -v fzf >/dev/null 2>&1; then
    fail "已启用 --select，但未找到 fzf；可先执行 brew install fzf。"
  fi
}

# 创建本次打包使用的临时目录、清单路径和桌面输出路径。
prepare_output_paths() {
  local timestamp="$(date +%Y%m%d_%H%M%S)"
  local desktop_path="$HOME/Desktop"
  mkdir -p "$desktop_path"

  ZIP_PATH="$desktop_path/${PROJECT_NAME}_flutter_deps_${timestamp}.zip"
  TMP_PARENT="$(mktemp -d "/tmp/${PROJECT_NAME}_flutter_deps_${timestamp}.XXXXXX")"
  STAGE_NAME="${PROJECT_NAME}_flutter_deps_${timestamp}"
  STAGE="$TMP_PARENT/$STAGE_NAME"
  ALL_DEPS_TSV="$STAGE/manifest/all_package_roots.tsv"
  SELECTED_DEPS_TSV="$STAGE/manifest/selected_package_roots.tsv"
  mkdir -p "$STAGE/manifest" "$STAGE/dart_packages" "$STAGE/native" "$STAGE/project_files"
}

# 删除当前脚本创建的临时打包目录。
cleanup_temp_files() {
  [[ -n "${TMP_PARENT:-}" && -d "$TMP_PARENT" && "$TMP_PARENT" == /tmp/* ]] || return 0
  rm -rf -- "$TMP_PARENT"
}

# 从 package_config.json 提取工程实际解析到的依赖根目录。
extract_package_roots() {
  info_echo "正在解析 package_config.json..."
  ruby -rjson -ruri -e '
config = File.expand_path(ARGV[0])
project_root = File.expand_path(ARGV[1])
pub_cache = File.expand_path(ENV["PUB_CACHE"] || File.join(Dir.home, ".pub-cache"))
base_dir = File.dirname(config)
base_uri = "file://#{base_dir}/"

JSON.parse(File.read(config)).fetch("packages", []).each do |pkg|
  name = pkg["name"].to_s
  root_uri = pkg["rootUri"].to_s
  next if name.empty? || root_uri.empty?

  begin
    uri = URI.parse(root_uri)
    if uri.scheme.nil?
      path = URI::DEFAULT_PARSER.unescape(URI.join(base_uri, root_uri).path)
    elsif uri.scheme == "file"
      path = URI::DEFAULT_PARSER.unescape(uri.path)
    else
      next
    end
  rescue URI::InvalidURIError
    path = File.expand_path(root_uri, base_dir)
  end

  path = File.expand_path(path)
  next if path == project_root || !File.directory?(path)

  type = if path.start_with?(pub_cache + "/")
           "pub-cache"
         elsif path.include?("/flutter/") || path.include?("/flutter_sdk/")
           "flutter-sdk"
         else
           "local-or-path"
         end
  puts [name, path, type].join("\t")
end
' "$PACKAGE_CONFIG" "$PROJECT_ROOT" | sort -u > "$ALL_DEPS_TSV"

  TOTAL_COUNT="$(wc -l < "$ALL_DEPS_TSV" | tr -d ' ')"
  (( TOTAL_COUNT > 0 )) || fail "未从 package_config.json 提取到依赖包路径。"
  success_echo "共发现 ${TOTAL_COUNT} 个依赖包根目录。"
}

# 根据运行模式全选依赖，或通过 fzf 接收用户多选结果。
select_package_roots() {
  local selected_lines=""
  if (( SELECT_MODE == 1 )); then
    jobs_prompt_output info_echo "进入 fzf 多选：Tab 选中，Enter 确认，Esc 取消。"
    selected_lines="$(fzf -m \
      --delimiter=$'\t' \
      --with-nth=1,3,2 \
      --header='Tab 多选依赖；Enter 确认；Esc 取消' \
      --preview='printf "%s\n" {} | awk -F"\t" '\''{print "name: " $1 "\ntype: " $3 "\npath: " $2}'\''' \
      < "$ALL_DEPS_TSV" || true)"
    [[ -n "$selected_lines" ]] || fail "没有选择任何依赖，已取消。"
    print -r -- "$selected_lines" > "$SELECTED_DEPS_TSV"
  else
    cp -p "$ALL_DEPS_TSV" "$SELECTED_DEPS_TSV"
  fi

  SELECTED_COUNT="$(wc -l < "$SELECTED_DEPS_TSV" | tr -d ' ')"
  info_echo "本次将打包 ${SELECTED_COUNT} 个 Dart / Flutter 依赖。"
}

# 复制目录并跳过版本库、缓存和构建产物。
copy_dir() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$(dirname "$target_dir")"
  rsync -a \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='Pods/' \
    --exclude='.dart_tool/' \
    --exclude='build/' \
    --exclude='DerivedData/' \
    --exclude='.packages' \
    "$source_dir/" "$target_dir/"
}

# 在源文件存在时保留属性复制到目标路径。
copy_file_if_exists() {
  local source_file="$1"
  local target_file="$2"
  [[ -f "$source_file" ]] || return 0
  mkdir -p "$(dirname "$target_file")"
  cp -p "$source_file" "$target_file"
}

# 在源目录存在时复制原生依赖目录。
copy_dir_if_exists() {
  local source_dir="$1"
  local target_dir="$2"
  [[ -d "$source_dir" ]] || return 0
  info_echo "复制原生依赖目录：${source_dir#$PROJECT_ROOT/}"
  copy_dir "$source_dir" "$target_dir"
}

# 按工程相对路径复制依赖解析文件。
copy_project_file_rel() {
  local source_file="$1"
  [[ -f "$source_file" ]] || return 0
  local relative_path="${source_file#$PROJECT_ROOT/}"
  copy_file_if_exists "$source_file" "$STAGE/project_files/$relative_path"
}

# 复制选中的 Dart / Flutter 包并记录源路径映射。
copy_dart_packages() {
  local copied_manifest="$STAGE/manifest/copied_package_roots.tsv"
  local package_name=""
  local package_path=""
  local package_type=""
  local safe_name=""
  local target_dir=""
  : > "$copied_manifest"

  while IFS=$'\t' read -r package_name package_path package_type; do
    [[ -n "$package_name" && -d "$package_path" ]] || continue
    safe_name="$(print -rn -- "$package_name" | tr -c 'A-Za-z0-9._-' '_')"
    target_dir="$STAGE/dart_packages/$safe_name"
    info_echo "复制依赖：$package_name"
    copy_dir "$package_path" "$target_dir"
    printf '%s\t%s\t%s\t%s\n' "$package_name" "$package_path" "$package_type" "dart_packages/$safe_name" >> "$copied_manifest"
  done < "$SELECTED_DEPS_TSV"
}

# 复制 pub、CocoaPods、SwiftPM 和 Gradle 相关工程文件。
copy_project_dependency_files() {
  local search_root=""
  local found_file=""

  copy_project_file_rel "$PROJECT_ROOT/pubspec.yaml"
  copy_project_file_rel "$PROJECT_ROOT/pubspec.lock"
  copy_project_file_rel "$PROJECT_ROOT/.metadata"
  copy_project_file_rel "$PROJECT_ROOT/analysis_options.yaml"
  copy_project_file_rel "$PROJECT_ROOT/.dart_tool/package_config.json"
  copy_project_file_rel "$PROJECT_ROOT/.dart_tool/package_graph.json"
  copy_project_file_rel "$PROJECT_ROOT/ios/Podfile"
  copy_project_file_rel "$PROJECT_ROOT/ios/Podfile.lock"
  copy_project_file_rel "$PROJECT_ROOT/macos/Podfile"
  copy_project_file_rel "$PROJECT_ROOT/macos/Podfile.lock"

  copy_dir_if_exists "$PROJECT_ROOT/ios/Pods" "$STAGE/native/ios/Pods"
  copy_dir_if_exists "$PROJECT_ROOT/macos/Pods" "$STAGE/native/macos/Pods"
  copy_dir_if_exists "$PROJECT_ROOT/ios/.symlinks" "$STAGE/native/ios/.symlinks"
  copy_dir_if_exists "$PROJECT_ROOT/macos/.symlinks" "$STAGE/native/macos/.symlinks"
  copy_dir_if_exists "$PROJECT_ROOT/build/ios/SwiftPackages" "$STAGE/native/ios/SwiftPackages"
  copy_dir_if_exists "$PROJECT_ROOT/build/macos/SwiftPackages" "$STAGE/native/macos/SwiftPackages"

  for search_root in "$PROJECT_ROOT/ios" "$PROJECT_ROOT/macos"; do
    [[ -d "$search_root" ]] || continue
    while IFS= read -r -d '' found_file; do
      copy_project_file_rel "$found_file"
    done < <(find "$search_root" -name 'Package.resolved' -type f -print0 2>/dev/null)
  done

  if [[ -d "$PROJECT_ROOT/android" ]]; then
    while IFS= read -r -d '' found_file; do
      copy_project_file_rel "$found_file"
    done < <(find "$PROJECT_ROOT/android" \( \
      -name 'build.gradle' -o \
      -name 'build.gradle.kts' -o \
      -name 'settings.gradle' -o \
      -name 'settings.gradle.kts' -o \
      -name 'gradle.properties' -o \
      -name 'libs.versions.toml' \
    \) -type f -print0 2>/dev/null)
  fi
}

# 生成压缩包内的环境清单和使用说明。
write_package_manifest() {
  {
    echo "Project name: $PROJECT_NAME"
    echo "Project root: $PROJECT_ROOT"
    echo "Created at: $(date)"
    echo "Select mode: $SELECT_MODE"
    echo "Package config: $PACKAGE_CONFIG"
    echo "Selected packages: $SELECTED_COUNT / $TOTAL_COUNT"
    echo "Zip path: $ZIP_PATH"
  } > "$STAGE/manifest/project_info.txt"

  jobs_flutter_sdk_command "${FLUTTER_CMD[@]}" --version > "$STAGE/manifest/flutter_version.txt" 2>&1
  jobs_flutter_sdk_command "${FLUTTER_CMD[@]}" pub deps --style=compact > "$STAGE/manifest/flutter_pub_deps_compact.txt" 2>&1

  cat > "$STAGE/README.txt" <<'README'
目录说明：
- dart_packages/：package_config.json 实际解析到的 Dart / Flutter 包源码。
- native/：工程现有的 CocoaPods、旧版插件 symlink 和 SwiftPM 输出。
- project_files/：pubspec、Podfile.lock、Package.resolved、Gradle 声明等文件。
- manifest/：依赖清单、Flutter 版本、pub deps 输出与复制路径映射。

注意：
1. 不复制整个 ~/.gradle/caches，避免压缩包体积失控。
2. Pods 不存在时不会自动执行 pod install。
3. --select 只筛选 Dart / Flutter 包，原生依赖仍按工程现状复制。
README
}

# 使用 macOS ditto 生成保留父目录结构的 Zip 压缩包。
create_zip_archive() {
  local zip_size=""
  info_echo "开始压缩到桌面：$ZIP_PATH"
  (cd "$TMP_PARENT" && ditto -c -k --sequesterRsrc --keepParent "$STAGE_NAME" "$ZIP_PATH")
  [[ -f "$ZIP_PATH" ]] || fail "压缩失败：$ZIP_PATH"
  zip_size="$(du -h "$ZIP_PATH" | awk '{print $1}')"
  success_echo "打包完成：$ZIP_PATH"
  success_echo "压缩包大小：$zip_size"
  gray_echo "执行日志：$LOG_FILE"
}

# 编排完整的依赖解析、复制与压缩流程。
run_main_flow() {
  # 解析运行参数，确定选择模式、pub get 策略和可选工程路径。
  parse_arguments "$@"
  # 展示配套 README，确保用户理解脚本用途和影响范围后再继续。
  show_script_intro_and_wait
  # 定位包含 pubspec.yaml 的 Flutter / Dart 工程根目录。
  resolve_project_root
  # 初始化工程名称、依赖配置路径并检查工程类型。
  prepare_project_context
  # 按项目 FVM、系统 FVM、全局 Flutter 的顺序选择可用命令。
  resolve_flutter_command
  # 根据用户确认结果刷新或复用 package_config.json。
  prepare_package_config
  # 检查 Ruby、rsync、ditto 以及可选 fzf 是否可用。
  check_environment
  # 创建桌面输出路径、临时工作区和依赖清单路径。
  prepare_output_paths
  # 注册退出清理，确保本次创建的临时目录不会残留。
  trap cleanup_temp_files EXIT
  # 从 package_config.json 提取工程实际解析到的包根目录。
  extract_package_roots
  # 根据全量或 fzf 多选模式生成本次待复制依赖清单。
  select_package_roots
  # 复制选中的 Dart / Flutter 包源码并记录路径映射。
  copy_dart_packages
  # 复制 pub、CocoaPods、SwiftPM 与 Gradle 相关工程文件。
  copy_project_dependency_files
  # 写入环境信息、依赖统计和压缩包目录说明。
  write_package_manifest
  # 使用 macOS ditto 生成最终 Zip 压缩包并输出结果。
  create_zip_archive
}

# 将主入口统一委托给完整业务流程。
main() {
  # 调用完整业务流程，避免入口承载条件判断和业务细节。
  run_main_flow "$@"
}

main "$@"
