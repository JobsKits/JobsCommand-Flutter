#!/usr/bin/env python3
"""Project-only configuration writes. Paths/data are arguments, never Python source."""
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

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import tempfile
from datetime import datetime


def backup(path):
    if path.exists():
        target = path.with_name(path.name + '.bak.' + datetime.now().strftime('%Y%m%d%H%M%S%f'))
        shutil.copy2(path, target)


def write(path, content, mode=None):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f'拒绝覆盖符号链接：{path}')
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == content:
        if mode is not None:
            os.chmod(path, mode)
        return
    backup(path)
    fd, stage = tempfile.mkstemp(prefix='.jobs-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(stage, mode or (path.stat().st_mode & 0o777 if path.exists() else 0o600))
        os.replace(stage, path)
    finally:
        if os.path.exists(stage):
            os.unlink(stage)


def read_object(path):
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f'配置顶层必须是对象：{path}')
    return data


def write_json(path, data):
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def ignore(root):
    path = root / '.gitignore'
    old = path.read_text() if path.exists() else ''
    lines = old.splitlines()
    extra = [x for x in ('/.fvm/', '/.jobs-flutter/', '*.bak.*') if x not in lines]
    if extra:
        write(path, old + ('\n' if old and not old.endswith('\n') else '') + '\n'.join(extra) + '\n')


def current(root):
    cfg = read_object(root / '.fvmrc')
    legacy = root / '.fvm/fvm_config.json'
    version = cfg.get('flutter', '')
    if not version and legacy.exists():
        version = read_object(legacy).get('flutterSdkVersion', '')
    repo = cfg.get('flutterUrl', '')
    if not isinstance(version, str) or not isinstance(repo, str):
        raise ValueError('.fvmrc 的 flutter / flutterUrl 必须是字符串')
    repo = repo.rstrip('/').removesuffix('.git')
    known_repos = {
        'https://github.com/flutter/flutter': 'official',
        'https://gitcode.com/CPF-Flutter/flutter_flutter': 'harmony',
        'https://gitcode.com/openharmony-tpc/flutter_flutter': 'harmony',
        'https://gitee.com/openharmony-sig/flutter_flutter': 'harmony',
    }
    lock = read_object(root / '.jobs-flutter/sdk.json')
    if repo and repo not in known_repos:
        print('unknown\n')
        print(f'已有自定义仓库 {repo}；必须明确选择 SDK 类型，不自动改为官方版。', file=sys.stderr)
    elif version.startswith('custom_jobs_ohos_') and lock.get('fvmVersion') == version:
        if not isinstance(lock.get('ref'), str) or not lock['ref']:
            raise ValueError('鸿蒙 SDK 记录缺少有效 ref')
        print('harmony')
        print(lock['ref'])
    elif (known_repos.get(repo) == 'harmony' and not version.startswith('custom_')
          and re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._+-]*', version)):
        print('harmony')
        print(version)
    elif version and re.fullmatch(r'(stable|beta|master|[0-9]+\.[0-9]+\.[0-9]+(?:[-+][a-zA-Z0-9.-]+)?)', version):
        print('harmony' if 'ohos' in version else 'official')
        print(version)
    else:
        print('unknown' if version else 'official')
        print('')
        if version:
            print(f'已有自定义 SDK {version}；请明确选择此次版本。', file=sys.stderr)


BINDING_FILES = ('.fvmrc', '.fvm/fvm_config.json', '.fvm/version', '.fvm/release')
BINDING_VERSIONS = '.fvm/versions'


def binding_versions(root):
    path = root / BINDING_VERSIONS
    if path.is_symlink() or (path.exists() and not path.is_dir()):
        raise ValueError('.fvm/versions 必须是普通目录，拒绝交给 FVM 删除')
    if not path.exists():
        return {'exists': False, 'links': {}}
    links = {}
    for entry in path.iterdir():
        if not entry.is_symlink():
            raise ValueError(f'.fvm/versions 只允许一层 SDK 符号链接，保留原内容：{entry}')
        links[entry.name] = os.readlink(entry)
    return {'exists': True, 'links': links}


