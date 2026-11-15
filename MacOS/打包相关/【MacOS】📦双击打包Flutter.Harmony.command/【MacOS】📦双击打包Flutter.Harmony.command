#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】📦双击打包Flutter.Harmony.command
# - 核心用途：使用鸿蒙适配版 Flutter 一次构建 HAP 安装包和 APP 发布包，默认 release。
# - 影响范围：解析工程依赖、执行 Hvigor 构建并写入构建目录；签名沿用工程配置。
# - 运行提示：先打印内置自述；终端回车确认，Ctrl+C / EOF 取消；--help / --check 不构建；缺少工具链时停止。

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
    # 完整颜色帧有界重发；仅退出恢复容忍帧外回车和明确方向键。
    jobs_terminal_style_query() {
        jobs_style_query_key=$1
        jobs_style_reply=''
        jobs_style_query_buffer=''
        jobs_style_query_target_reply=''
        jobs_style_query_target_normalized=''
        jobs_style_query_target_rgb=''
        jobs_style_query_st="${jobs_style_esc}\\"
        jobs_style_query_stale_count=0
        jobs_style_query_phase=${2:-strict}
        jobs_style_query_cr=$(printf '\r')
        jobs_style_query_lf=$(printf '\n.')
        jobs_style_query_lf=${jobs_style_query_lf%.}
        jobs_style_query_failure='未收到目标颜色的完整答复（最多 3 次查询，每次约 2 秒）'
        for jobs_style_query_round in 1 2 3; do
            printf '\033]%s;?\007' "$jobs_style_query_key" > /dev/tty || {
                jobs_style_query_failure='无法向原终端发送配色查询'
                return 1
            }
            for jobs_style_attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
                # 哨兵保留末尾换行，不能把只有回车的键盘输入误当成无答复。
                jobs_style_piece=$(dd bs=256 count=1 2>/dev/null < /dev/tty; printf '.')
                jobs_style_piece=${jobs_style_piece%.}
                jobs_style_query_buffer=$jobs_style_query_buffer$jobs_style_piece
                while [ -n "$jobs_style_query_buffer" ]; do
                    # 仅退出恢复阶段允许帧外的明确控制键，普通文字仍然失败。
                    if [ "$jobs_style_query_phase" = cleanup ]; then
                        jobs_style_query_control_sequence=''
                        jobs_style_query_control_partial=0
                        case $jobs_style_query_buffer in
                            "$jobs_style_query_cr"*) jobs_style_query_control_sequence=$jobs_style_query_cr ;;
                            "$jobs_style_query_lf"*) jobs_style_query_control_sequence=$jobs_style_query_lf ;;
                        esac
                        if [ -z "$jobs_style_query_control_sequence" ]; then
                            for jobs_style_query_direction in A B C D; do
                                for jobs_style_query_control_candidate in \
                                    "${jobs_style_esc}[${jobs_style_query_direction}" \
                                    "${jobs_style_esc}O${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;2${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;3${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;4${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;5${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;6${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;7${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;8${jobs_style_query_direction}"; do
                                    case $jobs_style_query_buffer in
                                        "$jobs_style_query_control_candidate"*)
                                            jobs_style_query_control_sequence=$jobs_style_query_control_candidate
                                            break 2
                                            ;;
                                    esac
                                    case $jobs_style_query_control_candidate in
                                        "$jobs_style_query_buffer"*) jobs_style_query_control_partial=1 ;;
                                    esac
                                done
                            done
                        fi
                        if [ -n "$jobs_style_query_control_sequence" ]; then
                            jobs_style_cleanup_control_keys=$(( ${jobs_style_cleanup_control_keys:-0} + 1 ))
                            if [ "$jobs_style_cleanup_control_keys" -gt 64 ]; then
                                jobs_style_query_failure='退出恢复期间已识别控制键超过 64 个，已停止自动恢复'
                                return 1
                            fi
                            jobs_style_query_buffer=${jobs_style_query_buffer#"$jobs_style_query_control_sequence"}
                            continue
                        fi
                        if [ "$jobs_style_query_control_partial" = 1 ]; then
                            break
                        fi
                    fi
                    case $jobs_style_query_buffer in
                        "$jobs_style_esc"|"$jobs_style_esc]") break ;;
                        "$jobs_style_esc]"*) ;;
                        *) jobs_style_query_failure='收到非配色查询输入，已停止读取'; return 1 ;;
                    esac
                    jobs_style_query_head=''
                    jobs_style_query_terminator=''
                    case $jobs_style_query_buffer in
                        *"$jobs_style_bel"*)
                            jobs_style_query_head=${jobs_style_query_buffer%%"$jobs_style_bel"*}
                            jobs_style_query_terminator=$jobs_style_bel
                            ;;
                    esac
                    case $jobs_style_query_buffer in
                        *"$jobs_style_query_st"*)
                            jobs_style_query_st_head=${jobs_style_query_buffer%%"$jobs_style_query_st"*}
                            if [ -z "$jobs_style_query_terminator" ] ||
                               [ "${#jobs_style_query_st_head}" -lt "${#jobs_style_query_head}" ]; then
                                jobs_style_query_head=$jobs_style_query_st_head
                                jobs_style_query_terminator=$jobs_style_query_st
                            fi
                            ;;
                    esac
                    [ -n "$jobs_style_query_terminator" ] || break
                    jobs_style_query_frame=$jobs_style_query_head$jobs_style_query_terminator
                    jobs_style_query_buffer=${jobs_style_query_buffer#"$jobs_style_query_frame"}
                    jobs_style_query_body=${jobs_style_query_head#"$jobs_style_esc]"}
                    case $jobs_style_query_body in
                        *';rgb:'*) ;;
                        *) jobs_style_query_failure='配色答复格式或 RGB 数据无效'; return 1 ;;
                    esac
                    jobs_style_query_frame_key=${jobs_style_query_body%%';rgb:'*}
                    case $jobs_style_query_frame_key in
                        10|11|12|'4;'[0-9]|'4;1'[0-5]) ;;
                        *) jobs_style_query_failure='收到不属于本次颜色协议的答复'; return 1 ;;
                    esac
                    jobs_style_query_frame_rgb=${jobs_style_query_body#"$jobs_style_query_frame_key;rgb:"}
                    jobs_style_query_frame_normalized=$(printf '%s\n' "$jobs_style_query_frame_rgb" | LC_ALL=C awk -F/ '
                        BEGIN { valid = 1 }
                        NR != 1 || NF != 3 { valid = 0; exit }
                        {
                            for (i = 1; i <= 3; i++) {
                                h = tolower($i)
                                if (length(h) < 1 || length(h) > 4 || h ~ /[^0-9a-f]/) {
                                    valid = 0
                                    exit
                                }
                                n = 0
                                for (j = 1; j <= length(h); j++) n = n * 16 + index("0123456789abcdef", substr(h, j, 1)) - 1
                                value[i] = int(n * 65535 / (16 ^ length(h) - 1) + 0.5)
                            }
                        }
                        END {
                            if (!valid || NR != 1) exit 1
                            printf "%d/%d/%d", value[1], value[2], value[3]
                        }
                    ')
                    if [ -z "$jobs_style_query_frame_normalized" ]; then
                        jobs_style_query_failure='配色答复格式或 RGB 数据无效'
                        return 1
                    fi
                    if [ "$jobs_style_query_frame_key" = "$jobs_style_query_key" ]; then
                        if [ -n "$jobs_style_query_target_reply" ] &&
                           [ "$jobs_style_query_target_normalized" != "$jobs_style_query_frame_normalized" ]; then
                            jobs_style_query_failure='同一颜色的重复答复不一致，已停止自动恢复'
                            return 1
                        fi
                        jobs_style_query_target_reply=$jobs_style_query_frame
                        jobs_style_query_target_normalized=$jobs_style_query_frame_normalized
                        jobs_style_query_target_rgb=$jobs_style_query_frame_rgb
                    else
                        jobs_style_query_stale_count=$((jobs_style_query_stale_count + 1))
                        if [ "$jobs_style_query_stale_count" -gt 128 ]; then
                            jobs_style_query_failure='收到过多旧颜色答复，已停止读取'
                            return 1
                        fi
                    fi
                done
                if [ -n "$jobs_style_query_target_reply" ] && [ -z "$jobs_style_query_buffer" ]; then
                    jobs_style_reply=$jobs_style_query_target_reply
                    jobs_style_normalized=$jobs_style_query_target_normalized
                    jobs_style_rgb=$jobs_style_query_target_rgb
                    return 0
                fi
            done
            # 残缺帧不能通过重发拼成另一个答复，更不能被当成键盘空输入。
            if [ -n "$jobs_style_query_buffer" ]; then
                jobs_style_query_failure='配色答复帧不完整，已停止自动恢复'
                return 1
            fi
        done
        return 1
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
            jobs_style_cleanup_issue='无法读取或设置原终端输入模式，或临时配色未完成核验'
            jobs_style_conflicts=''
            jobs_style_restore_safe=''
            jobs_style_cleanup_control_keys=0
            if [ "$jobs_style_applied_complete" = 1 ]; then
                jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_style_stty=''
                if [ -n "$jobs_style_stty" ] && stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
                    jobs_style_query_active=1
                    jobs_style_cleanup_ok=1
                    while IFS='|' read -r jobs_style_key jobs_style_expected jobs_style_original; do
                        [ -n "$jobs_style_key" ] || continue
                        if ! jobs_terminal_style_query "$jobs_style_key" cleanup; then
                            jobs_style_cleanup_ok=0
                            jobs_style_cleanup_issue="颜色项 $jobs_style_key：$jobs_style_query_failure"
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
                    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_cleanup_ok=0; jobs_style_cleanup_issue='无法恢复原终端输入模式'; }
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
                printf '终端配色未能安全自动恢复（%s）；确认覆盖当前配色后可运行：sh "%s"\n' "$jobs_style_cleanup_issue" "$jobs_style_recovery" >&2
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
    trap 'jobs_style_exit_status=129; jobs_terminal_style_cleanup 129 continue; jobs_style_changed=0; exit 129' HUP
    trap 'jobs_style_exit_status=130; jobs_terminal_style_cleanup 130 continue; jobs_style_changed=0; exit 130' INT
    trap 'jobs_style_exit_status=143; jobs_terminal_style_cleanup 143 continue; jobs_style_changed=0; exit 143' TERM
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
        trap 'jobs_style_exit_status=129; jobs_terminal_style_cleanup 129 continue; jobs_style_changed=0; exit 129' HUP
        trap 'jobs_style_exit_status=130; jobs_terminal_style_cleanup 130 continue; jobs_style_changed=0; exit 130' INT
        trap 'jobs_style_exit_status=143; jobs_terminal_style_cleanup 143 continue; jobs_style_changed=0; exit 143' TERM
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

source "${${(%):-%x}:A:h}/Scripts/【MacOS】FlutterSDK网络适配.zsh/【MacOS】FlutterSDK网络适配.zsh" || return 1

SCRIPT_SOURCE="$0"
SCRIPT_PATH=""
SCRIPT_DIR=""
SCRIPT_BASENAME=""
LOG_FILE=""
LOG_READY=0
IS_SOURCETREE_RUNTIME=0
PLAIN_OUTPUT=0
PROJECT_ROOT=""
BUILD_BASE=""
BUILD_MODE="${BUILD_MODE:-}"
BUILD_TARGET="all"
SDK_OVERRIDE=""
DEVECO_CONTENTS=""
FLUTTER_CMD=()
BUILD_TARGETS=(hap app)
OUTPUT_ROOTS=()
typeset -a HAP_ARTIFACTS=() APP_ARTIFACTS=()
CHECK_ONLY=0
BUILD_MARKER=""


# 始终按脚本自身路径定位，不依赖启动工作目录。
resolve_script_path() {
  SCRIPT_PATH="${${(%):-%x}:A}"
  SCRIPT_DIR="${SCRIPT_PATH:h}"
  SCRIPT_BASENAME="${SCRIPT_PATH:t:r}"
  LOG_FILE='确认后在系统临时目录 JobsFlutterHarmonyPackager.* 中创建'
}

# 在第一屏及正式执行前同步初始化纯文本环境。
configure_output_mode() {
  if [[ "$IS_SOURCETREE_RUNTIME" == 1 || ! -t 1 || -z "${TERM:-}" || "${TERM:-}" == dumb || -n "${NO_COLOR+x}" ]]; then
    PLAIN_OUTPUT=1
    export NO_COLOR=1 FORCE_COLOR=0 CLICOLOR=0 ANSI_COLORS_DISABLED=1 npm_config_color=false
  fi
}
# 过滤脚本和外部命令输出中的 ANSI 颜色与控制序列。
strip_ansi_stream() {
  /usr/bin/perl -pe 's/\e\][^\a]*(?:\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\\(?:033|e|x1[bB])\[[0-9;]*m//g'
}
# 终端和日志同步记录；日志始终保存可检索的纯文本。
log() {
  local line="$1"
  if [[ "$PLAIN_OUTPUT" == 1 ]]; then
    print -r -- "$line" | strip_ansi_stream
  else
    print -r -- "$line"
  fi
  if [[ "$LOG_READY" == 1 ]]; then
    print -r -- "$line" | strip_ansi_stream >> "$LOG_FILE" || return 1
  fi
}
# 颜色仅用于终端展示，避免把路径内反斜杠当转义字符。
color_log() {
  if [[ "$PLAIN_OUTPUT" == 1 ]]; then
    log "$2"
  else
    log "$(printf '\033[%sm%s\033[0m' "$1" "$2")"
  fi
}
# 输出构建步骤与环境信息。
info_echo() { color_log '1;34' "ℹ $1"; }
# 输出已经核验的结果。
success_echo() { color_log '1;32' "✔ $1"; }
# 输出需要人工处理的条件。
warn_echo() { color_log '1;33' "⚠ $1"; }
# 输出失败原因。
error_echo() { color_log '1;31' "✖ $1"; }
# 自述标题红色加粗，正文蓝色常规字重。
intro_line() {
  local style='0;34'
  [[ "$1" == title ]] && style='1;31'
  color_log "$style" "$2"
}
# 首先展示固定自述，确认之前不写日志或改动工程。
show_script_intro_and_wait() {
  resolve_script_path || exit 1
  configure_output_mode
  intro_line title "================ 鸿蒙 Flutter 打包 ================"
  intro_line title "脚本名称：${SCRIPT_BASENAME}.command"
  intro_line body '1、用途：构建已有 Flutter 鸿蒙工程，默认 release，一次生成 HAP 安装包和 APP 发布包。'
  intro_line body '2、依赖：鸿蒙适配 Flutter → Dart / 鸿蒙 SDK → Node / ohpm / Hvigor / Java。'
  intro_line body '3、影响：联网解析依赖、执行工程构建与现有签名配置，写入缓存和构建目录。'
  intro_line body '4、策略：已有 Flutter 缺失的 Dart / 引擎先检测网络并自动补齐，失败持续重试，Ctrl+C 结束；不升级工具链、不创建 ohos、不修改证书或系统配置。'
  jobs_prompt_output intro_line body '5、先确认工程根目录，再回车开始；Ctrl+C / EOF 取消，--check 只检查工程清单。'
  intro_line body "日志：$LOG_FILE"
  intro_line title '===================================================='
  [[ "${1:-}" == --help || "${1:-}" == --check ]] && return 0
  if [[ ! -t 0 ]]; then
    error_echo '没有交互输入，请在终端运行，或使用 --check 只读检查。'
    exit 1
  fi
  local answer=""
  IFS= read -r "answer?$(jobs_prompt_render '👉 按回车继续；Ctrl+C 取消：')" || exit 1
}
# 确认后配置当前进程和日志，保留调用者 PATH 优先级。
initialize_script_runtime() {
  setopt NO_NOMATCH PIPE_FAIL
  export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin:$HOME/.pub-cache/bin:$HOME/.fvm/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  configure_output_mode
  umask 077
  local run_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/JobsFlutterHarmonyPackager.XXXXXX")" || return 1
  LOG_FILE="$run_dir/$SCRIPT_BASENAME.log"
  : > "$LOG_FILE" || { print -u2 -r -- "日志不可写：$LOG_FILE"; exit 1; }
  LOG_READY=1
}
# 先校验全部参数，再进入 SDK 或联网操作。
parse_build_options() {
  BUILD_MODE="release"
  BUILD_TARGET="all"
  SDK_OVERRIDE="${FLUTTER_OHOS_SDK:-}"
  while (( $# > 0 )); do
    case "$1" in
      --mode|--flutter-sdk|--project)
        (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] || { error_echo "$1 缺少参数值。"; return 2; }
        case "$1" in
          --mode) BUILD_MODE="$2" ;;
          --project) [[ -z "$BUILD_BASE" ]] || return 2; BUILD_BASE="$2" ;;
          --flutter-sdk) SDK_OVERRIDE="$2" ;;
        esac
        shift 2
        ;;
      --)
        shift
        (( $# <= 1 )) && [[ -z "$BUILD_BASE" ]] || { error_echo '只能指定一个工程目录。'; return 2; }
        BUILD_BASE="${1:-}"
        break
        ;;
      -*) error_echo "未知参数：$1"; return 2 ;;
      *) [[ -z "$BUILD_BASE" ]] || { error_echo '只能指定一个工程目录。'; return 2; }; BUILD_BASE="$1"; shift ;;
    esac
  done
  case "$BUILD_MODE" in release|debug|profile) ;; *) error_echo "无效构建模式：$BUILD_MODE"; return 2 ;; esac
  case "$BUILD_TARGET" in hap|app|all) ;; *) error_echo "无效鸿蒙产物类型：$BUILD_TARGET"; return 2 ;; esac
  [[ "${OPEN_AFTER_BUILD:-1}" == [01] ]] || { error_echo 'OPEN_AFTER_BUILD 只能是 0 或 1。'; return 2; }
  BUILD_TARGETS=("$BUILD_TARGET")
  [[ "$BUILD_TARGET" == all ]] && BUILD_TARGETS=(hap app)
  return 0
}
# 解除拖入路径的外层引号和转义，保留有效文件名中的原有字符。
normalize_input_path() {
  local input_value="$1"
  if [[ ! -e "$input_value" ]]; then
    input_value="${input_value%$'\r'}"
    input_value="${input_value%$'\n'}"
    [[ "$input_value" == \"*\" || "$input_value" == \'*\' ]] && input_value="${input_value[2,-2]}"
    [[ "$input_value" == '~/'* ]] && input_value="$HOME/${input_value#\~/}"
    [[ -e "$input_value" ]] || input_value="${(Q)input_value}"
  fi
  print -r -- "$input_value"
}
project_data() {
    /usr/bin/osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('Foundation');
function run(args) {
    function read(path) {
        var data = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
        if (!data) throw Error('无法读取文件：' + path);
        return ObjC.unwrap(data);
    }
    function clean(value) {
        if (typeof value !== 'string' || /[\x00-\x1f\x7f]/.test(value)) throw Error('字段包含控制字符或类型错误');
        return value;
    }
    function scalar(value) {
        value = value.trim();
        if (/^'[^']*'$/.test(value) || /^"[^"\\]*"$/.test(value)) return value.slice(1, -1);
        return value;
    }
    function uncomment(line) {
        var quote = '', result = '';
        for (var i = 0; i < line.length; i++) {
            var c = line[i];
            if (quote) {
                result += c;
                if (c === '\\' && quote === '"') { result += line[++i] || ''; continue; }
                if (c === quote) {
                    if (quote === "'" && line[i + 1] === "'") { result += line[++i]; continue; }
                    quote = '';
                }
            } else if (c === '#' && (i === 0 || /\s/.test(line[i - 1]))) break;
            else { result += c; if (c === "'" || c === '"') quote = c; }
        }
        return result.replace(/\s+$/, '');
    }
    function flow(text) {
        var pos = 0;
        function space() { while (/\s/.test(text[pos] || '') && pos < text.length) pos++; }
        function token() {
            space(); var start = pos, quote = text[pos];
            if (quote === '"' || quote === "'") {
                pos++; while (pos < text.length && text[pos] !== quote) { if (text[pos] === '\\') throw Error('不支持转义 flow scalar'); pos++; }
                if (text[pos++] !== quote) throw Error('引号未闭合');
                return text.slice(start + 1, pos - 1);
            }
            while (pos < text.length && !/[,:{}\[\]]/.test(text[pos])) pos++;
            var result = text.slice(start, pos).trim();
            if (!result || /[&*!|>]/.test(result)) throw Error('不支持该 YAML flow 写法');
            return result;
        }
        function map() {
            space(); if (text[pos++] !== '{') throw Error('要求 flow map');
            var result = Object.create(null); space();
            while (text[pos] !== '}') {
                var key = token(); space(); if (text[pos++] !== ':') throw Error('缺少冒号'); space();
                if (Object.prototype.hasOwnProperty.call(result, key)) throw Error('重复 YAML key：' + key);
                result[key] = text[pos] === '{' ? map() : token(); space();
                if (text[pos] === ',') { pos++; space(); } else if (text[pos] !== '}') throw Error('flow map 格式无效');
            }
            pos++; return result;
        }
        var result = map(); space(); if (pos !== text.length) throw Error('flow map 末尾有额外内容');
        return result;
    }
    // 读全部可读的 key: value 行；Tab 缩进与多文档标记直接拒绝，避免猜错层级。
    function loadEntries(path) {
        var lines = read(path).replace(/^\uFEFF/, '').split(/\r?\n/), entries = [];
        lines.forEach(function (line, i) {
            var cleanLine = uncomment(line);
            if (!cleanLine) return;
            if (/^[ \t]*\t/.test(cleanLine)) throw Error('缩进含 Tab，无法安全识别');
            if (/^\s*(?:---|\.\.\.)(?:\s|$)/.test(cleanLine)) throw Error('不支持 YAML 文档分隔标记');
            var indent = cleanLine.length - cleanLine.replace(/^ +/, '').length;
            var match = /^([^:]+):(?:\s+(.*)|\s*)$/.exec(cleanLine.slice(indent));
            if (!match) return;
            entries.push({ index: i, indent: indent, key: scalar(match[1]), value: (match[2] || '').trim() });
        });
        return entries;
    }
    // 取某节点的直接子节点：大于父缩进且取最小缩进，遇到回缩即截断。
    function childrenOf(entries, parent) {
        var result = [];
        if (!parent) {
            return entries.filter(function (entry) { return entry.indent === 0; });
        }
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].index <= parent.index) continue;
            if (entries[i].indent <= parent.indent) break;
            result.push(entries[i]);
        }
        if (result.length === 0) return [];
        var minimum = Math.min.apply(null, result.map(function (entry) { return entry.indent; }));
        return result.filter(function (entry) { return entry.indent === minimum; });
    }
    // 根级 key 必须唯一，否则不参与后续判定。
    function uniqueRoot(entries, key) {
        var roots = childrenOf(entries, null).filter(function (entry) { return entry.key === key; });
        return roots.length === 1 ? roots[0] : null;
    }
    // 逐层确认 dependencies.flutter.sdk 是 flutter，支持 block 与单行 flow 两种常见写法。
    function assertFlutterSDKDependency(entries, dependencies) {
        if (dependencies.value) {
            var flattened = flow(dependencies.value);
            if (!flattened.flutter) throw Error('缺少 dependencies.flutter');
            // 嵌套 flow map 已被解析成对象，只有仍是字符串的单行写法才需要二次解析。
            var nested = typeof flattened.flutter === 'string' ? flow(flattened.flutter) : flattened.flutter;
            if (!nested || nested.sdk !== 'flutter') throw Error('dependencies.flutter.sdk 不是 flutter');
            return true;
        }
        var declarations = childrenOf(entries, dependencies).filter(function (entry) { return entry.key === 'flutter'; });
        if (declarations.length !== 1) throw Error('缺少唯一直接依赖 flutter');
        var declaration = declarations[0];
        if (declaration.value) {
            if (flow(declaration.value).sdk !== 'flutter') throw Error('dependencies.flutter.sdk 不是 flutter');
            return true;
        }
        var fields = childrenOf(entries, declaration).filter(function (entry) { return entry.key === 'sdk'; });
        if (fields.length !== 1) throw Error('缺少唯一 sdk 声明');
        if (scalar(fields[0].value) !== 'flutter') throw Error('dependencies.flutter.sdk 不是 flutter');
        return true;
    }
    if (args[0] === 'directory-kind') {
        var url = $.NSURL.fileURLWithPath(args[1]);
        var properties = ObjC.deepUnwrap(url.resourceValuesForKeysError($([$.NSURLIsDirectoryKey, $.NSURLIsPackageKey, $.NSURLIsAliasFileKey, $.NSURLIsSymbolicLinkKey]), null));
        if (!properties || properties.NSURLIsDirectoryKey !== true || properties.NSURLIsPackageKey !== false ||
            properties.NSURLIsAliasFileKey !== false || properties.NSURLIsSymbolicLinkKey !== false) throw Error('目标不是普通目录，或是 package / Alias / 符号链接');
        return 'directory';
    }
    if (args[0] === 'pubspec') {
        if (read(args[1]).indexOf(String.fromCharCode(0)) !== -1) throw Error('清单含 NUL');
        var manifestEntries = loadEntries(args[1]);
        var dependencies = uniqueRoot(manifestEntries, 'dependencies');
        if (!dependencies) throw Error('必须有唯一根级 dependencies');
        if (assertFlutterSDKDependency(manifestEntries, dependencies)) return 'flutter';
        throw Error('未识别到 Flutter SDK 依赖');
    }
    throw Error('未知数据操作');
}
JXA
}
# 仅处理用户指定的工程根目录，不扫描或猜测其它工程。
resolve_flutter_project() {
  local base="$(normalize_input_path "$BUILD_BASE")" item="" size=""
  while [[ "$base" == */ && "$base" != / ]]; do
    base="${base%/}"
  done
  [[ -n "$base" && "$base" != / && "$base" != *[[:cntrl:]]* && -d "$base" && ! -L "$base" ]] || {
    error_echo '请指定当前层的普通 Flutter 鸿蒙工程根目录，不接受链接或控制字符。'; return 1
  }
  PROJECT_ROOT="${base:A}"
  for item in pubspec.yaml ohos/build-profile.json5 ohos/oh-package.json5; do
    [[ -f "$PROJECT_ROOT/$item" && ! -L "$PROJECT_ROOT/$item" && -s "$PROJECT_ROOT/$item" ]] || {
      jobs_prompt_output error_echo "工程缺少普通非空清单：$item"; return 1
    }
  done
  [[ -d "$PROJECT_ROOT/lib" && ! -L "$PROJECT_ROOT/lib" && ! -L "$PROJECT_ROOT/ohos" ]] || {
    error_echo '工程需有普通 lib/ 和 ohos/ 目录'; return 1
  }
  size="$(/usr/bin/stat -f %z "$PROJECT_ROOT/pubspec.yaml")" || return 1
  [[ "$size" == <-> && "$size" -le 1048576 ]] || { error_echo 'pubspec.yaml 超过 1 MiB'; return 1; }
  project_data directory-kind "$PROJECT_ROOT" >/dev/null || return 1
  project_data pubspec "$PROJECT_ROOT/pubspec.yaml" >/dev/null || { error_echo '无法确认 Flutter SDK 依赖'; return 1; }
  info_echo "工程目录：$PROJECT_ROOT"
}

