# FlutterTools.psm1 | JobsCommand-Flutter Windows 工具核心
# Created by Jobs on 2026年10月23日，星期五.
# 功能以 Windows 原生命令实现；入口自述确认、日志、精确备份统一在此编排。
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-JobsMessage {
    param([string]$Message)
    Write-Host ('[Jobs] ' + $Message)
}
function Confirm-JobsChange {
    param([string]$Message, [string]$Token = 'YES')
    Write-JobsMessage $Message
    if ((Read-Host ('输入 ' + $Token + ' 继续，其它输入取消')) -cne $Token) { throw '用户取消，操作未继续。' }
}
function Resolve-JobsDirectory {
    param([string]$Path)
    if (-not $Path) { $Path = Read-Host '输入或拖入目标目录' }
    $Path = $Path.Trim('"')
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) { throw '目标必须是目录。' }
    $cursor = $item
    while ($null -ne $cursor) {
        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('不处理链接或联接：' + $cursor.FullName) }
        $cursor = $cursor.Parent
    }
    return $item.FullName
}
function Resolve-JobsProject {
    param([string]$Path)
    $root = Resolve-JobsDirectory $Path
    if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml') -PathType Leaf)) { throw ('缺少 pubspec.yaml：' + $root) }
    return $root
}
function Get-JobsCommand {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw ('找不到命令 ' + $Name + '，请安装相应工具并在新终端重试。') }
    return $command.Source
}
function Invoke-JobsCommand {
    param([string]$Executable, [string[]]$Arguments = @())
    Write-JobsMessage ('执行：' + [IO.Path]::GetFileName($Executable) + ' ' + ($Arguments -join ' '))
    if ([IO.Path]::GetExtension($Executable) -in @('.bat','.cmd')) {
        foreach ($value in @($Executable) + $Arguments) {
            if ($value -match '[&|<>^%!"\r\n]') { throw '批处理入口参数含 cmd 特殊字符，拒绝继续；请将工具链放在普通路径。' }
        }
    }
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = -1
        & $Executable @Arguments 2>&1 | ForEach-Object { Write-Host ([string]$_) }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw ('命令失败，退出码 ' + $code + '：' + $Executable) }
}
function Get-JobsFlutter {
    param([string]$Project)
    $local = Join-Path $Project '.fvm/flutter_sdk/bin/flutter.bat'
    if (Test-Path -LiteralPath $local -PathType Leaf) { return $local }
    if ((Test-Path -LiteralPath (Join-Path $Project '.fvmrc')) -or (Test-Path -LiteralPath (Join-Path $Project '.fvm/fvm_config.json'))) { throw '项目声明了 FVM，但本地 SDK 缺失。先运行安装 FVM 入口，不能悄悄切换全局版本。' }
    return Get-JobsCommand 'flutter'
}
function Invoke-JobsFlutter {
    param([string]$Project, [string[]]$Arguments)
    Push-Location -LiteralPath $Project
    try { Invoke-JobsCommand (Get-JobsFlutter $Project) $Arguments } finally { Pop-Location }
}
function Invoke-JobsDart {
    param([string]$Project, [string[]]$Arguments)
    $flutter = Get-JobsFlutter $Project
    $dart = Join-Path (Split-Path -Parent $flutter) 'dart.bat'
    if (-not (Test-Path -LiteralPath $dart -PathType Leaf)) { throw 'Flutter 同源 Dart 缺失。' }
    Push-Location -LiteralPath $Project
    try { Invoke-JobsCommand $dart $Arguments } finally { Pop-Location }
}
function Get-JobsSourceFiles {
    param([string]$Directory, [string[]]$Extensions)
    foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        if ($item.PSIsContainer) {
            if ($item.Name -notin @('.git','node_modules','Pods','.dart_tool','build','DerivedData','.gradle','.fvm')) { Get-JobsSourceFiles $item.FullName $Extensions }
        } elseif ($item.Extension -in $Extensions) { $item }
    }
}
function Backup-JobsPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw '不能备份或覆盖链接。' }
        $backup = $Path + '.jobs-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
        Copy-Item -LiteralPath $Path -Destination $backup -Recurse -Force
        Write-JobsMessage ('备份：' + $backup)
        return $backup
    }
}
function Write-JobsText {
    param([string]$Path, [string]$Text)
    [void](Backup-JobsPath $Path)
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}
function Select-JobsItem {
    param([string]$Title, [object[]]$Items)
    if ($Items.Count -eq 0) { throw ($Title + '：没有可选项。') }
    for ($i=0; $i -lt $Items.Count; $i++) { Write-Host ('{0}、{1}' -f ($i+1), $Items[$i]) }
    $answer = Read-Host ($Title + '，输入序号；留空取消')
    $index = 0
    if (-not [int]::TryParse($answer, [ref]$index) -or $index -lt 1 -or $index -gt $Items.Count) { throw '未选择有效项。' }
    return $Items[$index-1]
}
function Import-JobsFeature {
    param([string]$Name)
    return Import-Module (Join-Path $PSScriptRoot ('Features/' + $Name + '/Action.psm1')) -PassThru -Force -DisableNameChecking
}
function Get-JobsAndroidSdk {
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
    if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
    return $sdk
}
function Get-JobsAdb {
    $adb = Join-Path (Get-JobsAndroidSdk) 'platform-tools/adb.exe'
    if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) { return Get-JobsCommand 'adb' }
    return $adb
}
function Get-JobsAndroidSerial {
    param([string]$Requested)
    $adb = Get-JobsAdb
    $text = & $adb devices
    if ($LASTEXITCODE -ne 0) { throw 'adb devices 失败。' }
    $serials = @($text | ForEach-Object { if ($_ -match '^(\S+)\s+device\s*$') { $Matches[1] } })
    if ($Requested) { if ($Requested -notin $serials) { throw '指定设备未连接或未授权。' }; return $Requested }
    return Select-JobsItem '选择 Android 设备' $serials
}
function Invoke-JobsAndroidPrepare {
    param([switch]$Create)
    $module = Import-JobsFeature 'Android'
    if ($Create) { & $module { Invoke-JobsAndroidSimulatorAction -Target ([Environment]::GetFolderPath('DesktopDirectory')) -Create }; return }
    & $module {
        [void](Get-JobsAndroidArchitecture)
        $sdk = Get-JobsAndroidSdk
        $java = Get-JobsAndroidJava
        $tools = Get-JobsAndroidHealthyTools -Sdk $sdk -Java $java
        Repair-JobsAndroidComponents -Sdk $sdk -Java $java -Tools $tools
        $listing=Invoke-JobsAndroidTool $java $tools 'sdkmanager' @(('--sdk_root=' + $sdk), '--list', '--channel=0')
        $platforms=@([regex]::Matches($listing,'(?m)^\s*(platforms;android-\d+)\s*\|') | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique | Sort-Object { [int]($_ -replace '^platforms;android-','') } -Descending)
        $buildTools=@([regex]::Matches($listing,'(?m)^\s*(build-tools;\d+\.\d+\.\d+)\s*\|') | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique | Sort-Object { [version]($_ -replace '^build-tools;','') } -Descending)
        if($platforms.Count -eq 0 -or $buildTools.Count -eq 0){throw '官方清单缺少稳定 Android Platform 或 Build Tools。'}
        $platform=Read-JobsAndroidChoice '选择工程 compileSdk 所需 Android Platform' $platforms
        $build=Read-JobsAndroidChoice '选择 Android Build Tools' $buildTools
        Write-Host ('来源：Google Android SDK 官方仓库；目标：'+$sdk+'；安装 '+$platform+' / '+$build)
        Invoke-JobsAndroidTool $java $tools 'sdkmanager' @(('--sdk_root=' + $sdk), '--licenses') -Interactive
        Invoke-JobsAndroidTool $java $tools 'sdkmanager' @(('--sdk_root=' + $sdk), '--install', $platform, $build) -Interactive
        Write-Host ('Android SDK 准备完成：' + $sdk)
    }
}
function Start-JobsAndroid {
    param([string]$Requested)
    $emulator = Join-Path (Get-JobsAndroidSdk) 'emulator/emulator.exe'
    if (-not (Test-Path -LiteralPath $emulator -PathType Leaf)) { throw 'Android emulator 缺失，请先运行配置 Android Studio 入口。' }
    $avds = @(& $emulator -list-avds | Where-Object { $_.Trim() })
    if ($LASTEXITCODE -ne 0) { throw '无法列出 AVD。' }
    if (-not $Requested) { $Requested = Select-JobsItem '选择已有 AVD（没有设备时使用新建入口 -Mode Create）' $avds }
    if ($Requested -notin $avds -or $Requested -notmatch '^[A-Za-z0-9_.-]+$') { throw '无效 AVD 名称。' }
    $module=Import-JobsFeature 'Android'
    & $module { param($s,$n) Start-JobsAndroidAvd -Sdk $s -Name $n } (Get-JobsAndroidSdk) $Requested
    return $Requested
}
function Start-JobsFlutterProject {
    param([string]$Project, [string]$Kind, [string]$Device)
    $flutter = Get-JobsFlutter $Project
    Push-Location -LiteralPath $Project
    try {
        $oldPreference=$ErrorActionPreference
        try { $ErrorActionPreference='Continue'; $raw = & $flutter devices --machine; $deviceExit=$LASTEXITCODE } finally { $ErrorActionPreference=$oldPreference }
        if ($deviceExit -ne 0) { throw '无法查询 Flutter 设备。' }
        $devices = @((($raw -join [Environment]::NewLine) | ConvertFrom-Json) | Where-Object {
            $platform=[string]$_.targetPlatform
            switch($Kind){
                'web' {$platform -match '^web'}
                'windows' {$platform -match '^windows'}
                'physical' {$platform -match '^android' -and -not $_.emulator}
                'emulator' {$platform -match '^android' -and $_.emulator}
                default {$platform -match '^android'}
            }
        })
        if ($devices.Count -eq 0) { throw ('当前 '+$Kind+' 平台没有可用设备。Android 需启动 AVD 或授权真机，Web 需已有浏览器，Windows 需已安装桌面工具链。') }
        if (-not $Device) { $Device = Select-JobsItem '选择运行目标' @($devices | ForEach-Object { $_.id }) }
        if ($Device -notin @($devices | ForEach-Object { $_.id })) { throw '指定设备不在当前平台列表中。' }
        Invoke-JobsCommand $flutter @('pub','get')
        Invoke-JobsCommand $flutter @('run','-d',$Device)
    } finally { Pop-Location }
}
function Install-JobsFlutterSdk {
    param([string]$Destination, [string]$Version)
    if (-not $Destination) { $Destination = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'develop' }
    $Destination = [IO.Path]::GetFullPath($Destination)
    $sdk = Join-Path $Destination 'flutter'
    if (Test-Path -LiteralPath $sdk) { throw ('目标已存在，拒绝覆盖：' + $sdk) }
    $index = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    Write-JobsMessage ('来源：官方 Flutter Windows 发布清单 ' + $index)
    $metadata = Invoke-RestMethod -Uri $index -TimeoutSec 60
    $release = $null
    if ($Version) { $release = $metadata.releases | Where-Object { $_.version -eq $Version -and $_.channel -eq 'stable' } | Select-Object -First 1 }
    else { $release = $metadata.releases | Where-Object { $_.hash -eq $metadata.current_release.stable } | Select-Object -First 1 }
    if (-not $release -or -not $release.sha256 -or $release.archive -notmatch '^stable/windows/[^/]+\.zip$') { throw '发布清单无匹配稳定版本或缺少校验值。' }
    $url = 'https://storage.googleapis.com/flutter_infra_release/releases/' + $release.archive
    Confirm-JobsChange ('下载 ' + $url + '；版本 ' + $release.version + '；安装至 ' + $sdk)
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('JobsFlutterSdk-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($stage)
    try {
        $zip = Join-Path $stage 'flutter.zip'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 3600
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ine $release.sha256) { throw '下载文件 SHA-256 校验失败。' }
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $stage 'unpacked')
        [void][IO.Directory]::CreateDirectory($Destination)
        Move-Item -LiteralPath (Join-Path $stage 'unpacked/flutter') -Destination $sdk
        Write-JobsMessage ('安装完成，将此目录加入用户 Path：' + (Join-Path $sdk 'bin'))
    } finally { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }
}
function Initialize-JobsFlutterBootstrap {
    if(Get-Command dart -ErrorAction SilentlyContinue){return}
    $flutter=Get-Command flutter -ErrorAction SilentlyContinue
    if($flutter){
        $bin=Split-Path -Parent $flutter.Source
        if(Test-Path -LiteralPath (Join-Path $bin 'dart.bat')){$env:PATH=$bin+[IO.Path]::PathSeparator+$env:PATH;return}
    }
    $sdk=Install-JobsFlutterSdk '' ''
    $env:PATH=(Join-Path $sdk 'bin')+[IO.Path]::PathSeparator+$env:PATH
}
function Set-JobsFvm {
    param([string]$Project, [string]$Version)
    $dart = Get-JobsCommand 'dart'
    Write-JobsMessage '来源：pub.dev 的 fvm 包；范围：当前用户 Dart 全局包缓存与所选工程。'
    Invoke-JobsCommand $dart @('pub','global','activate','fvm')
    $fvm = Get-Command fvm -ErrorAction SilentlyContinue
    $fvmPath = if ($fvm) { $fvm.Source } else { Join-Path $env:LOCALAPPDATA 'Pub/Cache/bin/fvm.bat' }
    if (-not (Test-Path -LiteralPath $fvmPath -PathType Leaf)) { throw 'FVM 安装后命令仍不可用。请将 Dart Pub Cache/bin 加入用户 Path 并重开终端。' }
    if (-not $Version) {
        $config = Join-Path $Project '.fvmrc'
        if (Test-Path -LiteralPath $config) { $Version = (Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json).flutter }
        if (-not $Version) { $Version = Read-Host '输入项目 Flutter 版本，例如 stable 或具体版本号' }
    }
    if ($Version -notmatch '^(stable|beta|master|[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)$') { throw '版本格式无效。' }
    Push-Location -LiteralPath $Project
    try {
        Invoke-JobsCommand $fvmPath @('install',$Version)
        Invoke-JobsCommand $fvmPath @('use',$Version)
    } finally { Pop-Location }
}
function Set-JobsVSCode {
    param([string]$Project, [string]$Kind)
    $pairs = @()
    if ($Kind -ne 'global') { $pairs += ,@('https://github.com/JobsKits/VScodeConfigByFlutter.git',(Join-Path $Project '.vscode')) }
    if ($Kind -ne 'project') { $pairs += ,@('https://github.com/JobsKits/JobsConfigByVSCode.git',(Join-Path $env:APPDATA 'Code/User')) }
    foreach ($pair in $pairs) {
        $source = $pair[0]; $destination = $pair[1]
        Confirm-JobsChange ('来源：' + $source + '；目标：' + $destination + '；已有目录将备份，合并覆盖同名配置。')
        $stage = Join-Path ([IO.Path]::GetTempPath()) ('JobsVSCode-' + [guid]::NewGuid().ToString('N'))
        try {
            Invoke-JobsCommand (Get-JobsCommand 'git') @('clone','--depth','1','--',$source,$stage)
            [void](Backup-JobsPath $destination)
            [void][IO.Directory]::CreateDirectory($destination)
            Get-ChildItem -LiteralPath $stage -Force | Where-Object { $_.Name -notin @('.git','.github','.gitignore') } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force }
        } finally { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }
    }
}
function Set-JobsWindowsEnvironment {
    param([string]$Sdk, [string]$Java, [string]$Mode)
    $record = Join-Path $env:LOCALAPPDATA 'JobsCommandFlutter/environment-backup.json'
    if ($Mode -eq 'Restore') {
        $saved = Get-Content -LiteralPath $record -Raw -Encoding UTF8 | ConvertFrom-Json
        Confirm-JobsChange '恢复该入口保存的 ANDROID_HOME、ANDROID_SDK_ROOT、JAVA_HOME 用户变量；不改 Path 和系统级配置。'
        foreach ($name in @('ANDROID_HOME','ANDROID_SDK_ROOT','JAVA_HOME')) {
            if ([Environment]::GetEnvironmentVariable($name,'User') -cne $saved.after.$name) { throw ('变量已有其它改动，拒绝覆盖：' + $name) }
        }
        foreach ($name in @('ANDROID_HOME','ANDROID_SDK_ROOT','JAVA_HOME')) { [Environment]::SetEnvironmentVariable($name,$saved.before.$name,'User') }
        Move-Item -LiteralPath $record -Destination ($record + '.restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
        return
    }
    if (-not $Sdk) { $Sdk = Read-Host '输入已有 Android SDK 目录' }
    $Sdk = Resolve-JobsDirectory $Sdk
    if (-not $Java) { $Java = Read-Host '输入已有 JDK 根目录' }
    $Java = Resolve-JobsDirectory $Java
    if (-not (Test-Path -LiteralPath (Join-Path $Java 'bin/java.exe'))) { throw 'JDK 缺少 bin/java.exe。' }
    Confirm-JobsChange ('将写入当前用户 Android/JDK 变量：' + $Sdk + '；' + $Java + '。恢复用 -Mode Restore。')
    if (Test-Path -LiteralPath $record) { throw ('已有未撤回快照，先 Restore 或人工归档：' + $record) }
    $before = @{}; $after = @{ ANDROID_HOME=$Sdk; ANDROID_SDK_ROOT=$Sdk; JAVA_HOME=$Java }
    foreach ($name in @('ANDROID_HOME','ANDROID_SDK_ROOT','JAVA_HOME')) { $before[$name] = [Environment]::GetEnvironmentVariable($name,'User') }
    Write-JobsText $record (@{before=$before;after=$after} | ConvertTo-Json -Depth 4)
    foreach ($name in @('ANDROID_HOME','ANDROID_SDK_ROOT','JAVA_HOME')) { [Environment]::SetEnvironmentVariable($name,$after[$name],'User') }
    Write-JobsMessage '用户变量已保存，新终端生效；Path 保持原样。'
}
function Convert-JobsImports {
    param([string]$Project, [switch]$Encode)
    $pubspec = Get-Content -LiteralPath (Join-Path $Project 'pubspec.yaml') -Raw -Encoding UTF8
    if ($pubspec -notmatch '(?m)^name:\s*([a-z][a-z0-9_]*)\s*(?:#.*)?$') { throw '无法读取项目 package 名称。' }
    $packageName = $Matches[1]
    $lib = Join-Path $Project 'lib'
    $pattern = '(?m)^(?<prefix>[ \t]*(?:import|export|part)\s+[''"])(?<uri>[^''"]+)(?<suffix>[''"])'
    foreach ($file in @(Get-JobsSourceFiles $lib @('.dart'))) {
        $text = [IO.File]::ReadAllText($file.FullName)
        $changed = [regex]::Replace($text,$pattern,[Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $uri = $match.Groups['uri'].Value
            if ($Encode) {
                $uri = [regex]::Replace($uri,'[^\x00-\x7F]+',[Text.RegularExpressions.MatchEvaluator]{param($part) [Uri]::EscapeDataString($part.Value)})
            } elseif ($uri -notmatch '^[A-Za-z][A-Za-z0-9+.-]*:') {
                $candidate = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName ($uri -replace '/', [IO.Path]::DirectorySeparatorChar)))
                if ($candidate.StartsWith($lib + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
                    $relative = $candidate.Substring($lib.Length+1) -replace '\\','/'
                    $uri = 'package:' + $packageName + '/' + $relative
                }
            }
            return $match.Groups['prefix'].Value + $uri + $match.Groups['suffix'].Value
        })
        if ($changed -cne $text) { Write-JobsText $file.FullName $changed; Write-JobsMessage ('已更新：' + $file.FullName) }
    }
}
function Export-JobsDependencies {
    param([string]$Project, [string]$Output)
    $configPath = Join-Path $Project '.dart_tool/package_config.json'
    if (-not (Test-Path -LiteralPath $configPath)) { throw '缺少 package_config.json，请先 pub get。' }
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $Output) { $Output = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) ('FlutterDependencies-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip') }
    if (Test-Path -LiteralPath $Output) { throw '输出已存在，拒绝覆盖。' }
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('JobsFlutterDeps-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($stage)
    $manifest = @()
    try {
        foreach ($package in $config.packages) {
            if ($package.name -notmatch '^[a-zA-Z_][a-zA-Z0-9_]*$') { throw '依赖包名无效。' }
            $baseUri = New-Object Uri ($configPath)
            $uri = New-Object Uri ($baseUri, [string]$package.rootUri)
            if (-not $uri.IsFile) { throw '依赖路径必须是本地 file URI。' }
            $source = Resolve-JobsDirectory $uri.LocalPath
            $dest = Join-Path $stage ('dart_packages/' + $package.name)
            [void][IO.Directory]::CreateDirectory($dest)
            Copy-JobsTree $source $dest
            $manifest += @{name=$package.name;source=$source}
        }
        foreach ($name in @('pubspec.yaml','pubspec.lock','.dart_tool/package_config.json','android/build.gradle','android/settings.gradle','android/gradle.properties')) {
            $source = Join-Path $Project $name
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                $dest = Join-Path $stage ('project_files/' + $name)
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dest)); Copy-Item -LiteralPath $source -Destination $dest
            }
        }
        [IO.File]::WriteAllText((Join-Path $stage 'manifest.json'),($manifest | ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding $false))
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        # 5.1 宿主可能沿用 .NET 的反斜杠 ZIP 路径；显式使用 / 保证跨端解压目录。
        $archive = [IO.Compression.ZipFile]::Open([IO.Path]::GetFullPath($Output),[IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($item in Get-ChildItem -LiteralPath $stage -Recurse -Force) {
                $entryName = $item.FullName.Substring($stage.Length+1).Replace('\','/')
                if ($item.PSIsContainer) {
                    if (@(Get-ChildItem -LiteralPath $item.FullName -Force).Count -eq 0) { [void]$archive.CreateEntry($entryName+'/') }
                } else {
                    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$item.FullName,$entryName)
                }
            }
        } finally { $archive.Dispose() }
        Write-JobsMessage ('已导出源码和依赖声明：' + $Output)
    } finally { if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }
}
function Copy-JobsTree {
    param([string]$Source, [string]$Destination)
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        if ($item.Name -in @('.git','node_modules','Pods','.dart_tool','build','DerivedData')) { continue }
        $target = Join-Path $Destination $item.Name
        if ($item.PSIsContainer) { [void][IO.Directory]::CreateDirectory($target); Copy-JobsTree $item.FullName $target }
        else { Copy-Item -LiteralPath $item.FullName -Destination $target -Force }
    }
}
function Repair-JobsNamespace {
    param([string]$Project, [string]$Namespace)
    if ($Namespace -notmatch '^[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+$') { throw '用 -Value 指定合法 namespace，例如 com.example.app。' }
    $file=''
    foreach($relative in @('android/app/build.gradle','android/app/build.gradle.kts','android/build.gradle','android/build.gradle.kts')){
        $candidate=Join-Path $Project $relative
        if(Test-Path -LiteralPath $candidate -PathType Leaf){$file=$candidate;break}
    }
    if(-not $file){throw '目标工程或本地插件中没有 Android Gradle 文件。'}
    $kotlin=$file.EndsWith('.kts')
    $text = [IO.File]::ReadAllText($file)
    if ($text -match '(?m)^\s*namespace\s*(?:=|["''])') { Write-JobsMessage '已有 namespace，不覆盖。'; return }
    if ($text -notmatch '(?m)^\s*android\s*\{') { throw '找不到明确 android 配置块。' }
    $line = if ($kotlin) { '    namespace = "' + $Namespace + '"' } else { '    namespace "' + $Namespace + '"' }
    $text = [regex]::Replace($text,'(?m)^(\s*android\s*\{)',('$1' + "`n" + $line),1)
    Write-JobsText $file $text
}
function Invoke-JobsRecording {
    param([string]$Device, [string]$Output, [int]$Seconds)
    if ($Seconds -lt 1 -or $Seconds -gt 180) { throw '录屏时长必须为 1～180 秒。' }
    $serial = Get-JobsAndroidSerial $Device
    $adb = Get-JobsAdb; $ffmpeg = Get-JobsCommand 'ffmpeg'
    if (-not $Output) { $Output = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) ('AndroidRecording-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.gif') }
    if (Test-Path -LiteralPath $Output) { throw '输出已存在，拒绝覆盖。' }
    $remote = '/sdcard/jobs-record-' + [guid]::NewGuid().ToString('N') + '.mp4'
    $local = Join-Path ([IO.Path]::GetTempPath()) ('JobsRecording-' + [guid]::NewGuid().ToString('N') + '.mp4')
    try {
        Invoke-JobsCommand $adb @('-s',$serial,'shell','screenrecord','--time-limit',[string]$Seconds,$remote)
        Invoke-JobsCommand $adb @('-s',$serial,'pull',$remote,$local)
        Invoke-JobsCommand $ffmpeg @('-n','-i',$local,'-vf','fps=12,scale=640:-1:flags=lanczos',$Output)
    } finally {
        & $adb -s $serial shell rm $remote | Out-Null
        if (Test-Path -LiteralPath $local) { Remove-Item -LiteralPath $local -Force }
    }
}
function Invoke-JobsTask {
    [CmdletBinding()]
    param([string]$Action, [string]$Title, [hashtable]$Options)
    Write-Host ('=== ' + $Title + ' ===') -ForegroundColor Red
    Write-Host '范围：Windows Flutter / Android / 当前用户配置；写操作会改变所选工程或工具缓存。先核对目标，Ctrl+C 可取消。'
    Write-Host '使用 -Plan 仅展示入口；-Check 仅检查路径与功能包；执行命令使用独立 argv，不拼接或 eval 用户输入。'
    if ($Options.Plan) { Write-Host ('计划：' + $Action + '；目标：' + $Options.TargetPath); return }
    if ($Options.Check) {
        if ($Options.TargetPath) { [void](Resolve-JobsDirectory $Options.TargetPath) }
        foreach ($name in @('Doctor','Codegen','Packager','Android','Harmony')) {
            if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot ('Features/' + $name + '/Action.psm1')))) { throw ('功能包缺失：' + $name) }
        }
        Write-Host '入口与随包模块完整；未启动 SDK、联网、安装或修改配置。'; return
    }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw '真实操作仅支持 Windows。可以在其它系统使用 -Plan / -Check。' }
    if ([Console]::IsInputRedirected) { throw '需要交互终端；输入重定向或 EOF 时停止。只读检查请传 -Plan / -Check。' }
    Write-Host ('日志位于系统临时目录 JobsFlutter-' + $Action + '-时间戳.log')
    if ((Read-Host '回车继续，其它输入取消') -cne '') { throw '用户取消。' }
    $log = Join-Path ([IO.Path]::GetTempPath()) ('JobsFlutter-' + $Action + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.log')
    Start-Transcript -LiteralPath $log | Out-Null
    $originalPath=$env:PATH
    try {
        $projectActions = @('postclone','imports','uri','doctor','codegen','outdated','namespace','dependencies','clean','assets','androidrun','physicalrun','build','upgrade','pubupgrade','precache','setup','harmony','fvm','extractsources','vscode','vscodeproject')
        $root = ''
        if ($Action -in $projectActions) { $root = Resolve-JobsProject $Options.TargetPath }
        switch ($Action) {
            'doctor' { $module=Import-JobsFeature 'Doctor'; & $module { param($p) Invoke-JobsFlutterDoctorAction $p } $root }
            'codegen' { $module=Import-JobsFeature 'Codegen'; & $module { param($p) Invoke-JobsFlutterCodegenAction $p } $root }
            'androidprepare' { Invoke-JobsAndroidPrepare }
            'androidstart' { if ($Options.Mode -eq 'Create') { Invoke-JobsAndroidPrepare -Create } else { [void](Start-JobsAndroid $Options.Device) } }
            'androidrun' { [void](Start-JobsAndroid $Options.Device); Start-JobsFlutterProject $root 'emulator' '' }
            'physicalrun' { Start-JobsFlutterProject $root 'physical' $Options.Device }
            'build' { $module=Import-JobsFeature 'Packager'; $type=Select-JobsItem 'Android 产物' @('apk','appbundle','all'); & $module { param($p,$t,$l) $script:PackagerLog=$l; Invoke-JobsPackagerBuild -Project $p -Type $t } $root $type $log }
            'upgrade' { Confirm-JobsChange '升级当前项目选中的 Flutter SDK，可能影响共用该版本的工程。'; Invoke-JobsFlutter $root @('upgrade') }
            'pubupgrade' { Confirm-JobsChange '升级项目允许范围内的依赖并更新 pubspec.lock。'; Invoke-JobsFlutter $root @('pub','upgrade') }
            'outdated' { Invoke-JobsFlutter $root @('pub','outdated') }
            'precache' { Invoke-JobsFlutter $root @('precache','--android','--web','--windows') }
            'sdk' { Install-JobsFlutterSdk $Options.TargetPath $Options.Version }
            'fvm' { Set-JobsFvm $root $Options.Version }
            'postclone' { Set-JobsFvm $root $Options.Version; Invoke-JobsFlutter $root @('pub','get'); Set-JobsFlutterVSCodePath $root }
            'setup' {
                $platform=$Options.Mode
                if($platform -notin @('Android','Web','Windows')){$platform=Select-JobsItem '选择 Windows 可用 Flutter 目标' @('Android','Web','Windows')}
                Initialize-JobsFlutterBootstrap
                if($platform -eq 'Android'){Invoke-JobsAndroidPrepare}
                Set-JobsFvm $root $Options.Version
                Invoke-JobsFlutter $root @('pub','get')
                Invoke-JobsFlutter $root @('precache',('--'+$platform.ToLowerInvariant()))
                Start-JobsFlutterProject $root $platform.ToLowerInvariant() $Options.Device
            }
            'harmony' {
                if (-not (Test-Path -LiteralPath (Join-Path $root 'ohos') -PathType Container)) { throw '工程缺少 ohos 平台，先完成鸿蒙 Flutter 适配。' }
                if($Options.Mode -eq 'Create'){
                    $creator=Import-JobsFeature 'Harmony'
                    & $creator {Invoke-JobsHarmonySimulatorAction -Target ([Environment]::GetFolderPath('DesktopDirectory'))}
                }
                $module = Import-JobsFeature 'Packager'
                $sdk = & $module {
                    param($p,$l)
                    $script:PackagerLog=$l
                    $flutter=Get-JobsPackagerFlutter -Project $p -SdkRoot $env:FLUTTER_OHOS_SDK
                    Initialize-JobsPackagerHarmonyEnvironment
                    Assert-JobsPackagerHarmonyToolchain -Project $p -Flutter $flutter -Targets @('hap')
                    return $flutter
                } $root $log
                Push-Location -LiteralPath $root
                try {
                    $oldPreference=$ErrorActionPreference
                    try {$ErrorActionPreference='Continue';$listing=& $sdk devices --machine;$deviceExit=$LASTEXITCODE} finally {$ErrorActionPreference=$oldPreference}
                    if($deviceExit -ne 0){throw '鸿蒙设备查询失败。'}
                    $devices=@((($listing -join [Environment]::NewLine)|ConvertFrom-Json)|Where-Object {$_.targetPlatform -match 'ohos|harmony'})
                    $device=$Options.Device
                    if(-not $device){$device=Select-JobsItem '选择鸿蒙设备' @($devices|ForEach-Object {$_.id})}
                    if($device -notin @($devices|ForEach-Object {$_.id})){throw '指定鸿蒙设备不可用。'}
                    Invoke-JobsCommand $sdk @('pub','get'); Invoke-JobsCommand $sdk @('run','-d',$device)
                } finally { Pop-Location }
            }
            'vscode' { Set-JobsVSCode $root 'both' }
            'vscodeproject' { Set-JobsVSCode $root 'project' }
            'vscodeglobal' { Set-JobsVSCode '' 'global' }
            'environment' { Set-JobsWindowsEnvironment $Options.TargetPath $Options.SourcePath $Options.Mode }
            'imports' { Confirm-JobsChange '将 lib 内相对 import/export/part 转为本项目 package URI，逐文件备份。'; Convert-JobsImports $root }
            'uri' { Confirm-JobsChange '对 lib 内 URI 各路径片段进行 UTF-8 转义，逐文件备份。'; Convert-JobsImports $root -Encode }
            'namespace' { Confirm-JobsChange '仅给本工程 Android app Gradle 补缺失 namespace 并备份；不改第三方 Pub 缓存。'; Repair-JobsNamespace $root $Options.Value }
            'dependencies' { Export-JobsDependencies $root $Options.OutputPath }
            'extractsources' {
                $output=$Options.OutputPath
                if(-not $output){$output=[Environment]::GetFolderPath('DesktopDirectory')}
                $output=Resolve-JobsDirectory $output
                Invoke-JobsDart $root @((Join-Path $PSScriptRoot 'ExtractFlutterDependencies.dart'),'--project',$root,'--destination',$output)
            }
            'clean' { Confirm-JobsChange ('执行 flutter clean，移除所选工程生成缓存：' + $root) 'CLEAN'; Invoke-JobsFlutter $root @('clean'); Invoke-JobsFlutter $root @('pub','get') }
            'assets' {
                $source = Resolve-JobsDirectory $Options.SourcePath
                $target = Join-Path $root 'assets'
                Confirm-JobsChange ('来源：' + $source + '；复制到 ' + $target + '，已有资源先备份；生成器按项目配置执行。')
                [void](Backup-JobsPath $target); [void][IO.Directory]::CreateDirectory($target); Copy-JobsTree $source $target
                $module=Import-JobsFeature 'Codegen'; & $module { param($p) Invoke-JobsFlutterCodegenAction $p } $root
            }
            'record' { Invoke-JobsRecording $Options.Device $Options.OutputPath $Options.Seconds }
            'androidrepair' {
                $serial=Get-JobsAndroidSerial $Options.Device; $adb=Get-JobsAdb
                Invoke-JobsCommand $adb @('-s',$serial,'shell','df','-h','/data')
                Invoke-JobsCommand $adb @('-s',$serial,'shell','pm','get-install-location')
                Confirm-JobsChange ('将 Android ' + $serial + ' 的安装位置恢复自动，并重启 adb 服务；不卸载应用或擦除 AVD。')
                Invoke-JobsCommand $adb @('-s',$serial,'shell','pm','set-install-location','0')
                Invoke-JobsCommand $adb @('kill-server'); Invoke-JobsCommand $adb @('start-server')
            }
            'shortcut' {
                $target=Resolve-JobsDirectory $Options.TargetPath
                $link=Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) ((Split-Path -Leaf $target) + '.lnk')
                if (Test-Path -LiteralPath $link) { throw '桌面同名快捷方式已存在。' }
                $shell=New-Object -ComObject WScript.Shell; $shortcut=$shell.CreateShortcut($link); $shortcut.TargetPath=$target; $shortcut.Save()
            }
            'terminal' { $target=Resolve-JobsDirectory $Options.TargetPath; Start-Process -FilePath (Get-JobsCommand 'powershell.exe') -WorkingDirectory $target }
            'shell' { $shell=Select-JobsItem '选择本次会话 Shell' @('powershell.exe','cmd.exe','pwsh.exe'); Start-Process -FilePath (Get-JobsCommand $shell); Write-JobsMessage '已打开所选 Shell；如需默认终端请在 Windows Terminal 设置中选择默认配置文件。' }
            'hidden' {
                $registry='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; $old=(Get-ItemProperty -LiteralPath $registry).Hidden
                $next=if($old -eq 1){2}else{1}; Set-ItemProperty -LiteralPath $registry -Name Hidden -Value $next
                Write-JobsMessage '已切换资源管理器普通隐藏文件显示；按 F5 刷新。再次运行可切回；不改变受保护系统文件显示。'
            }
            'authorize' {
                if(-not $Options.TargetPath){$Options.TargetPath=Read-Host '输入或拖入一个普通文件'}
                $target=Get-Item -LiteralPath ($Options.TargetPath.Trim('"')) -Force
                if($target.PSIsContainer -or ($target.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw '仅支持一个普通文件。'}
                Confirm-JobsChange ('解除文件下载区域标记：' + $target.FullName + '。不执行文件、不改系统执行策略。')
                Unblock-File -LiteralPath $target.FullName
            }
            'color' {
                $value=$Options.Value; if(-not $value){$value=Read-Host '输入 #RRGGBB 或 #AARRGGBB'}
                if($value -notmatch '^#?(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$'){throw '颜色格式无效。'}
                $hex=$value.TrimStart('#'); if($hex.Length -eq 6){$hex='FF'+$hex}
                $a=[Convert]::ToInt32($hex.Substring(0,2),16);$r=[Convert]::ToInt32($hex.Substring(2,2),16);$g=[Convert]::ToInt32($hex.Substring(4,2),16);$b=[Convert]::ToInt32($hex.Substring(6,2),16)
                Write-Host ('ARGB：#{0}；CSS：rgba({1}, {2}, {3}, {4:F3})；Flutter：Color(0x{0})' -f $hex,$r,$g,$b,($a/255.0))
            }
            'profile' { if(-not(Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts)){throw '当前用户 PowerShell profile 尚不存在。'}; Start-Process -FilePath (Get-JobsCommand 'notepad.exe') -ArgumentList @($PROFILE.CurrentUserAllHosts); Write-JobsMessage '编辑后请在新终端确认效果；不会自动执行未知 profile。' }
            'jobsfunction' {
                $path=$PROFILE.CurrentUserAllHosts
                $content=if(Test-Path -LiteralPath $path){[IO.File]::ReadAllText($path)}else{''}
                if($content -match '(?m)^function jobs\b'){throw '已有 jobs 函数，请人工合并，避免覆盖。'}
                $content += "`r`nfunction jobs {`r`n    Write-Host ('PowerShell profile: ' + `$PROFILE.CurrentUserAllHosts)`r`n    Get-Command flutter, dart, git, java, adb -ErrorAction SilentlyContinue | Select-Object Name, Source`r`n}`r`n"
                Confirm-JobsChange ('向当前用户 PowerShell profile 添加 jobs 环境摘要函数：' + $path)
                Write-JobsText $path $content
            }
            'sourcetree' {
                $target=$Options.TargetPath; if(-not $target){$target=Join-Path ([Environment]::GetFolderPath('UserProfile')) 'SourceTree.command'}
                if(Test-Path -LiteralPath $target){throw '目标已存在，拒绝覆盖。'}
                $url='https://github.com/JobsKits/SourceTree.sh.git'; Write-JobsMessage ('来源：'+$url+'；目标：'+$target)
                Invoke-JobsCommand (Get-JobsCommand 'git') @('clone','--depth','1','--',$url,$target)
            }
            default { throw ('未知功能：' + $Action) }
        }
        Write-JobsMessage ('完成。日志：' + $log)
    } finally { $env:PATH=$originalPath; Stop-Transcript | Out-Null }
}
function Test-JobsJsonComment {
    param([string]$Text)
    $quoted=$false
    for($i=0;$i -lt $Text.Length;$i++){
        $character=$Text[$i]
        if($quoted -and $character -eq [char]92){$i++;continue}
        if($character -eq [char]34){$quoted=-not $quoted;continue}
        if(-not $quoted -and $character -eq '/' -and $i+1 -lt $Text.Length -and $Text[$i+1] -in @('/','*')){return $true}
    }
    return $false
}
function Set-JobsFlutterVSCodePath {
    param([string]$Project)
    $path=Join-Path $Project '.vscode/settings.json'
    $config=@{}
    if(Test-Path -LiteralPath $path){
        try { $raw=[IO.File]::ReadAllText($path); if(Test-JobsJsonComment $raw){throw 'JSONC'}; $existing=$raw | ConvertFrom-Json; if($null -eq $existing){throw 'JSON 必须是对象'} } catch { throw '已有 settings.json 含注释或不能解析，保留原文，请人工设置 dart.flutterSdkPath。' }
        foreach($property in $existing.PSObject.Properties){$config[$property.Name]=$property.Value}
    }
    $config['dart.flutterSdkPath']='.fvm/flutter_sdk'
    Write-JobsText $path ($config | ConvertTo-Json -Depth 32)
}
Export-ModuleMember -Function Invoke-JobsTask