def saved_binding_versions(manifest):
    state = manifest.get('versions')
    if (not isinstance(state, dict) or type(state.get('exists')) is not bool
            or not isinstance(state.get('links'), dict)):
        raise ValueError('恢复快照缺少有效 .fvm/versions 状态；保留快照，不修改工程')
    if not state['exists'] and state['links']:
        raise ValueError('恢复快照的 .fvm/versions 状态冲突；保留快照，不修改工程')
    for name, target in state['links'].items():
        if (not isinstance(name, str) or not name or name in ('.', '..')
                or '/' in name or '\0' in name or not isinstance(target, str)
                or not target or '\0' in target):
            raise ValueError('恢复快照含无效 SDK 链接；保留快照，不修改工程')
    return state


def validate_binding_targets(root):
    fvm = root / '.fvm'
    if fvm.is_symlink() or (fvm.exists() and not fvm.is_dir()):
        raise ValueError('.fvm 必须是普通目录，拒绝修改')
    for relative in BINDING_FILES:
        target = root / relative
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(f'绑定配置不是普通文件：{target}')
    link = root / '.fvm/flutter_sdk'
    if link.exists() and not link.is_symlink():
        raise ValueError('.fvm/flutter_sdk 不是符号链接，拒绝覆盖')
    return binding_versions(root)


def save_binding(root, snapshot):
    versions = validate_binding_targets(root)
    existing = []
    for relative in BINDING_FILES:
        original = root / relative
        if original.exists():
            saved = snapshot / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, saved)
            existing.append(relative)
    link = root / '.fvm/flutter_sdk'
    write_json(snapshot / 'manifest.json', {
        'files': existing, 'link': os.readlink(link) if link.is_symlink() else None,
        'versions': versions,
    })


def restore_binding(root, snapshot):
    manifest = read_object(snapshot / 'manifest.json')
    if not isinstance(manifest.get('files'), list) or 'link' not in manifest:
        raise ValueError('恢复快照不完整；保留快照，不修改工程')
    versions = saved_binding_versions(manifest)
    if (manifest['link'] is not None
            and (not isinstance(manifest['link'], str) or not manifest['link']
                 or '\0' in manifest['link'])):
        raise ValueError('恢复快照含无效 flutter_sdk 链接；保留快照，不修改工程')
    validate_binding_targets(root)  # Check all destinations before replacing any file.
    for relative in BINDING_FILES:
        if relative in manifest['files'] and not (snapshot / relative).is_file():
            raise ValueError(f'恢复快照缺少 {relative}')
    for relative in BINDING_FILES:
        target = root / relative
        if relative in manifest['files']:
            target.parent.mkdir(parents=True, exist_ok=True)
            fd, stage = tempfile.mkstemp(prefix='.jobs-restore-', dir=target.parent)
            os.close(fd)
            try:
                shutil.copy2(snapshot / relative, stage)
                os.replace(stage, target)
            finally:
                if os.path.lexists(stage):
                    os.unlink(stage)
        elif target.exists():
            target.unlink()
    link = root / '.fvm/flutter_sdk'
    if manifest['link'] is not None:
        link.parent.mkdir(parents=True, exist_ok=True)
        fd, stage = tempfile.mkstemp(prefix='.jobs-link-', dir=link.parent)
        os.close(fd)
        os.unlink(stage)
        try:
            os.symlink(manifest['link'], stage)
            os.replace(stage, link)
        finally:
            if os.path.lexists(stage):
                os.unlink(stage)
    elif link.is_symlink():
        link.unlink()
    # FVM use recreates this directory; unlink metadata only, never recurse into SDKs.
    current = binding_versions(root)
    directory = root / BINDING_VERSIONS
    if current['exists']:
        for name in current['links']:
            (directory / name).unlink()
        directory.rmdir()
    if versions['exists']:
        directory.mkdir(parents=True)
        for name, target in versions['links'].items():
            (directory / name).symlink_to(target)