# 显式指定 SDK 优先，其次项目固定 SDK，最后当前 PATH；不默默替换固定版本。
choose_flutter_sdk() {
  if [[ -n "$SDK_OVERRIDE" ]]; then
    SDK_OVERRIDE="$(normalize_input_path "$SDK_OVERRIDE")"
    [[ -x "$SDK_OVERRIDE/bin/flutter" ]] || { error_echo "指定 SDK 中没有可执行 bin/flutter：$SDK_OVERRIDE"; return 1; }
    FLUTTER_CMD=("${SDK_OVERRIDE:A}/bin/flutter")
  elif [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER_CMD=("$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter")
  elif [[ -e "$PROJECT_ROOT/.fvmrc" || -e "$PROJECT_ROOT/.fvm/fvm_config.json" || -L "$PROJECT_ROOT/.fvm/flutter_sdk" ]]; then
    error_echo '工程固定了 FVM，但 .fvm/flutter_sdk 尚不可用。请先恢复该 SDK，或显式指定 --flutter-sdk；入口不自动下载 SDK。'
    return 1
  elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD=("${commands[flutter]:A}")
  else
    error_echo '没有 Flutter SDK。请用 --flutter-sdk 或 FLUTTER_OHOS_SDK 指定鸿蒙适配版 SDK 根目录。'
    return 1
  fi
  info_echo "Flutter 命令：${(j: :)FLUTTER_CMD}"
}
# 仅配置本进程的 DevEco 路径，保留显式 SDK 和 Java 设置。
prepare_deveco_environment() {
  local candidate="" requested="${DEVECO_STUDIO_HOME:-${TOOL_HOME:-}}"
  local -a candidates=()
  if [[ -z "${DEVECO_SDK_HOME:-}" && -n "${HOS_SDK_HOME:-}" ]]; then
    export DEVECO_SDK_HOME="$HOS_SDK_HOME"
  fi
  if [[ -n "$requested" ]]; then
    requested="$(normalize_input_path "$requested")"
    [[ -d "$requested/Contents" ]] && requested="$requested/Contents"
    [[ -d "$requested" ]] || { error_echo "DevEco 路径不存在：$requested"; return 1; }
    DEVECO_CONTENTS="$requested"
  elif [[ -z "${DEVECO_SDK_HOME:-}" ]]; then
    for candidate in /Applications/DevEco*.app/Contents(N) "$HOME"/Applications/DevEco*.app/Contents(N); do
      [[ -d "$candidate/sdk" ]] && candidates+=("$candidate")
    done
    if (( ${#candidates[@]} == 1 )); then
      DEVECO_CONTENTS="${candidates[1]}"
    elif (( ${#candidates[@]} > 1 )); then
      error_echo '发现多个 DevEco Studio，请用 DEVECO_STUDIO_HOME 明确选择。'
      return 1
    fi
  fi
  if [[ -n "$DEVECO_CONTENTS" ]]; then
    export TOOL_HOME="$DEVECO_CONTENTS"
    [[ -n "${DEVECO_SDK_HOME:-}" ]] || export DEVECO_SDK_HOME="$DEVECO_CONTENTS/sdk"
    export PATH="$DEVECO_CONTENTS/tools/node/bin:$DEVECO_CONTENTS/tools/ohpm/bin:$DEVECO_CONTENTS/tools/hvigor/bin:$DEVECO_CONTENTS/tool/node/bin:$DEVECO_CONTENTS/ohpm/bin:$DEVECO_CONTENTS/hvigor/bin:$PATH"
    if [[ -z "${JAVA_HOME:-}" && -x "$DEVECO_CONTENTS/jbr/Contents/Home/bin/java" ]]; then
      export JAVA_HOME="$DEVECO_CONTENTS/jbr/Contents/Home"
    fi
  fi
  if [[ -n "${JAVA_HOME:-}" ]]; then
    [[ -x "$JAVA_HOME/bin/java" ]] || { error_echo "JAVA_HOME 没有可执行 bin/java：$JAVA_HOME"; return 1; }
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  if [[ -n "${NODE_HOME:-}" ]]; then
    [[ -x "$NODE_HOME/bin/node" ]] || { error_echo "NODE_HOME 没有可执行 bin/node：$NODE_HOME"; return 1; }
    export PATH="$NODE_HOME/bin:$PATH"
  fi
  rehash
  [[ -n "${DEVECO_SDK_HOME:-}" && -d "$DEVECO_SDK_HOME" ]] || {
    error_echo '没有有效 DEVECO_SDK_HOME。请先准备 DevEco Studio / HarmonyOS SDK；不将 OHOS_SDK_HOME 当作同义路径。'
    return 1
  }
  info_echo "HarmonyOS SDK：$DEVECO_SDK_HOME"
}
# 外部输出同步过滤和落盘，启用 PIPE_FAIL 后任何阶段失败均会停止。
run_step() {
  local title="$1" command_ec=0
  shift
  info_echo "开始：$title" || return 1
  if "$@" 2>&1 | strip_ansi_stream | /usr/bin/tee -a "$LOG_FILE"; then
    success_echo "完成：$title"
  else
    command_ec=$?
    error_echo "$title 失败，退出码 $command_ec；日志：$LOG_FILE"
    return "$command_ec"
  fi
}
# 验证实际命令可执行，不安装或升级工程工具链。
check_build_toolchain() {
  local tool=""
  for tool in node npm ohpm java; do
    command -v "$tool" >/dev/null 2>&1 || { error_echo "缺少 $tool，请检查 DevEco 工具目录和 PATH。"; return 1; }
  done
  run_step 'Node.js 健康检查' node --version || return $?
  run_step 'npm 健康检查' npm --version || return $?
  run_step 'ohpm 健康检查' ohpm --version || return $?
  run_step 'Java 健康检查' java -version || return $?
  if command -v hvigorw >/dev/null 2>&1; then
    run_step 'Hvigor 健康检查' hvigorw --version || return $?
  else
    error_echo '缺少 hvigorw，请把 DevEco tools/hvigor/bin 加入 PATH。'
    return 1
  fi
  jobs_command_sdk 'Flutter / Dart 初始化' "${FLUTTER_CMD[1]:A:h:h}" "" "${FLUTTER_CMD[@]}" --version || return $?
  local target="" help_text=""
  for target in "${BUILD_TARGETS[@]}"; do
    if ! help_text="$("${FLUTTER_CMD[@]}" build "$target" --help 2>&1)"; then
      log "$help_text"
      error_echo "此 SDK 不支持 flutter build $target，请切换匹配工程的鸿蒙适配版 SDK。"
      return 1
    fi
    if ! print -r -- "$help_text" | strip_ansi_stream | /usr/bin/grep -Fq "flutter build $target"; then
      error_echo "未确认 flutter build $target 能力；当前 SDK 可能是普通 Android / iOS 版本。"
      return 1
    fi
  done
}
# 从 Flutter 汇总目录和 DevEco 模块输出目录收集实际产物。
report_build_outputs() {
  local target="$1" output_root="" artifact="" found=0
  local -a artifacts=()
  OUTPUT_ROOTS=("$PROJECT_ROOT/build/ohos" "$PROJECT_ROOT/ohos/build")
  for output_root in "$PROJECT_ROOT"/ohos/*/build(N/); do
    OUTPUT_ROOTS+=("$output_root")
  done
  for output_root in "${OUTPUT_ROOTS[@]}"; do
    [[ -d "$output_root" && ! -L "$output_root" ]] || continue
    while IFS= read -r -d '' artifact; do
      [[ -s "$artifact" ]] || continue
      [[ ! -L "$artifact" ]] || continue
      if [[ -n "$BUILD_MARKER" && ! "$artifact" -nt "$BUILD_MARKER" ]]; then
        info_echo "保留历史 .$target，未计入本轮产物：$artifact"
        continue
      fi
      artifacts+=("$artifact")
    done < <(/usr/bin/find "$output_root" \( -type d \( -name node_modules -o -name intermediates \) -prune \) -o \( -type f -name "*.$target" \( -path '*/outputs/*' -o -path '*/build/ohos/*' \) -print0 \))
  done
  for artifact in "${artifacts[@]}"; do
    found=1
    if [[ "$artifact" == *-unsigned.* ]]; then
      warn_echo "未签名产物：$artifact；安装或上架前必须完成对应签名。"
    else
      success_echo "产物：$artifact（签名有效性由工程工具另行验证）"
    fi
  done
  (( found == 1 )) || { error_echo "构建命令结束，但未发现本轮非空 .$target 产物；旧包保留，请检查增量构建输出。"; return 1; }
  if [[ "$target" == hap ]]; then
    HAP_ARTIFACTS=("${artifacts[@]}")
  else
    APP_ARTIFACTS=("${artifacts[@]}")
  fi
  if [[ "${OPEN_AFTER_BUILD:-1}" == 1 ]]; then
    /usr/bin/open -R "${artifacts[1]}" 2>/dev/null || warn_echo "无法在 Finder 定位：${artifacts[1]}"
  fi
}
# 第二步可能重写输出目录，最终重新确认两类包同时存在。
verify_both_outputs() {
  local artifact="" hap_count=0 app_count=0
  for artifact in "${HAP_ARTIFACTS[@]}"; do
    [[ -f "$artifact" && -s "$artifact" && ! -L "$artifact" ]] && hap_count=$((hap_count + 1))
  done
  for artifact in "${APP_ARTIFACTS[@]}"; do
    [[ -f "$artifact" && -s "$artifact" && ! -L "$artifact" ]] && app_count=$((app_count + 1))
  done
  (( hap_count > 0 && app_count > 0 )) || { error_echo '最终检查失败：HAP 与 APP 未同时保留在输出目录。'; return 1; }
}
# 全部前置检查通过后，按顺序解析依赖和构建所选包型。
run_build_flow() {
  resolve_flutter_project || return $?
  cd "$PROJECT_ROOT" || return 1
  choose_flutter_sdk || return $?
  prepare_deveco_environment || return $?
  check_build_toolchain || return $?
  jobs_command_sdk_platform "${FLUTTER_CMD[1]:A:h:h}" "" "${FLUTTER_CMD[1]}" ohos || return $?
  info_echo '依赖来源：沿用工程 pubspec.yaml / 锁文件和当前 Pub、ohpm 软件源配置。'
  run_step 'flutter pub get' "${FLUTTER_CMD[@]}" pub get || return $?
  local target=""
  for target in "${BUILD_TARGETS[@]}"; do
    BUILD_MARKER="$(/usr/bin/mktemp "${LOG_FILE:h}/build-start.XXXXXX")" || return 1
    run_step "flutter build $target --$BUILD_MODE" "${FLUTTER_CMD[@]}" build "$target" "--$BUILD_MODE" || return $?
    report_build_outputs "$target" || return $?
  done
  verify_both_outputs || return $?
  success_echo "HAP + APP 构建与双产物检查完成；签名是否满足发布要求需结合工程配置核对。日志：$LOG_FILE"
}
# 保留失败退出码，避免尾部日志掩盖构建错误。
run_checked_build() {
  local build_ec=0
  if run_build_flow "$@"; then
    return 0
  else
    build_ec=$?
    error_echo "脚本已停止，退出码 $build_ec。日志：$LOG_FILE"
    exit "$build_ec"
  fi
}
# 以唯一入口编排确认、初始化和构建。
main() {
  # 自述与参数检查不运行工程命令；日志在确认后创建。
  if [[ "${1:-}" == --help || "${1:-}" == --check ]]; then
    show_script_intro_and_wait "$1"
    if [[ "$1" == --help ]]; then
      print -r -- '用法：/bin/zsh <本脚本> [--project <Flutter根目录>] [--mode release|debug|profile] [--flutter-sdk <鸿蒙SDK根目录>]'
      print -r -- '--check --project <目录>：只检查清单，不调用工具、不创建日志、不联网。'
      print -r -- '始终同时构建 HAP + APP；可用 FLUTTER_OHOS_SDK 指定 SDK，OPEN_AFTER_BUILD=0 禁止定位产物。'
      return 0
    fi
    shift
    parse_build_options "$@" || return $?
    resolve_flutter_project || return $?
    info_echo "工程清单检查通过；计划 HAP + APP / $BUILD_MODE；未验证工具链、签名或执行构建。"
    return 0
  fi
  show_script_intro_and_wait
  parse_build_options "$@" || return $?
  if [[ -z "$BUILD_BASE" ]]; then
    IFS= read -r 'BUILD_BASE?👉 输入或拖入 Flutter 鸿蒙工程根目录；Ctrl+C 取消：' || return 130
  fi
  initialize_script_runtime || return $?
  # 使用已解析的配置，避免重复解析丢失交互输入。
  run_checked_build
}


main "$@"
