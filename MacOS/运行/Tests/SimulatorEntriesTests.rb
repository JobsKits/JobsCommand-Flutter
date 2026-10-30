# frozen_string_literal: true
# 隔离夹具验证新模拟器入口；不下载、安装或启动真实工具。
require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'shellwords'

class SimulatorEntriesTests < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  RUN = File.join(ROOT, '【MacOS】☀️双击运行Flutter项目（鸿蒙模拟器）.command')
  ENTRY = File.join(RUN, File.basename(RUN))
  OPEN = File.join(ROOT, '【MacOS】📱双击打开已实例化的鸿蒙模拟器.command')

  def setup
    @temporary = Dir.mktmpdir('Jobs simulator 中文 ')
    @library = File.join(@temporary, 'EntryLibrary.zsh')
    File.write(@library, File.read(ENTRY).sub(/main "\$@"\s*\z/, ''))
  end
  def teardown
    FileUtils.remove_entry(@temporary)
  end
  def shell(body, *args)
    Open3.capture3('/bin/zsh', '-c', 'source "$1"; shift; ' + body, 'test', @library, *args)
  end
  def test_filters_physical_android_and_unsupported_devices
    data = [{id:'harmony-1',name:'鸿蒙模拟器',targetPlatform:'ohos-arm64',emulator:true},
      {id:'physical',targetPlatform:'ohos-arm64',emulator:false},
      {id:'android',targetPlatform:'android-arm64',emulator:true},
      {id:'unsupported',targetPlatform:'ohos-arm64',emulator:true,isSupported:false}]
    file=File.join(@temporary,'devices.json');File.write(file,JSON.generate(data))
    out,err,status=shell('jobs_harmony_device_rows "$1"',file)
    assert status.success?,err
    assert_equal "harmony-1\t鸿蒙模拟器 — 鸿蒙模拟器\n",out
  end
  def test_bad_or_duplicate_device_identifiers_stop
    ['', '-option', "bad\tid"].each do |id|
      file=File.join(@temporary,'devices.json')
      File.write(file,JSON.generate([{id:id,targetPlatform:'ohos',emulator:true}]))
      _,_,status=shell('jobs_harmony_device_rows "$1"',file)
      refute status.success?
    end
    file=File.join(@temporary,'devices.json')
    File.write(file,JSON.generate(Array.new(2){{id:'same',targetPlatform:'ohos',emulator:true}}))
    _,_,status=shell('jobs_harmony_device_rows "$1"',file)
    refute status.success?
  end
  def test_empty_devices_are_empty_not_a_silent_fallback
    file=File.join(@temporary,'devices.json');File.write(file,'[]')
    out,err,status=shell('jobs_harmony_device_rows "$1"',file)
    assert status.success?,err
    assert_equal "\n",out
  end
  def test_copy_and_rename_keep_project_check_independent_of_working_directory
    copy=File.join(@temporary,'复制 包 (renamed)');FileUtils.cp_r(RUN,copy)
    project=File.join(@temporary,'项目 root');FileUtils.mkdir_p([File.join(project,'lib'),File.join(project,'ohos')])
    File.write(File.join(project,'pubspec.yaml'),"name: fixture\ndependencies:\n  flutter:\n    sdk: flutter\n")
    %w[build-profile.json5 oh-package.json5].each{|f|File.write(File.join(project,'ohos',f),'{}')}
    output,status=Open3.capture2e('/bin/zsh',File.join(copy,File.basename(RUN)),'--check','--project',project,chdir:'/tmp')
    assert status.success?,output
    assert_includes output,'工程清单检查通过'
    refute File.exist?(File.join(project,'pubspec.lock'))
  end
  def test_missing_fvm_binding_does_not_use_global_sdk
    project=File.join(@temporary,'project');FileUtils.mkdir_p(project);File.write(File.join(project,'.fvmrc'),'{}')
    output,status=Open3.capture2e('/bin/zsh','-c','source "$1"; PROJECT_ROOT="$2"; choose_flutter_sdk','test',File.join(RUN,'FlutterHarmonyTools.zsh'),project)
    refute status.success?
    assert_includes output,'FVM'
  end
  def test_existing_instance_does_not_initialize
    output,status=Open3.capture2e('/bin/zsh','-c',<<~'ZSH','test',File.join(OPEN,'HarmonySimulator.zsh'))
      source "$1"
      HS_NAMES=('Existing Phone')
      hs_choose() { print -r -- 'Existing Phone'; }
      hs_prepare_environment() { print BAD_INITIALIZE; return 9; }
      hs_review_licenses() { return 0; }
      jobs_harmony_start_backend() { print -r -- "START:$1"; }
      jobs_harmony_select_and_start 0
    ZSH
    assert status.success?,output
    assert_includes output,'START:Existing Phone'
    refute_includes output,'BAD_INITIALIZE'
  end
  def test_open_empty_list_does_not_initialize
    output,status=Open3.capture2e('/bin/zsh','-c','source "$1"; HS_NAMES=(); hs_prepare_environment(){print BAD;}; jobs_harmony_select_and_start 0','test',File.join(OPEN,'HarmonySimulator.zsh'))
    refute status.success?
    refute_includes output,'BAD'
    assert_includes output,'先运行'
  end
  def test_cancel_prevents_start_and_creation
    output,status=Open3.capture2e('/bin/zsh','-c','source "$1"; HS_NAMES=(Existing); hs_choose(){return 130;}; jobs_harmony_start_backend(){print BAD;}; jobs_harmony_select_and_start 1','test',File.join(OPEN,'HarmonySimulator.zsh'))
    assert_equal 130,status.exitstatus
    refute_includes output,'BAD'
  end
  def test_missing_instance_initializes_then_starts_exact_name
    output,status=Open3.capture2e('/bin/zsh','-c',<<~'ZSH','test',File.join(OPEN,'HarmonySimulator.zsh'))
      source "$1"
      HS_NAMES=()
      hs_prepare_environment() { print PREPARE; }
      hs_select_image() { HS_NAME=NewPhone; }
      hs_create_and_verify() { print CREATE; }
      hs_query_output() { print '[]'; }
      hs_json() { print NewPhone; }
      hs_review_licenses() { return 0; }
      jobs_harmony_start_backend() { print -r -- "START:$1"; }
      jobs_harmony_select_and_start 1
    ZSH
    assert status.success?,output
    assert_equal "PREPARE\nCREATE\nSTART:NewPhone\n",output
  end
  def test_query_timeout_stops_child_before_late_write
    script=File.join(@temporary,'query.sh');marker=File.join(@temporary,'late')
    File.write(script,"#!/bin/sh\n(sleep 3; touch \"$1\") &\nwait\n");File.chmod(0755,script)
    _,_,status=shell('jobs_harmony_query "$1" 1 "$2" "$3"',File.join(@temporary,'query.log'),script,marker)
    assert_equal 124,status.exitstatus
    sleep 3
    refute File.exist?(marker)
  end
  def test_quick_start_failure_is_reported
    fake=File.join(@temporary,'Emulator');File.write(fake,"#!/bin/sh\nexit 7\n");File.chmod(0755,fake)
    output,status=Open3.capture2e('/bin/zsh','-c','source "$1"; HS_BIN="$2"; HS_LOG="$3"; jobs_harmony_start_backend Phone','test',File.join(OPEN,'HarmonySimulator.zsh'),fake,File.join(@temporary,'log'))
    assert_equal 7,status.exitstatus,output
    assert_includes output,'启动失败'
  end
  def test_new_entry_syntax_and_readonly_help
    Dir.glob(File.join(ROOT,'*')).select{|p|File.directory?(p)&&File.basename(p).match?(/初始化Android|初始化鸿蒙|实例化的鸿蒙|鸿蒙模拟器）/)}.each do |package|
      Dir.glob(File.join(package,'*.{command,zsh}')).each do |file|
        output,status=Open3.capture2e('/bin/zsh','-n',file);assert status.success?,output
      end
      command=File.join(package,File.basename(package));output,status=Open3.capture2e('/bin/zsh',command,'--help')
      assert status.success?,output
    end
  end
end