def configure_fvm(root, cache, repo):
    path = root / '.fvmrc'
    data = read_object(path)  # Invalid JSON must fail before any replacement.
    data.update(cachePath=cache, flutterUrl=repo, useGitCache=False,
                updateVscodeSettings=False, updateMelosSettings=False,
                updateGitIgnore=False, runPubGetOnSdkChanges=False)
    write_json(path, data)
    ignore(root)


def vscode(root, env, sdk, family, previous_env=None):
    for filename in ('settings.json', 'launch.json'):
        path = root / '.vscode' / filename
        try:
            data = read_object(path)
            if filename == 'settings.json':
                old_env = data.get('dart.env', {})
                if not isinstance(old_env, dict):
                    raise ValueError('dart.env 不是对象')
                for key, value in (previous_env or {}).items():
                    if old_env.get(key) == value:
                        old_env.pop(key)
                old_env.update(env)
                data.update({'dart.flutterSdkPath': sdk, 'dart.env': old_env})
                data.pop('dart.sdkPath', None)
            else:
                configs = data.setdefault('configurations', [])
                if not isinstance(configs, list):
                    raise ValueError('configurations 不是数组')
                name = 'Jobs Flutter'
                config = {'name': name, 'type': 'dart', 'request': 'launch',
                          'program': 'lib/main.dart', 'env': env}
                # Devices are selected at run time; no stale simulator UUID is saved.
                existing = next((c for c in configs if isinstance(c, dict) and c.get('name') == name), None)
                if existing is None:
                    configs.append(config)
                else:
                    existing.update(config)
                data.setdefault('version', '0.2.0')
            write_json(path, data)
        except (ValueError, OSError) as error:
            # JSONC comments/trailing commas are legitimate VS Code inputs. Preserve them.
            suggestion = root / '.jobs-flutter' / (filename + '.suggested.json')
            suggested = ({'dart.flutterSdkPath': sdk, 'dart.env': env} if filename == 'settings.json'
                         else {'version': '0.2.0', 'configurations': [
                             {'name': 'Jobs Flutter', 'type': 'dart', 'request': 'launch',
                              'program': 'lib/main.dart', 'env': env}]})
            write_json(suggestion, suggested)
            print(f'保留 {path}（JSONC/不可合并：{error}）；请合并建议：{suggestion}', file=sys.stderr)


NETWORK_RESOURCES = ('【MacOS】FlutterSDK网络适配.zsh', '【MacOS】FlutterSDK网络选路.zsh')


def install_runtime_network(root):
    """Ship project-local SDK helpers; never retain a path into this configuration package."""
    scripts = Path(__file__).resolve().parent.parent
    target_root = root / '.jobs-flutter'
    if target_root.is_symlink() or (target_root.exists() and not target_root.is_dir()):
        raise ValueError('.jobs-flutter 必须是普通目录，拒绝写入网络资源')
    resources = []
    for name in NETWORK_RESOURCES:
        source = scripts / name
        target = target_root / name
        if target.is_symlink() or (target.exists() and not target.is_dir()):
            raise ValueError(f'网络资源目标必须是普通目录：{target}')
        for filename in (name, 'README.md'):
            original = source / filename
            if original.is_symlink() or not original.is_file():
                raise ValueError(f'缺少随包 SDK 网络资源：{original}')
            resources.append((target / filename, original.read_text(), 0o700 if filename == name else 0o600))
    for path, content, mode in resources:
        write(path, content, mode)


