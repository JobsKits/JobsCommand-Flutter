"""Protect existing FVM version links when a project SDK switch needs rollback."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('binding_versions_config', ROOT / 'Scripts/project_config.py')
config = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(config)


def tree(path):
    """Observe fixture contents without following any SDK or external directory link."""
    if path.is_symlink():
        return ('link', os.readlink(path))
    if path.is_file():
        return ('file', path.read_bytes(), path.stat().st_mode & 0o777)
    if path.is_dir():
        return {child.name: tree(child) for child in path.iterdir()}
    return None


class BindingVersionsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='jobs-harmony-binding-')
        self.base = Path(self.temp.name)
        self.project = self.base / '工程 with spaces'
        self.snapshot = self.base / 'binding snapshot'
        self.project.mkdir()
        self.snapshot.mkdir()
        self.versions = self.project / '.fvm/versions'
        self.sdk_link = self.project / '.fvm/flutter_sdk'

    def tearDown(self):
        self.temp.cleanup()

    def seed_binding(self):
        for index, relative in enumerate(config.BINDING_FILES):
            path = self.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'original {index}\n')
            path.chmod(0o640)
        self.sdk_link.symlink_to('../missing original SDK')

    def simulate_fvm_switch(self):
        """Reproduce the real FVM use replacement of files and version link directory."""
        for relative in config.BINDING_FILES:
            path = self.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('changed by use\n')
        if self.sdk_link.is_symlink():
            self.sdk_link.unlink()
        self.sdk_link.symlink_to('/missing/new SDK')
        if self.versions.exists():
            for entry in self.versions.iterdir():
                entry.unlink()
            self.versions.rmdir()
        self.versions.mkdir(parents=True)
        (self.versions / 'custom_jobs_ohos_new').symlink_to('/missing/new SDK')

    def assert_restore_rejected_without_writes(self, message):
        project_before = tree(self.project)
        snapshot_before = tree(self.snapshot)
        with self.assertRaisesRegex(ValueError, message):
            config.restore_binding(self.project, self.snapshot)
        self.assertEqual(tree(self.project), project_before)
        self.assertEqual(tree(self.snapshot), snapshot_before)

    def test_restore_recovers_links_and_original_binding_files(self):
        self.seed_binding()
        self.versions.mkdir()
        external = self.base / 'existing SDK source'
        external.mkdir()
        (external / 'source.dart').write_text('keep external SDK source\n')
        targets = {
            'stable': str(external),
            'custom_old': '/missing/absolute SDK',
            'old relative SDK': '../../missing relative SDK',
        }
        for name, target in targets.items():
            (self.versions / name).symlink_to(target)
        original = tree(self.project)
        external_before = tree(external)
        config.save_binding(self.project, self.snapshot)

        self.simulate_fvm_switch()
        config.restore_binding(self.project, self.snapshot)

        self.assertEqual(tree(self.project), original)
        self.assertEqual(tree(external), external_before)
        self.assertEqual(os.readlink(self.versions / 'old relative SDK'), targets['old relative SDK'])
        self.assertTrue((self.versions / 'custom_old').is_symlink())
        self.assertFalse((self.versions / 'custom_old').exists())
        self.assertTrue((self.snapshot / 'manifest.json').is_file())
        config.restore_binding(self.project, self.snapshot)
        self.assertEqual(tree(self.project), original, 'Repeated recovery must preserve exact links')

    def test_restore_retains_originally_empty_versions_directory(self):
        self.seed_binding()
        self.versions.mkdir()
        original = tree(self.project)
        config.save_binding(self.project, self.snapshot)
        self.simulate_fvm_switch()

        config.restore_binding(self.project, self.snapshot)

        self.assertTrue(self.versions.is_dir())
        self.assertEqual(list(self.versions.iterdir()), [])
        self.assertEqual(tree(self.project), original)

    def test_restore_removes_versions_directory_when_originally_absent(self):
        self.seed_binding()
        original = tree(self.project)
        config.save_binding(self.project, self.snapshot)
        self.simulate_fvm_switch()

        config.restore_binding(self.project, self.snapshot)

        self.assertFalse(os.path.lexists(self.versions))
        self.assertEqual(tree(self.project), original)

    def test_save_rejects_real_content_before_creating_snapshot(self):
        for kind in ('file', 'directory'):
            with self.subTest(kind=kind):
                self.versions.mkdir(parents=True, exist_ok=True)
                protected = self.versions / 'protected SDK source'
                if kind == 'file':
                    protected.write_text('do not let FVM remove this source\n')
                else:
                    protected.mkdir()
                    (protected / 'source.dart').write_text('keep\n')
                original = tree(self.project)

                with self.assertRaisesRegex(ValueError, '只允许一层 SDK 符号链接'):
                    config.save_binding(self.project, self.snapshot)

                self.assertEqual(tree(self.project), original)
                self.assertEqual(list(self.snapshot.iterdir()), [])
                if kind == 'file':
                    protected.unlink()
                else:
                    (protected / 'source.dart').unlink()
                    protected.rmdir()

    def test_save_rejects_versions_symlink_including_broken_link(self):
        self.versions.parent.mkdir()
        external = self.base / 'external versions'
        external.mkdir()
        (external / 'keep.txt').write_text('keep\n')
        for target in (str(external), '/missing/external versions'):
            with self.subTest(target=target):
                self.versions.symlink_to(target)
                original = tree(self.project)
                with self.assertRaisesRegex(ValueError, '必须是普通目录'):
                    config.save_binding(self.project, self.snapshot)
                self.assertEqual(tree(self.project), original)
                self.assertEqual((external / 'keep.txt').read_text(), 'keep\n')
                self.assertEqual(list(self.snapshot.iterdir()), [])
                self.versions.unlink()

    def test_save_rejects_versions_regular_file(self):
        self.versions.parent.mkdir()
        self.versions.write_text('protected data\n')
        original = tree(self.project)
        with self.assertRaisesRegex(ValueError, '必须是普通目录'):
            config.save_binding(self.project, self.snapshot)
        self.assertEqual(tree(self.project), original)
        self.assertEqual(list(self.snapshot.iterdir()), [])

    def test_binding_check_cli_is_readonly_and_rejects_late_real_content(self):
        self.seed_binding()
        self.versions.mkdir()
        (self.versions / 'old').symlink_to('/missing old SDK')
        for expected in (0, 1):
            with self.subTest(expected=expected):
                if expected:
                    (self.versions / 'new source.dart').write_text('must not be deleted by use\n')
                original = tree(self.project)
                result = subprocess.run(
                    [sys.executable, str(ROOT / 'Scripts/project_config.py'),
                     'binding-check', str(self.project)],
                    capture_output=True, text=True, timeout=10,
                    env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'),
                )
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertEqual(tree(self.project), original)
                self.assertEqual(list(self.snapshot.iterdir()), [])
                if expected:
                    self.assertIn('只允许一层 SDK 符号链接', result.stderr)

    def test_restore_preflight_protects_real_content_and_snapshot(self):
        self.seed_binding()
        config.save_binding(self.project, self.snapshot)
        (self.project / '.fvmrc').write_text('leave current binding on rejected recovery\n')
        self.versions.mkdir()
        for kind in ('file', 'directory'):
            with self.subTest(kind=kind):
                protected = self.versions / 'unexpected source'
                if kind == 'file':
                    protected.write_text('keep current source\n')
                else:
                    protected.mkdir()
                self.assert_restore_rejected_without_writes('只允许一层 SDK 符号链接')
                if kind == 'file':
                    protected.unlink()
                else:
                    protected.rmdir()

    def test_restore_preflight_rejects_redirected_versions_directory(self):
        self.seed_binding()
        config.save_binding(self.project, self.snapshot)
        external = self.base / 'external source'
        external.mkdir()
        (external / 'keep.dart').write_text('keep\n')
        self.versions.symlink_to(external)

        self.assert_restore_rejected_without_writes('必须是普通目录')

        self.assertEqual((external / 'keep.dart').read_text(), 'keep\n')

    def test_legacy_manifest_without_versions_stops_instead_of_clearing_links(self):
        self.seed_binding()
        config.save_binding(self.project, self.snapshot)
        self.simulate_fvm_switch()
        manifest = self.snapshot / 'manifest.json'
        data = json.loads(manifest.read_text())
        data.pop('versions')
        manifest.write_text(json.dumps(data))

        self.assert_restore_rejected_without_writes('缺少有效 .fvm/versions 状态')

    def test_invalid_versions_manifest_stops_before_any_binding_write(self):
        self.seed_binding()
        config.save_binding(self.project, self.snapshot)
        self.simulate_fvm_switch()
        manifest = self.snapshot / 'manifest.json'
        original = json.loads(manifest.read_text())
        invalid_states = (
            None,
            {'exists': 'false', 'links': {}},
            {'exists': False, 'links': {'old': '/sdk'}},
            {'exists': True, 'links': {'../outside': '/sdk'}},
            {'exists': True, 'links': {'.': '/sdk'}},
            {'exists': True, 'links': {'old': None}},
            {'exists': True, 'links': {'old': ''}},
            {'exists': True, 'links': {'old': 'invalid\0target'}},
        )
        for state in invalid_states:
            with self.subTest(state=state):
                data = dict(original, versions=state)
                manifest.write_text(json.dumps(data))
                self.assert_restore_rejected_without_writes('保留快照，不修改工程')

    def test_incomplete_file_snapshot_cannot_modify_versions_or_binding(self):
        self.seed_binding()
        self.versions.mkdir()
        (self.versions / 'old').symlink_to('/old SDK')
        config.save_binding(self.project, self.snapshot)
        self.simulate_fvm_switch()
        (self.snapshot / '.fvm/version').unlink()

        self.assert_restore_rejected_without_writes('恢复快照缺少 .fvm/version')


if __name__ == '__main__':
    unittest.main()
