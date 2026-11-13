"""Offline regression using temporary projects and fake tool executables only."""
# JOBS_TERMINAL_STYLE_GUARD_V1_BEGIN
# 保存与恢复由监督进程负责；导入本模块时不接管终端。
def _jobs_terminal_style_bootstrap_v1():
    import os as _os
    import base64 as _base64
    import json as _json
    import shutil as _shutil
    import subprocess as _subprocess
    import sys as _sys
    import tempfile as _tempfile

    _entry = _os.path.abspath(__file__)
    if _os.environ.get("JOBS_TERMINAL_STYLE_REEXEC") == _entry:
        _os.environ.pop("JOBS_TERMINAL_STYLE_REEXEC", None)
        return
    if (getattr(_sys, "frozen", False) or not _sys.stdin or not _sys.stdout
            or not _sys.stdin.isatty() or not _sys.stdout.isatty()
            or "NO_COLOR" in _os.environ
            or _os.environ.get("PLAIN_OUTPUT") == "1"
            or _os.environ.get("IS_SOURCETREE_RUNTIME") == "1"
            or any(_key.upper().startswith(("SOURCETREE", "SOURCE_TREE"))
                   for _key in _os.environ)):
        return
    if _os.name != "nt" and (_os.environ.get("TERM", "") in ("", "dumb")
                             or _os.environ.get("TMUX") or _os.environ.get("STY")):
        return
    _original = getattr(_sys, "orig_argv", None)
    _module_start = False
    for _argument in list(_original[1:]) if _original else []:
        if _argument == "--" or _os.path.abspath(_argument) == _entry:
            break
        if _argument in ("-c", "-m"):
            _module_start = True
            break
    if _module_start:
        _os.environ.update(NO_COLOR="1", PLAIN_OUTPUT="1", FORCE_COLOR="0", CLICOLOR="0")
        return
    _command = [_sys.executable] + (list(_original[1:]) if _original else list(_sys.argv))
    _environment = _os.environ.copy()
    _environment["JOBS_TERMINAL_STYLE_REEXEC"] = _entry
    _shell_core = r"""# 临时保护当前终端配色，业务进程自行管理原有退出清理。
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
"""
    _powershell_core = r"""$__jobsTerminalCommand = @($args)
# BEGIN JOBS_TERMINAL_STYLE_V1 - session-only colors; no profile or registry changes.
function New-JobsTerminalStyleState {
    if ($PSVersionTable.PSVersion.Major -lt 5) { return @{ JobsTerminalPlainFallback = $true; Before = @{} } }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $Host.Name -ne 'ConsoleHost') { return $null }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or [Console]::IsErrorRedirected) { return $null }
    if ((Test-Path Env:NO_COLOR) -or $env:TERM -ieq 'dumb' -or $env:PLAIN_OUTPUT -eq '1') { return $null }
    foreach ($key in [Environment]::GetEnvironmentVariables().Keys) {
        if ([string]$key -match '^(?i:SOURCE_?TREE)') { return $null }
    }
    if (-not ('Jobs.TerminalStyleV1.Native' -as [type])) {
        try {
        Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
namespace Jobs.TerminalStyleV1 {
    public static class Native {
        [StructLayout(LayoutKind.Explicit, Size=20, CharSet=CharSet.Unicode)]
        public struct InputRecord {
            [FieldOffset(0)] public ushort Kind;
            [FieldOffset(4)] public int Down;
            [FieldOffset(8)] public ushort Repeat;
            [FieldOffset(10)] public ushort Key;
            [FieldOffset(12)] public ushort Scan;
            [FieldOffset(14)] public char Character;
            [FieldOffset(16)] public uint Modifiers;
        }
        [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
        [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint mode);
        [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint mode);
        [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint milliseconds);
        [DllImport("kernel32.dll")] static extern bool GetNumberOfConsoleInputEvents(IntPtr h, out uint count);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] static extern bool ReadConsoleInputW(IntPtr h, [Out] InputRecord[] records, uint count, out uint read);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] static extern bool WriteConsoleInputW(IntPtr h, InputRecord[] records, uint count, out uint written);
        const string OwnerName = "JOBS_TERMINAL_STYLE_WINDOWS_OWNER";
        static readonly string[] Keys = { "10", "11", "4;0", "4;1", "4;2", "4;3", "4;4", "4;5", "4;6", "4;7", "4;8", "4;9", "4;10", "4;11", "4;12", "4;13", "4;14", "4;15" };
        static readonly string[] Hex = { "000000", "ff5f56", "5fd787", "ffd75f", "5fafff", "d787ff", "5fd7ff", "eeeeee", "9e9e9e", "ff8787", "87ffaf", "ffff87", "87bfff", "ffafff", "afffff", "ffffff" };
        static readonly Regex Reply = new Regex("\\x1b\\](?<key>10|11|4;[0-9]{1,2});(?<rgb>rgb:[0-9a-f]{1,4}/[0-9a-f]{1,4}/[0-9a-f]{1,4})(?:\\x07|\\x1b\\\\)", RegexOptions.IgnoreCase);
        public sealed class State {
            public IntPtr Input, Output;
            public uint OutputMode;
            public ConsoleColor Foreground, Background;
            public Dictionary<string,string> Original, Applied;
            public string Owner, PreviousOwner, Recovery;
            public bool Active, ModeChanged, Fallback;
            public Dictionary<string,string> EnvironmentBefore = new Dictionary<string,string>();
        }
        static string Escape(string key, string value) { return "\x1b]" + key + ";" + value + "\x07"; }
        static string Rgb(string hex) { return "rgb:" + hex.Substring(0,2) + "/" + hex.Substring(2,2) + "/" + hex.Substring(4,2); }
        static string Normal(string rgb) {
            string[] parts = rgb.Substring(4).Split('/');
            for (int n=0; n<3; n++) {
                int maximum = (1 << (4 * parts[n].Length)) - 1;
                int value = Convert.ToInt32(parts[n],16);
                parts[n] = ((value * 65535L + maximum/2) / maximum).ToString("x4");
            }
            return String.Join("/",parts);
        }
        // Preserve unrelated key/window records instead of consuming user input during color queries.
        static Dictionary<string,string> Query(State state) {
            uint pending;
            if (!GetNumberOfConsoleInputEvents(state.Input,out pending) || pending != 0) { return null; }
            StringBuilder commands = new StringBuilder();
            foreach (string key in Keys) { commands.Append(Escape(key,"?")); }
            Console.Write(commands.ToString());
            List<InputRecord> records = new List<InputRecord>();
            List<int> characterIndices = new List<int>();
            StringBuilder text = new StringBuilder();
            Dictionary<string,string> result = new Dictionary<string,string>();
            Stopwatch timer = Stopwatch.StartNew();
            try {
                while (timer.ElapsedMilliseconds < 600) {
                    if (result.Count == Keys.Length && GetNumberOfConsoleInputEvents(state.Input,out pending) && pending == 0) { break; }
                    if (WaitForSingleObject(state.Input,20) != 0) { continue; }
                    InputRecord[] item = new InputRecord[1]; uint read;
                    if (!ReadConsoleInputW(state.Input,item,1,out read) || read != 1) { break; }
                    int index = -1;
                    if (item[0].Kind == 1 && item[0].Character != '\0') {
                        if (item[0].Down != 0) { index = text.Length; text.Append(item[0].Character); }
                        else if (text.Length != 0 && text[text.Length-1] == item[0].Character) { index = text.Length-1; }
                    }
                    records.Add(item[0]); characterIndices.Add(index);
                    foreach (Match match in Reply.Matches(text.ToString())) {
                        string key = match.Groups["key"].Value;
                        if (Array.IndexOf(Keys,key) >= 0) { result[key] = match.Groups["rgb"].Value; }
                    }
                }
            } finally {
                bool[] used = new bool[text.Length];
                foreach (Match match in Reply.Matches(text.ToString())) {
                    for (int n=match.Index; n<match.Index+match.Length; n++) { used[n] = true; }
                }
                List<InputRecord> replay = new List<InputRecord>();
                for (int n=0; n<records.Count; n++) {
                    int index = characterIndices[n];
                    if (index < 0 || !used[index]) { replay.Add(records[n]); }
                }
                if (replay.Count != 0) {
                    uint written;
                    if (!WriteConsoleInputW(state.Input,replay.ToArray(),(uint)replay.Count,out written) || written != replay.Count) {
                        Console.Error.WriteLine("[Jobs] Could not replay terminal input; color protection is unavailable.");
                        result.Clear();
                    }
                }
            }
            return result.Count == Keys.Length ? result : null;
        }
        static void Plain(State state) {
            foreach (string key in new string[] { "NO_COLOR", "PLAIN_OUTPUT", "FORCE_COLOR", "CLICOLOR", "ANSI_COLORS_DISABLED" }) {
                state.EnvironmentBefore[key] = Environment.GetEnvironmentVariable(key);
                Environment.SetEnvironmentVariable(key, key == "FORCE_COLOR" || key == "CLICOLOR" ? "0" : "1");
            }
            state.Fallback = true;
        }
        public static void Enter(State state) {
            try {
                state.Input = GetStdHandle(-10); state.Output = GetStdHandle(-11);
                uint inputMode;
                if (!GetConsoleMode(state.Input,out inputMode) || !GetConsoleMode(state.Output,out state.OutputMode)) { Plain(state); return; }
                IntPtr window = GetConsoleWindow();
                if (window == IntPtr.Zero) { Plain(state); return; }
                string identity = window.ToInt64().ToString("x");
                state.PreviousOwner = Environment.GetEnvironmentVariable(OwnerName);
                if (!String.IsNullOrEmpty(state.PreviousOwner)) {
                    string[] owner = state.PreviousOwner.Split(':');
                    int pid; long started;
                    if (owner.Length == 3 && owner[0] == identity && Int32.TryParse(owner[1],out pid) && Int64.TryParse(owner[2],out started)) {
                        try { if (Process.GetProcessById(pid).StartTime.ToUniversalTime().Ticks == started) { return; } } catch {}
                    }
                }
                state.Foreground = Console.ForegroundColor; state.Background = Console.BackgroundColor;
                if ((state.OutputMode & 4) == 0) {
                    if (!SetConsoleMode(state.Output,state.OutputMode | 4)) { Plain(state); return; }
                    state.ModeChanged = true;
                }
                state.Original = Query(state);
                if (state.Original == null) { Restore(state); Plain(state); return; }
                state.Applied = new Dictionary<string,string>();
                state.Applied["10"] = "rgb:ff/ff/ff"; state.Applied["11"] = "rgb:00/00/00";
                for (int n=0; n<16; n++) { state.Applied["4;"+n] = Rgb(Hex[n]); }
                StringBuilder restore = new StringBuilder();
                foreach (string key in Keys) { restore.Append(Escape(key,state.Original[key])); }
                string encoded = Convert.ToBase64String(Encoding.UTF8.GetBytes(restore.ToString()));
                state.Recovery = Path.Combine(Path.GetTempPath(),"JobsTerminalStyle-"+Process.GetCurrentProcess().Id+"-"+Guid.NewGuid().ToString("N")+".ps1");
                string manual = "# Restore only the session colors saved by this Jobs script.\r\n"+
                    "if ([Console]::IsOutputRedirected) { throw 'Run in the original console.' }\r\n"+
                    "Add-Type -Namespace Jobs -Name RecoveryConsole -MemberDefinition '[System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern System.IntPtr GetStdHandle(int n); [System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m); [System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);'\r\n"+
                    "$h = [Jobs.RecoveryConsole]::GetStdHandle(-11); [uint32]$m = 0\r\n"+
                    "if (-not [Jobs.RecoveryConsole]::GetConsoleMode($h, [ref]$m)) { throw 'Run in the original console.' }\r\n"+
                    "try {\r\nif (-not [Jobs.RecoveryConsole]::SetConsoleMode($h, ($m -bor 4))) { throw 'Cannot enable terminal recovery.' }\r\n"+
                    "[Console]::Write([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"+encoded+"')))\r\n"+
                    "[Console]::ForegroundColor = [ConsoleColor]"+((int)state.Foreground)+"\r\n"+
                    "[Console]::BackgroundColor = [ConsoleColor]"+((int)state.Background)+"\r\n"+
                    "[Console]::Write([string][char]27 + '[39;49m')\r\n"+
                    "} finally { [void][Jobs.RecoveryConsole]::SetConsoleMode($h, $m) }\r\n";
                File.WriteAllText(state.Recovery,manual,new UTF8Encoding(false));
                state.Owner = identity+":"+Process.GetCurrentProcess().Id+":"+Process.GetCurrentProcess().StartTime.ToUniversalTime().Ticks;
                Environment.SetEnvironmentVariable(OwnerName,state.Owner);
                state.Active = true;
                foreach (string key in Keys) { Console.Write(Escape(key,state.Applied[key])); }
                Console.ForegroundColor = ConsoleColor.White; Console.BackgroundColor = ConsoleColor.Black;
                Dictionary<string,string> check = Query(state);
                foreach (string key in Keys) {
                    if (check == null || Normal(check[key]) != Normal(state.Applied[key])) { Restore(state); Plain(state); return; }
                }
            } catch (Exception error) {
                Restore(state); Plain(state);
                Console.Error.WriteLine("[Jobs] Terminal style unavailable: " + error.Message);
            }
        }
        public static void Restore(State state) {
            if (state == null) { return; }
            try {
                if (state.Active) {
                    Dictionary<string,string> current = Query(state);
                    bool complete = current != null;
                    if (current != null) {
                        bool restoreForeground = Console.ForegroundColor == ConsoleColor.White && Normal(current["10"]) == Normal(state.Applied["10"]) && Normal(current["4;15"]) == Normal(state.Applied["4;15"]);
                        bool restoreBackground = Console.BackgroundColor == ConsoleColor.Black && Normal(current["11"]) == Normal(state.Applied["11"]) && Normal(current["4;0"]) == Normal(state.Applied["4;0"]);
                        foreach (string key in Keys) {
                            if (Normal(current[key]) == Normal(state.Applied[key])) { Console.Write(Escape(key,state.Original[key])); }
                            else if (Normal(current[key]) != Normal(state.Original[key])) {
                                complete = false; Console.Error.WriteLine("[Jobs] Kept a concurrent color change: " + key);
                            }
                        }
                        if (restoreForeground) { Console.ForegroundColor = state.Foreground; Console.Write("\x1b[39m"); }
                        if (restoreBackground) { Console.BackgroundColor = state.Background; Console.Write("\x1b[49m"); }
                    }
                    if (complete) {
                        Dictionary<string,string> check = Query(state);
                        foreach (string key in Keys) { if (check == null || Normal(check[key]) != Normal(state.Original[key])) { complete = false; } }
                    }
                    if (complete) { File.Delete(state.Recovery); }
                    else { Console.Error.WriteLine("[Jobs] Color restore needs review. Manual recovery: powershell -NoProfile -File \""+state.Recovery+"\""); }
                }
            } catch (Exception error) {
                Console.Error.WriteLine("[Jobs] Color restore failed: "+error.Message+"; recovery: "+state.Recovery);
            } finally {
                if (state.Owner != null && Environment.GetEnvironmentVariable(OwnerName) == state.Owner) { Environment.SetEnvironmentVariable(OwnerName,state.PreviousOwner); }
                state.Active = false;
                uint currentMode;
                if (state.ModeChanged && GetConsoleMode(state.Output,out currentMode) && currentMode == (state.OutputMode | 4)) { SetConsoleMode(state.Output,state.OutputMode); }
                state.ModeChanged = false;
                if (state.Fallback) {
                    foreach (KeyValuePair<string,string> pair in state.EnvironmentBefore) {
                        string applied = pair.Key == "FORCE_COLOR" || pair.Key == "CLICOLOR" ? "0" : "1";
                        if (Environment.GetEnvironmentVariable(pair.Key) == applied) { Environment.SetEnvironmentVariable(pair.Key,pair.Value); }
                    }
                    state.Fallback = false;
                }
            }
        }
    }
}
'@
        } catch {
            [Console]::Error.WriteLine('[Jobs] Terminal style setup failed; using plain output: ' + $_.Exception.Message)
            return @{ JobsTerminalPlainFallback = $true; Before = @{} }
        }
    }
    return New-Object Jobs.TerminalStyleV1.Native+State
}
# Guard setup is optional; failure keeps business behavior and the user's original terminal settings.
function Start-JobsTerminalStyle {
    param($State)
    if ($State -is [Collections.IDictionary] -and $State.Contains('JobsTerminalPlainFallback')) {
        foreach ($key in @('NO_COLOR', 'PLAIN_OUTPUT', 'FORCE_COLOR', 'CLICOLOR', 'ANSI_COLORS_DISABLED')) {
            $State.Before[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $(if (@('FORCE_COLOR', 'CLICOLOR') -contains $key) { '0' } else { '1' }))
        }
        return
    }
    if ($null -ne $State) { [Jobs.TerminalStyleV1.Native]::Enter($State) }
}
# A finally block also runs for script exit and Ctrl+C; direct .NET calls avoid stopped pipelines.
function Stop-JobsTerminalStyle {
    param($State)
    if ($State -is [Collections.IDictionary] -and $State.Contains('JobsTerminalPlainFallback')) {
        foreach ($key in $State.Before.Keys) {
            $applied = if (@('FORCE_COLOR', 'CLICOLOR') -contains $key) { '0' } else { '1' }
            if ([Environment]::GetEnvironmentVariable($key) -ceq $applied) { [Environment]::SetEnvironmentVariable($key, $State.Before[$key]) }
        }
        return
    }
    if ($null -ne $State) { [Jobs.TerminalStyleV1.Native]::Restore($State) }
}
# END JOBS_TERMINAL_STYLE_V1

$__jobsTerminalStyleState = $null
$__jobsTerminalExitCode = 0
try {
    $__jobsTerminalStyleState = New-JobsTerminalStyleState
    Start-JobsTerminalStyle $__jobsTerminalStyleState
    if ($null -eq $__jobsTerminalCommand -or $__jobsTerminalCommand.Count -eq 0) { throw 'A program is required.' }
    $__jobsTerminalProgram = $__jobsTerminalCommand[0]
    $__jobsTerminalArguments = @()
    if ($__jobsTerminalCommand.Count -gt 1) { $__jobsTerminalArguments = @($__jobsTerminalCommand[1..($__jobsTerminalCommand.Count-1)]) }
    $LASTEXITCODE = 0
    & $__jobsTerminalProgram @__jobsTerminalArguments
    $__jobsTerminalCommandSucceeded = $?
    $__jobsTerminalExitCode = $LASTEXITCODE
    if (-not $__jobsTerminalCommandSucceeded -and $__jobsTerminalExitCode -eq 0) { $__jobsTerminalExitCode = 1 }
} finally {
    Stop-JobsTerminalStyle $__jobsTerminalStyleState
}
exit $__jobsTerminalExitCode
"""
    _interrupted = False
    # 等监督进程完成恢复后再退出，避免 Ctrl+C 提前关闭控制终端。
    def _wait(_arguments):
        nonlocal _interrupted
        _process = _subprocess.Popen(_arguments, env=_environment)
        while True:
            try:
                return _process.wait()
            except KeyboardInterrupt:
                _interrupted = True
                continue
    try:
        if _os.name == "nt":
            _powershell = _shutil.which("powershell.exe") or _shutil.which("pwsh.exe")
            if not _powershell:
                _os.environ.update(NO_COLOR="1", PLAIN_OUTPUT="1", FORCE_COLOR="0", CLICOLOR="0")
                return
            with _tempfile.TemporaryDirectory(prefix="jobs-terminal-style-") as _directory:
                _wrapper = _os.path.join(_directory, "guard.ps1")
                with open(_wrapper, "w", encoding="utf-8-sig", newline="\n") as _file:
                    _file.write(_powershell_core)
                # 原参数经 JSON 交给原生 Python 数组，避开旧 Windows PowerShell 的参数重解析。
                _environment["JOBS_TERMINAL_STYLE_PYTHON_COMMAND"] = _json.dumps(_command, ensure_ascii=False)
                _receipt = _os.path.join(_directory, "started")
                _environment["JOBS_TERMINAL_STYLE_PYTHON_RECEIPT"] = _receipt
                _bridge_source = """import json, os, subprocess, sys
command = json.loads(os.environ.pop('JOBS_TERMINAL_STYLE_PYTHON_COMMAND'))
with open(os.environ.pop('JOBS_TERMINAL_STYLE_PYTHON_RECEIPT'), 'wb') as receipt:
    receipt.write(b'started')
process = subprocess.Popen(command)
while True:
    try:
        result = process.wait()
        break
    except KeyboardInterrupt:
        continue
sys.exit(result if result >= 0 else 128 - result)
"""
                _bridge = "exec(__import__('base64').b64decode('" + _base64.b64encode(_bridge_source.encode()).decode() + "'))"
                _result = _wait([_powershell, "-NoProfile", "-ExecutionPolicy", "Bypass",
                                 "-File", _wrapper, _sys.executable, "-c", _bridge])
                if not _os.path.exists(_receipt) and not _interrupted and _result not in (129, 130, 143, -1073741510, 0xC000013A):
                    _os.environ.update(NO_COLOR="1", PLAIN_OUTPUT="1", FORCE_COLOR="0", CLICOLOR="0")
                    print("终端配色保护未能启动，保持原配色并使用纯文本。", file=_sys.stderr)
                    return
        else:
            _result = _wait(["/bin/sh", "-c", _shell_core + '\njobs_terminal_style_run "$@"\n',
                             "jobs-terminal-style", *_command])
    except KeyboardInterrupt:
        raise SystemExit(130) from None
    except OSError:
        _os.environ.update(NO_COLOR="1", PLAIN_OUTPUT="1", FORCE_COLOR="0", CLICOLOR="0")
        print("终端配色保护未能启动，保持原配色并使用纯文本。", file=_sys.stderr)
        return
    if _result in (-1073741510, 0xC000013A):
        raise SystemExit(130)
    raise SystemExit(_result if _result >= 0 else 128 - _result)


