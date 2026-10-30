require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'pty'
require 'timeout'

class HarmonyPackagingTest < Minitest::Test
  ENTRY = File.expand_path('../【MacOS】📦双击打包Flutter.Harmony.command', __dir__)

  def setup
    @root = Dir.mktmpdir('Jobs Harmony 打包 ')
    @project = File.join(@root, '工程 空格')
    @sdk = File.join(@root, '鸿蒙 SDK')
    @tools = File.join(@root, 'tools')
    @trace = File.join(@root, 'trace')
    FileUtils.mkdir_p([File.join(@project, 'lib'), File.join(@project, 'ohos'), File.join(@sdk, 'bin'), @tools, File.join(@root, 'sdk')])
    File.write(File.join(@project, 'pubspec.yaml'), "name: fixture\ndependencies:\n  flutter:\n    sdk: flutter\n")
    %w[build-profile.json5 oh-package.json5].each { |name| File.write(File.join(@project, 'ohos', name), '{}') }
    %w[node npm ohpm hvigorw java].each do |name|
      write_tool(File.join(@tools, name), "#!/bin/zsh\nprint -r -- 'fixture version'\n")
    end
    write_tool(File.join(@sdk, 'bin/flutter'), <<~'ZSH')
      #!/bin/zsh
      if [[ "$1" == --version ]]; then print -r -- 'Flutter fixture'; exit 0; fi
      if [[ "$3" == --help ]]; then
        [[ "$MISSING_CAPABILITY" != "$2" ]] || exit 9
        print -r -- "flutter build $2"; exit 0
      fi
      print -r -- "$*" >> "$TRACE"
      if [[ "$1" == pub ]]; then [[ "$FAIL_STEP" != pub ]] || exit 23; exit 0; fi
      [[ "$FAIL_STEP" != "$2" ]] || exit 24
      [[ "$EMPTY_OUTPUT" != "$2" ]] || exit 0
      if [[ "$2" == app && "$REMOVE_HAP" == 1 ]]; then
        /bin/rm -f "$FIXTURE_PROJECT/build/ohos/hap/entry-default-signed.hap"
      fi
      /bin/mkdir -p "$FIXTURE_PROJECT/build/ohos/$2"
      print -r -- 'fixture artifact' > "$FIXTURE_PROJECT/build/ohos/$2/entry-default-signed.$2"
    ZSH
    @definitions = File.join(@root, 'definitions.zsh')
    File.write(@definitions, File.read(ENTRY).sub(/^main "\$@"\s*\z/, ''))
    @env = {
      'PATH' => "#{@tools}:/usr/bin:/bin:/usr/sbin:/sbin", 'DEVECO_SDK_HOME' => File.join(@root, 'sdk'),
      'DEVECO_STUDIO_HOME' => '', 'TOOL_HOME' => '', 'HOS_SDK_HOME' => '', 'JAVA_HOME' => '', 'NODE_HOME' => '',
      'FLUTTER_OHOS_SDK' => '', 'OPEN_AFTER_BUILD' => '0', 'NO_COLOR' => '1', 'TRACE' => @trace,
      'FIXTURE_PROJECT' => @project, 'FAIL_STEP' => '', 'MISSING_CAPABILITY' => '', 'EMPTY_OUTPUT' => '',
      'BUILD_TARGET' => 'hap', 'OHOS_BUILD_TARGET' => 'hap', 'BUILD_MODE' => 'debug'
    }
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write_tool(path, source)
    File.write(path, source)
    File.chmod(0755, path)
  end

  def build(overrides = {}, sdk: true)
    code = 'source "$1"; PLAIN_OUTPUT=1; initialize_script_runtime || exit $?; parse_build_options --project "$2"'
    code += ' --flutter-sdk "$3"' if sdk
    code += ' || exit $?; run_build_flow'
    Open3.capture3(@env.merge(overrides), '/bin/zsh', '-fc', code, '--', @definitions, @project, @sdk)
  end

  def trace
    File.exist?(@trace) ? File.readlines(@trace, chomp: true) : []
  end

  def test_builds_both_in_order_with_fixed_default
    out, err, status = build
    assert status.success?, out + err
    assert_equal ['pub get', 'build hap --release', 'build app --release'], trace
    assert_includes out, 'HAP + APP'
  end

  def test_interactive_entry_runs_both_with_fake_tools
    output = +''
    result = nil
    Timeout.timeout(15) do
      PTY.spawn(@env.merge('FLUTTER_OHOS_SDK' => @sdk), '/bin/zsh', ENTRY) do |reader, writer, pid|
        writer.write("\n#{@project}\n")
        begin
          loop { output << reader.readpartial(4096) }
        rescue Errno::EIO, EOFError
          # macOS PTY closes after the child exits.
        end
        _pid, result = Process.wait2(pid)
      end
    end
    output.force_encoding(Encoding::UTF_8)
    assert result.success?, output
    assert_equal ['pub get', 'build hap --release', 'build app --release'], trace
    assert_includes output, 'HAP + APP 构建与双产物检查完成'
  end

  def test_app_failure_preserves_failure_and_hap
    out, err, status = build('FAIL_STEP' => 'app')
    assert_equal 24, status.exitstatus, out + err
    assert File.exist?(File.join(@project, 'build/ohos/hap/entry-default-signed.hap'))
    refute_includes out, 'HAP + APP 构建与双产物检查完成'
  end

  def test_hap_failure_never_builds_app
    _out, _err, status = build('FAIL_STEP' => 'hap')
    assert_equal 24, status.exitstatus
    assert_equal ['pub get', 'build hap --release'], trace
  end

  def test_pub_failure_never_builds_packages
    _out, _err, status = build('FAIL_STEP' => 'pub')
    assert_equal 23, status.exitstatus
    assert_equal ['pub get'], trace
  end

  def test_both_capabilities_are_checked_before_pub_get
    out, err, status = build('MISSING_CAPABILITY' => 'app')
    refute status.success?, out + err
    assert_empty trace
  end

  def test_missing_app_output_is_failure
    _out, _err, status = build('EMPTY_OUTPUT' => 'app')
    refute status.success?
    assert_equal ['pub get', 'build hap --release', 'build app --release'], trace
  end

  def test_app_removing_hap_is_not_overall_success
    out, _err, status = build('REMOVE_HAP' => '1')
    refute status.success?
    assert_includes out, 'HAP 与 APP 未同时保留'
    refute_includes out, 'HAP + APP 构建与双产物检查完成'
  end

  def test_stale_app_is_not_a_new_output
    old = File.join(@project, 'build/ohos/app/old.app')
    FileUtils.mkdir_p(File.dirname(old))
    File.write(old, 'old')
    File.utime(Time.at(1), Time.at(1), old)
    out, _err, status = build('EMPTY_OUTPUT' => 'app')
    refute status.success?
    assert_includes out, '保留历史 .app'
    assert_equal 'old', File.read(old)
  end

  def test_broken_fvm_never_falls_back
    File.write(File.join(@project, '.fvmrc'), '{"flutter":"fixture"}')
    _out, _err, status = build({}, sdk: false)
    refute status.success?
    assert_empty trace
  end

  def test_check_is_offline_and_validates_harmony_metadata
    out, err, status = Open3.capture3(@env, '/bin/zsh', ENTRY, '--check', '--project', @project)
    assert status.success?, out + err
    assert_includes out, '未验证工具链'
    assert_empty trace
    FileUtils.rm(File.join(@project, 'ohos/build-profile.json5'))
    _out, _err, status = Open3.capture3(@env, '/bin/zsh', ENTRY, '--check', '--project', @project)
    refute status.success?
    assert_empty trace
  end

  def test_rejects_non_flutter_and_symlink_project
    File.write(File.join(@project, 'pubspec.yaml'), "name: ordinary\ndependencies:\n  sample: any\n")
    _out, _err, status = build
    refute status.success?
    assert_empty trace
    link = File.join(@root, 'link')
    File.symlink(@project, link)
    _out, _err, status = Open3.capture3(@env, '/bin/zsh', ENTRY, '--check', '--project', link)
    refute status.success?
  end
end
