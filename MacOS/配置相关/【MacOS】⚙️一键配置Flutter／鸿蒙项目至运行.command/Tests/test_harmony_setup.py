"""Offline regression using temporary projects and fake tool executables only."""
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
ENTRY = next(ROOT.glob('*.command'))
spec = importlib.util.spec_from_file_location('harmony_config', ROOT / 'Scripts/project_config.py')
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class HarmonySetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-harmony-tests-')
        self.base = Path(self.temp.name).resolve()
        self.project = self.base / "工程 空格 ' $(touch INJECTED) `touch BACKTICK`"
        (self.project / 'lib').mkdir(parents=True)
        (self.project / 'pubspec.yaml').write_text('name: example\n')
        (self.base / 'home').mkdir()
        self.env = dict(os.environ, TEST_PROJECT=str(self.project), TEST_BASE=str(self.base),
                        TEST_PYTHON=sys.executable, HOME=str(self.base / 'home'),
                        TMPDIR=str(self.base), PYTHONDONTWRITEBYTECODE='1', NO_COLOR='1')
        for key in ('HARMONY_EMULATOR_BIN', 'DEVECO_STUDIO_HOME', 'TOOL_HOME', 'JAVA_HOME',
                    'JOBS_HOMEBREW_BIN', 'JOBS_PYTHON_BIN', 'FVM_CACHE_PATH', 'FVM_FLUTTER_URL'):
            self.env.pop(key, None)

    def tearDown(self):
        self.temp.cleanup()

    def definitions(self):
        """Load definitions without running the entrypoint's initialize or main."""
        source, count = re.subn(r'\nmain "\$@"\s*\Z', '\n', ENTRY.read_text())
        self.assertEqual(count, 1, 'The entrypoint must have one final main invocation')
        return (source + '\nSCRIPT_DIR=' + shlex.quote(str(ROOT)) + '\n'
                'source "$SCRIPT_DIR/Scripts/harmony_workflow.zsh"\n'
                'JOBS_PYTHON_BIN="$TEST_PYTHON"\n'
                'setopt NO_NOMATCH PIPE_FAIL EXTENDED_GLOB\n')

    def assert_no_injection(self):
        for root in (self.base, self.project, self.base / 'home'):
            self.assertFalse((root / 'INJECTED').exists())
            self.assertFalse((root / 'BACKTICK').exists())

    def zsh(self, code, data='', expected=0):
        result = subprocess.run(['/bin/zsh', '-c', self.definitions() + code], input=data,
                                text=True, capture_output=True, cwd=self.base,
                                env=self.env, timeout=20)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assert_no_injection()
        return result

    def entry(self, *args):
        return subprocess.run(['/bin/zsh', str(ENTRY), *map(str, args)], input='', text=True,
                              capture_output=True, cwd=self.base, env=self.env, timeout=20)

    def snapshot(self):
        """Inspect every fixture file so read-only modes cannot silently write caches."""
        result = {}
        for path in self.base.rglob('*'):
            key = str(path.relative_to(self.base))
            if path.is_symlink():
                result[key] = ('link', os.readlink(path))
            elif path.is_file():
                result[key] = ('file', path.read_bytes(), path.stat().st_mode & 0o777)
            else:
                result[key] = ('directory',)
        return result

    def fake_executable(self, path, body='exit 0\n'):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/zsh\n' + body)
        path.chmod(0o700)
        return path

    def test_noninteractive_entry_cannot_install(self):
        before = self.snapshot()
        result = self.entry()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('交互终端', result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_help_is_noninteractive_and_does_not_write(self):
        before = self.snapshot()
        result = self.entry('--help')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('--check', result.stdout)
        self.assertIn('鸿蒙', result.stdout)
        self.assertNotIn('\x1b', result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_missing_readonly_environment_fails_without_writes(self):
        self.env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin'
        self.env['HARMONY_EMULATOR_BIN'] = str(self.base / 'missing/Emulator')
        before = self.snapshot()
        result = self.entry('--check', self.project)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_valid_readonly_environment_never_executes_tools_or_writes(self):
        bin_dir = self.base / 'bin'
        marker = 'touch "$TEST_BASE/SHOULD_NOT_EXECUTE"\nexit 73\n'
        for name in ('brew', 'fvm'):
            self.fake_executable(bin_dir / name, marker)
        emulator = self.fake_executable(self.base / 'clt/emulator/Emulator', marker)
        sdk = self.base / 'readonly-sdk'
        self.fake_executable(sdk / 'bin/flutter', marker)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(sdk)
        (self.project / 'ohos').mkdir()
        for filename in ('build-profile.json5', 'oh-package.json5'):
            (self.project / 'ohos' / filename).write_text('{}\n')
        self.env.update(PATH=str(bin_dir) + ':/usr/bin:/bin:/usr/sbin:/sbin',
                        HARMONY_EMULATOR_BIN=str(emulator))
        before = self.snapshot()
        result = self.entry('--check', self.project)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('未执行健康检查', result.stdout)
        self.assertIn('离线盘点', result.stdout)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.base / 'SHOULD_NOT_EXECUTE').exists())

    def test_sdk_selection_is_project_only_harmony(self):
        result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_choose_sdk || exit $?