if __name__ == "__main__":
    _jobs_terminal_style_bootstrap_v1()
# JOBS_TERMINAL_STYLE_GUARD_V1_END

import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
ENTRY = next(ROOT.glob('*.command'))
spec = importlib.util.spec_from_file_location('harmony_config', ROOT / 'Scripts/project_config.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)

# Generated projects own copied helpers. Keep the real adapter/retry wrappers and
# intercept only their network boundary in existing business/configuration tests.
_original_project_runtime = config.project_runtime


def project_runtime_offline_fixture(root, *args):
    _original_project_runtime(root, *args)
    core = Path(root) / '.jobs-flutter/【MacOS】FlutterSDK网络选路.zsh/【MacOS】FlutterSDK网络选路.zsh'
    core.write_text(core.read_text() + '\njobs_flutter_route_prepare() { return 0; }\n')


config.project_runtime = project_runtime_offline_fixture


class HarmonySetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-harmony-tests-')
        self.base = Path(self.temp.name).resolve()
        self.project = self.base / "工程 空格 ' $(touch INJECTED) `touch BACKTICK`"
        (self.project / 'lib').mkdir(parents=True)
        (self.project / 'pubspec.yaml').write_text('name: example\n')
        (self.base / 'home').mkdir()
        self.env = dict(os.environ, TEST_PROJECT=str(self.project), TEST_BASE=str(self.base),
                        TEST_PYTHON=sys.executable, HOME=str(self.base / 'home'),
                        TMPDIR=str(self.base), PYTHONDONTWRITEBYTECODE='1', NO_COLOR='1')
        for key in ('HARMONY_EMULATOR_BIN', 'DEVECO_STUDIO_HOME', 'TOOL_HOME', 'JAVA_HOME',
                    'JOBS_HOMEBREW_BIN', 'JOBS_PYTHON_BIN', 'FVM_CACHE_PATH', 'FVM_FLUTTER_URL'):
            self.env.pop(key, None)

    def tearDown(self):
        self.temp.cleanup()

    def definitions(self):
        """Load definitions without running the entrypoint's initialize or main."""
        source, count = re.subn(r'\nmain "\$@"\s*\Z', '\n', ENTRY.read_text())
        self.assertEqual(count, 1, 'The entrypoint must have one final main invocation')
        return (source + '\nSCRIPT_DIR=' + shlex.quote(str(ROOT)) + '\n'
                'source "$SCRIPT_DIR/Scripts/harmony_workflow.zsh"\n'
                'JOBS_PYTHON_BIN="$TEST_PYTHON"\n'
                 'jobs_command_sdk() { shift 3; "$@"; }\n'
                 'jobs_command_sdk_platform() { return 0; }\n'
                 'jobs_command_fvm_runtime() { return 0; }\n'
                'setopt NO_NOMATCH PIPE_FAIL EXTENDED_GLOB\n')

    def assert_no_injection(self):
        for root in (self.base, self.project, self.base / 'home'):
            self.assertFalse((root / 'INJECTED').exists())
            self.assertFalse((root / 'BACKTICK').exists())

    def zsh(self, code, data='', expected=0):
        result = subprocess.run(['/bin/zsh', '-c', self.definitions() + code], input=data,
                                text=True, capture_output=True, cwd=self.base,
                                env=self.env, timeout=20)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assert_no_injection()
        return result

    def entry(self, *args):
        return subprocess.run(['/bin/zsh', str(ENTRY), *map(str, args)], input='', text=True,
                              capture_output=True, cwd=self.base, env=self.env, timeout=20)

    def snapshot(self):
        """Inspect every fixture file so read-only modes cannot silently write caches."""
        result = {}
        for path in self.base.rglob('*'):
            key = str(path.relative_to(self.base))
            if path.is_symlink():
                result[key] = ('link', os.readlink(path))
            elif path.is_file():
                result[key] = ('file', path.read_bytes(), path.stat().st_mode & 0o777)
            else:
                result[key] = ('directory',)
        return result

    def fake_executable(self, path, body='exit 0\n'):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/zsh\n' + body)
        path.chmod(0o700)
        return path

    def test_noninteractive_entry_cannot_install(self):
        before = self.snapshot()
        result = self.entry()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('交互终端', result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_help_is_noninteractive_and_does_not_write(self):
        before = self.snapshot()
        result = self.entry('--help')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('--check', result.stdout)
        self.assertIn('鸿蒙', result.stdout)
        self.assertNotIn('\x1b', result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_missing_readonly_environment_fails_without_writes(self):
        self.env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin'
        self.env['HARMONY_EMULATOR_BIN'] = str(self.base / 'missing/Emulator')
        before = self.snapshot()
        result = self.entry('--check', self.project)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_valid_readonly_environment_never_executes_tools_or_writes(self):
        bin_dir = self.base / 'bin'
        marker = 'touch "$TEST_BASE/SHOULD_NOT_EXECUTE"\nexit 73\n'
        for name in ('brew', 'fvm'):
            self.fake_executable(bin_dir / name, marker)
        emulator = self.fake_executable(self.base / 'clt/emulator/Emulator', marker)
        sdk = self.base / 'readonly-sdk'
        self.fake_executable(sdk / 'bin/flutter', marker)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(sdk)
        (self.project / 'ohos').mkdir()
        for filename in ('build-profile.json5', 'oh-package.json5'):
            (self.project / 'ohos' / filename).write_text('{}\n')
        self.env.update(PATH=str(bin_dir) + ':/usr/bin:/bin:/usr/sbin:/sbin',
                        HARMONY_EMULATOR_BIN=str(emulator))
        before = self.snapshot()
        result = self.entry('--check', self.project)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('未执行健康检查', result.stdout)
        self.assertIn('离线盘点', result.stdout)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.base / 'SHOULD_NOT_EXECUTE').exists())

    def test_sdk_selection_is_project_only_harmony(self):
        result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_choose_sdk || exit $?
print -r -- "SDK=$JOBS_SDK_FAMILY MODE=$JOBS_INSTALL_MODE REF=$JOBS_SDK_REF"
(( ! ${+functions[jobs_choose_install_mode]} && ! ${+functions[jobs_enable_global]} ))
''', '\n')
        self.assertIn('SDK=harmony MODE=fvm REF=3.35.7+ohos-1.0.5', result.stdout)
        self.assertFalse((self.project / '.fvmrc').exists())
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_existing_official_binding_requires_exact_yes(self):
        original = '{"flutter":"3.24.5","flavors":{"prod":"3.24.5"}}\n'
        path = self.project / '.fvmrc'
        for answer in ('', 'yes', 'Yes', 'YES ', ' YES', 'Y', 'anything', 'YES'):
            with self.subTest(answer=answer):
                path.write_text(original)
                before = self.snapshot()
                expected = 0 if answer == 'YES' else 130
                result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_choose_sdk || exit $?
print -r -- "$JOBS_SDK_FAMILY/$JOBS_INSTALL_MODE"
''', answer + '\n\n', expected=expected)
                self.assertEqual(self.snapshot(), before)
                if answer == 'YES':
                    self.assertIn('harmony/fvm', result.stdout)

    def test_legacy_binding_requires_explicit_switch(self):
        (self.project / '.fvm').mkdir()
        path = self.project / '.fvm/fvm_config.json'
        original = '{"flutterSdkVersion":"3.24.5"}'
        path.write_text(original)
        self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', '\n', expected=130)
        self.assertEqual(path.read_text(), original)

    def test_known_harmony_ref_is_preserved(self):
        original = json.dumps({'flutter': '3.35.7+ohos-1.0.5',
                               'flutterUrl': 'https://gitcode.com/CPF-Flutter/flutter_flutter.git'})
        path = self.project / '.fvmrc'
        path.write_text(original)
        result = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk || exit $?\nprint -r -- "$JOBS_SDK_REF"', '\n')
        self.assertIn('3.35.7+ohos-1.0.5', result.stdout)
        self.assertEqual(path.read_text(), original)

    def test_unknown_fork_cannot_switch_implicitly(self):
        for version, repo in (('myfork/stable', ''),
                              ('3.24.5', 'https://example.com/team/flutter.git'),
                              ('custom_jobs_ohos_' + 'a' * 40, 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')):
            with self.subTest(version=version):
                path = self.project / '.fvmrc'
                original = json.dumps({'flutter': version, 'flutterUrl': repo})
                path.write_text(original)
                self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', '\n\n', expected=130)
                self.assertEqual(path.read_text(), original)

    def test_sdk_ref_rejects_options_and_shell_code(self):
        result = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk || exit $?\nprint -r -- "REF=$JOBS_SDK_REF"',
                          '-bad\n$(touch INJECTED)\na..b\nrelease_1+ohos-2\n')
        self.assertIn('REF=release_1+ohos-2', result.stdout)

    def test_empty_paths_retry_and_quoted_finder_path_is_safe(self):
        result = self.zsh('jobs_choose_project || exit $?\nprint -r -- "ROOT=$PROJECT_ROOT"',
                          '\n\n/no/such/path\n' + shlex.quote(str(self.project)) + '\n')
        self.assertIn('ROOT=' + str(self.project), result.stdout)
        self.assertEqual(result.stderr.count('拖入或输入'), 4)

    def test_finder_escaped_path_is_safe(self):
        path = str(self.project)
        for char in ('\\', ' ', "'", '$', '`', '(', ')'):
            path = path.replace(char, '\\' + char)
        result = self.zsh('jobs_choose_project || exit $?\nprint -r -- "$PROJECT_ROOT"', path + '\n')
        self.assertIn(str(self.project), result.stdout)

    def test_argument_path_is_validated(self):
        result = self.zsh('jobs_choose_project "$TEST_PROJECT" || exit $?\nprint -r -- "$PROJECT_ROOT"')
        self.assertIn(str(self.project), result.stdout)

    def test_eof_cancels_path_and_sdk_prompts(self):
        self.zsh('jobs_choose_project', '\n\n', expected=130)
        self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', expected=130)

    def test_symlinked_configuration_is_rejected(self):
        for component in ('.fvm', '.jobs-flutter', '.vscode', '.gitignore', '.fvmrc'):
            with self.subTest(component=component):
                path = self.project / component
                path.symlink_to(self.base, target_is_directory=True)
                self.zsh('jobs_choose_project "$TEST_PROJECT"', expected=1)
                path.unlink()

    def test_corrupt_fvmrc_is_not_overwritten(self):
        path = self.project / '.fvmrc'
        path.write_text('{broken')
        with self.assertRaises(ValueError):
            config.configure_fvm(self.project, '/cache', 'https://repo.git')
        self.assertEqual(path.read_text(), '{broken')

    def test_fvm_configuration_preserves_version_and_flavors(self):
        path = self.project / '.fvmrc'
        path.write_text(json.dumps({'flutter': '3.24.5', 'flavors': {'prod': '3.24.5'}}))
        config.configure_fvm(self.project, '/cache/harmony', 'https://repo.git')
        data = json.loads(path.read_text())
        self.assertEqual(data['flutter'], '3.24.5')
        self.assertEqual(data['flavors'], {'prod': '3.24.5'})
        self.assertFalse(data['updateVscodeSettings'])
        self.assertFalse(data['runPubGetOnSdkChanges'])
        self.assertTrue(list(self.project.glob('.fvmrc.bak.*')))

    def test_vscode_preserves_user_settings_and_debug_configuration(self):
        (self.project / '.vscode').mkdir()
        settings = self.project / '.vscode/settings.json'
        settings.write_text(json.dumps({'editor.fontSize': 19, 'dart.sdkPath': '/old',
                                        'dart.env': {'CUSTOM': 'yes'}}))
        launch = self.project / '.vscode/launch.json'
        launch.write_text(json.dumps({'version': '0.2.0', 'configurations': [
            {'name': 'User debug', 'args': ['hello']}]}))
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        data = json.loads(settings.read_text())
        self.assertEqual(data['editor.fontSize'], 19)
        self.assertNotIn('dart.sdkPath', data)
        self.assertEqual(data['dart.env']['CUSTOM'], 'yes')
        self.assertEqual(json.loads(launch.read_text())['configurations'][0]['name'], 'User debug')
        self.assertEqual(len(json.loads(launch.read_text())['configurations']), 2)

    def test_jsonc_is_preserved_with_merge_suggestions(self):
        (self.project / '.vscode').mkdir()
        for filename in ('settings.json', 'launch.json'):
            (self.project / '.vscode' / filename).write_text('{\n // 用户说明\n "custom": true,\n}\n')
        before = {p.name: p.read_bytes() for p in (self.project / '.vscode').iterdir()}
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        for filename, content in before.items():
            self.assertEqual((self.project / '.vscode' / filename).read_bytes(), content)
            self.assertTrue((self.project / '.jobs-flutter' / (filename + '.suggested.json')).exists())

    def test_runtime_environment_and_launcher_quote_untrusted_paths(self):
        sdk = self.base / "SDK ' $(touch INJECTED) `touch BACKTICK`"
        self.fake_executable(sdk / 'bin/flutter', 'if [[ "$1" == precache && "$2" == --help ]]; then print -- --ohos; exit 0; fi\nprint -rl -- "$PWD" "$@" "$TOOL_HOME" "$JAVA_HOME"\n')
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(sdk)
        tool = self.base / "工具 ' $(touch INJECTED) `touch BACKTICK`"
        java = self.base / "Java ' $(touch INJECTED) `touch BACKTICK`"
        (tool / 'tools/node/bin').mkdir(parents=True)
        config.project_runtime(self.project, 'harmony', 'release', 'custom_jobs_ohos_test',
                               'a' * 40, str(sdk), str(tool), str(java))
        result = subprocess.run([str(self.project / '.jobs-flutter/flutter'), 'run', '-d',
                                 'device with space'], cwd=self.base, text=True,
                                capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for value in (str(self.project), str(tool), str(java), 'device with space'):
            self.assertIn(value, result.stdout)
        self.assert_no_injection()
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_launcher_follows_current_fvm_link_and_refuses_missing_binding(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        first, second = self.base / 'FIRST', self.base / 'SECOND'
        for sdk in (first, second):
            self.fake_executable(sdk / 'bin/flutter', 'print -r -- ' + sdk.name + '\n')
        link.symlink_to(first)
        config.project_runtime(self.project, 'harmony', 'release', 'custom_test', 'a' * 40,
                               str(first), str(self.base / 'tool'), str(self.base / 'java'))
        launcher = self.project / '.jobs-flutter/flutter'
        link.unlink()
        link.symlink_to(second)
        result = subprocess.run([str(launcher), '--version'], text=True, capture_output=True,
                                env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'SECOND')
        link.unlink()
        result = subprocess.run([str(launcher), '--version'], text=True, capture_output=True,
                                env=self.env, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('FIRST', result.stdout)

    def test_harmony_tag_is_peeled_and_missing_or_ambiguous_ref_fails(self):
        result = self.zsh('''JOBS_SDK_REPO=https://test.git
JOBS_SDK_REF=release
jobs_git() { print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release'; print -r -- 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/release^{}'; }
jobs_resolve_harmony_commit || exit $?
print -r -- "$JOBS_FVM_VERSION"
''')
        self.assertIn('custom_jobs_ohos_' + 'b' * 40, result.stdout)
        self.zsh('JOBS_SDK_REPO=https://test.git\nJOBS_SDK_REF=nope\njobs_git() { return 0; }\njobs_resolve_harmony_commit', expected=1)
        self.zsh('''JOBS_SDK_REPO=https://test.git
JOBS_SDK_REF=release
jobs_git() { print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release'; print -r -- 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/heads/release'; }
jobs_resolve_harmony_commit
''', expected=1)

    def test_binding_failure_restores_original_files_and_sdk_link(self):
        original = '{"flutter":"3.24.5"}\n'
        (self.project / '.fvmrc').write_text(original)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to('/old/sdk')
        (self.project / '.fvm/version').write_text('OLD_VERSION')
        (self.project / '.fvm/fvm_config.json').write_text('{"old":true}')
        self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  print NEW_VERSION > "$PROJECT_ROOT/.fvm/version"
  print NEW_RELEASE > "$PROJECT_ROOT/.fvm/release"
  print '{"new":true}' > "$PROJECT_ROOT/.fvm/fvm_config.json"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  return 7
}
jobs_setup_sdk
''', expected=7)
        self.assertEqual((self.project / '.fvmrc').read_text(), original)
        self.assertEqual((self.project / '.fvm/version').read_text(), 'OLD_VERSION')
        self.assertEqual((self.project / '.fvm/fvm_config.json').read_text(), '{"old":true}')
        self.assertFalse((self.project / '.fvm/release').exists())
        self.assertEqual(os.readlink(self.project / '.fvm/flutter_sdk'), '/old/sdk')

    def test_signal_restores_binding_and_stops_downstream(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        for name in ('TERM', 'INT', 'HUP'):
            with self.subTest(signal=name):
                (self.project / '.fvmrc').write_text('ORIGINAL')
                if link.is_symlink():
                    link.unlink()
                link.symlink_to('/old/sdk')
                self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  kill -''' + name + ''' $$
}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
''', expected=130)
                self.assertEqual((self.project / '.fvmrc').read_text(), 'ORIGINAL')
                self.assertEqual(os.readlink(link), '/old/sdk')
                self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())

    def test_ctrl_c_during_child_command_restores_binding(self):
        (self.project / '.fvmrc').write_text('BEFORE_INTERRUPT')
        ready = self.base / 'READY'
        child = self.base / 'interrupt-child.py'
        child.write_text('''import os, signal, sys, time
from pathlib import Path
signal.signal(signal.SIGINT, lambda *_: sys.exit(130))
Path(os.environ['TEST_BASE'], 'READY').touch()
time.sleep(30)
''')
        source = self.definitions() + '''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  "$TEST_PYTHON" "$TEST_BASE/interrupt-child.py"
}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
'''
        process = subprocess.Popen(['/bin/zsh', '-c', source], env=self.env, cwd=self.base,
                                   text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(ready.exists(), 'SDK setup did not reach the child command')
            os.killpg(process.pid, signal.SIGINT)
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 130, stdout + stderr)
            self.assertEqual((self.project / '.fvmrc').read_text(), 'BEFORE_INTERRUPT')
            self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()

    def test_failed_restore_keeps_recovery_snapshot(self):
        (self.project / '.fvmrc').write_text('RECOVER_ME')
        result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() { print changed > "$PROJECT_ROOT/.fvmrc"; return 7; }
jobs_restore_binding() { return 1; }
jobs_setup_sdk
''', expected=7)
        snapshots = list(self.base.glob('JobsFlutterBinding.*'))
        self.assertEqual(len(snapshots), 1, result.stdout + result.stderr)
        self.assertEqual((snapshots[0] / '.fvmrc').read_text(), 'RECOVER_ME')
        self.assertIn(str(snapshots[0]), result.stdout + result.stderr)

    def fake_fvm(self):
        path = self.base / 'fvm'
        path.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['TEST_BASE'] + '/calls.jsonl', 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
if args[0] != 'use':
    raise SystemExit('Unexpected fake FVM command')
if os.environ.get('FAIL_INSTALL'):
    raise SystemExit(9)
root = Path.cwd()
cache = Path(os.environ['FVM_CACHE_PATH'])
(root / '.fvm').mkdir(exist_ok=True)
link = root / '.fvm/flutter_sdk'
if link.is_symlink():
    link.unlink()
link.symlink_to(cache / 'versions' / args[1])
cfg = json.loads((root / '.fvmrc').read_text())
cfg['flutter'] = args[1]
(root / '.fvmrc').write_text(json.dumps(cfg))
''')
        path.chmod(0o700)
        return path

    def setup_fake_harmony_sdk(self):
        fake = self.fake_fvm()
        return '''PROJECT_ROOT="$TEST_PROJECT"
JOBS_FVM_BIN=''' + shlex.quote(str(fake)) + '''
JOBS_SDK_FAMILY=harmony
JOBS_INSTALL_MODE=fvm
JOBS_SDK_REPO="$JOBS_HARMONY_REPO"
JOBS_SDK_REF=release
jobs_git() {
  case "$1" in
    ls-remote) print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release' ;;
    clone)
      mkdir -p "$4/bin" "$4/.git"
      print -rl -- '#!/bin/zsh' '[[ "$*" != "build -h" ]] || print hap' 'exit 0' > "$4/bin/flutter"
      chmod +x "$4/bin/flutter"
      ;;
    -C) [[ "$3" != rev-parse ]] || print aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
  esac
  return 0
}
'''

    def test_custom_harmony_fvm_binding_never_calls_global(self):
        self.zsh(self.setup_fake_harmony_sdk() + 'jobs_setup_sdk', '\n')
        data = json.loads((self.project / '.fvmrc').read_text())
        self.assertEqual(data['flutter'], 'custom_jobs_ohos_' + 'a' * 40)
        self.assertEqual(data['flutterUrl'], 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')
        self.assertTrue((self.project / '.fvm/flutter_sdk/bin/flutter').exists())
        calls = [json.loads(line) for line in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([args[0] for args in calls], ['use'])
        self.assertIn('--skip-setup', calls[0])
        self.assertIn('--skip-pub-get', calls[0])
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_failed_fvm_binding_restores_original_version(self):
        original = '{"flutter":"3.19.0"}'
        (self.project / '.fvmrc').write_text(original)
        self.env['FAIL_INSTALL'] = '1'
        self.zsh(self.setup_fake_harmony_sdk() + 'jobs_setup_sdk', '\n', expected=9)
        self.assertEqual((self.project / '.fvmrc').read_text(), original)
        self.assertFalse((self.project / '.fvm/flutter_sdk').is_symlink())
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_harmony_cache_with_wrong_origin_is_not_overwritten(self):
        target = self.base / 'cache/versions/custom_jobs_ohos_test'
        (target / '.git').mkdir(parents=True)
        (target / 'keep').write_text('keep')
        self.zsh('''JOBS_FVM_CACHE="$TEST_BASE/cache"
JOBS_FVM_VERSION=custom_jobs_ohos_test
JOBS_SDK_REPO=https://expected.git
JOBS_SDK_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
jobs_git() { [[ "$*" != *rev-parse* ]] || { print aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; return; }; print https://wrong.git; }
jobs_clone_harmony
''', expected=1)
        self.assertEqual((target / 'keep').read_text(), 'keep')

    def test_unreadable_git_status_is_not_treated_as_clean(self):
        target = self.base / 'cache/versions/custom_jobs_ohos_test'
        (target / '.git').mkdir(parents=True)
        self.fake_executable(target / 'bin/flutter')
        self.zsh('''JOBS_FVM_CACHE="$TEST_BASE/cache"
JOBS_FVM_VERSION=custom_jobs_ohos_test
JOBS_SDK_REPO=https://expected.git
JOBS_SDK_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
jobs_git() {
  case "$3" in
    rev-parse) print aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
    remote) print https://expected.git ;;
    status) return 128 ;;
  esac
}
jobs_clone_harmony
''', expected=1)

    def test_device_filter_uses_target_platform_instead_of_device_id(self):
        devices = [
            {'id': 'ios1', 'name': 'iPhone', 'targetPlatform': 'ios'},
            {'id': '127.0.0.1:5555', 'name': 'Android', 'targetPlatform': 'android-arm64'},
            {'id': 'harmony id with space', 'name': 'Harmony', 'targetPlatform': 'ohos-arm64'},
            {'id': 'legacy', 'name': 'Legacy', 'platform': 'ohos-arm64'},
            {'id': 'bad\nvalue', 'name': 'Unsafe', 'targetPlatform': 'ohos-arm64'},
        ]
        result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'),
                                 'devices', 'harmony'], input=json.dumps(devices), text=True,
                                capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('ios1', result.stdout)
        self.assertNotIn('127.0.0.1:5555', result.stdout)
        self.assertNotIn('Unsafe', result.stdout)
        self.assertIn('harmony id with space\tHarmony\tohos-arm64', result.stdout)
        self.assertIn('legacy\tLegacy\tohos-arm64', result.stdout)

    def test_unsupported_and_control_character_devices_are_not_selectable(self):
        devices = [{'id': 'ready', 'name': 'Ready', 'targetPlatform': 'ohos-arm64'},
                   {'id': 'unsupported', 'name': 'Unsupported', 'targetPlatform': 'ohos-arm64',
                    'isSupported': False}]
        for field in ('id', 'name', 'targetPlatform'):
            for control in ('\t', '\n', '\r', '\x1b', '\x7f'):
                item = {'id': 'unsafe', 'name': 'Unsafe', 'targetPlatform': 'ohos-arm64'}
                item[field] += control + 'unexpected'
                devices.append(item)
        result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'),
                                 'devices', 'harmony'], input=json.dumps(devices), text=True,
                                capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'ready\tReady\tohos-arm64\n')

    def test_invalid_device_list_items_fail_clearly(self):
        for item in (None, 'invalid', 17, []):
            with self.subTest(item=item):
                result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'),
                                         'devices', 'harmony'], input=json.dumps([item]),
                                        text=True, capture_output=True, env=self.env, timeout=10)
                self.assertEqual(result.returncode, 1)
                self.assertIn('设备列表项必须是对象', result.stderr)
                self.assertNotIn('Traceback', result.stderr)

    def fake_jdk(self, java_version='17.0.16', javac_version='17.0.16',
                 java_result=0, javac_result=0):
        root = self.base / 'JDK 目录'
        self.fake_executable(root / 'bin/java',
                             'print -u2 -r -- ' + shlex.quote('openjdk version "' + java_version + '" 2025-07-15')
                             + '\nexit ' + str(java_result) + '\n')
        self.fake_executable(root / 'bin/javac',
                             'print -u2 -r -- ' + shlex.quote('javac ' + javac_version)
                             + '\nexit ' + str(javac_result) + '\n')
        self.env['TEST_JDK'] = str(root)
        return root

    def test_java_and_javac_17_are_accepted(self):
        self.fake_jdk()
        self.zsh('jobs_java_17_ok "$TEST_JDK"')

    def test_java_8_11_and_21_or_mismatched_javac_are_rejected(self):
        for java, javac in (('1.8.0_482', '1.8.0_482'), ('11.0.29', '11.0.29'),
                            ('21.0.9', '21.0.9'), ('17.0.16', '21.0.9'),
                            ('21.0.9', '17.0.16')):
            with self.subTest(java=java, javac=javac):
                self.fake_jdk(java, javac)
                self.zsh('jobs_java_17_ok "$TEST_JDK"', expected=1)

    def test_jre_without_javac_is_rejected(self):
        root = self.fake_jdk()
        (root / 'bin/javac').unlink()
        self.zsh('jobs_java_17_ok "$TEST_JDK"', expected=1)

    def test_java_or_javac_command_failure_is_rejected(self):
        for java_result, javac_result in ((3, 0), (0, 5), (3, 5)):
            with self.subTest(java_result=java_result, javac_result=javac_result):
                self.fake_jdk(java_result=java_result, javac_result=javac_result)
                self.zsh('jobs_java_17_ok "$TEST_JDK"', expected=1)

    def test_logged_command_failure_preserves_original_exit_code(self):
        self.zsh('''LOG_FILE="$TEST_BASE/command.log"
jobs_run /bin/zsh -c 'print FAILED_COMMAND_OUTPUT; exit 23'
''', expected=23)
        self.assertIn('FAILED_COMMAND_OUTPUT', (self.base / 'command.log').read_text())

    def test_tee_failure_is_not_reported_as_success(self):
        self.zsh('''LOG_FILE="$TEST_BASE/missing-parent/command.log"
jobs_run /bin/zsh -c 'print COMMAND_OUTPUT'
''', expected=1)

    def test_command_failure_takes_precedence_over_tee_failure(self):
        self.zsh('''LOG_FILE="$TEST_BASE/missing-parent/command.log"
jobs_run /bin/zsh -c 'print COMMAND_OUTPUT; exit 23'
''', expected=23)

    def test_invalid_fvm_value_returns_clear_error(self):
        (self.project / '.fvmrc').write_text('{"flutter":123}')
        result = self.zsh('jobs_config current "$TEST_PROJECT"', expected=1)
        self.assertIn('配置失败', result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def prepare_project_fixture(self):
        """Make native dependency and Flutter calls inspectable without a real SDK."""
        sdk = self.base / 'platform-sdk'
        tool = self.base / 'platform-tools'
        flutter = sdk / 'bin/flutter'
        flutter.parent.mkdir(parents=True, exist_ok=True)
        flutter.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['TEST_BASE'] + '/platform-calls.jsonl', 'a') as stream:
    stream.write(json.dumps(['flutter'] + args) + '\\n')
