#!/usr/bin/env python3
"""Project-only configuration writes. Paths/data are arguments, never Python source."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import tempfile
from datetime import datetime


def backup(path):
    if path.exists():
        target = path.with_name(path.name + '.bak.' + datetime.now().strftime('%Y%m%d%H%M%S%f'))
        shutil.copy2(path, target)


def write(path, content, mode=None):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f'拒绝覆盖符号链接：{path}')
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == content:
        if mode is not None:
            os.chmod(path, mode)
        return
    backup(path)
    fd, stage = tempfile.mkstemp(prefix='.jobs-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(stage, mode or (path.stat().st_mode & 0o777 if path.exists() else 0o600))
        os.replace(stage, path)
    finally:
        if os.path.exists(stage):
            os.unlink(stage)


def read_object(path):
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f'配置顶层必须是对象：{path}')
    return data


def write_json(path, data):
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def ignore(root):
    path = root / '.gitignore'
    old = path.read_text() if path.exists() else ''
    lines = old.splitlines()
    extra = [x for x in ('/.fvm/', '/.jobs-flutter/', '*.bak.*') if x not in lines]
    if extra:
        write(path, old + ('\n' if old and not old.endswith('\n') else '') + '\n'.join(extra) + '\n')


def current(root):
    cfg = read_object(root / '.fvmrc')
    legacy = root / '.fvm/fvm_config.json'
    version = cfg.get('flutter', '')
    if not version and legacy.exists():
        version = read_object(legacy).get('flutterSdkVersion', '')
    repo = cfg.get('flutterUrl', '')
    if not isinstance(version, str) or not isinstance(repo, str):
        raise ValueError('.fvmrc 的 flutter / flutterUrl 必须是字符串')
    repo = repo.rstrip('/').removesuffix('.git')
    known_repos = {
        'https://github.com/flutter/flutter': 'official',
        'https://gitcode.com/CPF-Flutter/flutter_flutter': 'harmony',
        'https://gitcode.com/openharmony-tpc/flutter_flutter': 'harmony',
        'https://gitee.com/openharmony-sig/flutter_flutter': 'harmony',
    }
    lock = read_object(root / '.jobs-flutter/sdk.json')
    if repo and repo not in known_repos:
        print('unknown\n')
        print(f'已有自定义仓库 {repo}；必须明确选择 SDK 类型，不自动改为官方版。', file=sys.stderr)
    elif version.startswith('custom_jobs_ohos_') and lock.get('fvmVersion') == version:
        if not isinstance(lock.get('ref'), str) or not lock['ref']:
            raise ValueError('鸿蒙 SDK 记录缺少有效 ref')
        print('harmony')
        print(lock['ref'])
    elif (known_repos.get(repo) == 'harmony' and not version.startswith('custom_')
          and re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._+-]*', version)):
        print('harmony')
        print(version)
    elif version and re.fullmatch(r'(stable|beta|master|[0-9]+\.[0-9]+\.[0-9]+(?:[-+][a-zA-Z0-9.-]+)?)', version):
        print('harmony' if 'ohos' in version else 'official')
        print(version)
    else:
        print('unknown' if version else 'official')
        print('')
        if version:
            print(f'已有自定义 SDK {version}；请明确选择此次版本。', file=sys.stderr)


BINDING_FILES = ('.fvmrc', '.fvm/fvm_config.json', '.fvm/version', '.fvm/release')


def validate_binding_targets(root):
    if (root / '.fvm').is_symlink():
        raise ValueError('拒绝修改符号链接 .fvm')
    for relative in BINDING_FILES:
        target = root / relative
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(f'绑定配置不是普通文件：{target}')
    link = root / '.fvm/flutter_sdk'
    if link.exists() and not link.is_symlink():
        raise ValueError('.fvm/flutter_sdk 不是符号链接，拒绝覆盖')


def save_binding(root, snapshot):
    validate_binding_targets(root)
    existing = []
    for relative in BINDING_FILES:
        original = root / relative
        if original.exists():
            saved = snapshot / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, saved)
            existing.append(relative)
    link = root / '.fvm/flutter_sdk'
    write_json(snapshot / 'manifest.json', {
        'files': existing, 'link': os.readlink(link) if link.is_symlink() else None,
    })


def restore_binding(root, snapshot):
    manifest = read_object(snapshot / 'manifest.json')
    if not isinstance(manifest.get('files'), list) or 'link' not in manifest:
        raise ValueError('恢复快照不完整；保留快照，不修改工程')
    validate_binding_targets(root)  # Check all destinations before replacing any file.
    for relative in BINDING_FILES:
        if relative in manifest['files'] and not (snapshot / relative).is_file():
            raise ValueError(f'恢复快照缺少 {relative}')
    for relative in BINDING_FILES:
        target = root / relative
        if relative in manifest['files']:
            target.parent.mkdir(parents=True, exist_ok=True)
            fd, stage = tempfile.mkstemp(prefix='.jobs-restore-', dir=target.parent)
            os.close(fd)
            try:
                shutil.copy2(snapshot / relative, stage)
                os.replace(stage, target)
            finally:
                if os.path.lexists(stage):
                    os.unlink(stage)
        elif target.exists():
            target.unlink()
    link = root / '.fvm/flutter_sdk'
    if manifest['link'] is not None:
        link.parent.mkdir(parents=True, exist_ok=True)
        fd, stage = tempfile.mkstemp(prefix='.jobs-link-', dir=link.parent)
        os.close(fd)
        os.unlink(stage)
        try:
            os.symlink(manifest['link'], stage)
            os.replace(stage, link)
        finally:
            if os.path.lexists(stage):
                os.unlink(stage)
    elif link.is_symlink():
        link.unlink()


def configure_fvm(root, cache, repo):
    path = root / '.fvmrc'
    data = read_object(path)  # Invalid JSON must fail before any replacement.
    data.update(cachePath=cache, flutterUrl=repo, useGitCache=False,
                updateVscodeSettings=False, updateMelosSettings=False,
                updateGitIgnore=False, runPubGetOnSdkChanges=False)
    write_json(path, data)
    ignore(root)


def vscode(root, env, sdk, family, previous_env=None):
    for filename in ('settings.json', 'launch.json'):
        path = root / '.vscode' / filename
        try:
            data = read_object(path)
            if filename == 'settings.json':
                old_env = data.get('dart.env', {})
                if not isinstance(old_env, dict):
                    raise ValueError('dart.env 不是对象')
                for key, value in (previous_env or {}).items():
                    if old_env.get(key) == value:
                        old_env.pop(key)
                old_env.update(env)
                data.update({'dart.flutterSdkPath': sdk, 'dart.env': old_env})
                data.pop('dart.sdkPath', None)
            else:
                configs = data.setdefault('configurations', [])
                if not isinstance(configs, list):
                    raise ValueError('configurations 不是数组')
                name = 'Jobs Flutter'
                config = {'name': name, 'type': 'dart', 'request': 'launch',
                          'program': 'lib/main.dart', 'env': env}
                # Devices are selected at run time; no stale simulator UUID is saved.
                existing = next((c for c in configs if isinstance(c, dict) and c.get('name') == name), None)
                if existing is None:
                    configs.append(config)
                else:
                    existing.update(config)
                data.setdefault('version', '0.2.0')
            write_json(path, data)
        except (ValueError, OSError) as error:
            # JSONC comments/trailing commas are legitimate VS Code inputs. Preserve them.
            suggestion = root / '.jobs-flutter' / (filename + '.suggested.json')
            suggested = ({'dart.flutterSdkPath': sdk, 'dart.env': env} if filename == 'settings.json'
                         else {'version': '0.2.0', 'configurations': [
                             {'name': 'Jobs Flutter', 'type': 'dart', 'request': 'launch',
                              'program': 'lib/main.dart', 'env': env}]})
            write_json(suggestion, suggested)
            print(f'保留 {path}（JSONC/不可合并：{error}）；请合并建议：{suggestion}', file=sys.stderr)


def project_runtime(root, family, ref, version, commit, sdk, tool, java):
    previous_env = read_object(root / '.jobs-flutter/sdk.json').get('managedEnv', {})
    env = {}
    dirs = []
    if family == 'harmony':
        tool = Path(tool)
        sdk_home = str(tool / 'sdk')
        hdc = str(tool / 'sdk/default/openharmony/toolchains')
        env.update(TOOL_HOME=str(tool), DEVECO_SDK_HOME=sdk_home, HOS_SDK_HOME=sdk_home,
                   OHOS_SDK_HOME=sdk_home, HDC_HOME=hdc, JAVA_HOME=java)
        for relative in ('tools/node/bin', 'tool/node/bin', 'tools/ohpm/bin', 'ohpm/bin',
                         'tools/hvigor/bin', 'hvigor/bin'):
            if (tool / relative).is_dir():
                dirs.append(str(tool / relative))
        dirs += [hdc, str(Path(java) / 'bin')]
    # Only explicit mirror overrides are saved. Never guess an OH engine mirror.
    for key in ('PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL', 'PUB_CACHE'):
        if os.environ.get(key):
            env[key] = os.environ[key]
    lines = ['# Generated project environment; source only for this project.']
    lines += [f'export {key}={shlex.quote(value)}' for key, value in env.items()]
    if dirs:
        prefix = ':'.join(dirs)
        lines += [f'export PATH={shlex.quote(prefix)}:"$PATH"']
        # VS Code does not expand shell variables inside dart.env.
        env['PATH'] = prefix + ':' + os.environ['PATH']
    write(root / '.jobs-flutter/env.zsh', '\n'.join(lines) + '\n')
    launcher = ('#!/bin/zsh\nset -e\n'
                'project="${0:A:h:h}"\ncd -- "$project"\n'
                'source "$project/.jobs-flutter/env.zsh"\n'
                'sdk="$project/.fvm/flutter_sdk"\n'
                'if [[ ! -L "$sdk" || ! -x "$sdk/bin/flutter" ]]; then\n'
                '  print -u2 -r -- "工程 FVM 链接不可用，请重新运行配置脚本；未使用系统 Flutter。"\n'
                '  exit 1\nfi\n'
                'exec "$sdk/bin/flutter" "$@"\n')
    write(root / '.jobs-flutter/flutter', launcher, 0o700)
    write_json(root / '.jobs-flutter/sdk.json', {
        'family': family, 'ref': ref, 'fvmVersion': version, 'commit': commit, 'sdk': sdk,
        'toolHome': str(tool) if tool else '', 'javaHome': java,
        'managedEnv': env,
    })
    ignore(root)
    vscode(root, env, '.fvm/flutter_sdk', family, previous_env)


def profile(path, sdk):
    # Caller must already hold an exact, interactive YES authorization.
    path = Path(path)
    if path.is_symlink():
        path = path.resolve(strict=True)
    old = path.read_text() if path.exists() else ''
    begin, end = '# >>> Jobs Flutter global >>>', '# <<< Jobs Flutter global <<<'
    if (old.count(begin) != old.count(end) or old.count(begin) > 1
            or (begin in old and old.index(begin) > old.index(end))):
        raise ValueError('现有 Jobs Flutter 配置块不完整，请手动修复')
    old = re.sub(re.escape(begin) + r'.*?' + re.escape(end) + r'\n?', '', old, flags=re.S)
    block = f'{begin}\nexport PATH={shlex.quote(sdk + "/bin")}:"$PATH"\n{end}\n'
    write(path, old.rstrip('\n') + '\n' + block)


def main():
    action, *args = sys.argv[1:]
    if action == 'current':
        current(Path(args[0]))
    elif action == 'fvm':
        configure_fvm(Path(args[0]), *args[1:])
    elif action == 'runtime':
        project_runtime(Path(args[0]), *args[1:])
    elif action == 'profile':
        profile(*args)
    elif action == 'binding-save':
        save_binding(Path(args[0]), Path(args[1]))
    elif action == 'binding-restore':
        restore_binding(Path(args[0]), Path(args[1]))
    elif action == 'devices':
        family = args[0]
        devices = json.load(sys.stdin)
        if not isinstance(devices, list):
            raise ValueError('设备列表不是数组')
        for device in devices:
            platform = device.get('targetPlatform', device.get('platform', ''))
            if family == 'harmony' and not str(platform).startswith('ohos'):
                continue
            values = [str(device.get(k, '')) for k in ('id', 'name')]
            if all(v and not any(ord(c) < 32 for c in v) for v in values):
                print('\t'.join(values + [str(platform)]))
    else:
        raise ValueError('未知配置操作')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f'配置失败：{error}', file=sys.stderr)
        sys.exit(1)
