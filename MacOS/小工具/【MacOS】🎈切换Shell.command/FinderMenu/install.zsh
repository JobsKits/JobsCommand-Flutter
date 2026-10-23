#!/bin/zsh
# shell: zsh
# 所有编译在暂存目录完成；签名校验通过后才替换当前用户的安装。
set -euo pipefail

SOURCE_DIR="${0:A:h}"
APP_ID='com.jobs.JobsShellSwitcher'
EXTENSION_ID="$APP_ID.FinderSync"
APP_NAME='JobsShellSwitcher.app'
APP_PARENT="${JOBS_SHELL_APP_DIR:-$HOME/Applications}"
APP_PATH="$APP_PARENT/$APP_NAME"
EXTENSION_REL='Contents/PlugIns/JobsShellFinderSync.appex'
LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
stage=''
replacing=0
complete=0

fail() { print -u2 -r -- "✖ $*"; exit 1; }

validate_existing_app() {
  [[ ! -L "$APP_PATH" ]] || fail "安装路径不能是符号链接：$APP_PATH"
  if [[ -e "$APP_PATH" ]]; then
    local identifier
    identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" 2>/dev/null)" ||
      fail "目标不是本工具创建的 App，未覆盖：$APP_PATH"
    [[ "$identifier" == "$APP_ID" ]] || fail "目标属于其它应用，未覆盖：$APP_PATH"
  fi
}

