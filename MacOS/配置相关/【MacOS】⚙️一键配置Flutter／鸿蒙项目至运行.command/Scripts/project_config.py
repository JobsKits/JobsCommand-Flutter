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
BINDING_VERSIONS = '.fvm/versions'


def binding_versions(root):
    path = root / BINDING_VERSIONS
    if path.is_symlink() or (path.exists() and not path.is_dir()):
        raise ValueError('.fvm/versions 必须是普通目录，拒绝交给 FVM 删除')
    if not path.exists():
        return {'exists': False, 'links': {}}
    links = {}
    for entry in path.iterdir():
        if not entry.is_symlink():
            raise ValueError(f'.fvm/versions 只允许一层 SDK 符号链接，保留原内容：{entry}')
        links[entry.name] = os.readlink(entry)
    return {'exists': True, 'links': links}


def saved_binding_versions(manifest):
    state = manifest.get('versions')
    if (not isinstance(state, dict) or type(state.get('exists')) is not bool
            or not isinstance(state.get('links'), dict)):
        raise ValueError('恢复快照缺少有效 .fvm/versions 状态；保留快照，不修改工程')
    if not state['exists'] and state['links']:
        raise ValueError('恢复快照的 .fvm/versions 状态冲突；保留快照，不修改工程')
    for name, target in state['links'].items():
        if (not isinstance(name, str) or not name or name in ('.', '..')
                or '/' in name or '\0' in name or not isinstance(target, str)
                or not target or '\0' in target):
            raise ValueError('恢复快照含无效 SDK 链接；保留快照，不修改工程')
    return state


def validate_binding_targets(root):
    fvm = root / '.fvm'
    if fvm.is_symlink() or (fvm.exists() and not fvm.is_dir()):
        raise ValueError('.fvm 必须是普通目录，拒绝修改')
    for relative in BINDING_FILES:
        target = root / relative
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(f'绑定配置不是普通文件：{target}')
    link = root / '.fvm/flutter_sdk'
    if link.exists() and not link.is_symlink():
        raise ValueError('.fvm/flutter_sdk 不是符号链接，拒绝覆盖')
    return binding_versions(root)


def save_binding(root, snapshot):
    versions = validate_binding_targets(root)
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
        'versions': versions,
    })


def restore_binding(root, snapshot):
    manifest = read_object(snapshot / 'manifest.json')
    if not isinstance(manifest.get('files'), list) or 'link' not in manifest:
        raise ValueError('恢复快照不完整；保留快照，不修改工程')
    versions = saved_binding_versions(manifest)
    if (manifest['link'] is not None
            and (not isinstance(manifest['link'], str) or not manifest['link']
                 or '\0' in manifest['link'])):
        raise ValueError('恢复快照含无效 flutter_sdk 链接；保留快照，不修改工程')
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
    # FVM use recreates this directory; unlink metadata only, never recurse into SDKs.
    current = binding_versions(root)
    directory = root / BINDING_VERSIONS
    if current['exists']:
        for name in current['links']:
            (directory / name).unlink()
        directory.rmdir()
    if versions['exists']:
        directory.mkdir(parents=True)
        for name, target in versions['links'].items():
            (directory / name).symlink_to(target)


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


NETWORK_RESOURCES = ('【MacOS】FlutterSDK网络适配.zsh', '【MacOS】FlutterSDK网络选路.zsh')


def install_runtime_network(root):
    """Ship project-local SDK helpers; never retain a path into this configuration package."""
    scripts = Path(__file__).resolve().parent
    target_root = root / '.jobs-flutter'
    if target_root.is_symlink() or (target_root.exists() and not target_root.is_dir()):
        raise ValueError('.jobs-flutter 必须是普通目录，拒绝写入网络资源')
    resources = []
    for name in NETWORK_RESOURCES:
        source = scripts / name
        target = target_root / name
        if target.is_symlink() or (target.exists() and not target.is_dir()):
            raise ValueError(f'网络资源目标必须是普通目录：{target}')
        for filename in (name, 'README.md'):
            original = source / filename
            if original.is_symlink() or not original.is_file():
                raise ValueError(f'缺少随包 SDK 网络资源：{original}')
            resources.append((target / filename, original.read_text(), 0o700 if filename == name else 0o600))
    for path, content, mode in resources:
        write(path, content, mode)


