#!/usr/bin/env python3
"""Actual legacy entry functions + real SDK adapters; only networking/SDK/host tools are fixtures."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

MACOS = Path(__file__).resolve().parents[2]
PACKAGES = {
    'android': ('打包相关', '【MacOS】📦双击打包Flutter.Android.command'),
    'repair': ('小工具', '【MacOS】♻️双击修复：找不到 Android SDK 或 platforms 目录为空.command'),
    'device': ('运行', '【MacOS】🎈双击真机运行项目.command'),
    'ios': ('运行', '【MacOS】☀️双击运行Flutter项目（iOS 模拟器）.command'),
    'deps': ('更新升级', '【MacOS】⬆️双击更新Flutter依赖.command'),
}
CORE = '【MacOS】FlutterSDK网络选路.zsh'


class SdkEntryFrontendTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-extra-cli-sdk-中文-')
        self.root = Path(self.temp.name)
        self.project = self.root / '工程 空格'
        self.project.mkdir()
        (self.project / 'pubspec.yaml').write_text('name: fixture\n')
        self.sdk = self.root / 'versions/3.38.4'
        (self.sdk / 'bin/internal').mkdir(parents=True)
        (self.sdk / 'bin/cache/dart-sdk/bin').mkdir(parents=True)
        (self.sdk / 'bin/internal/engine.version').write_text('a' * 40)
        (self.sdk / 'bin/cache/engine-dart-sdk.stamp').write_text('a' * 40)
        dart = self.sdk / 'bin/cache/dart-sdk/bin/dart'
        dart.write_text('#!/bin/zsh\nexit 99\n')
        dart.chmod(0o700)
        self.calls = self.root / 'calls.jsonl'
        self.route = self.root / 'route.calls'
        self.pods = self.root / 'pod.calls'
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(self.sdk)
        (self.project / '.fvmrc').write_text('{"flutter":"3.38.4"}')
        flutter = self.sdk / 'bin/flutter'
        flutter.write_text('#!' + sys.executable + '\n' + '''import json,os,pathlib,sys
args=sys.argv[1:]
with open(os.environ['FAKE_CALLS'],'a') as f:f.write(json.dumps({'args':args,'java':os.environ.get('JAVA_HOME'),'source':os.environ.get('FLUTTER_STORAGE_BASE_URL')})+'\\n')
state=pathlib.Path(os.environ['FAKE_STATE']);action=args[0] if args else 'none'
counter=state/('count-'+action);count=int(counter.read_text())+1 if counter.exists() else 1;counter.write_text(str(count))
if action=='--version':
 if count==1 and os.environ.get('FAKE_FIRST_BOOT_FAIL')=='1':print('Error downloading: fixture',file=sys.stderr);sys.exit(9)
 print('{"flutter":"fixture"}');sys.exit(0)
if action=='precache':print('fixture SDK prepared');sys.exit(0)
if action=='devices':print(json.dumps([{'id':'desktop','targetPlatform':'darwin','emulator':False},{'id':'手机 空格','targetPlatform':'android-arm64','emulator':False}]));sys.exit(0)
print(json.dumps({'args':args},ensure_ascii=False))
if action=='run' and os.environ.get('FAKE_RUN_RECOVERS')=='1':sys.exit(7 if count==1 else 0)
sys.exit(int(os.environ.get('FAKE_BUSINESS_EXIT','7')))
''')
        flutter.chmod(0o700)
        fake_bin = self.root / 'bin'
        fake_bin.mkdir()
        (fake_bin / 'flutter').symlink_to(flutter)
        fvm = fake_bin / 'fvm'
        fvm.write_text('#!' + sys.executable + '\n' + '''import json,os,subprocess,sys
args=sys.argv[1:]
if args[:2]==['api','context']:print(json.dumps({'context':{'versionsCachePath':os.environ['FAKE_VERSIONS'],'flutterUrl':'https://private.example.invalid/flutter.git'}}));sys.exit(0)
if args[:1]==['--version']:print('FVM fixture');sys.exit(0)
if args[:1]==['flutter']:sys.exit(subprocess.run([os.environ['FAKE_FLUTTER'],*args[1:]]).returncode)
sys.exit(99)
''')
        fvm.chmod(0o700)
        forbidden = fake_bin / 'forbidden-network'
        forbidden.write_text('#!/bin/zsh\nprint unexpected-network >> "$FAKE_ROUTES"\nexit 99\n')
        forbidden.chmod(0o700)
        self.env = dict(os.environ)
        for key in ('FLUTTER_STORAGE_BASE_URL', 'PUB_HOSTED_URL', 'JOBS_FLUTTER_ROUTE_CACHE_DIR', 'JOBS_FLUTTER_ROUTE_LOG', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy'):
            self.env.pop(key, None)
        self.env.update(PATH=str(fake_bin) + ':' + self.env.get('PATH', ''), FAKE_CALLS=str(self.calls), FAKE_ROUTES=str(self.route),
                        FAKE_STATE=str(self.root), FAKE_FLUTTER=str(flutter), FAKE_VERSIONS=str(self.sdk.parent),
                        JOBS_FLUTTER_ROUTE_CURL=str(forbidden), JOBS_FLUTTER_ROUTE_GIT=str(forbidden), TMPDIR=str(self.root) + '/', NO_COLOR='1')

    def tearDown(self):
        self.temp.cleanup()

    def stage(self, key, functions):
        directory, name = PACKAGES[key]
        source = MACOS / directory / name
        stage = self.root / '移动包 空格' / name
        shutil.copytree(source, stage)
        entry = stage / name
        text = entry.read_text()
        core = stage / 'Scripts' / CORE / CORE
        # Real wrapper retry, once, FVM gate and adapter dispatch remain. Only physical networking is isolated.
        core.write_text(core.read_text().replace('if [[ \"$ZSH_EVAL_CONTEXT\" == toplevel ]]; then jfs_route_main \"$@\"; fi', '') + '''\njobs_flutter_route_prepare() {
 print -r -- "$4|$1" >> "$FAKE_ROUTES"
 [[ "${FAKE_CANCEL:-0}" != 1 ]] || return 130
 return 0
}
if [[ \"$ZSH_EVAL_CONTEXT\" == toplevel ]]; then jfs_route_main \"$@\"; fi
''')
        block = re.search(r'# JOBS_FLUTTER_NETWORK_ADAPTER_BEGIN\n.*?# JOBS_FLUTTER_NETWORK_ADAPTER_END', text, re.S).group()
        definitions = []
        for name in functions:
            match = re.search(r'^  ' + re.escape(name) + r'\(\) \{\n.*?^  \}', text, re.M | re.S)
            self.assertIsNotNone(match, name)
            definitions.append(match.group())
        preamble = block + '\n' + '\n'.join(definitions) + '\n'
        preamble += f'JOBS_FLUTTER_NETWORK_ENTRY_FILE={shlex.quote(str(entry))}\n'
        preamble += f'JOBS_FLUTTER_NETWORK_ENTRY_BASE={shlex.quote(str(stage))}\n'
        preamble += f'flutter_cmd=({shlex.quote(str(self.sdk / "bin/flutter"))})\n'
        preamble += f'JAVA_HOME={shlex.quote(str(self.root / "Java 空格"))}\n'
        preamble += f'DEFAULT_SDK={shlex.quote(str(self.root / "Android SDK"))}\n'
        preamble += f'LOG_FILE={shlex.quote(str(self.root / "entry.log"))}\n'
        preamble += 'info_echo(){ :; };success_echo(){ :; };warn_echo(){ :; };highlight_echo(){ :; };error_echo(){ :; };color_echo(){ :; }\n'
        return preamble

    def run_code(self, code, extra=None, data=''):
        process = subprocess.Popen(['/bin/zsh', '-f', '-c', code], env=dict(self.env, **(extra or {})), cwd=self.project,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            output, error = process.communicate(data, timeout=12)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, error = process.communicate()
            self.fail('Bounded fixture timed out: ' + error[-1600:])
        result = subprocess.CompletedProcess([], process.returncode, output, error)
        self.assertNotIn('unexpected-network', self.route.read_text() if self.route.exists() else '')
        return result

    def entries(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_all_five_array_invocations_are_wrapped_and_resource_syntax_is_valid(self):
        for key, (directory, name) in PACKAGES.items():
            with self.subTest(key=key):
                source = MACOS / directory / name
                entry = source / name
                text = entry.read_text()
                self.assertTrue(text.splitlines()[1].startswith('# 脚本自述'))
                for line in text.splitlines():
                    if '"${flutter_cmd[@]}"' not in line:
                        continue
                    self.assertRegex(line, r'jobs_flutter_sdk_(command|bootstrap|platform|run_release_device)', line)
                self.assertIn("--fvm-runtime", (source / 'Scripts/【MacOS】FlutterSDK命令适配.sh/【MacOS】FlutterSDK命令适配.sh').read_text())
                for path in [entry, source / 'Scripts' / CORE / CORE]:
                    result = subprocess.run(['/bin/zsh', '-n', str(path)], capture_output=True, text=True)
                    self.assertEqual(0, result.returncode, result.stderr)

    def test_android_build_prepares_sdk_then_preserves_java_and_one_native_build(self):
        code = self.stage('android', ['run_flutter_with_java']) + 'run_flutter_with_java build apk --debug\n'
        result = self.run_code(code)
        self.assertEqual(7, result.returncode, result.stderr)
        calls = self.entries()
        self.assertEqual('--version', calls[0]['args'][0])
        self.assertIn(['precache', '--android'], [v['args'] for v in calls])
        builds = [v for v in calls if v['args'][0] == 'build']
        self.assertEqual([['build', 'apk', '--debug']], [v['args'] for v in builds])
        self.assertEqual(str(self.root / 'Java 空格'), builds[0]['java'])

    def test_android_sdk_configuration_is_not_replayed_on_business_failure(self):
        result = self.run_code(self.stage('repair', ['configure_flutter_sdk']) + 'configure_flutter_sdk\n')
        self.assertEqual(7, result.returncode, result.stderr)
        self.assertEqual('--version', self.entries()[0]['args'][0])
        self.assertEqual([['config', '--android-sdk', str(self.root / 'Android SDK')]], [v['args'] for v in self.entries() if v['args'][0] == 'config'])

    def test_real_device_json_prepares_android_and_runs_original_release_once(self):
        result = self.run_code(self.stage('device', ['run_flutter_on_device']) + 'run_flutter_on_device\n')
        self.assertEqual(7, result.returncode, result.stderr)
        calls = [v['args'] for v in self.entries()]
        self.assertIn(['precache', '--android'], calls)
        self.assertEqual([['run', '--release']], [v for v in calls if v[0] == 'run'])

    def test_ios_keeps_original_pod_recovery_after_sdk_preparation(self):
        code = self.stage('ios', ['run_flutter_app']) + f'''ios_device_id='模拟器 UUID'
ios_device_name=fixture
entry_file='lib/中文 main.dart'
build_mode=debug
flavor_args=(--flavor demo)
pod() {{ print pod >> {shlex.quote(str(self.pods))}; }}
sleep() {{ :; }}
run_flutter_app
'''
        result = self.run_code(code, {'FAKE_RUN_RECOVERS': '1'})
        self.assertEqual(0, result.returncode, result.stderr)
        calls = [v['args'] for v in self.entries()]
        self.assertIn(['precache', '--ios'], calls)
        runs = [v for v in calls if v[0] == 'run']
        self.assertEqual(2, len(runs), 'The original pod-specific recovery is retained, without SDK-induced extra retries')
        self.assertEqual(runs[0], runs[1])
        self.assertEqual(['pod'], self.pods.read_text().splitlines())

    def test_ios_sdk_cancel_never_runs_business_or_pod_recovery(self):
        code = self.stage('ios', ['run_flutter_app']) + f'''ios_device_id=fixture
ios_device_name=fixture
entry_file=lib/main.dart
build_mode=debug
flavor_args=()
pod() {{ print pod >> {shlex.quote(str(self.pods))}; }}
run_flutter_app
'''
        result = self.run_code(code, {'FAKE_CANCEL': '1'})
        self.assertEqual(130, result.returncode, result.stderr)
        self.assertEqual([], self.entries())
        self.assertFalse(self.pods.exists())

    def test_dependency_update_bootstrap_retries_but_pub_get_is_once(self):
        result = self.run_code(self.stage('deps', ['maybe_run_pub_get']) + 'maybe_run_pub_get\n', {'FAKE_FIRST_BOOT_FAIL': '1', 'FAKE_BUSINESS_EXIT': '0'}, data='\n')
        self.assertEqual(0, result.returncode, result.stderr)
        calls = [v['args'] for v in self.entries()]
        self.assertEqual([['--version'], ['--version'], ['pub', 'get']], calls)

    def test_initial_executor_gates_cancel_before_later_workflow_stages(self):
        for key, function, root_name in [('repair', 'init_flutter_command', 'flutter_root'), ('deps', 'detect_flutter_command', 'project_dir')]:
            with self.subTest(key=key):
                code = self.stage(key, [function]) + f'{root_name}={shlex.quote(str(self.project))}\n{function} || exit $?\nprint FOLLOWING_BUSINESS\n'
                result = self.run_code(code, {'FAKE_CANCEL': '1'})
                self.assertEqual(130, result.returncode, result.stderr)
                self.assertNotIn('FOLLOWING_BUSINESS', result.stdout)
                self.assertEqual([], self.entries())

    def test_fvm_array_keeps_original_manager_and_business_argv(self):
        code = self.stage('repair', ['configure_flutter_sdk']) + 'flutter_cmd=(fvm flutter)\nconfigure_flutter_sdk\n'
        result = self.run_code(code)
        self.assertEqual(7, result.returncode, result.stderr)
        calls = [v['args'] for v in self.entries()]
        self.assertEqual('--version', calls[0][0])
        self.assertEqual([['config', '--android-sdk', str(self.root / 'Android SDK')]], [v for v in calls if v[0] == 'config'])


if __name__ == '__main__':
    unittest.main()