def runtime_launcher(family):
    header = '#!/bin/zsh\nset -e\numask 077\n' + f'family={shlex.quote(family)}\n'
    return header + r'''project="${0:A:h:h}"
cd -- "$project"
source "$project/.jobs-flutter/env.zsh"
sdk="$project/.fvm/flutter_sdk"
if [[ ! -L "$sdk" || ! -x "$sdk/bin/flutter" ]]; then
  print -u2 -r -- "工程 FVM 链接不可用，请重新运行配置脚本；未使用系统 Flutter。"
  exit 1
fi
source "$project/.jobs-flutter/【MacOS】FlutterSDK网络适配.zsh/【MacOS】FlutterSDK网络适配.zsh"
LOG_FILE="${JOBS_FLUTTER_ROUTE_LOG:-}"
[[ -n "$LOG_FILE" ]] || LOG_FILE="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/JobsFlutterProjectSdk.XXXXXX")"
# SDK获取可重试；业务保持原argv、stdin/stdout和退出码，只执行一次。
case "${1:-}" in
  --version)
    jobs_command_sdk '工程Flutter / Dart首次补齐' "$sdk" '' "$sdk/bin/flutter" "$@"
    exit $?
    ;;
  precache)
    JOBS_FLUTTER_ROUTE_MODE=platform jobs_command_sdk '工程Flutter平台SDK获取' "$sdk" '' "$sdk/bin/flutter" "$@"
    exit $?
    ;;
  upgrade)
    jobs_command_sdk '升级前当前Flutter / Dart补齐' "$sdk" '' "$sdk/bin/flutter" --version >&2
    jobs_command_sdk_load
    JOBS_SDK_LOG_REPLACED=0 JOBS_FLUTTER_ROUTE_CAPTURE_OUTPUT=1 jobs_flutter_upgrade '工程Flutter SDK升级' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
    exit $?
    ;;
esac
jobs_command_sdk '工程Flutter / Dart首次补齐' "$sdk" '' "$sdk/bin/flutter" --version >&2
platform='' needs_platform=0 device='' devices='' index=0
case "${1:-}" in
  build)
    case "${2:-}" in
      apk|appbundle|aar) platform=android ;;
      ios|ipa|ios-framework) platform=ios ;;
      macos) platform=macos ;;
      web) platform=web ;;
      hap|app|ohos) platform=ohos ;;
      -h|--help) ;;
      *) needs_platform=1 ;;
    esac
    ;;
  run)
    needs_platform=1
    for (( index=2; index<=$#; index++ )); do
      case "$argv[index]" in
        -h|--help) needs_platform=0; break ;;
        -d|--device-id) (( index++ )); device="${argv[index]:-}" ;;
        --device-id=*) device="${argv[index]#*=}" ;;
      esac
    done
    if (( needs_platform )); then
      case "$device" in
        macos) platform=macos ;; chrome|edge|web-server) platform=web ;;
        *)
          if [[ "$family" == harmony ]]; then
            platform=ohos
          elif devices="$(jfs_fvm_timed "$sdk/bin/flutter" devices --machine --device-timeout 5 2>/dev/null)"; then
            platform="$(print -r -- "$devices" | /usr/bin/osascript -l JavaScript -e 'ObjC.import("Foundation"); function run(a){var d=$.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile; var s=ObjC.unwrap($.NSString.alloc.initWithDataEncoding(d,$.NSUTF8StringEncoding)); var rows=JSON.parse(s); if(!Array.isArray(rows)) return ""; var selected=rows.filter(function(v){return v&&v.isSupported!==false&&(!a[0]||v.id===a[0]);}); if(selected.length!==1) return ""; var p=String(selected[0].targetPlatform||selected[0].platform||""); return /^android/.test(p)?"android":/^ios/.test(p)?"ios":/^(darwin|macos)/.test(p)?"macos":/^web/.test(p)?"web":/^(ohos|openharmony)/.test(p)?"ohos":"";}' "$device" 2>/dev/null)" || platform=''
          fi
          ;;
      esac
    fi
    ;;
esac
if [[ -n "$platform" ]]; then
  jobs_command_sdk_platform "$sdk" '' "$sdk/bin/flutter" "$platform" >&2
  jobs_flutter_sdk_once '工程Flutter命令（仅一次）' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
elif (( needs_platform )); then
  print -u2 -r -- '设备/目标平台尚未确定，按当前engine代表对象检测通道，原业务仅执行一次。'
  JOBS_FLUTTER_ROUTE_MODE=platform jobs_flutter_sdk_once '工程Flutter命令（平台通道，仅一次）' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
else
  jobs_flutter_sdk_once '工程Flutter命令（仅一次）' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
fi
'''