if args and args[0] == 'create':
    platform = Path(os.environ['TEST_PROJECT']) / 'ohos'
    platform.mkdir()
    (platform / 'build-profile.json5').write_text('{}')
    (platform / 'oh-package.json5').write_text('{}')
if args == ['pub', 'get'] and os.environ.get('FAIL_PUB'):
    raise SystemExit(29)
''')
        flutter.chmod(0o700)
        for name in ('ohpm', 'hvigorw'):
            self.fake_executable(tool / name,
                                 'print -r -- "' + name + ':$*" >> "$TEST_BASE/native-calls"\n')
        self.env.update(TEST_SDK=str(sdk), TEST_TOOL_ROOT=str(tool))
        return '''PROJECT_ROOT="$TEST_PROJECT"
JOBS_SDK_PATH="$TEST_SDK"
JOBS_TOOL_ROOT="$TEST_TOOL_ROOT"
JOBS_JAVA_HOME="$TEST_BASE/java"
JOBS_SDK_REF=release
JOBS_FVM_VERSION=custom_test
JOBS_SDK_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
JOBS_OHPM_BIN="$TEST_TOOL_ROOT/ohpm"
JOBS_HVIGOR_BIN="$TEST_TOOL_ROOT/hvigorw"
jobs_config() { [[ "$1" == runtime ]]; }
'''

    def platform_calls(self):
        path = self.base / 'platform-calls.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_missing_platform_requires_exact_yes_before_generation(self):
        source = self.prepare_project_fixture()
        for answer in ('', 'yes', 'Yes', 'YES ', ' YES', 'anything'):
            with self.subTest(answer=answer):
                self.zsh(source + 'jobs_prepare_project || exit $?\nprint "READY=$JOBS_PLATFORM_READY"',
                         answer + '\n')
                self.assertFalse((self.project / 'ohos').exists())
                self.assertTrue(all(call[1:] == ['doctor', '-v'] for call in self.platform_calls()))
                self.assertFalse((self.base / 'native-calls').exists())
        result = self.zsh(source + 'jobs_prepare_project || exit $?\nprint "READY=$JOBS_PLATFORM_READY"', 'YES\n')
        self.assertIn('READY=1', result.stdout)
        self.assertIn(['flutter', 'create', '--platforms=ohos', '.'], self.platform_calls())
        self.assertIn(['flutter', 'pub', 'get'], self.platform_calls())
        self.assertEqual((self.base / 'native-calls').read_text().splitlines(),
                         ['ohpm:install', 'hvigorw:--version'])

    def test_existing_incomplete_platform_is_never_regenerated(self):
        source = self.prepare_project_fixture()
        (self.project / 'ohos').mkdir()
        signature = self.project / 'ohos/build-profile.json5'
        signature.write_text('{"signingConfigs":[{"name":"USER_CERT"}]}')
        before = signature.read_bytes()
        self.zsh(source + 'jobs_prepare_project', expected=1)
        self.assertEqual(signature.read_bytes(), before)
        self.assertEqual(self.platform_calls(), [['flutter', 'doctor', '-v']])
        self.assertFalse((self.base / 'native-calls').exists())

    def test_pub_failure_stops_native_dependency_installation(self):
        source = self.prepare_project_fixture()
        (self.project / 'ohos').mkdir()
        for name in ('build-profile.json5', 'oh-package.json5'):
            (self.project / 'ohos' / name).write_text('{}')
        self.env['FAIL_PUB'] = '1'
        self.zsh(source + 'jobs_prepare_project', expected=29)
        self.assertEqual(self.platform_calls(), [['flutter', 'doctor', '-v'],
                                                 ['flutter', 'pub', 'get']])
        self.assertFalse((self.base / 'native-calls').exists())

    def test_empty_device_list_can_reload_and_select_harmony_only(self):
        sdk = self.base / 'devices-sdk'
        flutter = sdk / 'bin/flutter'
        flutter.parent.mkdir(parents=True)
        flutter.write_text('#!' + sys.executable + '\n' + '''import json, os
from pathlib import Path
counter = Path(os.environ['TEST_BASE']) / 'device-query-count'
count = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(count))
print(json.dumps([] if count == 1 else [
    {'id':'ios1', 'name':'iPhone', 'targetPlatform':'ios'},
    {'id':'harmony device', 'name':'Harmony', 'targetPlatform':'ohos-arm64'}]))
''')
        flutter.chmod(0o700)
        self.fake_executable(self.project / '.jobs-flutter/flutter',
                             'print -rl -- "$@" > "$TEST_BASE/run-args"\n')
        result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
JOBS_SDK_PATH=''' + shlex.quote(str(sdk)) + '''
JOBS_PLATFORM_READY=1
jobs_select_and_run
''', '\n\n\n')
        self.assertIn('暂无鸿蒙设备', result.stdout)
        self.assertNotIn('ios1', result.stdout)
        self.assertEqual((self.base / 'device-query-count').read_text(), '2')
        self.assertEqual((self.base / 'run-args').read_text().splitlines(),
                         ['run', '-d', 'harmony device'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
