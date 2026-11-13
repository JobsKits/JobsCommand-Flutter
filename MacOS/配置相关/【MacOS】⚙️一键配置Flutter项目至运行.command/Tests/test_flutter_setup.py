"""Offline regression: fake executables and temporary projects only."""
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
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENTRY = next(ROOT.glob('*.command'))
spec = importlib.util.spec_from_file_location('config', ROOT / 'Scripts/project_config.py')
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


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-flutter-tests-')
        self.base = Path(self.temp.name).resolve()
        self.project = self.base / "工程 空格 ' $(touch INJECTED) `touch BACKTICK`"
        (self.project / 'lib').mkdir(parents=True)
        (self.project / 'pubspec.yaml').write_text('name: example\n')
        (self.base / 'home').mkdir()
        self.env = dict(os.environ, TEST_PROJECT=str(self.project), TEST_BASE=str(self.base),
                        TEST_PYTHON=sys.executable, HOME=str(self.base / 'home'), TMPDIR=str(self.base))

    def tearDown(self):
        self.temp.cleanup()

    def zsh(self, code, data='', expected=0):
        source = f'source {shlex.quote(str(ENTRY))}\nJOBS_PYTHON_BIN="$TEST_PYTHON"\n' + 'jobs_command_sdk() { shift 3; "$@"; }\njobs_command_sdk_platform() { return 0; }\njobs_command_fvm_runtime() { return 0; }\n' + code
        result = subprocess.run(['/bin/zsh', '-c', source], input=data, text=True,
                                capture_output=True, cwd=self.base, env=self.env, timeout=15)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertFalse((self.base / 'INJECTED').exists())
        self.assertFalse((self.base / 'BACKTICK').exists())
        return result

    def test_only_exact_yes_enables_global(self):
        for answer in ('', 'yes', 'Yes', 'YES ', ' YES', 'Y', 'anything', 'YES'):
            with self.subTest(answer=answer):
                r = self.zsh('jobs_choose_install_mode || exit $?\nprint "MODE=$JOBS_INSTALL_MODE AUTH=$JOBS_GLOBAL_AUTHORIZED"', answer + '\n')
                expected = 'global AUTH=1' if answer == 'YES' else 'fvm AUTH=0'
                self.assertIn('MODE=' + expected, r.stdout)

    def test_empty_paths_retry_and_finder_quoting_is_safe(self):
        path = shlex.quote(str(self.project))
        r = self.zsh('jobs_choose_project || exit $?\nprint -r -- "ROOT=$PROJECT_ROOT"', '\n\n/no/such/path\n' + path + '\n')
        self.assertIn('ROOT=' + str(self.project), r.stdout)
        self.assertEqual(r.stderr.count('拖入或输入'), 4)

    def test_finder_escaped_spaces_and_tilde(self):
        r = self.zsh('jobs_choose_project || exit $?\nprint -r -- "$PROJECT_ROOT"',
                     str(self.project).replace(' ', '\\ ').replace("'", "\\'").replace('$', '\\$').replace('`', '\\`').replace('(', '\\(').replace(')', '\\)') + '\n')
        self.assertIn(str(self.project), r.stdout)

    def test_eof_cancels_instead_of_looping(self):
        self.zsh('jobs_choose_project', '\n\n', expected=130)
        self.zsh('jobs_choose_install_mode', '', expected=130)

    def test_global_without_authorization_does_not_execute(self):
        r = self.zsh('JOBS_INSTALL_MODE=global\nJOBS_FVM_BIN=/no/such/fvm\njobs_enable_global', expected=1)
        self.assertIn('缺少精确 YES', r.stderr)

    def test_argument_project_is_validated(self):
        r = self.zsh('jobs_choose_project "$TEST_PROJECT"\nprint -r -- "$PROJECT_ROOT"')
        self.assertIn(str(self.project), r.stdout)

    def test_linked_config_directory_is_rejected(self):
        (self.project / '.vscode').symlink_to(self.base, target_is_directory=True)
        self.zsh('jobs_choose_project "$TEST_PROJECT"', expected=1)

    def test_corrupt_fvmrc_is_not_overwritten(self):
        path = self.project / '.fvmrc'
        path.write_text('{broken')
        with self.assertRaises(ValueError):
            config.configure_fvm(self.project, '/cache', 'https://repo.git')
        self.assertEqual(path.read_text(), '{broken')

    def test_fvm_configuration_keeps_versions_flavors(self):
        p = self.project / '.fvmrc'
        p.write_text(json.dumps({'flutter': '3.24.5', 'flavors': {'prod': '3.24.5'}}))
        config.configure_fvm(self.project, '/cache/official', 'https://github.com/flutter/flutter.git')
        data = json.loads(p.read_text())
        self.assertEqual(data['flutter'], '3.24.5')
        self.assertEqual(data['flavors'], {'prod': '3.24.5'})
        self.assertFalse(data['updateVscodeSettings'])
        self.assertTrue(list(self.project.glob('.fvmrc.bak.*')))

    def test_existing_sdk_is_default(self):
        (self.project / '.fvmrc').write_text('{"flutter":"3.24.5"}')
        r = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\nJOBS_PYTHON_BIN="$TEST_PYTHON"\njobs_choose_sdk || exit $?\nprint "$JOBS_SDK_FAMILY/$JOBS_SDK_REF"', '\n\n')
        self.assertIn('official/3.24.5', r.stdout)

    def test_vscode_merges_instead_of_replacing(self):
        (self.project / '.vscode').mkdir()
        settings = self.project / '.vscode/settings.json'
        settings.write_text(json.dumps({'editor.fontSize': 19, 'dart.sdkPath': '/old', 'dart.env': {'CUSTOM': 'yes'}}))
        launch = self.project / '.vscode/launch.json'
        launch.write_text(json.dumps({'version': '0.2.0', 'configurations': [{'name': 'User debug', 'args': ['hello']}]}))
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        data = json.loads(settings.read_text())
        self.assertEqual(data['editor.fontSize'], 19)
        self.assertNotIn('dart.sdkPath', data)
        self.assertEqual(data['dart.env']['CUSTOM'], 'yes')
        self.assertEqual(json.loads(launch.read_text())['configurations'][0]['name'], 'User debug')
        config.vscode(self.project, {}, '.fvm/flutter_sdk', 'harmony')
        self.assertEqual(len(json.loads(launch.read_text())['configurations']), 2)

    def test_jsonc_is_preserved_with_suggestion(self):
        (self.project / '.vscode').mkdir()
        p = self.project / '.vscode/settings.json'
        original = '{\n // my comment\n "editor.fontSize": 19,\n}'
        p.write_text(original)
        config.vscode(self.project, {}, '.fvm/flutter_sdk', 'official')
        self.assertEqual(p.read_text(), original)
        self.assertTrue((self.project / '.jobs-flutter/settings.json.suggested.json').exists())

    def test_runtime_launcher_quotes_paths(self):
        sdk = self.base / "sdk ' $(touch INJECTED)"
        (sdk / 'bin').mkdir(parents=True)
        flutter = sdk / 'bin/flutter'
        flutter.write_text('#!/bin/zsh\nprint -rl -- "$PWD" "$@"\n')
        flutter.chmod(0o700)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(sdk)
        config.project_runtime(self.project, 'official', 'stable', '3.1.0', 'a'*40, str(sdk), '', '')
        result = subprocess.run([str(self.project / '.jobs-flutter/flutter'), 'run', '-d', 'device with space'], cwd=self.base, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('device with space', result.stdout)
        self.assertIn(str(self.project), result.stdout)
        self.assertFalse((self.project / 'INJECTED').exists())

    def test_switch_to_official_removes_only_owned_editor_environment(self):
        (self.project / '.vscode').mkdir()
        (self.project / '.jobs-flutter').mkdir()
        (self.project / '.jobs-flutter/sdk.json').write_text(json.dumps({'managedEnv': {'HOS_SDK_HOME': '/old/sdk', 'PATH': '/old/path'}}))
        settings = self.project / '.vscode/settings.json'
        settings.write_text(json.dumps({'dart.env': {'HOS_SDK_HOME': '/old/sdk', 'PATH': '/old/path', 'CUSTOM': 'keep'}}))
        config.project_runtime(self.project, 'official', '3.24.5', '3.24.5', 'a'*40, '/new/sdk', '', '')
        env = json.loads(settings.read_text())['dart.env']
        self.assertNotIn('HOS_SDK_HOME', env)
        self.assertNotIn('PATH', env)
        self.assertEqual(env['CUSTOM'], 'keep')

    def test_profile_is_idempotent_and_preserves_user_lines(self):
        profile = self.base / '.zprofile'
        profile.write_text('export USER_VALUE=hello\n')
        config.profile(profile, "/sdk ' $()/one")
        config.profile(profile, '/sdk/two')
        text = profile.read_text()
        self.assertIn('export USER_VALUE=hello', text)
        self.assertEqual(text.count('# >>> Jobs Flutter global >>>'), 1)
        self.assertNotIn('/sdk \'', text)

    def test_harmony_tag_is_peeled_and_missing_ref_fails(self):
        r = self.zsh('''JOBS_SDK_REPO=https://test.git
JOBS_SDK_REF=release
jobs_git() { print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release'; print -r -- 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/release^{}'; }
jobs_resolve_harmony_commit || exit $?
print "$JOBS_FVM_VERSION"
''')
        self.assertIn('custom_jobs_ohos_' + 'b'*40, r.stdout)
        self.zsh('JOBS_SDK_REPO=https://test.git\nJOBS_SDK_REF=nope\njobs_git() { return 0; }\njobs_resolve_harmony_commit', expected=1)

    def test_binding_restores_after_install_failure(self):
        old = '{"flutter":"3.24.5"}\n'
        (self.project / '.fvmrc').write_text(old)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to('/old/sdk')
        self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  return 7
}
jobs_setup_sdk
''', expected=7)
        self.assertEqual((self.project / '.fvmrc').read_text(), old)
        self.assertEqual(os.readlink(self.project / '.fvm/flutter_sdk'), '/old/sdk')

    def fake_fvm(self):
        fake = self.base / 'fvm'
        fake.write_text('#!' + sys.executable + '\n' + r'''
