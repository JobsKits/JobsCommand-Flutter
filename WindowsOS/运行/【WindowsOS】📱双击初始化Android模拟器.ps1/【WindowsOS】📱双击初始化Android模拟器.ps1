# 【WindowsOS】📱双击初始化Android模拟器.ps1
# 脚本自述：准备缺失 Android 工具链、选择型号和镜像，创建唯一 AVD 并启动；先显示影响范围并等待回车，Ctrl+C 可取消。
# Created by Jobs on 2026年10月29日，星期四.
[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$TargetPath = '',
    [string]$SourcePath = '',
    [string]$OutputPath = '',
    [string]$Version = '',
    [string]$Device = '',
    [string]$Value = '',
    [string]$Mode = '',
    [string]$HarmonyFlutterSdkPath = '',
    [ValidateRange(1,180)][int]$Seconds = 30,
    [switch]$Plan,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
try {
    $base = $PSScriptRoot
    while ($base -and -not (Test-Path -LiteralPath (Join-Path $base 'Scripts/FlutterTools.psm1'))) {
        $parent = Split-Path -Parent $base
        if ($parent -eq $base) { $base = ''; break }
        $base = $parent
    }
    if (-not $base) { throw '随包 Scripts/FlutterTools.psm1 缺失，请保留完整功能目录及随包 Scripts。' }
    Import-Module (Join-Path $base 'Scripts/FlutterTools.psm1') -Force -DisableNameChecking
    $options = @{TargetPath=$TargetPath;SourcePath=$SourcePath;OutputPath=$OutputPath;Version=$Version;Device=$Device;Value=$Value;Mode=$Mode;Seconds=$Seconds;Plan=$Plan;Check=$Check;HarmonyFlutterSdkPath=$HarmonyFlutterSdkPath}
    Write-Host '准备缺失 Android 工具链、选择型号和镜像，创建唯一 AVD 并启动'
    Invoke-JobsTask -Action 'androidcreate' -Title '【WindowsOS】📱双击初始化Android模拟器' -Options $options
    exit 0
} catch { Write-Host ('[错误] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
