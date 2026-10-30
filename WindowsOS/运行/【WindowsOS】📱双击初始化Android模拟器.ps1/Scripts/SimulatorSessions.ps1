# SimulatorSessions.ps1 | JobsCommand-Flutter
# Created by Jobs on 2026年10月29日，星期四.
# 选择、启动鸿蒙实例与有界等待 Flutter；不注册扩展、不改全局 SDK。
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
    param([string]$Flutter, [string]$Project, [string[]]$Arguments, [int]$TimeoutSeconds = 30)
    # 在独立 PowerShell 进程内调用 .bat，使用编码后的结构化数据保持路径与 argv 边界。
    $payload = @{ File=$Flutter; Project=$Project; Arguments=$Arguments } | ConvertTo-Json -Depth 4 -Compress
    $data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    $command = '$ErrorActionPreference="Continue"; $d=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("' + $data + '"))|ConvertFrom-Json; Set-Location -LiteralPath $d.Project; $a=[string[]]@($d.Arguments); $global:LASTEXITCODE=-1; & ([string]$d.File) @a; exit $LASTEXITCODE'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $hostFile = (Get-Process -Id $PID).Path
    $module = Import-JobsFeature 'Packager'
    return & $module {
        param($file, $code, $project, $limit)
        Invoke-JobsProcess -FilePath $file -Arguments @('-NoLogo','-NoProfile','-EncodedCommand',$code) -WorkingDirectory $project -TimeoutSeconds $limit
    } $hostFile $encoded $Project $TimeoutSeconds
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
