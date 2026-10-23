# 【WindowsOS】🧪提取Flutter第三方依赖.ps1
# 脚本自述：复用随包 Dart 核心提取已解析第三方 Pub 源码，排除 SDK、缓存与外部原生依赖；先显示影响范围并等待回车，Ctrl+C 可取消。
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
    Write-Host '复用随包 Dart 核心提取已解析第三方 Pub 源码，排除 SDK、缓存与外部原生依赖'
    Invoke-JobsTask -Action 'extractsources' -Title '【WindowsOS】🧪提取Flutter第三方依赖' -Options $options
    exit 0
} catch { Write-Host ('[错误] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