print -r -- "SDK=$JOBS_SDK_FAMILY MODE=$JOBS_INSTALL_MODE REF=$JOBS_SDK_REF"
(( ! ${+functions[jobs_choose_install_mode]} && ! ${+functions[jobs_enable_global]} ))
''', '\n')
        self.assertIn('SDK=harmony MODE=fvm REF=3.35.7+ohos-1.0.5', result.stdout)
        self.assertFalse((self.project / '.fvmrc').exists())
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_existing_official_binding_requires_exact_yes(self):
        original = '{"flutter":"3.24.5","flavors":{"prod":"3.24.5"}}\n'
        path = self.project / '.fvmrc'
        for answer in ('', 'yes', 'Yes', 'YES ', ' YES', 'Y', 'anything', 'YES'):
            with self.subTest(answer=answer):
                path.write_text(original)
                before = self.snapshot()
                expected = 0 if answer == 'YES' else 130
                result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_choose_sdk || exit $?
print -r -- "$JOBS_SDK_FAMILY/$JOBS_INSTALL_MODE"
''', answer + '\n\n', expected=expected)
                self.assertEqual(self.snapshot(), before)
                if answer == 'YES':
                    self.assertIn('harmony/fvm', result.stdout)

    def test_legacy_binding_requires_explicit_switch(self):
        (self.project / '.fvm').mkdir()
        path = self.project / '.fvm/fvm_config.json'
        original = '{"flutterSdkVersion":"3.24.5"}'
        path.write_text(original)
        self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', '\n', expected=130)
        self.assertEqual(path.read_text(), original)

    def test_known_harmony_ref_is_preserved(self):
        original = json.dumps({'flutter': '3.35.7+ohos-1.0.5',
                               'flutterUrl': 'https://gitcode.com/CPF-Flutter/flutter_flutter.git'})
        path = self.project / '.fvmrc'
        path.write_text(original)
        result = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk || exit $?\nprint -r -- "$JOBS_SDK_REF"', '\n')
        self.assertIn('3.35.7+ohos-1.0.5', result.stdout)
        self.assertEqual(path.read_text(), original)

    def test_unknown_fork_cannot_switch_implicitly(self):
        for version, repo in (('myfork/stable', ''),
                              ('3.24.5', 'https://example.com/team/flutter.git'),
                              ('custom_jobs_ohos_' + 'a' * 40, 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')):
            with self.subTest(version=version):
                path = self.project / '.fvmrc'
                original = json.dumps({'flutter': version, 'flutterUrl': repo})
                path.write_text(original)
                self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', '\n\n', expected=130)
                self.assertEqual(path.read_text(), original)

    def test_sdk_ref_rejects_options_and_shell_code(self):
        result = self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk || exit $?\nprint -r -- "REF=$JOBS_SDK_REF"',
                          '-bad\n$(touch INJECTED)\na..b\nrelease_1+ohos-2\n')
        self.assertIn('REF=release_1+ohos-2', result.stdout)

    def test_empty_paths_retry_and_quoted_finder_path_is_safe(self):
        result = self.zsh('jobs_choose_project || exit $?\nprint -r -- "ROOT=$PROJECT_ROOT"',
                          '\n\n/no/such/path\n' + shlex.quote(str(self.project)) + '\n')
        self.assertIn('ROOT=' + str(self.project), result.stdout)
        self.assertEqual(result.stderr.count('拖入或输入'), 4)

    def test_finder_escaped_path_is_safe(self):
        path = str(self.project)
        for char in ('\\', ' ', "'", '$', '`', '(', ')'):
            path = path.replace(char, '\\' + char)
        result = self.zsh('jobs_choose_project || exit $?\nprint -r -- "$PROJECT_ROOT"', path + '\n')
        self.assertIn(str(self.project), result.stdout)

    def test_argument_path_is_validated(self):
        result = self.zsh('jobs_choose_project "$TEST_PROJECT" || exit $?\nprint -r -- "$PROJECT_ROOT"')
        self.assertIn(str(self.project), result.stdout)

    def test_eof_cancels_path_and_sdk_prompts(self):
        self.zsh('jobs_choose_project', '\n\n', expected=130)
        self.zsh('PROJECT_ROOT="$TEST_PROJECT"\njobs_choose_sdk', expected=130)

    def test_symlinked_configuration_is_rejected(self):
        for component in ('.fvm', '.jobs-flutter', '.vscode', '.gitignore', '.fvmrc'):
            with self.subTest(component=component):
                path = self.project / component
                path.symlink_to(self.base, target_is_directory=True)
                self.zsh('jobs_choose_project "$TEST_PROJECT"', expected=1)
                path.unlink()

    def test_corrupt_fvmrc_is_not_overwritten(self):
        path = self.project / '.fvmrc'
        path.write_text('{broken')
        with self.assertRaises(ValueError):
            config.configure_fvm(self.project, '/cache', 'https://repo.git')
        self.assertEqual(path.read_text(), '{broken')

    def test_fvm_configuration_preserves_version_and_flavors(self):
        path = self.project / '.fvmrc'
        path.write_text(json.dumps({'flutter': '3.24.5', 'flavors': {'prod': '3.24.5'}}))
        config.configure_fvm(self.project, '/cache/harmony', 'https://repo.git')
        data = json.loads(path.read_text())
        self.assertEqual(data['flutter'], '3.24.5')
        self.assertEqual(data['flavors'], {'prod': '3.24.5'})
        self.assertFalse(data['updateVscodeSettings'])
        self.assertFalse(data['runPubGetOnSdkChanges'])
        self.assertTrue(list(self.project.glob('.fvmrc.bak.*')))

    def test_vscode_preserves_user_settings_and_debug_configuration(self):
        (self.project / '.vscode').mkdir()
        settings = self.project / '.vscode/settings.json'
        settings.write_text(json.dumps({'editor.fontSize': 19, 'dart.sdkPath': '/old',
                                        'dart.env': {'CUSTOM': 'yes'}}))
        launch = self.project / '.vscode/launch.json'
        launch.write_text(json.dumps({'version': '0.2.0', 'configurations': [
            {'name': 'User debug', 'args': ['hello']}]}))
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        data = json.loads(settings.read_text())
        self.assertEqual(data['editor.fontSize'], 19)
        self.assertNotIn('dart.sdkPath', data)
        self.assertEqual(data['dart.env']['CUSTOM'], 'yes')
        self.assertEqual(json.loads(launch.read_text())['configurations'][0]['name'], 'User debug')
        self.assertEqual(len(json.loads(launch.read_text())['configurations']), 2)

    def test_jsonc_is_preserved_with_merge_suggestions(self):
        (self.project / '.vscode').mkdir()
        for filename in ('settings.json', 'launch.json'):
            (self.project / '.vscode' / filename).write_text('{\n // 用户说明\n "custom": true,\n}\n')
        before = {p.name: p.read_bytes() for p in (self.project / '.vscode').iterdir()}
        config.vscode(self.project, {'HOS_SDK_HOME': '/sdk'}, '.fvm/flutter_sdk', 'harmony')
        for filename, content in before.items():
            self.assertEqual((self.project / '.vscode' / filename).read_bytes(), content)
            self.assertTrue((self.project / '.jobs-flutter' / (filename + '.suggested.json')).exists())

    def test_runtime_environment_and_launcher_quote_untrusted_paths(self):
        sdk = self.base / "SDK ' $(touch INJECTED) `touch BACKTICK`"
        self.fake_executable(sdk / 'bin/flutter', 'print -rl -- "$PWD" "$@" "$TOOL_HOME" "$JAVA_HOME"\n')
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(sdk)
        tool = self.base / "工具 ' $(touch INJECTED) `touch BACKTICK`"
        java = self.base / "Java ' $(touch INJECTED) `touch BACKTICK`"
        (tool / 'tools/node/bin').mkdir(parents=True)
        config.project_runtime(self.project, 'harmony', 'release', 'custom_jobs_ohos_test',
                               'a' * 40, str(sdk), str(tool), str(java))
        result = subprocess.run([str(self.project / '.jobs-flutter/flutter'), 'run', '-d',
                                 'device with space'], cwd=self.base, text=True,
                                capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for value in (str(self.project), str(tool), str(java), 'device with space'):
            self.assertIn(value, result.stdout)
        self.assert_no_injection()
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_launcher_follows_current_fvm_link_and_refuses_missing_binding(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        first, second = self.base / 'FIRST', self.base / 'SECOND'
        for sdk in (first, second):
            self.fake_executable(sdk / 'bin/flutter', 'print -r -- ' + sdk.name + '\n')
        link.symlink_to(first)
        config.project_runtime(self.project, 'harmony', 'release', 'custom_test', 'a' * 40,
                               str(first), str(self.base / 'tool'), str(self.base / 'java'))
        launcher = self.project / '.jobs-flutter/flutter'
        link.unlink()
        link.symlink_to(second)
        result = subprocess.run([str(launcher), '--version'], text=True, capture_output=True,
                                env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'SECOND')
        link.unlink()
        result = subprocess.run([str(launcher), '--version'], text=True, capture_output=True,
                                env=self.env, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('FIRST', result.stdout)

    def test_harmony_tag_is_peeled_and_missing_or_ambiguous_ref_fails(self):
        result = self.zsh('''JOBS_SDK_REPO=https://test.git
JOBS_SDK_REF=release
jobs_git() { print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release'; print -r -- 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/release^{}'; }
jobs_resolve_harmony_commit || exit $?
print -r -- "$JOBS_FVM_VERSION"
''')
        self.assertIn('custom_jobs_ohos_' + 'b' * 40, result.stdout)
        self.zsh('JOBS_SDK_REPO=https://test.git\nJOBS_SDK_REF=nope\njobs_git() { return 0; }\njobs_resolve_harmony_commit', expected=1)
        self.zsh('''JOBS_SDK_REPO=https://test.git
JOBS_SDK_REF=release
jobs_git() { print -r -- 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/tags/release'; print -r -- 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/heads/release'; }
jobs_resolve_harmony_commit
''', expected=1)

    def test_binding_failure_restores_original_files_and_sdk_link(self):
        original = '{"flutter":"3.24.5"}\n'
        (self.project / '.fvmrc').write_text(original)
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to('/old/sdk')
        (self.project / '.fvm/version').write_text('OLD_VERSION')
        (self.project / '.fvm/fvm_config.json').write_text('{"old":true}')
        self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  print NEW_VERSION > "$PROJECT_ROOT/.fvm/version"
  print NEW_RELEASE > "$PROJECT_ROOT/.fvm/release"
  print '{"new":true}' > "$PROJECT_ROOT/.fvm/fvm_config.json"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  return 7
}
jobs_setup_sdk
''', expected=7)
        self.assertEqual((self.project / '.fvmrc').read_text(), original)
        self.assertEqual((self.project / '.fvm/version').read_text(), 'OLD_VERSION')
        self.assertEqual((self.project / '.fvm/fvm_config.json').read_text(), '{"old":true}')
        self.assertFalse((self.project / '.fvm/release').exists())
        self.assertEqual(os.readlink(self.project / '.fvm/flutter_sdk'), '/old/sdk')

    def test_signal_restores_binding_and_stops_downstream(self):
        (self.project / '.fvm').mkdir()
        link = self.project / '.fvm/flutter_sdk'
        for name in ('TERM', 'INT', 'HUP'):
            with self.subTest(signal=name):
                (self.project / '.fvmrc').write_text('ORIGINAL')
                if link.is_symlink():
                    link.unlink()
                link.symlink_to('/old/sdk')
                self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  rm "$PROJECT_ROOT/.fvm/flutter_sdk"
  ln -s /new/sdk "$PROJECT_ROOT/.fvm/flutter_sdk"
  kill -''' + name + ''' $$
}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
''', expected=130)
                self.assertEqual((self.project / '.fvmrc').read_text(), 'ORIGINAL')
                self.assertEqual(os.readlink(link), '/old/sdk')
                self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())

    def test_ctrl_c_during_child_command_restores_binding(self):
        (self.project / '.fvmrc').write_text('BEFORE_INTERRUPT')
        ready = self.base / 'READY'
        child = self.base / 'interrupt-child.py'
        child.write_text('''import os, signal, sys, time
from pathlib import Path
signal.signal(signal.SIGINT, lambda *_: sys.exit(130))
Path(os.environ['TEST_BASE'], 'READY').touch()
time.sleep(30)
''')
        source = self.definitions() + '''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() {
  print changed > "$PROJECT_ROOT/.fvmrc"
  "$TEST_PYTHON" "$TEST_BASE/interrupt-child.py"
}
jobs_setup_sdk || exit $?
touch "$TEST_BASE/SHOULD_NOT_RUN"
'''
        process = subprocess.Popen(['/bin/zsh', '-c', source], env=self.env, cwd=self.base,
                                   text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(ready.exists(), 'SDK setup did not reach the child command')
            os.killpg(process.pid, signal.SIGINT)
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 130, stdout + stderr)
            self.assertEqual((self.project / '.fvmrc').read_text(), 'BEFORE_INTERRUPT')
            self.assertFalse((self.base / 'SHOULD_NOT_RUN').exists())
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()

    def test_failed_restore_keeps_recovery_snapshot(self):
        (self.project / '.fvmrc').write_text('RECOVER_ME')
        result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
jobs_setup_sdk_impl() { print changed > "$PROJECT_ROOT/.fvmrc"; return 7; }
jobs_restore_binding() { return 1; }
jobs_setup_sdk
''', expected=7)
        snapshots = list(self.base.glob('JobsFlutterBinding.*'))
        self.assertEqual(len(snapshots), 1, result.stdout + result.stderr)
        self.assertEqual((snapshots[0] / '.fvmrc').read_text(), 'RECOVER_ME')
        self.assertIn(str(snapshots[0]), result.stdout + result.stderr)

    def fake_fvm(self):
        path = self.base / 'fvm'
        path.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['TEST_BASE'] + '/calls.jsonl', 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
if args[0] != 'use':
    raise SystemExit('Unexpected fake FVM command')
if os.environ.get('FAIL_INSTALL'):
    raise SystemExit(9)
root = Path.cwd()
cache = Path(os.environ['FVM_CACHE_PATH'])
(root / '.fvm').mkdir(exist_ok=True)
link = root / '.fvm/flutter_sdk'
if link.is_symlink():
    link.unlink()
link.symlink_to(cache / 'versions' / args[1])
cfg = json.loads((root / '.fvmrc').read_text())
cfg['flutter'] = args[1]
(root / '.fvmrc').write_text(json.dumps(cfg))
''')
        path.chmod(0o700)
        return path

    def setup_fake_harmony_sdk(self):
        fake = self.fake_fvm()
        return '''PROJECT_ROOT="$TEST_PROJECT"
JOBS_FVM_BIN=''' + shlex.quote(str(fake)) + '''
JOBS_SDK_FAMILY=harmony
JOBS_INSTALL_MODE=fvm
JOBS_SDK_REPO="$JOBS_HARMONY_REPO"
JOBS_SDK_REF=release
jobs_git() {
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
}
'''

    def test_custom_harmony_fvm_binding_never_calls_global(self):
        self.zsh(self.setup_fake_harmony_sdk() + 'jobs_setup_sdk', '\n')
        data = json.loads((self.project / '.fvmrc').read_text())
        self.assertEqual(data['flutter'], 'custom_jobs_ohos_' + 'a' * 40)
        self.assertEqual(data['flutterUrl'], 'https://gitcode.com/CPF-Flutter/flutter_flutter.git')
        self.assertTrue((self.project / '.fvm/flutter_sdk/bin/flutter').exists())
        calls = [json.loads(line) for line in (self.base / 'calls.jsonl').read_text().splitlines()]
        self.assertEqual([args[0] for args in calls], ['use'])
        self.assertIn('--skip-setup', calls[0])
        self.assertIn('--skip-pub-get', calls[0])
        self.assertFalse((self.base / 'home/.zprofile').exists())

    def test_failed_fvm_binding_restores_original_version(self):
        original = '{"flutter":"3.19.0"}'
        (self.project / '.fvmrc').write_text(original)
        self.env['FAIL_INSTALL'] = '1'
        self.zsh(self.setup_fake_harmony_sdk() + 'jobs_setup_sdk', '\n', expected=9)
        self.assertEqual((self.project / '.fvmrc').read_text(), original)
        self.assertFalse((self.project / '.fvm/flutter_sdk').is_symlink())
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

    def test_unreadable_git_status_is_not_treated_as_clean(self):
        target = self.base / 'cache/versions/custom_jobs_ohos_test'
        (target / '.git').mkdir(parents=True)
        self.fake_executable(target / 'bin/flutter')
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

    def test_device_filter_uses_target_platform_instead_of_device_id(self):
        devices = [
            {'id': 'ios1', 'name': 'iPhone', 'targetPlatform': 'ios'},
            {'id': '127.0.0.1:5555', 'name': 'Android', 'targetPlatform': 'android-arm64'},
            {'id': 'harmony id with space', 'name': 'Harmony', 'targetPlatform': 'ohos-arm64'},
            {'id': 'legacy', 'name': 'Legacy', 'platform': 'ohos-arm64'},
            {'id': 'bad\nvalue', 'name': 'Unsafe', 'targetPlatform': 'ohos-arm64'},
        ]
        result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'),
                                 'devices', 'harmony'], input=json.dumps(devices), text=True,
                                capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('ios1', result.stdout)
        self.assertNotIn('127.0.0.1:5555', result.stdout)
        self.assertNotIn('Unsafe', result.stdout)
        self.assertIn('harmony id with space\tHarmony\tohos-arm64', result.stdout)
        self.assertIn('legacy\tLegacy\tohos-arm64', result.stdout)

    def test_unsupported_and_control_character_devices_are_not_selectable(self):
        devices = [{'id': 'ready', 'name': 'Ready', 'targetPlatform': 'ohos-arm64'},
                   {'id': 'unsupported', 'name': 'Unsupported', 'targetPlatform': 'ohos-arm64',
                    'isSupported': False}]
        for field in ('id', 'name', 'targetPlatform'):
            for control in ('\t', '\n', '\r', '\x1b', '\x7f'):
                item = {'id': 'unsafe', 'name': 'Unsafe', 'targetPlatform': 'ohos-arm64'}
                item[field] += control + 'unexpected'
                devices.append(item)
        result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'),
                                 'devices', 'harmony'], input=json.dumps(devices), text=True,
                                capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'ready\tReady\tohos-arm64\n')

    def test_invalid_device_list_items_fail_clearly(self):
        for item in (None, 'invalid', 17, []):
            with self.subTest(item=item):
                result = subprocess.run([sys.executable, str(ROOT / 'Scripts/project_config.py'),
                                         'devices', 'harmony'], input=json.dumps([item]),
                                        text=True, capture_output=True, env=self.env, timeout=10)
                self.assertEqual(result.returncode, 1)
                self.assertIn('设备列表项必须是对象', result.stderr)
                self.assertNotIn('Traceback', result.stderr)

    def fake_jdk(self, java_version='17.0.16', javac_version='17.0.16',
                 java_result=0, javac_result=0):
        root = self.base / 'JDK 目录'
        self.fake_executable(root / 'bin/java',
                             'print -u2 -r -- ' + shlex.quote('openjdk version "' + java_version + '" 2025-07-15')
                             + '\nexit ' + str(java_result) + '\n')
        self.fake_executable(root / 'bin/javac',
                             'print -u2 -r -- ' + shlex.quote('javac ' + javac_version)
                             + '\nexit ' + str(javac_result) + '\n')
        self.env['TEST_JDK'] = str(root)
        return root

    def test_java_and_javac_17_are_accepted(self):
        self.fake_jdk()
        self.zsh('jobs_java_17_ok "$TEST_JDK"')

    def test_java_8_11_and_21_or_mismatched_javac_are_rejected(self):
        for java, javac in (('1.8.0_482', '1.8.0_482'), ('11.0.29', '11.0.29'),
                            ('21.0.9', '21.0.9'), ('17.0.16', '21.0.9'),
                            ('21.0.9', '17.0.16')):
            with self.subTest(java=java, javac=javac):
                self.fake_jdk(java, javac)
                self.zsh('jobs_java_17_ok "$TEST_JDK"', expected=1)

    def test_jre_without_javac_is_rejected(self):
        root = self.fake_jdk()
        (root / 'bin/javac').unlink()
        self.zsh('jobs_java_17_ok "$TEST_JDK"', expected=1)

    def test_java_or_javac_command_failure_is_rejected(self):
        for java_result, javac_result in ((3, 0), (0, 5), (3, 5)):
            with self.subTest(java_result=java_result, javac_result=javac_result):
                self.fake_jdk(java_result=java_result, javac_result=javac_result)
                self.zsh('jobs_java_17_ok "$TEST_JDK"', expected=1)

    def test_logged_command_failure_preserves_original_exit_code(self):
        self.zsh('''LOG_FILE="$TEST_BASE/command.log"
jobs_run /bin/zsh -c 'print FAILED_COMMAND_OUTPUT; exit 23'
''', expected=23)
        self.assertIn('FAILED_COMMAND_OUTPUT', (self.base / 'command.log').read_text())

    def test_tee_failure_is_not_reported_as_success(self):
        self.zsh('''LOG_FILE="$TEST_BASE/missing-parent/command.log"
jobs_run /bin/zsh -c 'print COMMAND_OUTPUT'
''', expected=1)

    def test_command_failure_takes_precedence_over_tee_failure(self):
        self.zsh('''LOG_FILE="$TEST_BASE/missing-parent/command.log"
jobs_run /bin/zsh -c 'print COMMAND_OUTPUT; exit 23'
''', expected=23)

    def test_invalid_fvm_value_returns_clear_error(self):
        (self.project / '.fvmrc').write_text('{"flutter":123}')
        result = self.zsh('jobs_config current "$TEST_PROJECT"', expected=1)
        self.assertIn('配置失败', result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def prepare_project_fixture(self):
        """Make native dependency and Flutter calls inspectable without a real SDK."""
        sdk = self.base / 'platform-sdk'
        tool = self.base / 'platform-tools'
        flutter = sdk / 'bin/flutter'
        flutter.parent.mkdir(parents=True, exist_ok=True)
        flutter.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['TEST_BASE'] + '/platform-calls.jsonl', 'a') as stream:
    stream.write(json.dumps(['flutter'] + args) + '\\n')