def project_runtime(root, family, ref, version, commit, sdk, tool, java):
    previous_env = read_object(root / '.jobs-flutter/sdk.json').get('managedEnv', {})
    env = {}
    dirs = []
    if family == 'harmony':
        tool = Path(tool)
        sdk_home = str(tool / 'sdk')
        hdc = str(tool / 'sdk/default/openharmony/toolchains')
        env.update(TOOL_HOME=str(tool), DEVECO_SDK_HOME=sdk_home, HOS_SDK_HOME=sdk_home,
                   OHOS_HOME=sdk_home,
                   OHOS_SDK_HOME=sdk_home, HDC_HOME=hdc, JAVA_HOME=java)
        for relative in ('tools/node/bin', 'tool/node/bin', 'tools/ohpm/bin', 'ohpm/bin',
                         'tools/hvigor/bin', 'hvigor/bin'):
            if (tool / relative).is_dir():
                dirs.append(str(tool / relative))
        dirs += [hdc, str(Path(java) / 'bin')]
    # Only explicit mirror overrides are saved. Never guess an OH engine mirror.
    for key in ('PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL', 'PUB_CACHE'):
        if key in os.environ:
            env[key] = os.environ[key]
    lines = ['# Generated project environment; source only for this project.']
    for key, value in env.items():
        export = f'export {key}={shlex.quote(value)}'
        if key in ('PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL', 'PUB_CACHE'):
            lines.append(f'(( ${{+{key}}} )) || {export}')
        else:
            lines.append(export)
    if dirs:
        prefix = ':'.join(dirs)
        lines += [f'export PATH={shlex.quote(prefix)}:"$PATH"']
        # VS Code does not expand shell variables inside dart.env.
        env['PATH'] = prefix + ':' + os.environ['PATH']
    write(root / '.jobs-flutter/env.zsh', '\n'.join(lines) + '\n')
    install_runtime_network(root)
    write(root / '.jobs-flutter/flutter', runtime_launcher(family), 0o700)
    write_json(root / '.jobs-flutter/sdk.json', {
        'family': family, 'ref': ref, 'fvmVersion': version, 'commit': commit, 'sdk': sdk,
        'toolHome': str(tool) if tool else '', 'javaHome': java,
        'managedEnv': env,
    })
    ignore(root)
    vscode(root, env, '.fvm/flutter_sdk', family, previous_env)


def main():
    action, *args = sys.argv[1:]
    if action == 'current':
        current(Path(args[0]))
    elif action == 'fvm':
        configure_fvm(Path(args[0]), *args[1:])
    elif action == 'runtime':
        project_runtime(Path(args[0]), *args[1:])
    elif action == 'binding-check':
        validate_binding_targets(Path(args[0]))
    elif action == 'binding-save':
        save_binding(Path(args[0]), Path(args[1]))
    elif action == 'binding-restore':
        restore_binding(Path(args[0]), Path(args[1]))
    elif action == 'devices':
        family = args[0]
        devices = json.load(sys.stdin)
        if not isinstance(devices, list):
            raise ValueError('设备列表不是数组')
        for device in devices:
            if not isinstance(device, dict):
                raise ValueError('设备列表项必须是对象')
            if device.get('isSupported') is False:
                continue
            platform = device.get('targetPlatform', device.get('platform', ''))
            if family == 'harmony' and not str(platform).startswith('ohos'):
                continue
            values = [str(device.get(k, '')) for k in ('id', 'name')]
            if all(v and not any(ord(c) < 32 or ord(c) == 127 for c in v) for v in values + [str(platform)]):
                print('\t'.join(values + [str(platform)]))
    else:
        raise ValueError('未知配置操作')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f'配置失败：{error}', file=sys.stderr)
        sys.exit(1)
