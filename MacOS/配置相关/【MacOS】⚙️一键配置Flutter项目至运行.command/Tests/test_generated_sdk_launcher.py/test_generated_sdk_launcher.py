#!/usr/bin/env python3
"""Generated launcher fixtures: no external network, SDK, device, build or registration work."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

PACKAGE = Path(__file__).resolve().parents[2]
NETWORK = '【MacOS】FlutterSDK网络选路.zsh'


class GeneratedSdkLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-generated-sdk-中文-')
        self.root = Path(self.temp.name)
        self.project = self.root / '项目 空格'
        self.sdk = self.root / 'SDK 空格'
        self.project.mkdir()
        (self.project / '.fvm').mkdir()
        (self.project / '.fvm/flutter_sdk').symlink_to(self.sdk)
        (self.sdk / 'bin').mkdir(parents=True)
        self.calls = self.root / 'calls.jsonl'
        self.route_calls = self.root / 'routes'
        self.env = dict(os.environ)
        for name in ('FLUTTER_STORAGE_BASE_URL', 'PUB_HOSTED_URL', 'PUB_CACHE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy', 'JOBS_FLUTTER_ROUTE_CACHE_DIR'):
            self.env.pop(name, None)
        self.env.update(TMPDIR=str(self.root) + '/', FAKE_CALLS=str(self.calls), FAKE_ROUTES=str(self.route_calls), FAKE_STATE=str(self.root), NO_COLOR='1')
        sdk_code = '''import json,os,pathlib,sys
args=sys.argv[1:]
with open(os.environ['FAKE_CALLS'],'a') as f: f.write(json.dumps({'args':args,'source':os.environ.get('FLUTTER_STORAGE_BASE_URL'),'sourceSet':'FLUTTER_STORAGE_BASE_URL' in os.environ})+'\\n')
state=pathlib.Path(os.environ['FAKE_STATE'])
if args and args[0]=='devices': print(json.dumps([{'id':'iOS UUID','targetPlatform':'ios'}])); sys.exit(0)
if args[:2]==['precache','--help']: print('--ohos --android --ios'); sys.exit(0)
action=args[0] if args else 'none'
countfile=state/('count-'+action)
count=int(countfile.read_text())+1 if countfile.exists() else 1
countfile.write_text(str(count))
if action=='precache' and os.environ.get('FAKE_FAIL_PRECACHE')=='1' and count==1: print('Failed to download: fixture',file=sys.stderr); sys.exit(9)
if action=='--version' and os.environ.get('FAKE_FAIL_VERSION')=='1' and count==1: print('Error downloading: fixture',file=sys.stderr); sys.exit(9)
print(json.dumps({'args':args,'ok':True},ensure_ascii=False))
if action in ('run','build','analyze'): sys.exit(int(os.environ.get('FAKE_BUSINESS_EXIT','0')))
'''
        flutter = self.sdk / 'bin/flutter'
        flutter.write_text('#!' + sys.executable + '\n' + sdk_code)
        flutter.chmod(0o700)
        self.forbidden = self.root / 'forbidden-curl'
        self.forbidden.write_text('#!/bin/zsh\nprint unexpected-network >> "$FAKE_ROUTES"\nexit 99\n')
        self.forbidden.chmod(0o700)
        self.env['JOBS_FLUTTER_ROUTE_CURL'] = str(self.forbidden)
        self.env['JOBS_FLUTTER_ROUTE_GIT'] = str(self.forbidden)
        spec = importlib.util.spec_from_file_location('project_config_fixture', PACKAGE / 'Scripts/project_config.py')
        self.config = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.config)

    def tearDown(self):
        self.temp.cleanup()

    def generate(self, family='official', source=None):
        with patch.dict(os.environ, self.env, clear=True):
            if source is not None:
                os.environ['FLUTTER_STORAGE_BASE_URL'] = source
            self.config.project_runtime(self.project, family, 'stable', '3.38.4', 'a' * 40, str(self.sdk), str(self.root / 'DevEco') if family == 'harmony' else '', str(self.root / 'Java') if family == 'harmony' else '')
        # Keep the real SDK adapter and acquisition/once wrappers. Only network preparation is a test boundary.
        core = self.project / '.jobs-flutter' / NETWORK / NETWORK
        core.write_text(core.read_text() + '''\njobs_flutter_route_prepare() {
  print -r -- "$4|$1|$2" >> "$FAKE_ROUTES"
  [[ "${FAKE_CANCEL:-0}" != 1 ]] || return 130
  (( ${+FLUTTER_STORAGE_BASE_URL} )) || export FLUTTER_STORAGE_BASE_URL=https://fixture-selected.invalid
  return 0
}
''')
        return self.project / '.jobs-flutter/flutter'

    def run_launcher(self, launcher, args, extra=None):
        result = subprocess.run([str(launcher), *args], cwd=self.root, env=dict(self.env, **(extra or {})), text=True, capture_output=True, timeout=12)
        self.assertNotIn('unexpected-network', self.route_calls.read_text() if self.route_calls.exists() else '')
        return result

    def entries(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_copied_resources_survive_project_move_and_business_runs_once(self):
        launcher = self.generate()
        moved = self.root / '移动后的工程 空格'
        self.project.rename(moved)
        launcher = moved / '.jobs-flutter/flutter'
        result = self.run_launcher(launcher, ['analyze', 'lib/中文 文件.dart'], {'FAKE_BUSINESS_EXIT': '7'})
        self.assertEqual(7, result.returncode, result.stderr)
        entries = self.entries()
        self.assertEqual(1, sum(v['args'][0] == '--version' for v in entries))
        self.assertEqual([['analyze', 'lib/中文 文件.dart']], [v['args'] for v in entries if v['args'][0] == 'analyze'])
        self.assertEqual({'args': ['analyze', 'lib/中文 文件.dart'], 'ok': True}, json.loads(result.stdout))
        self.assertNotIn(str(PACKAGE), launcher.read_text())
        self.assertTrue((moved / '.jobs-flutter' / NETWORK / NETWORK).is_file())

    def test_explicit_precache_retries_acquisition_without_running_business(self):
        launcher = self.generate()
        result = self.run_launcher(launcher, ['precache', '--ios'], {'FAKE_FAIL_PRECACHE': '1'})
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual([['precache', '--ios'], ['precache', '--ios']], [v['args'] for v in self.entries()])
        self.assertEqual(['platform', 'platform'], [v.split('|')[0] for v in self.route_calls.read_text().splitlines()])

    def test_first_bootstrap_retries_then_apk_resources_prepare_before_one_build(self):
        launcher = self.generate()
        result = self.run_launcher(launcher, ['build', 'apk', '--debug'], {'FAKE_FAIL_VERSION': '1', 'FAKE_BUSINESS_EXIT': '6'})
        self.assertEqual(6, result.returncode, result.stderr)
        self.assertEqual([['--version'], ['--version'], ['precache', '--android'], ['build', 'apk', '--debug']], [v['args'] for v in self.entries()])
        self.assertEqual({'args': ['build', 'apk', '--debug'], 'ok': True}, json.loads(result.stdout))

    def test_run_device_metadata_selects_ios_preflight_and_preserves_device_argument(self):
        launcher = self.generate()
        result = self.run_launcher(launcher, ['run', '-d', 'iOS UUID'])
        self.assertEqual(0, result.returncode, result.stderr)
        calls = [v['args'] for v in self.entries()]
        self.assertIn(['precache', '--ios'], calls)
        self.assertEqual(['run', '-d', 'iOS UUID'], calls[-1])
        self.assertEqual(1, sum(v[0] == 'run' for v in calls))

    def test_harmony_run_prepares_ohos_and_checks_help(self):
        launcher = self.generate('harmony')
        result = self.run_launcher(launcher, ['run', '-d', 'ohos device'])
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual([['--version'], ['precache', '--help'], ['precache', '--ohos'], ['run', '-d', 'ohos device']], [v['args'] for v in self.entries()])

    def test_cancelled_sdk_preparation_returns_130_before_any_sdk_or_business(self):
        launcher = self.generate()
        result = self.run_launcher(launcher, ['run'], {'FAKE_CANCEL': '1'})
        self.assertEqual(130, result.returncode, result.stderr)
        self.assertEqual([], self.entries())

    def test_current_explicit_empty_source_overrides_saved_source(self):
        launcher = self.generate(source='https://saved-source.invalid')
        result = self.run_launcher(launcher, ['analyze'], {'FLUTTER_STORAGE_BASE_URL': ''})
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertTrue(all(v['sourceSet'] and v['source'] == '' for v in self.entries()))
        self.assertIn('(( ${+FLUTTER_STORAGE_BASE_URL} ))', (self.project / '.jobs-flutter/env.zsh').read_text())

    def test_upgrade_prepares_current_sdk_before_target_upgrade_route(self):
        launcher = self.generate()
        (self.sdk / '.git').mkdir()
        (self.sdk / 'bin/internal').mkdir()
        cache = self.sdk / 'bin/cache'
        (cache / 'dart-sdk/bin').mkdir(parents=True)
        for path in (self.sdk / 'bin/internal/engine.version', cache / 'engine.stamp', cache / 'engine-dart-sdk.stamp'):
            path.write_text('a' * 40 + '\n')
        dart = cache / 'dart-sdk/bin/dart'
        dart.write_text('#!/bin/sh\nexit 0\n')
        dart.chmod(0o700)
        git = self.root / 'fake-git'
        git.write_text('''#!/bin/zsh
case "$*" in
  *symbolic-ref*) print stable ;;
  *'config --get branch.stable.remote'*) print origin ;;
  *'config --get branch.stable.merge'*) print refs/heads/stable ;;
  *'remote get-url'*) print https://github.com/flutter/flutter.git ;;
  *check-ref-format*|*ls-remote*) exit 0 ;;
  *) exit 1 ;;
esac
''')
        git.chmod(0o700)
        result = self.run_launcher(launcher, ['upgrade'], {'FAKE_FAIL_VERSION': '1', 'JOBS_FLUTTER_ROUTE_GIT': str(git)})
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual([['--version'], ['--version'], ['upgrade']], [v['args'] for v in self.entries()])
        self.assertEqual(['dart', 'dart', 'archive'], [v.split('|')[0] for v in self.route_calls.read_text().splitlines()])

    def test_generated_launcher_and_module_shell_syntax(self):
        launcher = self.generate()
        for path in [launcher, *list((self.project / '.jobs-flutter').glob('*zsh/*zsh'))]:
            result = subprocess.run(['/bin/zsh', '-n', str(path)], text=True, capture_output=True)
            self.assertEqual(0, result.returncode, result.stderr)

    def test_symlink_resource_destination_is_rejected_without_overwriting_target(self):
        directory = self.project / '.jobs-flutter'
        directory.mkdir()
        outside = self.root / '外部资料'
        outside.mkdir()
        (directory / NETWORK).symlink_to(outside)
        with self.assertRaises(ValueError):
            self.generate()
        self.assertEqual([], list(outside.iterdir()))


if __name__ == '__main__':
    unittest.main()
