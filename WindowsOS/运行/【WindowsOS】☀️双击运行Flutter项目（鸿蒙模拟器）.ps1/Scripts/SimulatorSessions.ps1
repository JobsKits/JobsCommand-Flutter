# SimulatorSessions.ps1 | JobsCommand-Flutter
# Created by Jobs on 2026年10月29日，星期四.
# 选择、启动鸿蒙实例与有界等待 Flutter；不注册扩展、不改全局 SDK。
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
try {
    if ($MyInvocation.InvocationName -ne '.') {
        $__jobsTerminalStyleState = New-JobsTerminalStyleState
        Start-JobsTerminalStyle $__jobsTerminalStyleState
    }
# BEGIN JOBS_TERMINAL_STYLE_ORIGINAL_BODY
function Select-JobsSimulatorItem {
    param([string]$Title, [string[]]$Items)
    $selector = Import-JobsFeature 'Packager'
    return & $selector { param($t, $items) Select-JobsPackagerChoice $t $items } $Title $Items
}
function Start-JobsHarmonySimulator {
    param([switch]$Create, [switch]$ExistingOnly)
    $module = Import-JobsFeature 'Harmony'
    $check = & $module { param($install) Get-JobsHarmonyCheck -InstallMissing:$install } ([bool](-not $ExistingOnly))
    $names = @($check.Instances | ForEach-Object { [string]$_.name })
    $selected = ''
    if (-not $Create -and $names.Count -gt 0) {
        $choices = @($names)
        if (-not $ExistingOnly) { $choices += '➕ 初始化新的鸿蒙模拟器' }
        $selected = Select-JobsSimulatorItem '选择鸿蒙模拟器' $choices
        if ($selected -ceq '➕ 初始化新的鸿蒙模拟器') { $Create = $true }
    } elseif ($names.Count -eq 0 -and $ExistingOnly) {
        throw '尚无已实例化的鸿蒙模拟器；先运行“📱双击初始化鸿蒙模拟器”。'
    } else { $Create = $true }
    if ($Create) {
        & $module { Invoke-JobsHarmonySimulatorAction -Target ([Environment]::GetFolderPath('DesktopDirectory')) -NoStart }
        $latest = @(& $module { param($emulator) Get-JobsHarmonyInstances $emulator } $check.Emulator)
        $created = @($latest | Where-Object { $_.name -cnotin $names })
        if ($created.Count -ne 1) { throw '未确认唯一新实例；已取消或现场已变化，未启动任何设备。' }
        $selected = $created[0].name
    }
    if ($selected -cnotmatch '\A[A-Za-z][A-Za-z0-9_+ ]{0,63}\z' -or $selected.EndsWith(' ')) { throw '所选实例名称无效，未启动。' }
    & $module {
        param($emulator, $name)
        Confirm-JobsHarmonyLicenses $emulator
        $directory = Join-Path ([IO.Path]::GetTempPath()) ('JobsHarmonyStart-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($directory)
        $output = Join-Path $directory 'emulator.stdout.log'
        $errors = Join-Path $directory 'emulator.stderr.log'
        $arguments = '-start ' + (Quote-JobsArgument $name)
        $process = Start-Process -FilePath $emulator -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $output -RedirectStandardError $errors
        try {
            if ($process.WaitForExit(1000) -and $process.ExitCode -ne 0) { throw ('模拟器启动失败，退出码 ' + $process.ExitCode + '；日志：' + $directory) }
        } finally { $process.Dispose() }
        Write-JobsHarmonyMessage ('已提交所选鸿蒙模拟器启动：' + $name + '；启动日志：' + $directory)
    } $check.Emulator $selected
    return [pscustomobject]@{ Name = $selected; Emulator = $check.Emulator }
}
function Invoke-JobsSimulatorFlutterQuery {
    param([string]$Flutter,[string]$Project,[string[]]$Arguments,[int]$TimeoutSeconds=30)
    if(-not(Get-Command Import-JobsSdkDownloadRoute -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'SdkDownloadOutput.ps1')}
    Import-JobsSdkDownloadRoute
    return Invoke-JobsSdkRoutedCommand $Flutter $Arguments $Project $TimeoutSeconds
}
function Get-JobsHarmonyEmulatorDevices {
    param([string]$Json)
    if (-not $Json.TrimStart().StartsWith('[')) { throw 'Flutter 设备清单必须为 JSON 数组。' }
    # 5.1 的 ConvertFrom-Json 保留顶层数组；赋值后再遍历，避免二次包装成嵌套数组。
    $records = $Json | ConvertFrom-Json -ErrorAction Stop
    $seen = @{}
    foreach ($device in $records) {
        if ($null -eq $device -or $null -eq $device.PSObject.Properties['targetPlatform'] -or $device.targetPlatform -notmatch 'ohos|harmony') { continue }
        if ($null -eq $device.PSObject.Properties['emulator'] -or $device.emulator -isnot [bool] -or -not $device.emulator) { continue }
        if ($null -ne $device.PSObject.Properties['isSupported'] -and $device.isSupported -eq $false) { continue }
        if ($null -eq $device.PSObject.Properties['id'] -or $device.id -isnot [string] -or -not $device.id -or $device.id.StartsWith('-') -or $device.id -match '[\x00-\x20\x7f]') { throw '鸿蒙模拟器设备 ID 无效。' }
        if ($seen.ContainsKey($device.id)) { throw '鸿蒙模拟器设备 ID 重复。' }
        $seen[$device.id] = $true
        $device
    }
}
function Invoke-JobsHarmonySimulatorRun {
    param([string]$Project, [string]$FlutterSdk, [string]$Log)
    if (-not [IO.Directory]::Exists((Join-Path $Project 'ohos'))) { throw '工程缺少 ohos 平台；不会自动创建或替换工程 SDK。' }
    $environmentNames = @('PATH','TOOL_HOME','DEVECO_SDK_HOME','JAVA_HOME','NODE_HOME','NO_COLOR','FORCE_COLOR','CLICOLOR','ANSI_COLORS_DISABLED','npm_config_color')
    $saved = @{}
    foreach ($name in $environmentNames) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    try {
        $module = Import-JobsFeature 'Packager'
        if (-not $FlutterSdk) { $FlutterSdk = $env:FLUTTER_OHOS_SDK }
        $flutter = & $module { param($p,$sdk,$l) $script:PackagerLog=$l; Get-JobsPackagerFlutter -Project $p -SdkRoot $sdk } $Project $FlutterSdk $Log
        $capability = Invoke-JobsSimulatorFlutterQuery $flutter $Project @('build','hap','--help') 60
        if ($capability.ExitCode -ne 0 -or $capability.StdOut -notmatch 'flutter\s+build\s+hap\b') { throw '当前 SDK 未确认支持鸿蒙 HAP；请指定工程适配 SDK，不会回退到普通 Flutter。' }
        $simulator = Start-JobsHarmonySimulator
        $sdkCandidate = Join-Path (Split-Path -Parent (Split-Path -Parent $simulator.Emulator)) 'sdk'
        if (-not $env:DEVECO_SDK_HOME -and [IO.Directory]::Exists($sdkCandidate)) { $env:DEVECO_SDK_HOME = $sdkCandidate }
        & $module { Initialize-JobsPackagerHarmonyEnvironment }
        $timeout = 180
        if ($env:JOBS_HARMONY_DEVICE_TIMEOUT) {
            if (-not [int]::TryParse($env:JOBS_HARMONY_DEVICE_TIMEOUT, [ref]$timeout) -or $timeout -lt 1 -or $timeout -gt 600) { throw 'JOBS_HARMONY_DEVICE_TIMEOUT 需为 1～600 秒。' }
        }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $devices = @()
        while ($clock.Elapsed.TotalSeconds -lt $timeout) {
            $result = Invoke-JobsSimulatorFlutterQuery $flutter $Project @('devices','--machine') ([Math]::Max(1,[Math]::Min(30,[int][Math]::Ceiling($timeout-$clock.Elapsed.TotalSeconds))))
            if ($result.ExitCode -eq 0) { $devices = @(Get-JobsHarmonyEmulatorDevices $result.StdOut) }
            if ($devices.Count -gt 0) { break }
            Write-JobsMessage '等待鸿蒙模拟器出现在 Flutter 列表中…'
            Start-Sleep -Seconds 2
        }
        if ($devices.Count -eq 0) { throw ('等待 '+$timeout+' 秒仍无受支持的鸿蒙模拟器；保留实例，请检查 hdc / Flutter doctor 后重试。') }
        $device = Select-JobsSimulatorItem '选择要运行的鸿蒙模拟器设备' @($devices | ForEach-Object { $_.id })
        if ($device -cnotin @($devices | ForEach-Object { $_.id })) { throw '选择器返回了无效设备，未运行工程。' }
        Push-Location -LiteralPath $Project
        try { Invoke-JobsCommand $flutter @('pub','get'); Invoke-JobsCommand $flutter @('run','-d',$device) } finally { Pop-Location }
    } finally {
        foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
    }
}

# END JOBS_TERMINAL_STYLE_ORIGINAL_BODY
} finally {
    Stop-JobsTerminalStyle $__jobsTerminalStyleState
}