cleanup() {
  local result=$?
  trap - EXIT
  if (( ! complete )) && { (( replacing )) || [[ -n "$stage" && -d "$stage/Previous.app" ]]; }; then
    print -u2 -r -- '安装未完成，正在恢复原有安装。'
    [[ ! -e "$APP_PATH" ]] || /bin/rm -rf -- "$APP_PATH"
    if [[ -d "$stage/Previous.app" ]]; then
      /bin/mv "$stage/Previous.app" "$APP_PATH"
      "$LSREGISTER" -f "$APP_PATH" || true
      /usr/bin/pluginkit -a "$APP_PATH/$EXTENSION_REL" || true
    fi
  fi
  [[ -z "$stage" || ! -d "$stage" ]] || /bin/rm -rf -- "$stage"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

build_app() {
  local app="$1" extension="$1/$EXTENSION_REL" identity sdk
  /usr/bin/xcrun --find clang >/dev/null 2>&1 ||
    fail '需要 Command Line Tools，请先运行 xcode-select --install 后重试。'
  sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  /bin/mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$extension/Contents/MacOS"
  /bin/cp "$SOURCE_DIR/App-Info.plist" "$app/Contents/Info.plist"
  /bin/cp "$SOURCE_DIR/Extension-Info.plist" "$extension/Contents/Info.plist"
  /bin/cp "$SOURCE_DIR/../【MacOS】🎈切换Shell.command" "$app/Contents/Resources/ShellSwitcher.zsh"
  cat > "$app/Contents/Resources/SwitchShell.command" <<'LAUNCHER'
#!/bin/zsh
source "${0:A:h}/ShellSwitcher.zsh"
main --switch-shell
result=$?
if [[ -t 0 ]]; then
  read -r '?按回车结束：' || true
fi
exit "$result"
LAUNCHER
  /bin/chmod +x "$app/Contents/Resources/SwitchShell.command"
  print -r -- '正在编译桌面 / Finder 右键菜单扩展…'
  /usr/bin/xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter \
    -isysroot "$sdk" -mmacosx-version-min=10.15 -framework Cocoa \
    "$SOURCE_DIR/Launcher.m" -o "$app/Contents/MacOS/JobsShellSwitcher"
  /usr/bin/xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter \
    -isysroot "$sdk" -mmacosx-version-min=10.15 -framework Cocoa -framework FinderSync \
    -fapplication-extension -Wl,-e,_NSExtensionMain \
    "$SOURCE_DIR/FinderSync.m" -o "$extension/Contents/MacOS/JobsShellFinderSync"
  # 本地源码编译默认使用 ad-hoc 签名，不借用钥匙串中的开发证书。
  # Apple Development 证书单独签名不等同于完整的开发 provisioning 配置。
  identity="${JOBS_CODESIGN_IDENTITY:--}"
  [[ "$identity" != - ]] || print -r -- '使用本机临时签名；仅用于当前 Mac。'
  /usr/bin/codesign --force --sign "$identity" --timestamp=none \
    --entitlements "$SOURCE_DIR/Extension.entitlements" "$extension"
  /usr/bin/codesign --force --sign "$identity" --timestamp=none "$app"
  /usr/bin/codesign --verify --deep --strict "$app"
  /usr/bin/plutil -lint "$app/Contents/Info.plist" "$extension/Contents/Info.plist"
}

install_menu() {
  local attempt registration=''
  validate_existing_app
  /bin/mkdir -p "$APP_PARENT"
  stage="$(/usr/bin/mktemp -d "$APP_PARENT/.jobs-shell-build.XXXXXX")"
  build_app "$stage/$APP_NAME"
  # 从此处起失败时由 EXIT trap 恢复旧 App。
  if [[ -e "$APP_PATH" ]]; then
    /bin/mv "$APP_PATH" "$stage/Previous.app"
  fi
  replacing=1
  /bin/mv "$stage/$APP_NAME" "$APP_PATH"
  "$LSREGISTER" -f "$APP_PATH"
  /usr/bin/pluginkit -a "$APP_PATH/$EXTENSION_REL"
  # Launch Services 注册是异步的；pluginkit -a 返回 0 仍可能暂时查不到扩展。
  for attempt in {1..20}; do
    registration="$(/usr/bin/pluginkit -m -v -i "$EXTENSION_ID")"
    [[ "$registration" == *"$APP_PATH/$EXTENSION_REL"* ]] && break
    /bin/sleep 1
  done
  [[ "$registration" == *"$APP_PATH/$EXTENSION_REL"* ]] || fail '系统未完成扩展注册，请检查系统策略后重试。'
  /usr/bin/pluginkit -e use -i "$EXTENSION_ID"
  complete=1
  print -r -- "✔ 已安装：$APP_PATH"
  registration="$(/usr/bin/pluginkit -m -v -i "$EXTENSION_ID")"
  if print -r -- "$registration" | /usr/bin/awk '$1 == "+" { enabled=1 } END { exit !enabled }'; then
    print -r -- '✔ 系统已启用扩展：桌面或 Finder 文件夹空白处右键 → 🎈 切换 Shell…'
  else
    print -r -- 'App 已保存，但扩展尚未启用；请在系统设置的 Finder 扩展中启用“切换 Shell”。'
  fi
  print -r -- '安装未修改当前默认 Shell。菜单尚未出现时，请关闭右键菜单后重新打开，或新开 Finder 窗口。'
  print -r -- "$registration"
}

uninstall_menu() {
  validate_existing_app
  [[ -d "$APP_PATH" ]] || { print -r -- '右键菜单尚未安装。'; return 0; }
  /usr/bin/pluginkit -e ignore -i "$EXTENSION_ID"
  /usr/bin/pluginkit -r "$APP_PATH/$EXTENSION_REL"
  "$LSREGISTER" -u "$APP_PATH"
  /bin/rm -rf -- "$APP_PATH"
  print -r -- '✔ 已卸载切换 Shell 右键菜单；账户默认 Shell 保持不变。'
}

[[ "$(/usr/bin/uname -s)" == Darwin ]] || fail '此安装器仅支持 macOS。'
case "${1:-}" in
  install) install_menu ;;
  uninstall) uninstall_menu ;;
  status)
    if [[ -d "$APP_PATH" ]]; then
      print -r -- "安装位置：$APP_PATH"
      print -r -- '以下输出中 + 表示启用，- 表示停用；无记录表示未注册。'
      /usr/bin/pluginkit -m -v -i "$EXTENSION_ID"
    else
      print -r -- '右键菜单尚未安装。'
    fi
    ;;
  *) fail '用法：install.zsh install | uninstall | status' ;;
esac