def runtime_launcher(family):
    header = '#!/bin/zsh\nset -e\numask 077\n' + f'family={shlex.quote(family)}\n'
    return header + r'''project="${0:A:h:h}"
cd -- "$project"
source "$project/.jobs-flutter/env.zsh"
sdk="$project/.fvm/flutter_sdk"
if [[ ! -L "$sdk" || ! -x "$sdk/bin/flutter" ]]; then
  print -u2 -r -- "工程 FVM 链接不可用，请重新运行配置脚本；未使用系统 Flutter。"
  exit 1
fi
source "$project/.jobs-flutter/【MacOS】FlutterSDK网络适配.zsh/【MacOS】FlutterSDK网络适配.zsh"
LOG_FILE="${JOBS_FLUTTER_ROUTE_LOG:-}"
[[ -n "$LOG_FILE" ]] || LOG_FILE="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/JobsFlutterProjectSdk.XXXXXX")"
# SDK获取可重试；业务保持原argv、stdin/stdout和退出码，只执行一次。
case "${1:-}" in
  --version)
    jobs_command_sdk '工程Flutter / Dart首次补齐' "$sdk" '' "$sdk/bin/flutter" "$@"
    exit $?
    ;;
  precache)
    JOBS_FLUTTER_ROUTE_MODE=platform jobs_command_sdk '工程Flutter平台SDK获取' "$sdk" '' "$sdk/bin/flutter" "$@"
    exit $?
    ;;
  upgrade)
    jobs_command_sdk '升级前当前Flutter / Dart补齐' "$sdk" '' "$sdk/bin/flutter" --version >&2
    jobs_command_sdk_load
    JOBS_SDK_LOG_REPLACED=0 JOBS_FLUTTER_ROUTE_CAPTURE_OUTPUT=1 jobs_flutter_upgrade '工程Flutter SDK升级' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
    exit $?
    ;;
esac
jobs_command_sdk '工程Flutter / Dart首次补齐' "$sdk" '' "$sdk/bin/flutter" --version >&2
platform='' needs_platform=0 device='' devices='' index=0
case "${1:-}" in
  build)
    case "${2:-}" in
      apk|appbundle|aar) platform=android ;;
      ios|ipa|ios-framework) platform=ios ;;
      macos) platform=macos ;;
      web) platform=web ;;
      hap|app|ohos) platform=ohos ;;
      -h|--help) ;;
      *) needs_platform=1 ;;
    esac
    ;;
  run)
    needs_platform=1
    for (( index=2; index<=$#; index++ )); do
      case "$argv[index]" in
        -h|--help) needs_platform=0; break ;;
        -d|--device-id) (( index++ )); device="${argv[index]:-}" ;;
        --device-id=*) device="${argv[index]#*=}" ;;
      esac
    done
    if (( needs_platform )); then
      case "$device" in
        macos) platform=macos ;; chrome|edge|web-server) platform=web ;;
        *)
          if [[ "$family" == harmony ]]; then
            platform=ohos
          elif devices="$(jfs_fvm_timed "$sdk/bin/flutter" devices --machine --device-timeout 5 2>/dev/null)"; then
            platform="$(print -r -- "$devices" | /usr/bin/osascript -l JavaScript -e 'ObjC.import("Foundation"); function run(a){var d=$.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile; var s=ObjC.unwrap($.NSString.alloc.initWithDataEncoding(d,$.NSUTF8StringEncoding)); var rows=JSON.parse(s); if(!Array.isArray(rows)) return ""; var selected=rows.filter(function(v){return v&&v.isSupported!==false&&(!a[0]||v.id===a[0]);}); if(selected.length!==1) return ""; var p=String(selected[0].targetPlatform||selected[0].platform||""); return /^android/.test(p)?"android":/^ios/.test(p)?"ios":/^(darwin|macos)/.test(p)?"macos":/^web/.test(p)?"web":/^(ohos|openharmony)/.test(p)?"ohos":"";}' "$device" 2>/dev/null)" || platform=''
          fi
          ;;
      esac
    fi
    ;;
esac
if [[ -n "$platform" ]]; then
  jobs_command_sdk_platform "$sdk" '' "$sdk/bin/flutter" "$platform" >&2
  jobs_flutter_sdk_once '工程Flutter命令（仅一次）' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
elif (( needs_platform )); then
  print -u2 -r -- '设备/目标平台尚未确定，按当前engine代表对象检测通道，原业务仅执行一次。'
  JOBS_FLUTTER_ROUTE_MODE=platform jobs_flutter_sdk_once '工程Flutter命令（平台通道，仅一次）' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
else
  jobs_flutter_sdk_once '工程Flutter命令（仅一次）' "$LOG_FILE" "$sdk" '' "$sdk/bin/flutter" "$@"
fi
'''


