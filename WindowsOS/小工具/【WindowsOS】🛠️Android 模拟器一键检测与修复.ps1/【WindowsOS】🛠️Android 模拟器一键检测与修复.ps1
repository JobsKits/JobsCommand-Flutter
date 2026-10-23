# 【WindowsOS】🛠️Android 模拟器一键检测与修复.ps1
# 脚本自述：诊断设备数据分区和安装位置，确认后恢复自动安装位置并重启 adb；先显示影响范围并等待回车，Ctrl+C 可取消。
# Created by Jobs on 2026年10月23日，星期五.
[CmdletBinding()]
param(
    [Parameter(Position=0)][string]$TargetPath = '',
    [string]$SourcePath = '',
    [string]$OutputPath = '',
    [string]$Version = '',
    [string]$Device = '',
    [string]$Value = '',
    [string]$Mode = '',
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
    if (-not $base) { throw '随包 Scripts/FlutterTools.psm1 缺失，请保留整个 WindowsOS 目录。' }
    Import-Module (Join-Path $base 'Scripts/FlutterTools.psm1') -Force -DisableNameChecking
    $options = @{TargetPath=$TargetPath;SourcePath=$SourcePath;OutputPath=$OutputPath;Version=$Version;Device=$Device;Value=$Value;Mode=$Mode;Seconds=$Seconds;Plan=$Plan;Check=$Check}
    Write-Host '诊断设备数据分区和安装位置，确认后恢复自动安装位置并重启 adb'
    Invoke-JobsTask -Action 'androidrepair' -Title '【WindowsOS】🛠️Android 模拟器一键检测与修复' -Options $options
    exit 0
} catch { Write-Host ('[错误] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
