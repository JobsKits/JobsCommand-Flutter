# 【WindowsOS】📦双击打包Flutter.Harmony.ps1
# 脚本自述：使用已有鸿蒙 Flutter SDK 同时构建 HAP 和 APP，核验工具链与两种产物；只改所选工程和工具缓存，先显示自述并回车确认，Ctrl+C 可取消。
# Created by Jobs on 2026年10月28日，星期三.
[CmdletBinding()]
param(
    [Parameter(Position = 0)][Alias('ProjectPath')][string]$TargetPath = '',
    [string]$HarmonyFlutterSdkPath = $env:FLUTTER_OHOS_SDK,
    [ValidateSet('release', 'debug', 'profile')][string]$Mode = 'release',
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
    $options = @{
        TargetPath = $TargetPath
        HarmonyFlutterSdkPath = $HarmonyFlutterSdkPath
        Mode = $Mode
        Plan = $Plan
        Check = $Check
    }
    Write-Host '使用已有鸿蒙 Flutter SDK 执行 pub get、build hap 和 build app；默认 release，签名沿用工程配置。'
    Write-Host '只接受含 pubspec.yaml、lib、ohos 的 Flutter 根目录；缺工具或不同时支持 HAP / APP 的 SDK 会停止。'
    Invoke-JobsTask -Action 'build-harmony' -Title '【WindowsOS】📦双击打包Flutter.Harmony' -Options $options
    exit 0
} catch {
    Write-Host ('[错误] ' + $_.Exception.Message) -ForegroundColor Red
    $code = $_.Exception.Data['JobsExitCode']
    if ($null -ne $code -and [int]$code -gt 0 -and [int]$code -le 255) { exit ([int]$code) }
    exit 1
}
