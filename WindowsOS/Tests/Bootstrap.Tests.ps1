#requires -Version 5.1
# Bootstrap.Tests.ps1 | JobsCommand-Flutter
# Created by Jobs on 2026年10月29日，星期四.
# 只用临时 SDK 和下载/解压替身验证首次安装，不访问网络或用户工具链。
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$module = Import-Module (Join-Path $root 'Scripts/FlutterTools.psm1') -PassThru -Force -DisableNameChecking
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('JobsFlutterBootstrap-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$savedPath = $env:PATH
$state = @{ Count = 0; Destination = $fixture; Download = 0; Cancel = $false }
try {
    & $module {
        param($state)
        # 所有安装来源和内容都固定在当前夹具中。
        function Assert-Bootstrap {
            param($Condition, [string]$Label)
            if (-not $Condition) { throw $Label }
            $state.Count++
        }
        function Invoke-RestMethod {
            param($Uri, $TimeoutSec)
            return [pscustomobject]@{
                current_release = [pscustomobject]@{ stable = 'fixture-hash' }
                releases = @([pscustomobject]@{ hash = 'fixture-hash'; version = '3.0.0'; channel = 'stable'; sha256 = 'fixture-sha'; archive = 'stable/windows/flutter-fixture.zip' })
            }
        }
        function Confirm-JobsChange {
            param($Message)
            if ($state.Cancel) { throw 'fixture cancellation' }
        }
        function Invoke-WebRequest {
            param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec)
            $state.Download++
            [IO.File]::WriteAllText($OutFile, 'fixture archive')
        }
        function Get-FileHash { param($LiteralPath, $Algorithm) [pscustomobject]@{ Hash = 'fixture-sha' } }
        function Expand-Archive {
            param($LiteralPath, $DestinationPath)
            $bin = Join-Path $DestinationPath 'flutter/bin'
            [void][IO.Directory]::CreateDirectory($bin)
            [IO.File]::WriteAllText((Join-Path $bin 'flutter.bat'), '@rem fixture only')
            [IO.File]::WriteAllText((Join-Path $bin 'dart.bat'), '@rem fixture only')
        }
        $sdk = Install-JobsFlutterSdk -Destination $state.Destination -Version '3.0.0'
        Assert-Bootstrap ($sdk -ceq (Join-Path $state.Destination 'flutter')) '安装成功必须返回实际 SDK 目录，供首次初始化继续设置 PATH。'
        Assert-Bootstrap ([IO.File]::Exists((Join-Path $sdk 'bin/dart.bat'))) '返回的 SDK 目录包含同源 Dart。'
        Assert-Bootstrap ($state.Download -eq 1) '只下载一次夹具归档。'
        $state.Cancel = $true
        $cancelled = $false
        $cancelTarget = Join-Path $state.Destination 'cancelled'
        try { Install-JobsFlutterSdk -Destination $cancelTarget -Version '3.0.0' | Out-Null } catch { $cancelled = $true }
        Assert-Bootstrap ($cancelled -and $state.Download -eq 1) '取消下载时立即停止，不访问来源。'
        Assert-Bootstrap (-not [IO.Directory]::Exists($cancelTarget)) '取消后不创建安装目录。'
        $state.Sdk = $sdk
        function Install-JobsFlutterSdk {
            param($Destination, $Version)
            return $state.Sdk
        }
        function Get-Command { param($Name, $ErrorAction) return $null }
        $before = $env:PATH
        Initialize-JobsFlutterBootstrap
        Assert-Bootstrap ($env:PATH -ceq ((Join-Path $state.Sdk 'bin') + [IO.Path]::PathSeparator + $before)) '首次安装结果必须接入当前进程 PATH。'
        function Get-Command { param($Name, $ErrorAction) return [pscustomobject]@{ Source = 'healthy-fixture-dart' } }
        function Install-JobsFlutterSdk { throw '已有 Dart 时不应安装。' }
        $before = $env:PATH
        Initialize-JobsFlutterBootstrap
        Assert-Bootstrap ($env:PATH -ceq $before) '已有 Dart 时复用当前环境。'
        Write-Host ('PASS：' + $state.Count + ' 项 Flutter 首次安装断言；未联网或安装真实 SDK。')
    } $state
} finally {
    $env:PATH = $savedPath
    Remove-Module $module
    if ([IO.Directory]::Exists($fixture)) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
