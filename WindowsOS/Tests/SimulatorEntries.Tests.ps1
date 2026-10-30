# SimulatorEntries.Tests.ps1 | 仅临时夹具与内存替身，不执行真实 SDK 或模拟器。
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$module=Import-Module (Join-Path $root 'Scripts/FlutterTools.psm1') -PassThru -Force -DisableNameChecking
& $module {
    $script:count=0
    function Assert-True {param($value,$label);if(-not $value){throw $label};$script:count++}
    function Assert-Throws {param([scriptblock]$call,$label);$thrown=$false;try{&$call|Out-Null}catch{$thrown=$true};Assert-True $thrown $label}
    $devices=@(Get-JobsHarmonyEmulatorDevices '[{"id":"h1","targetPlatform":"ohos-arm64","emulator":true},{"id":"physical","targetPlatform":"ohos-arm64","emulator":false},{"id":"android","targetPlatform":"android-arm64","emulator":true},{"id":"unsupported","targetPlatform":"ohos-arm64","emulator":true,"isSupported":false}]')
    Assert-True ($devices.Count-eq 1-and$devices[0].id-ceq'h1') '只保留受支持鸿蒙模拟器'
    Assert-True (@(Get-JobsHarmonyEmulatorDevices '[]').Count-eq 0) '空设备不隐式回退'
    Assert-Throws {Get-JobsHarmonyEmulatorDevices '{}'} '非数组拒绝'
    Assert-Throws {Get-JobsHarmonyEmulatorDevices '[{"id":"same","targetPlatform":"ohos","emulator":true},{"id":"same","targetPlatform":"ohos","emulator":true}]'} '重复ID拒绝'
    Assert-Throws {Get-JobsHarmonyEmulatorDevices '[{"id":"-bad","targetPlatform":"ohos","emulator":true}]'} '参数式ID拒绝'
    # 模拟 Windows PowerShell 5.1 将顶层 JSON 数组作为单个管道对象输出。
    function ConvertFrom-Json {
        param([Parameter(ValueFromPipeline=$true)][string]$InputObject)
        process {
            $parsed=Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject $InputObject -ErrorAction Stop
            Write-Output -NoEnumerate @($parsed)
        }
    }
    $devices=@(Get-JobsHarmonyEmulatorDevices '[{"id":"ps51","targetPlatform":"ohos-arm64","emulator":true},{"id":"android","targetPlatform":"android-arm64","emulator":true}]')
    Assert-True ($devices.Count-eq 1-and$devices[0].id-ceq'ps51') '5.1非枚举数组仍按设备筛选'
    Remove-Item Function:ConvertFrom-Json
    $script:state=@{Create=0;Start=0;Instances=@([pscustomobject]@{name='Existing Phone'})}
    $script:fake=New-Module -Name JobsSimulatorFixture -ArgumentList $script:state -ScriptBlock {
        param($state)
        $script:state=$state
        function Get-JobsHarmonyCheck {param([switch]$InstallMissing);[pscustomobject]@{Emulator='fake-emulator';Instances=$script:state.Instances}}
        function Get-JobsHarmonyInstances {param($emulator);$script:state.Instances}
        function Invoke-JobsHarmonySimulatorAction {param($Target,[switch]$NoStart);$script:state.Create++;$script:state.Instances+= [pscustomobject]@{name='NewPhone'}}
        function Confirm-JobsHarmonyLicenses {param($emulator)}
        function Quote-JobsArgument {param($value);'"'+$value+'"'}
        function Write-JobsHarmonyMessage {param($message)}
        function Start-Process {
            param($FilePath,$ArgumentList,[switch]$PassThru,$WindowStyle,$RedirectStandardOutput,$RedirectStandardError)
            $script:state.Start++
            $p=[pscustomobject]@{ExitCode=0}
            $p|Add-Member ScriptMethod WaitForExit {param($timeout);return $true}
            $p|Add-Member ScriptMethod Dispose {}
            $p
        }
    }
    function script:Import-JobsFeature {param($Name);return $script:fake}
    function script:Select-JobsSimulatorItem {param($Title,$Items);return $Items[0]}
    $chosen=Start-JobsHarmonySimulator -ExistingOnly
    Assert-True ($chosen.Name-ceq'Existing Phone') '已有实例精确启动'
    Assert-True ($script:state.Create-eq 0-and$script:state.Start-eq 1) '已有路径不初始化'
    $script:state.Instances=@()
    Assert-Throws {Start-JobsHarmonySimulator -ExistingOnly} '打开空列表停止'
    Assert-True ($script:state.Create-eq 0-and$script:state.Start-eq 1) '空列表无副作用'
    $chosen=Start-JobsHarmonySimulator
    Assert-True ($chosen.Name-ceq'NewPhone'-and$script:state.Create-eq 1-and$script:state.Start-eq 2) '缺失实例初始化并启动唯一新实例'
    function script:Select-JobsSimulatorItem {param($Title,$Items);throw '已取消'}
    Assert-Throws {Start-JobsHarmonySimulator} '取消选择停止'
    Assert-True ($script:state.Start-eq 2-and$script:state.Create-eq 1) '取消不启动不创建'
    Write-Host ('PASS：'+$script:count+' 项鸿蒙模拟器行为断言；没有调用真实 SDK。')
}