import os,sys,json
from pathlib import Path
args=sys.argv[1:]
root=Path.cwd(); cache=Path(os.environ['FVM_CACHE_PATH'])
with open(os.environ['TEST_BASE']+'/calls.jsonl','a') as stream: stream.write(json.dumps(args)+'\n')
if args[0]=='use':
    if os.environ.get('FAIL_INSTALL'): sys.exit(9)
    sdk=cache/'versions'/args[1]
    if not args[1].startswith('custom_'):
        (sdk/'bin').mkdir(parents=True,exist_ok=True)
        flutter=sdk/'bin/flutter'; flutter.write_text('#!/bin/zsh\n[[ "$*" != "build -h" ]] || print hap\nexit 0\n'); flutter.chmod(0o700)
    (root/'.fvm').mkdir(exist_ok=True)
    link=root/'.fvm/flutter_sdk'
    if link.is_symlink(): link.unlink()
    link.symlink_to(cache/'versions'/args[1])
    cfg=json.loads((root/'.fvmrc').read_text()); cfg['flutter']=args[1]; (root/'.fvmrc').write_text(json.dumps(cfg))
elif args[0]=='global':
    (cache/'default').symlink_to(cache/'versions'/args[1])
else: sys.exit(4)
''')
        fake.chmod(0o700)
        return fake

    def test_official_fvm_flow_does_not_write_global_environment(self):
        fake = self.fake_fvm()
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=official
JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
JOBS_SDK_REF=3.24.5
JOBS_TOOL_ROOT=""
JOBS_JAVA_HOME=""
jobs_git() {{ print {'a'*40}; }}
jobs_choose_install_mode || exit $?
jobs_setup_sdk || exit $?
jobs_prepare_project
''', '\n\n\n\n')
        calls = [json.loads(x) for x in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([x[0] for x in calls], ['use'])
        self.assertFalse((self.base / 'home/.zprofile').exists())
        self.assertTrue((self.project / '.jobs-flutter/flutter').exists())

    def test_global_flow_writes_only_after_yes(self):
        fake = self.fake_fvm()
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=official
JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
JOBS_SDK_REF=3.24.5
jobs_git() {{ print {'a'*40}; }}
jobs_choose_install_mode || exit $?
jobs_setup_sdk
''', 'YES\n\n')
        profile = self.base / 'home/.zprofile'
        self.assertTrue(profile.exists())
        self.assertIn('Jobs Flutter global', profile.read_text())
        calls = [json.loads(x) for x in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([x[0] for x in calls], ['use', 'global'])

    def test_failed_download_restores_project_and_never_calls_global(self):
        fake = self.fake_fvm()
        self.env['FAIL_INSTALL'] = '1'
        original = '{"flutter":"3.19.0"}'
        (self.project / '.fvmrc').write_text(original)
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=official
JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
JOBS_SDK_REF=3.24.5
jobs_choose_install_mode || exit $?
jobs_setup_sdk
''', 'YES\n\n', expected=9)
        self.assertEqual((self.project / '.fvmrc').read_text(), original)
        self.assertFalse((self.base / 'home/.zprofile').exists())
        calls = [json.loads(x) for x in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([x[0] for x in calls], ['use'])

    def test_harmony_download_and_fvm_binding_are_separate_from_global(self):
        fake = self.fake_fvm()
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=harmony
JOBS_SDK_REPO="$JOBS_HARMONY_REPO"
JOBS_SDK_REF=release
jobs_git() {{
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
}}
jobs_choose_install_mode || exit $?
jobs_setup_sdk
''', '\n\n')
        cfg = json.loads((self.project / '.fvmrc').read_text())
        self.assertEqual(cfg['flutter'], 'custom_jobs_ohos_' + 'a'*40)
        self.assertEqual(cfg['flutterUrl'], 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')
        self.assertTrue((self.project / '.fvm/flutter_sdk/bin/flutter').exists())
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

    def test_device_filter_uses_flutter_target_platform(self):
        devices = [{'id': 'ios1', 'name': 'iPhone', 'targetPlatform': 'ios'},
                   {'id': '127.0.0.1:5555', 'name': 'Harmony', 'targetPlatform': 'ohos-arm64'}]
        result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'), 'devices', 'harmony'], input=json.dumps(devices), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn('ios1', result.stdout)
        self.assertIn('127.0.0.1:5555', result.stdout)

    def test_noninteractive_entry_cannot_install(self):
        result = subprocess.run(['/bin/zsh', str(ENTRY)], input='', text=True, capture_output=True, env=self.env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('交互终端', result.stderr)

    def test_signal_restores_binding_and_stops_downstream(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        for signal in ('TERM', 'INT', 'HUP'):
            with self.subTest(signal=signal):
                (self.project / '.fvmrc').write_text('ORIGINAL')
                if link.is_symlink():
                    link.unlink()
                link.symlink_to('/old/sdk')
                self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  kill -''' + signal + ''' $$
}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
''', expected=130)
                self.assertEqual((self.project / '.fvmrc').read_text(), 'ORIGINAL')
                self.assertEqual(os.readlink(link), '/old/sdk')
                self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())

    def test_failure_restores_all_fvm_metadata(self):
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/version').write_text('OLD_VERSION')
        (self.project / '.fvm/fvm_config.json').write_text('{"old":true}')
        self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print NEW_VERSION > "$PROJECT_ROOT/.fvm/version"
  print NEW_RELEASE > "$PROJECT_ROOT/.fvm/release"
  print '{"new":true}' > "$PROJECT_ROOT/.fvm/fvm_config.json"
  return 7
}
jobs_setup_sdk
''', expected=7)
        self.assertEqual((self.project / '.fvm/version').read_text(), 'OLD_VERSION')
        self.assertEqual((self.project / '.fvm/fvm_config.json').read_text(), '{"old":true}')
        self.assertFalse((self.project / '.fvm/release').exists())

    def test_recovery_snapshot_is_kept_when_restore_fails(self):
        (self.project / '.fvmrc').write_text('RECOVER_ME')
        r = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() { print changed > "$PROJECT_ROOT/.fvmrc"; return 7; }
jobs_restore_binding() { return 1; }
jobs_setup_sdk
''', expected=7)
        snapshots = list(self.base.glob('JobsFlutterBinding.*'))
        self.assertEqual(len(snapshots), 1, r.stdout + r.stderr)
        self.assertTrue(any(p.is_file() and p.read_text() == 'RECOVER_ME' for p in snapshots[0].rglob('*')))
        self.assertIn(str(snapshots[0]), r.stdout + r.stderr)

    def test_unknown_fork_requires_explicit_family_selection(self):
        for version, repo in (('myfork/stable', ''), ('3.24.5', 'https://example.com/team/flutter.git'),
                              ('custom_jobs_ohos_' + 'a'*40, 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')):
            with self.subTest(version=version):
                (self.project / '.fvmrc').write_text(json.dumps({'flutter': version, 'flutterUrl': repo}))
                r = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', '\n\n', expected=130)
                self.assertNotIn('版本 / tag / 分支', r.stderr)
                self.assertEqual(json.loads((self.project / '.fvmrc').read_text())['flutter'], version)

    def test_invalid_fvm_value_has_clear_error(self):
        (self.project / '.fvmrc').write_text('{"flutter":123}')
        r = self.zsh('jobs_config current "$TEST_PROJECT"', expected=1)
        self.assertIn('配置失败', r.stderr)
        self.assertNotIn('Traceback', r.stderr)

    def test_launcher_follows_fvm_switch_and_refuses_missing_link(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        sdks = []
        for name in ('FIRST', 'SECOND'):
            sdk = self.base / name
            (sdk / 'bin').mkdir(parents=True)
            flutter = sdk / 'bin/flutter'
            flutter.write_text('#!/bin/zsh\nprint ' + name + '\n')
            flutter.chmod(0o700)
            sdks.append(sdk)
        link.symlink_to(sdks[0])
        config.project_runtime(self.project, 'official', '3.24.5', '3.24.5', 'a'*40, str(sdks[0]), '', '')
        launcher = self.project / '.jobs-flutter/flutter'
        link.unlink()
        link.symlink_to(sdks[1])
        r = subprocess.run([str(launcher), '--version'], text=True, capture_output=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), 'SECOND')
        link.unlink()
        r = subprocess.run([str(launcher), '--version'], text=True, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('FIRST', r.stdout)

    def test_launcher_permissions_are_repaired_without_content_change(self):
        args = (self.project, 'official', '3.24.5', '3.24.5', 'a'*40, '/sdk', '', '')
        config.project_runtime(*args)
        launcher = self.project / '.jobs-flutter/flutter'
        launcher.chmod(0o600)
        config.project_runtime(*args)
        self.assertTrue(os.access(launcher, os.X_OK))

    def test_harmony_status_failure_does_not_mean_clean_cache(self):
        target = self.base / 'cache/versions/custom_jobs_ohos_test'
        (target / '.git').mkdir(parents=True)
        (target / 'bin').mkdir()
        (target / 'bin/flutter').write_text('#!/bin/zsh\nexit 0\n')
        (target / 'bin/flutter').chmod(0o700)
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

    def test_reversed_profile_markers_are_not_overwritten(self):
        profile = self.base / '.zprofile'
        original = '# <<< Jobs Flutter global <<<\nexport USER_VALUE=hello\n# >>> Jobs Flutter global >>>\n'
        profile.write_text(original)
        with self.assertRaises(ValueError):
            config.profile(profile, '/sdk')
        self.assertEqual(profile.read_text(), original)

    def test_ctrl_c_during_child_command_stops_and_restores(self):
        (self.project / '.fvmrc').write_text('BEFORE_INTERRUPT')
        ready = self.base / 'READY'
        code = f'''source {shlex.quote(str(ENTRY))}
PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
jobs_setup_sdk_impl() {{
  print changed > "$PROJECT_ROOT/.fvmrc"
  touch "$TEST_BASE/READY"
  /bin/sleep 30
}}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
'''
        proc = subprocess.Popen(['/bin/zsh', '-c', code], env=self.env, cwd=self.base,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and proc.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(ready.exists(), 'SDK setup did not start')
            os.killpg(proc.pid, signal.SIGINT)
            stdout, stderr = proc.communicate(timeout=10)
            self.assertEqual(proc.returncode, 130, stdout + stderr)
            self.assertEqual((self.project / '.fvmrc').read_text(), 'BEFORE_INTERRUPT')
            self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.communicate()

    def test_real_fvm_custom_sdk_contract_without_download(self):
        fvm = shutil.which('fvm')
        if not fvm:
            self.skipTest('FVM 未安装，跳过真实 CLI 接口验证；不会安装工具')
        (self.project / 'pubspec.yaml').write_text('name: jobs_fixture\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n')
        cache = self.base / 'real-fvm-cache'
        version = 'custom_jobs_fixture'
        sdk = cache / 'versions' / version
        (sdk / 'bin').mkdir(parents=True)
        flutter = sdk / 'bin/flutter'
        flutter.write_text('#!/bin/zsh\nprint FIXTURE_ONLY\n')
        flutter.chmod(0o700)
        subprocess.run(['/usr/bin/git', 'init', str(sdk)], capture_output=True, check=True)
        config.configure_fvm(self.project, str(cache), 'https://github.com/flutter/flutter.git')
        env = dict(self.env, FVM_CACHE_PATH=str(cache), FVM_USE_GIT_CACHE='false', FVM_FLUTTER_URL='https://github.com/flutter/flutter.git')
        result = subprocess.run([fvm, 'use', version, '--skip-setup', '--skip-pub-get'],
                                cwd=self.project, env=env, input='', text=True,
                                capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.project / '.fvm/flutter_sdk').resolve(), sdk)
        self.assertEqual(json.loads((self.project / '.fvmrc').read_text())['flutter'], version)
        self.assertFalse((self.base / 'home/.zprofile').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