def project_runtime(root, family, ref, version, commit, sdk, tool, java):
    previous_env = read_object(root / '.jobs-flutter/sdk.json').get('managedEnv', {})
    env = {}
    dirs = []
    if family == 'harmony':
        tool = Path(tool)
        sdk_home = str(tool / 'sdk')
        hdc = str(tool / 'sdk/default/openharmony/toolchains')
        env.update(TOOL_HOME=str(tool), DEVECO_SDK_HOME=sdk_home, HOS_SDK_HOME=sdk_home,
                   OHOS_HOME=sdk_home,
                   OHOS_SDK_HOME=sdk_home, HDC_HOME=hdc, JAVA_HOME=java)
        for relative in ('tools/node/bin', 'tool/node/bin', 'tools/ohpm/bin', 'ohpm/bin',
                         'tools/hvigor/bin', 'hvigor/bin'):
            if (tool / relative).is_dir():
                dirs.append(str(tool / relative))
        dirs += [hdc, str(Path(java) / 'bin')]
    # Only explicit mirror overrides are saved. Never guess an OH engine mirror.
    for key in ('PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL', 'PUB_CACHE'):
        if key in os.environ:
            env[key] = os.environ[key]
    lines = ['# Generated project environment; source only for this project.']
    for key, value in env.items():
        export = f'export {key}={shlex.quote(value)}'
        if key in ('PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL', 'PUB_CACHE'):
            lines.append(f'(( ${{+{key}}} )) || {export}')
        else:
            lines.append(export)
    if dirs:
        prefix = ':'.join(dirs)
        lines += [f'export PATH={shlex.quote(prefix)}:"$PATH"']
        # VS Code does not expand shell variables inside dart.env.
        env['PATH'] = prefix + ':' + os.environ['PATH']
    write(root / '.jobs-flutter/env.zsh', '\n'.join(lines) + '\n')
    install_runtime_network(root)
    write(root / '.jobs-flutter/flutter', runtime_launcher(family), 0o700)
    write_json(root / '.jobs-flutter/sdk.json', {
        'family': family, 'ref': ref, 'fvmVersion': version, 'commit': commit, 'sdk': sdk,
        'toolHome': str(tool) if tool else '', 'javaHome': java,
        'managedEnv': env,
    })
    ignore(root)
    vscode(root, env, '.fvm/flutter_sdk', family, previous_env)


def main():
    action, *args = sys.argv[1:]
    if action == 'current':
        current(Path(args[0]))
    elif action == 'fvm':
        configure_fvm(Path(args[0]), *args[1:])
    elif action == 'runtime':
        project_runtime(Path(args[0]), *args[1:])
    elif action == 'binding-check':
        validate_binding_targets(Path(args[0]))
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
            if not isinstance(device, dict):
                raise ValueError('设备列表项必须是对象')
            if device.get('isSupported') is False:
                continue
            platform = device.get('targetPlatform', device.get('platform', ''))
            if family == 'harmony' and not str(platform).startswith('ohos'):
                continue
            values = [str(device.get(k, '')) for k in ('id', 'name')]
            if all(v and not any(ord(c) < 32 or ord(c) == 127 for c in v) for v in values + [str(platform)]):
                print('\t'.join(values + [str(platform)]))
    else:
        raise ValueError('未知配置操作')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f'配置失败：{error}', file=sys.stderr)
        sys.exit(1)
