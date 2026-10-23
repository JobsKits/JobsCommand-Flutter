"""Offline regression: fake executables and temporary projects only."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENTRY = next(ROOT.glob('*.command'))
spec = importlib.util.spec_from_file_location('config', ROOT / 'Scripts/project_config.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-flutter-tests-')
        self.base = Path(self.temp.name).resolve()
        self.project = self.base / "工程 空格 ' $(touch INJECTED) `touch BACKTICK`"
        (self.project / 'lib').mkdir(parents=True)
        (self.project / 'pubspec.yaml').write_text('name: example\n')
        (self.base / 'home').mkdir()
        self.env = dict(os.environ, TEST_PROJECT=str(self.project), TEST_BASE=str(self.base),
                        TEST_PYTHON=sys.executable, HOME=str(self.base / 'home'), TMPDIR=str(self.base))

    def tearDown(self):
        self.temp.cleanup()

    def zsh(self, code, data='', expected=0):
        source = f'source {shlex.quote(str(ENTRY))}\nJOBS_PYTHON_BIN="$TEST_PYTHON"\n' + code
        result = subprocess.run(['/bin/zsh', '-c', source], input=data, text=True,
                                capture_output=True, cwd=self.base, env=self.env, timeout=15)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertFalse((self.base / 'INJECTED').exists())
        self.assertFalse((self.base / 'BACKTICK').exists())
        return result

    def test_only_exact_yes_enables_global(self):
        for answer in ('', 'yes', 'Yes', 'YES ', ' YES', 'Y', 'anything', 'YES'):
            with self.subTest(answer=answer):
                r = self.zsh('jobs_choose_install_mode || exit $?\nprint "MODE=$JOBS_INSTALL_MODE AUTH=$JOBS_GLOBAL_AUTHORIZED"', answer + '\n')
                expected = 'global AUTH=1' if answer == 'YES' else 'fvm AUTH=0'
                self.assertIn('MODE=' + expected, r.stdout)

    def test_empty_paths_retry_and_finder_quoting_is_safe(self):
        path = shlex.quote(str(self.project))
        r = self.zsh('jobs_choose_project || exit $?\nprint -r -- "ROOT=$PROJECT_ROOT"', '\n\n/no/such/path\n' + path + '\n')
        self.assertIn('ROOT=' + str(self.project), r.stdout)
        self.assertEqual(r.stderr.count('拖入或输入'), 4)

    def test_finder_escaped_spaces_and_tilde(self):
        r = self.zsh('jobs_choose_project || exit $?\nprint -r -- "$PROJECT_ROOT"',
                     str(self.project).replace(' ', '\\ ').replace("'", "\\'").replace('$', '\\$').replace('`', '\\`').replace('(', '\\(').replace(')', '\\)') + '\n')
        self.assertIn(str(self.project), r.stdout)

    def test_eof_cancels_instead_of_looping(self):
        self.zsh('jobs_choose_project', '\n\n', expected=130)
        self.zsh('jobs_choose_install_mode', '', expected=130)

    def test_global_without_authorization_does_not_execute(self):
        r = self.zsh('JOBS_INSTALL_MODE=global\nJOBS_FVM_BIN=/no/such/fvm\njobs_enable_global', expected=1)
        self.assertIn('缺少精确 YES', r.stderr)

    def test_argument_project_is_validated(self):
        r = self.zsh('jobs_choose_project "$TEST_PROJECT"\nprint -r -- "$PROJECT_ROOT"')
        self.assertIn(str(self.project), r.stdout)

    def test_linked_config_directory_is_rejected(self):
        (self.project / '.vscode').symlink_to(self.base, target_is_directory=True)
        self.zsh('jobs_choose_project "$TEST_PROJECT"', expected=1)

    def test_corrupt_fvmrc_is_not_overwritten(self):
        path = self.project / '.fvmrc'
        path.write_text('{broken')
        with self.assertRaises(ValueError):
            config.configure_fvm(self.project, '/cache', 'https://repo.git')
        self.assertEqual(path.read_text(), '{broken')

    def test_fvm_configuration_keeps_versions_flavors(self):
        p = self.project / '.fvmrc'
        p.write_text(json.dumps({'flutter': '3.24.5', 'flavors': {'prod': '3.24.5'}}))
        config.configure_fvm(self.project, '/cache/official', 'https://github.com/flutter/flutter.git')
        data = json.loads(p.read_text())
        self.assertEqual(data['flutter'], '3.24.5')
        self.assertEqual(data['flavors'], {'prod': '3.24.5'})
        self.assertFalse(data['updateVscodeSettings'])
        self.assertTrue(list(self.project.glob('.fvmrc.bak.*')))

    def test_existing_sdk_is_default(self):
        (self.project / '.fvmrc').write_text('{"flutter":"3.24.5"}')
        r = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\nJOBS_PYTHON_BIN="$TEST_PYTHON"\njobs_choose_sdk || exit $?\nprint "$JOBS_SDK_FAMILY/$JOBS_SDK_REF"', '\n\n')
        self.assertIn('official/3.24.5', r.stdout)

    def test_vscode_merges_instead_of_replacing(self):
        (self.project / '.vscode').mkdir()
        settings = self.project / '.vscode/settings.json'
        settings.write_text(json.dumps({'editor.fontSize': 19, 'dart.sdkPath': '/old', 'dart.env': {'CUSTOM': 'yes'}}))
        launch = self.project / '.vscode/launch.json'
        launch.write_text(json.dumps({'version': '0.2.0', 'configurations': [{'name': 'User debug', 'args': ['hello']}]}))
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        data = json.loads(settings.read_text())
        self.assertEqual(data['editor.fontSize'], 19)
        self.assertNotIn('dart.sdkPath', data)
        self.assertEqual(data['dart.env']['CUSTOM'], 'yes')
        self.assertEqual(json.loads(launch.read_text())['configurations'][0]['name'], 'User debug')
        config.vscode(self.project, {}, '.fvm/flutter_sdk', 'harmony')
        self.assertEqual(len(json.loads(launch.read_text())['configurations']), 2)

    def test_jsonc_is_preserved_with_suggestion(self):
        (self.project / '.vscode').mkdir()
        p = self.project / '.vscode/settings.json'
        original = '{\n // my comment\n "editor.fontSize": 19,\n}'
        p.write_text(original)
        config.vscode(self.project, {}, '.fvm/flutter_sdk', 'official')
        self.assertEqual(p.read_text(), original)
        self.assertTrue((self.project / '.jobs-flutter/settings.json.suggested.json').exists())

    def test_runtime_launcher_quotes_paths(self):
        sdk = self.base / "sdk ' $(touch INJECTED)"
        (sdk / 'bin').mkdir(parents=True)
        flutter = sdk / 'bin/flutter'
        flutter.write_text('#!/bin/zsh\nprint -rl -- "$PWD" "$@"\n')
        flutter.chmod(0o700)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(sdk)
        config.project_runtime(self.project, 'official', 'stable', '3.1.0', 'a'*40, str(sdk), '', '')
        result = subprocess.run([str(self.project / '.jobs-flutter/flutter'), 'run', '-d', 'device with space'], cwd=self.base, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('device with space', result.stdout)
        self.assertIn(str(self.project), result.stdout)
        self.assertFalse((self.project / 'INJECTED').exists())

    def test_switch_to_official_removes_only_owned_editor_environment(self):
        (self.project / '.vscode').mkdir()
        (self.project / '.jobs-flutter').mkdir()
        (self.project / '.jobs-flutter/sdk.json').write_text(json.dumps({'managedEnv': {'HOS_SDK_HOME': '/old/sdk', 'PATH': '/old/path'}}))
        settings = self.project / '.vscode/settings.json'
        settings.write_text(json.dumps({'dart.env': {'HOS_SDK_HOME': '/old/sdk', 'PATH': '/old/path', 'CUSTOM': 'keep'}}))
        config.project_runtime(self.project, 'official', '3.24.5', '3.24.5', 'a'*40, '/new/sdk', '', '')
        env = json.loads(settings.read_text())['dart.env']
        self.assertNotIn('HOS_SDK_HOME', env)
        self.assertNotIn('PATH', env)
        self.assertEqual(env['CUSTOM'], 'keep')

    def test_profile_is_idempotent_and_preserves_user_lines(self):
        profile = self.base / '.zprofile'
        profile.write_text('export USER_VALUE=hello\n')
        config.profile(profile, "/sdk ' $()/one")
        config.profile(profile, '/sdk/two')
        text = profile.read_text()
        self.assertIn('export USER_VALUE=hello', text)
        self.assertEqual(text.count('# >>> Jobs Flutter global >>>'), 1)
        self.assertNotIn('/sdk \'', text)

    def test_harmony_tag_is_peeled_and_missing_ref_fails(self):
        r = self.zsh('''JOBS_SDK_REPO=https://test.git
JOBS_SDK_REF=release
jobs_git() { print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release'; print -r -- 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/release^{}'; }
jobs_resolve_harmony_commit || exit $?
print "$JOBS_FVM_VERSION"
''')
        self.assertIn('custom_jobs_ohos_' + 'b'*40, r.stdout)
        self.zsh('JOBS_SDK_REPO=https://test.git\nJOBS_SDK_REF=nope\njobs_git() { return 0; }\njobs_resolve_harmony_commit', expected=1)

    def test_binding_restores_after_install_failure(self):
        old = '{"flutter":"3.24.5"}\n'
        (self.project / '.fvmrc').write_text(old)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to('/old/sdk')
        self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  return 7
}
jobs_setup_sdk
''', expected=7)
        self.assertEqual((self.project / '.fvmrc').read_text(), old)
        self.assertEqual(os.readlink(self.project / '.fvm/flutter_sdk'), '/old/sdk')

    def fake_fvm(self):
        fake = self.base / 'fvm'
        fake.write_text('#!' + sys.executable + '\n' + r'''
import os,sys,json
from pathlib import Path
args=sys.argv[1:]
root=Path.cwd(); cache=Path(os.environ['FVM_CACHE_PATH'])
with open(os.environ['TEST_BASE']+'/calls.jsonl','a') as stream: stream.write(json.dumps(args)+'\n')
if args[0]=='use':
    if os.environ.get('FAIL_INSTALL'): sys.exit(9)
    sdk=cache/'versions'/args[1]
    if not args[1].startswith('custom_'):
        (sdk/'bin').mkdir(parents=True,exist_ok=True)
        flutter=sdk/'bin/flutter'; flutter.write_text('#!/bin/zsh\n[[ "$*" != "build -h" ]] || print hap\nexit 0\n'); flutter.chmod(0o700)
    (root/'.fvm').mkdir(exist_ok=True)
    link=root/'.fvm/flutter_sdk'
    if link.is_symlink(): link.unlink()
    link.symlink_to(cache/'versions'/args[1])
    cfg=json.loads((root/'.fvmrc').read_text()); cfg['flutter']=args[1]; (root/'.fvmrc').write_text(json.dumps(cfg))
elif args[0]=='global':
    (cache/'default').symlink_to(cache/'versions'/args[1])
else: sys.exit(4)
''')
        fake.chmod(0o700)
        return fake

    def test_official_fvm_flow_does_not_write_global_environment(self):
        fake = self.fake_fvm()
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=official
JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
JOBS_SDK_REF=3.24.5
JOBS_TOOL_ROOT=""
JOBS_JAVA_HOME=""
jobs_git() {{ print {'a'*40}; }}
jobs_choose_install_mode || exit $?
jobs_setup_sdk || exit $?
jobs_prepare_project
''', '\n\n\n\n')
        calls = [json.loads(x) for x in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([x[0] for x in calls], ['use'])
        self.assertFalse((self.base / 'home/.zprofile').exists())
        self.assertTrue((self.project / '.jobs-flutter/flutter').exists())

    def test_global_flow_writes_only_after_yes(self):
        fake = self.fake_fvm()
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=official
JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
JOBS_SDK_REF=3.24.5
jobs_git() {{ print {'a'*40}; }}
jobs_choose_install_mode || exit $?
jobs_setup_sdk
''', 'YES\n\n')
        profile = self.base / 'home/.zprofile'
        self.assertTrue(profile.exists())
        self.assertIn('Jobs Flutter global', profile.read_text())
        calls = [json.loads(x) for x in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([x[0] for x in calls], ['use', 'global'])

    def test_failed_download_restores_project_and_never_calls_global(self):
        fake = self.fake_fvm()
        self.env['FAIL_INSTALL'] = '1'
        original = '{"flutter":"3.19.0"}'
        (self.project / '.fvmrc').write_text(original)
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=official
JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
JOBS_SDK_REF=3.24.5
jobs_choose_install_mode || exit $?
jobs_setup_sdk
''', 'YES\n\n', expected=9)
        self.assertEqual((self.project / '.fvmrc').read_text(), original)
        self.assertFalse((self.base / 'home/.zprofile').exists())
        calls = [json.loads(x) for x in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([x[0] for x in calls], ['use'])

    def test_harmony_download_and_fvm_binding_are_separate_from_global(self):
        fake = self.fake_fvm()
        self.zsh(f'''PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
JOBS_FVM_BIN={shlex.quote(str(fake))}
JOBS_SDK_FAMILY=harmony
JOBS_SDK_REPO="$JOBS_HARMONY_REPO"
JOBS_SDK_REF=release
jobs_git() {{
  case "$1" in
    ls-remote) print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release' ;;
    clone)
      mkdir -p "$4/bin" "$4/.git"
      print -rl -- '#!/bin/zsh' '[[ "$*" != "build -h" ]] || print hap' 'exit 0' > "$4/bin/flutter"
      chmod +x "$4/bin/flutter"
      ;;
    -C) [[ "$3" != rev-parse ]] || print aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
  esac
  return 0
}}
jobs_choose_install_mode || exit $?
jobs_setup_sdk
''', '\n\n')
        cfg = json.loads((self.project / '.fvmrc').read_text())
        self.assertEqual(cfg['flutter'], 'custom_jobs_ohos_' + 'a'*40)
        self.assertEqual(cfg['flutterUrl'], 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')
        self.assertTrue((self.project / '.fvm/flutter_sdk/bin/flutter').exists())
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_harmony_cache_with_wrong_origin_is_not_overwritten(self):
        target = self.base / 'cache/versions/custom_jobs_ohos_test'
        (target / '.git').mkdir(parents=True)
        (target / 'keep').write_text('keep')
        self.zsh('''JOBS_FVM_CACHE="$TEST_BASE/cache"
JOBS_FVM_VERSION=custom_jobs_ohos_test
JOBS_SDK_REPO=https://expected.git
JOBS_SDK_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
jobs_git() { [[ "$*" != *rev-parse* ]] || { print aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; return; }; print https://wrong.git; }
jobs_clone_harmony
''', expected=1)
        self.assertEqual((target / 'keep').read_text(), 'keep')

    def test_device_filter_uses_flutter_target_platform(self):
        devices = [{'id': 'ios1', 'name': 'iPhone', 'targetPlatform': 'ios'},
                   {'id': '127.0.0.1:5555', 'name': 'Harmony', 'targetPlatform': 'ohos-arm64'}]
        result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'), 'devices', 'harmony'], input=json.dumps(devices), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn('ios1', result.stdout)
        self.assertIn('127.0.0.1:5555', result.stdout)

    def test_noninteractive_entry_cannot_install(self):
        result = subprocess.run(['/bin/zsh', str(ENTRY)], input='', text=True, capture_output=True, env=self.env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('交互终端', result.stderr)

    def test_signal_restores_binding_and_stops_downstream(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        for signal in ('TERM', 'INT', 'HUP'):
            with self.subTest(signal=signal):
                (self.project / '.fvmrc').write_text('ORIGINAL')
                if link.is_symlink():
                    link.unlink()
                link.symlink_to('/old/sdk')
                self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  kill -''' + signal + ''' $$
}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
''', expected=130)
                self.assertEqual((self.project / '.fvmrc').read_text(), 'ORIGINAL')
                self.assertEqual(os.readlink(link), '/old/sdk')
                self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())

    def test_failure_restores_all_fvm_metadata(self):
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/version').write_text('OLD_VERSION')
        (self.project / '.fvm/fvm_config.json').write_text('{"old":true}')
        self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print NEW_VERSION > "$PROJECT_ROOT/.fvm/version"
  print NEW_RELEASE > "$PROJECT_ROOT/.fvm/release"
  print '{"new":true}' > "$PROJECT_ROOT/.fvm/fvm_config.json"
  return 7
}
jobs_setup_sdk
''', expected=7)
        self.assertEqual((self.project / '.fvm/version').read_text(), 'OLD_VERSION')
        self.assertEqual((self.project / '.fvm/fvm_config.json').read_text(), '{"old":true}')
        self.assertFalse((self.project / '.fvm/release').exists())

    def test_recovery_snapshot_is_kept_when_restore_fails(self):
        (self.project / '.fvmrc').write_text('RECOVER_ME')
        r = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() { print changed > "$PROJECT_ROOT/.fvmrc"; return 7; }
jobs_restore_binding() { return 1; }
jobs_setup_sdk
''', expected=7)
        snapshots = list(self.base.glob('JobsFlutterBinding.*'))
        self.assertEqual(len(snapshots), 1, r.stdout + r.stderr)
        self.assertTrue(any(p.is_file() and p.read_text() == 'RECOVER_ME' for p in snapshots[0].rglob('*')))
        self.assertIn(str(snapshots[0]), r.stdout + r.stderr)

    def test_unknown_fork_requires_explicit_family_selection(self):
        for version, repo in (('myfork/stable', ''), ('3.24.5', 'https://example.com/team/flutter.git'),
                              ('custom_jobs_ohos_' + 'a'*40, 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')):
            with self.subTest(version=version):
                (self.project / '.fvmrc').write_text(json.dumps({'flutter': version, 'flutterUrl': repo}))
                r = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', '\n\n', expected=130)
                self.assertNotIn('版本 / tag / 分支', r.stderr)
                self.assertEqual(json.loads((self.project / '.fvmrc').read_text())['flutter'], version)

    def test_invalid_fvm_value_has_clear_error(self):
        (self.project / '.fvmrc').write_text('{"flutter":123}')
        r = self.zsh('jobs_config current "$TEST_PROJECT"', expected=1)
        self.assertIn('配置失败', r.stderr)
        self.assertNotIn('Traceback', r.stderr)

    def test_launcher_follows_fvm_switch_and_refuses_missing_link(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        sdks = []
        for name in ('FIRST', 'SECOND'):
            sdk = self.base / name
            (sdk / 'bin').mkdir(parents=True)
            flutter = sdk / 'bin/flutter'
            flutter.write_text('#!/bin/zsh\nprint ' + name + '\n')
            flutter.chmod(0o700)
            sdks.append(sdk)
        link.symlink_to(sdks[0])
        config.project_runtime(self.project, 'official', '3.24.5', '3.24.5', 'a'*40, str(sdks[0]), '', '')
        launcher = self.project / '.jobs-flutter/flutter'
        link.unlink()
        link.symlink_to(sdks[1])
        r = subprocess.run([str(launcher), '--version'], text=True, capture_output=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), 'SECOND')
        link.unlink()
        r = subprocess.run([str(launcher), '--version'], text=True, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('FIRST', r.stdout)

    def test_launcher_permissions_are_repaired_without_content_change(self):
        args = (self.project, 'official', '3.24.5', '3.24.5', 'a'*40, '/sdk', '', '')
        config.project_runtime(*args)
        launcher = self.project / '.jobs-flutter/flutter'
        launcher.chmod(0o600)
        config.project_runtime(*args)
        self.assertTrue(os.access(launcher, os.X_OK))

    def test_harmony_status_failure_does_not_mean_clean_cache(self):
        target = self.base / 'cache/versions/custom_jobs_ohos_test'
        (target / '.git').mkdir(parents=True)
        (target / 'bin').mkdir()
        (target / 'bin/flutter').write_text('#!/bin/zsh\nexit 0\n')
        (target / 'bin/flutter').chmod(0o700)
        self.zsh('''JOBS_FVM_CACHE="$TEST_BASE/cache"
JOBS_FVM_VERSION=custom_jobs_ohos_test
JOBS_SDK_REPO=https://expected.git
JOBS_SDK_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
jobs_git() {
 case "$3" in
   rev-parse) print aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
   remote) print https://expected.git ;;
   status) return 128 ;;
 esac
}
jobs_clone_harmony
''', expected=1)

    def test_reversed_profile_markers_are_not_overwritten(self):
        profile = self.base / '.zprofile'
        original = '# <<< Jobs Flutter global <<<\nexport USER_VALUE=hello\n# >>> Jobs Flutter global >>>\n'
        profile.write_text(original)
        with self.assertRaises(ValueError):
            config.profile(profile, '/sdk')
        self.assertEqual(profile.read_text(), original)

    def test_ctrl_c_during_child_command_stops_and_restores(self):
        (self.project / '.fvmrc').write_text('BEFORE_INTERRUPT')
        ready = self.base / 'READY'
        code = f'''source {shlex.quote(str(ENTRY))}
PROJECT_ROOT="$TEST_PROJECT"
JOBS_PYTHON_BIN="$TEST_PYTHON"
jobs_setup_sdk_impl() {{
  print changed > "$PROJECT_ROOT/.fvmrc"
  touch "$TEST_BASE/READY"
  /bin/sleep 30
}}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
'''
        proc = subprocess.Popen(['/bin/zsh', '-c', code], env=self.env, cwd=self.base,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and proc.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(ready.exists(), 'SDK setup did not start')
            os.killpg(proc.pid, signal.SIGINT)
            stdout, stderr = proc.communicate(timeout=10)
            self.assertEqual(proc.returncode, 130, stdout + stderr)
            self.assertEqual((self.project / '.fvmrc').read_text(), 'BEFORE_INTERRUPT')
            self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.communicate()

    def test_real_fvm_custom_sdk_contract_without_download(self):
        fvm = shutil.which('fvm')
        if not fvm:
            self.skipTest('FVM 未安装，跳过真实 CLI 接口验证；不会安装工具')
        (self.project / 'pubspec.yaml').write_text('name: jobs_fixture\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n')
        cache = self.base / 'real-fvm-cache'
        version = 'custom_jobs_fixture'
        sdk = cache / 'versions' / version
        (sdk / 'bin').mkdir(parents=True)
        flutter = sdk / 'bin/flutter'
        flutter.write_text('#!/bin/zsh\nprint FIXTURE_ONLY\n')
        flutter.chmod(0o700)
        subprocess.run(['/usr/bin/git', 'init', str(sdk)], capture_output=True, check=True)
        config.configure_fvm(self.project, str(cache), 'https://github.com/flutter/flutter.git')
        env = dict(self.env, FVM_CACHE_PATH=str(cache), FVM_USE_GIT_CACHE='false', FVM_FLUTTER_URL='https://github.com/flutter/flutter.git')
        result = subprocess.run([fvm, 'use', version, '--skip-setup', '--skip-pub-get'],
                                cwd=self.project, env=env, input='', text=True,
                                capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.project / '.fvm/flutter_sdk').resolve(), sdk)
        self.assertEqual(json.loads((self.project / '.fvmrc').read_text())['flutter'], version)
        self.assertFalse((self.base / 'home/.zprofile').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