if args and args[0] == 'create':
    platform = Path(os.environ['TEST_PROJECT']) / 'ohos'
    platform.mkdir()
    (platform / 'build-profile.json5').write_text('{}')
    (platform / 'oh-package.json5').write_text('{}')
if args == ['pub', 'get'] and os.environ.get('FAIL_PUB'):
    raise SystemExit(29)
''')
        flutter.chmod(0o700)
        for name in ('ohpm', 'hvigorw'):
            self.fake_executable(tool / name,
                                 'print -r -- "' + name + ':$*" >> "$TEST_BASE/native-calls"\n')
        self.env.update(TEST_SDK=str(sdk), TEST_TOOL_ROOT=str(tool))
        return '''PROJECT_ROOT="$TEST_PROJECT"
JOBS_SDK_PATH="$TEST_SDK"
JOBS_TOOL_ROOT="$TEST_TOOL_ROOT"
JOBS_JAVA_HOME="$TEST_BASE/java"
JOBS_SDK_REF=release
JOBS_FVM_VERSION=custom_test
JOBS_SDK_COMMIT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
JOBS_OHPM_BIN="$TEST_TOOL_ROOT/ohpm"
JOBS_HVIGOR_BIN="$TEST_TOOL_ROOT/hvigorw"
jobs_config() { [[ "$1" == runtime ]]; }
'''

    def platform_calls(self):
        path = self.base / 'platform-calls.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_missing_platform_requires_exact_yes_before_generation(self):
        source = self.prepare_project_fixture()
        for answer in ('', 'yes', 'Yes', 'YES ', ' YES', 'anything'):
            with self.subTest(answer=answer):
                self.zsh(source + 'jobs_prepare_project || exit $?\nprint "READY=$JOBS_PLATFORM_READY"',
                         answer + '\n')
                self.assertFalse((self.project / 'ohos').exists())
                self.assertTrue(all(call[1:] == ['doctor', '-v'] for call in self.platform_calls()))
                self.assertFalse((self.base / 'native-calls').exists())
        result = self.zsh(source + 'jobs_prepare_project || exit $?\nprint "READY=$JOBS_PLATFORM_READY"', 'YES\n')
        self.assertIn('READY=1', result.stdout)
        self.assertIn(['flutter', 'create', '--platforms=ohos', '.'], self.platform_calls())
        self.assertIn(['flutter', 'pub', 'get'], self.platform_calls())
        self.assertEqual((self.base / 'native-calls').read_text().splitlines(),
                         ['ohpm:install', 'hvigorw:--version'])

    def test_existing_incomplete_platform_is_never_regenerated(self):
        source = self.prepare_project_fixture()
        (self.project / 'ohos').mkdir()
        signature = self.project / 'ohos/build-profile.json5'
        signature.write_text('{"signingConfigs":[{"name":"USER_CERT"}]}')
        before = signature.read_bytes()
        self.zsh(source + 'jobs_prepare_project', expected=1)
        self.assertEqual(signature.read_bytes(), before)
        self.assertEqual(self.platform_calls(), [['flutter', 'doctor', '-v']])
        self.assertFalse((self.base / 'native-calls').exists())

    def test_pub_failure_stops_native_dependency_installation(self):
        source = self.prepare_project_fixture()
        (self.project / 'ohos').mkdir()
        for name in ('build-profile.json5', 'oh-package.json5'):
            (self.project / 'ohos' / name).write_text('{}')
        self.env['FAIL_PUB'] = '1'
        self.zsh(source + 'jobs_prepare_project', expected=29)
        self.assertEqual(self.platform_calls(), [['flutter', 'doctor', '-v'],
                                                 ['flutter', 'pub', 'get']])
        self.assertFalse((self.base / 'native-calls').exists())

    def test_empty_device_list_can_reload_and_select_harmony_only(self):
        sdk = self.base / 'devices-sdk'
        flutter = sdk / 'bin/flutter'
        flutter.parent.mkdir(parents=True)
        flutter.write_text('#!' + sys.executable + '\n' + '''import json, os
from pathlib import Path
counter = Path(os.environ['TEST_BASE']) / 'device-query-count'
count = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(count))
print(json.dumps([] if count == 1 else [
    {'id':'ios1', 'name':'iPhone', 'targetPlatform':'ios'},
    {'id':'harmony device', 'name':'Harmony', 'targetPlatform':'ohos-arm64'}]))
''')
        flutter.chmod(0o700)
        self.fake_executable(self.project / '.jobs-flutter/flutter',
                             'print -rl -- "$@" > "$TEST_BASE/run-args"\n')
        result = self.zsh('''PROJECT_ROOT="$TEST_PROJECT"
JOBS_SDK_PATH=''' + shlex.quote(str(sdk)) + '''
JOBS_PLATFORM_READY=1
jobs_select_and_run
''', '\n\n\n')
        self.assertIn('暂无鸿蒙设备', result.stdout)
        self.assertNotIn('ios1', result.stdout)
        self.assertEqual((self.base / 'device-query-count').read_text(), '2')
        self.assertEqual((self.base / 'run-args').read_text().splitlines(),
                         ['run', '-d', 'harmony device'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
