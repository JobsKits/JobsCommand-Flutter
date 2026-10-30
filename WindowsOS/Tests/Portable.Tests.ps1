# Portable.Tests.ps1 | 隔离验证，不安装工具、不运行真实 Flutter / Android。
[CmdletBinding()]
param([switch]$SkipEntrypoints)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$module=Import-Module (Join-Path $root 'Scripts/FlutterTools.psm1') -PassThru -Force -DisableNameChecking
$temporaryRoot=if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){[IO.Path]::GetTempPath()}else{'/private/tmp'}
$fixture=Join-Path $temporaryRoot ('JobsFlutterTest-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$counter=@{Value=0}
function Assert-Equal { param($Actual,$Expected,[string]$Label); if($Actual -cne $Expected){throw ($Label+'：实际 '+$Actual+'，预期 '+$Expected)}; $counter.Value++ }
function Assert-Throws { param([scriptblock]$Operation,[string]$Label); $thrown=$false; try{& $Operation}catch{$thrown=$true}; if(-not $thrown){throw ($Label+'：预期失败却成功')}; $counter.Value++ }
try {
    & $module {
        param($f,$counter)
        # Windows PowerShell 5.1 的模块作用域看不到调用方脚本中的断言函数。
        function Assert-Equal { param($Actual,$Expected,[string]$Label); if($Actual -cne $Expected){throw ($Label+'：实际 '+$Actual+'，预期 '+$Expected)}; $counter.Value++ }
        function Assert-Throws { param([scriptblock]$Operation,[string]$Label); $thrown=$false; try{& $Operation}catch{$thrown=$true}; if(-not $thrown){throw ($Label+'：预期失败却成功')}; $counter.Value++ }
        $project=Join-Path $f '中文 Flutter project'
        [void][IO.Directory]::CreateDirectory((Join-Path $project 'lib/sub'))
        [IO.File]::WriteAllText((Join-Path $project 'pubspec.yaml'),"name: jobs_example`n")
        [IO.File]::WriteAllText((Join-Path $project 'lib/main.dart'),"import './sub/中文.dart';`nimport 'dart:io';`n// import '../outside.dart';`n")
        [IO.File]::WriteAllText((Join-Path $project 'lib/sub/中文.dart'),'// owned fixture')
        [void][IO.Directory]::CreateDirectory((Join-Path $project 'lib/build'))
        [IO.File]::WriteAllText((Join-Path $project 'lib/build/skip.dart'),"import '../main.dart';")
        Convert-JobsImports $project
        $actual=[IO.File]::ReadAllText((Join-Path $project 'lib/main.dart'))
        Assert-Equal ($actual.Contains("import 'package:jobs_example/sub/中文.dart';")) $true '相对 import 转 package'
        Assert-Equal ($actual.Contains("import 'dart:io';")) $true '保留 Dart URI'
        Assert-Equal ($actual.Contains("// import '../outside.dart';")) $true '保留注释'
        Assert-Equal ([IO.File]::ReadAllText((Join-Path $project 'lib/build/skip.dart'))) "import '../main.dart';" '跳过 build'
        Convert-JobsImports $project -Encode
        $encoded=[IO.File]::ReadAllText((Join-Path $project 'lib/main.dart'))
        Assert-Equal ($encoded.Contains('package:jobs_example/sub/%E4%B8%AD%E6%96%87.dart')) $true '中文编码保留 scheme'
        Assert-Equal ($encoded.Contains("import 'dart:io';")) $true '编码不损坏 scheme'
        Convert-JobsImports $project -Encode
        Assert-Equal ([IO.File]::ReadAllText((Join-Path $project 'lib/main.dart'))) $encoded '编码幂等'
        [IO.File]::WriteAllText((Join-Path $project '.fvmrc'),'{"flutter":"3.0.0"}')
        Assert-Throws { Get-JobsFlutter $project } 'FVM 缺失拒绝全局回退'
        [void][IO.Directory]::CreateDirectory((Join-Path $project 'android/app'))
        $gradle=Join-Path $project 'android/app/build.gradle'
        [IO.File]::WriteAllText($gradle,"android {`n    compileSdk 35`n}`n")
        Repair-JobsNamespace $project 'com.jobs.example'
        $withNamespace=[IO.File]::ReadAllText($gradle)
        Assert-Equal ($withNamespace.Contains('namespace "com.jobs.example"')) $true 'namespace 补齐'
        Repair-JobsNamespace $project 'com.other.name'
        Assert-Equal ([IO.File]::ReadAllText($gradle)) $withNamespace 'namespace 不覆盖'
        Assert-Throws { Repair-JobsNamespace $project 'bad;Remove-Item' } '拒绝非法 namespace'
        [void][IO.Directory]::CreateDirectory((Join-Path $project '.vscode'))
        $settings=Join-Path $project '.vscode/settings.json'
        [IO.File]::WriteAllText($settings,'{"editor.fontFamily":"中文字体","other":{"keep":true}}')
        Set-JobsFlutterVSCodePath $project
        $json=[IO.File]::ReadAllText($settings)|ConvertFrom-Json
        Assert-Equal $json.'editor.fontFamily' '中文字体' '保留已有设置 UTF8'
        Assert-Equal $json.other.keep $true '保留嵌套设置'
        Assert-Equal $json.'dart.flutterSdkPath' '.fvm/flutter_sdk' '合并 FVM SDK 路径'
        [IO.File]::WriteAllText($settings,"{// 注释`n}")
        Assert-Throws { Set-JobsFlutterVSCodePath $project } 'JSONC 不能解析时不覆盖'
        Assert-Equal ([IO.File]::ReadAllText($settings)) "{// 注释`n}" '保留 JSONC 原字节'
        $package=Join-Path $f '依赖 source'
        [void][IO.Directory]::CreateDirectory($package)
        [IO.File]::WriteAllText((Join-Path $package 'README.txt'),'dependency source')
        [void][IO.Directory]::CreateDirectory((Join-Path $package '层级 [data]'))
        [void][IO.Directory]::CreateDirectory((Join-Path $package 'empty-dir'))
        [IO.File]::WriteAllText((Join-Path $package '层级 [data]/中文 source.txt'),'UTF8 fixture')
        [void][IO.Directory]::CreateDirectory((Join-Path $project '.dart_tool'))
        $config=@{configVersion=2;packages=@(@{name='example_dep';rootUri=(New-Object Uri $package).AbsoluteUri})}|ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText((Join-Path $project '.dart_tool/package_config.json'),$config)
        $zip=Join-Path $f '依赖 archive.zip'
        Export-JobsDependencies $project $zip
        Assert-Equal ([IO.File]::Exists($zip)) $true '依赖 ZIP 生成'
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        $archive=[IO.Compression.ZipFile]::OpenRead($zip)
        try {
            Assert-Equal (@($archive.Entries|Where-Object FullName -eq 'dart_packages/example_dep/README.txt').Count) 1 '包源码路径正确'
            Assert-Equal (@($archive.Entries|Where-Object {$_.FullName.Contains('\')}).Count) 0 'ZIP 路径统一正斜杠'
            $nested=$archive.GetEntry('dart_packages/example_dep/层级 [data]/中文 source.txt')
            Assert-Equal ($null -ne $nested) $true '中文嵌套 ZIP 路径正确'
            $reader=New-Object IO.StreamReader($nested.Open(),[Text.Encoding]::UTF8)
            try { Assert-Equal $reader.ReadToEnd() 'UTF8 fixture' '中文路径文件内容完整' } finally {$reader.Dispose()}
            Assert-Equal ($null -ne $archive.GetEntry('dart_packages/example_dep/empty-dir/')) $true '保留空依赖目录'
        } finally {$archive.Dispose()}
        Assert-Throws { Export-JobsDependencies $project $zip } 'ZIP 拒绝覆盖'
        if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){
            Invoke-JobsCommand '/bin/sh' @('-c','printf ok >&2; exit 0')
            Assert-Throws { Invoke-JobsCommand '/bin/sh' @('-c','exit 7') } '原生命令非零失败'
        }
    } $fixture $counter
    $map=Get-Content -LiteralPath (Join-Path $root '功能映射.json') -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-Equal $map.entries.Count 46 'Windows 映射数'
    Assert-Equal $map.excluded.Count 16 'Mac 专用排除数'
    foreach($entry in $map.entries){
        $path=Join-Path (Split-Path -Parent $root) $entry.windows
        Assert-Equal (Test-Path -LiteralPath $path -PathType Leaf) $true ('入口存在 '+$entry.action)
        Assert-Equal (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($path,'.cmd')) -PathType Leaf) $true 'CMD 配套'
        if(-not $SkipEntrypoints){
            $hostPath=(Get-Process -Id $PID).Path
            & $hostPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $path -Plan | Out-Null
            Assert-Equal $LASTEXITCODE 0 'Plan 成功'
            & $hostPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $path -Check | Out-Null
            Assert-Equal $LASTEXITCODE 0 'Check 成功'
        }
    }
    Write-Host ('PASS：'+$counter.Value+' 项断言；临时夹具已清理；没有真实安装或构建。')
} finally {
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
