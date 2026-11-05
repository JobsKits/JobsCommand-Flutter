"""Exercise real retry/child isolation with an in-memory network boundary."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PACKAGE = Path(__file__).resolve().parents[2]
ADAPTER = PACKAGE / 'Scripts/【MacOS】FlutterSDK网络适配.zsh/【MacOS】FlutterSDK网络适配.zsh'


class SDKNetworkAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='Jobs SDK 路由 ')
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, TEST_ADAPTER=str(ADAPTER), TEST_ROOT=str(self.root),
                        HOME=str(self.root), TMPDIR=str(self.root), NO_COLOR='1')

    def tearDown(self):
        self.temp.cleanup()

    def run_zsh(self, code, expected=0, adapter=None):
        env = dict(self.env)
        if adapter:
            env['TEST_ADAPTER'] = str(adapter)
        setup = r'''
source "$TEST_ADAPTER" || exit $?
LOG_FILE="$TEST_ROOT/sdk.log"
jobs_command_sdk_load || exit $?
jobs_flutter_route_prepare() {
  print -r -- "${4:-dart}|$2|${JOBS_FLUTTER_ROUTE_SOURCE_URL:-}|${JOBS_FLUTTER_ROUTE_GIT_REF:-}" >> "$TEST_ROOT/probes"
  export FLUTTER_STORAGE_BASE_URL=https://selected.test HTTPS_PROXY=http://child.test:8080
}
jobs_flutter_route_invalidate() { print invalidated >> "$TEST_ROOT/probes"; }
export FLUTTER_STORAGE_BASE_URL=https://parent.test HTTPS_PROXY=http://parent.test:8080
'''
        result = subprocess.run(['/bin/zsh', '-f', '-c', setup + code], env=env, cwd=self.root,
                                text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def test_sdk_failure_reprobes_until_success_and_restores_parent(self):
        result = self.run_zsh(r'''
export JOBS_SDK_LOG_REPLACED=1
fake_sdk() {
  local n=0
  [[ ! -f "$TEST_ROOT/count" ]] || n="$(<"$TEST_ROOT/count")"
  (( n++ )); print "$n" > "$TEST_ROOT/count"
  (( n<=2 )) || return 130
  if (( n==1 )); then print -u2 'Failed to download SDK'; return 28; fi
  print -r -- "payload:$FLUTTER_STORAGE_BASE_URL:$HTTPS_PROXY"
}
jobs_command_sdk 'Flutter 3.38.4 / Dart' '' 3.38.4 fake_sdk || exit $?
print -r -- "parent:$FLUTTER_STORAGE_BASE_URL:$HTTPS_PROXY"
print -r -- "parent-marker:$JOBS_SDK_LOG_REPLACED"
''')
        self.assertEqual((self.root / 'count').read_text().strip(), '2')
        self.assertEqual((self.root / 'probes').read_text().splitlines(),
                         ['dart|3.38.4||', 'invalidated', 'dart|3.38.4||'])
        self.assertIn('payload:https://selected.test:http://child.test:8080', result.stdout)
        self.assertIn('parent:https://parent.test:http://parent.test:8080', result.stdout)
        self.assertIn('parent-marker:1', result.stdout)
        self.assertIn('Flutter 3.38.4 / Dart', (self.root / 'sdk.log').read_text())

    def test_git_uses_actual_repository_and_ref_with_clean_stdout(self):
        result = self.run_zsh(r'''
JOBS_SDK_REPO=https://private.test/sdk.git JOBS_SDK_GIT_REF=refs/tags/ohos-v1
fake_git() { print -r -- "${(j:|:)@}"; }
jobs_command_sdk_git 'private SDK' '' ohos-v1 fake_git ls-remote 'with spaces'
''')
        self.assertEqual(result.stdout.strip(), 'ls-remote|with spaces')
        self.assertEqual((self.root / 'probes').read_text().strip(),
                         'git|ohos-v1|https://private.test/sdk.git|refs/tags/ohos-v1')

    def test_harmony_capability_and_platform_download_have_separate_phases(self):
        self.run_zsh(r'''
fake_flutter() {
  print -r -- "$*" >> "$TEST_ROOT/flutter-calls"
  if [[ "$*" == 'precache --help' ]]; then print -- '--[no-]ohos'; return 0; fi
  local n=0
  [[ ! -f "$TEST_ROOT/count" ]] || n="$(<"$TEST_ROOT/count")"
  (( n++ )); print "$n" > "$TEST_ROOT/count"
  (( n>1 )) || return 28
}
jobs_command_sdk_platform '' ohos-v1 fake_flutter ohos
''')
        self.assertEqual((self.root / 'flutter-calls').read_text().splitlines(),
                         ['precache --help', 'precache --ohos', 'precache --ohos'])
        self.assertEqual((self.root / 'probes').read_text().splitlines(),
                         ['platform|ohos-v1||', 'invalidated', 'platform|ohos-v1||'])

    def test_unsupported_harmony_stops_before_network_or_download(self):
        self.run_zsh(r'''
fake_flutter() { print 'ios android'; }
jobs_command_sdk_platform '' ohos-v1 fake_flutter ohos
''', expected=1)
        self.assertFalse((self.root / 'probes').exists())

    def test_cancel_preserves_code_and_stops_downstream(self):
        for code in (130, 143):
            with self.subTest(code=code):
                self.run_zsh('fake_cancel() { return ' + str(code) + '; }\n'
                             'jobs_command_sdk sdk "" 3.38.4 fake_cancel || exit $?\n'
                             'touch "$TEST_ROOT/downstream"\n', expected=code)
        self.assertFalse((self.root / 'downstream').exists())
        self.assertNotIn('invalidated', (self.root / 'probes').read_text())

    def test_whole_package_resources_work_after_relocation(self):
        relocated = self.root / '移走的工具/Scripts'
        relocated.mkdir(parents=True)
        for name in ('【MacOS】FlutterSDK网络适配.zsh', '【MacOS】FlutterSDK网络选路.zsh'):
            shutil.copytree(PACKAGE / 'Scripts' / name, relocated / name)
        adapter = relocated / '【MacOS】FlutterSDK网络适配.zsh/【MacOS】FlutterSDK网络适配.zsh'
        result = self.run_zsh('fake_sdk() { print SDK-ready; }\njobs_command_sdk sdk "" 3.38.4 fake_sdk\n', adapter=adapter)
        self.assertEqual(result.stdout.strip(), 'SDK-ready')


if __name__ == '__main__':
    unittest.main(verbosity=2)
