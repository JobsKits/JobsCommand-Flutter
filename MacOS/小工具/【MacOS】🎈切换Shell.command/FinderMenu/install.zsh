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
# JOBS_INPUT_CHOICE_STYLE_BEGIN
# 只展示提示选项；不读取答案、不改变默认值、返回码或业务环境。
jobs_prompt_color_ready() {
  [ -z "${NO_COLOR+x}" ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
    [ "${PLAIN_OUTPUT:-0}" != 1 ] && [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]
}
# 原生 awk 分段着色；任意/非空输入优先，括号内外沿用同一个选项。
jobs_prompt_format() {
  /usr/bin/awk -v color="${1:-0}" -v lines="${2:-0}" -v keep="${3:-0}" '
    function typedEnter(value, start, prefix) {
      prefix = substr(value, 1, start - 1)
      gsub(/[“”‘’「」『』"]/, "", prefix)
      gsub(sprintf("%c", 39), "", prefix)
      if (prefix ~ /(空格|[Ss][Pp][Aa][Cc][Ee])[[:space:]]*(后|再|并|[Tt][Hh][Ee][Nn])?[[:space:]]*$/) return 1
      return prefix ~ /(输入|键入|填写|[Tt]ype)[^；;|]*[[:alnum:]_+-]+[[:space:]]*(后|再|并)?[[:space:]]*$/
    }
    function greenPosition(value, token, start) {
      if (match(value, /(直接|仅|只需|只|按下|按)?[[:space:]]*(回车|回車)/)) {
        start = RSTART
        return typedEnter(value, start) ? 0 : start
      }
      if (!match(value, /(^|[^[:alnum:]_])([Ee][Nn][Tt][Ee][Rr]|[Rr][Ee][Tt][Uu][Rr][Nn])([^[:alnum:]_]|$)/)) return 0
      start = RSTART
      token = substr(value, RSTART, RLENGTH)
      match(token, /[Ee][Nn][Tt][Ee][Rr]|[Rr][Ee][Tt][Uu][Rr][Nn]/)
      start += RSTART - 1
      return typedEnter(value, start) ? 0 : start
    }
    function segment(value, inherited, start, kind, prefix, body, red, green, connector, left, right, splitAt) {
      if (value == "") return value
      kind = inherited
      start = 1
      if (!kind) {
        if (match(value, /(输入)?(任意|任何)(非空)?(字符|内容|输入|键)|非空(字符|内容|输入)?|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key/)) {
          red = RSTART
        }
        green = greenPosition(value)
        if (red && green && green < red) {
          left = substr(value, 1, red - 1)
          right = substr(value, red)
          connector = ""
          if (match(left, /(或者|或)[[:space:]]*$/)) {
            connector = substr(left, RSTART)
            left = substr(left, 1, RSTART - 1)
          }
          return segment(left, 0) connector segment(right, 31)
        }
        if (red && green && red < green && match(value, /或[[:space:]]*(直接|仅|只需|只|按下|按)?(回车|回車)/)) {
          splitAt = RSTART
          return segment(substr(value, 1, splitAt - 1), 31) "或" segment(substr(value, splitAt + length("或")), 0)
        }
        if (red) {
          kind = 31
          start = red
        } else if (green) {
          kind = 32
          start = green
        }
      }
      if (!kind || !color) return value
      prefix = substr(value, 1, start - 1)
      body = substr(value, start)
      return prefix esc "[1;" kind "m" body esc "[0m"
    }
    function render(value, output, part, boundary, inherited, kind, consumed, depth, original) {
      original = value
      gsub(esc "\\[[0-9;]*m", "", value)
      if (color && keep && !greenPosition(value) && value !~ /(任意|任何|非空|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key)/) return original
      output = ""
      inherited = 0
      depth = 0
      while (match(value, /[；;\/|，,、？?：:=＝（）()\[\]【】]/)) {
        part = substr(value, 1, RSTART - 1)
        boundary = substr(value, RSTART, RLENGTH)
        consumed = RSTART + RLENGTH
        output = output segment(part, inherited) boundary
        if (boundary ~ /[（(\[【]/) {
          depth++
          if (part ~ /(任意|任何|非空|其它输入|其他输入|[Tt]ype (anything|any[^ ]*)|[Pp]ress any key)/) inherited = 31
          else if (greenPosition(part)) inherited = 32
        } else if (boundary ~ /[）)\]】]/) {
          if (depth) depth--
        } else if (boundary ~ /[：:=＝]/) {
          if (!inherited) {
            if (part ~ /(任意|任何|非空|其它输入|其他输入)/) inherited = 31
            else if (greenPosition(part)) inherited = 32
          }
        } else if (!depth) inherited = 0
        value = substr(value, consumed)
      }
      return output segment(value, inherited)
    }
    BEGIN { esc = sprintf("%c", 27); first = 1 }
    {
      if (lines == 2) {
        if (!first) printf "%s\n", render(pending)
        pending = $0
        first = 0
        next
      }
      if (!lines && !first) printf "\n"
      printf "%s", render($0)
      if (lines) printf "\n"
      first = 0
    }
    END {
      if (lines == 2 && !first) {
        sub(sprintf("%c", 1) "$", "", pending)
        printf "%s", render(pending)
      }
    }
  '
}
# read 的命令替换会使 stdout 成为管道，按输入与提示所在 stderr 判断终端。
jobs_prompt_render() {
  local jobs_prompt_color=0
  if [ -t 0 ] && [ -t 2 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  printf "%s" "$1" | jobs_prompt_format "$jobs_prompt_color" 0
}
# 仅放在显示链末端；tee 在此函数之前接收纯文本，不把 ANSI 写入日志。
jobs_prompt_stream() {
  local jobs_prompt_color=0
  if [ -t 1 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  jobs_prompt_format "$jobs_prompt_color" 1 1
}
# 显示管道保留原末尾换行；只删除本轮追加的最后一个结束标记。
jobs_prompt_filter() {
  local jobs_prompt_color=0
  if [ -t 1 ] && jobs_prompt_color_ready; then jobs_prompt_color=1; fi
  { /bin/cat; printf '\001'; } | jobs_prompt_format "$jobs_prompt_color" 2 1
}
# 仅包装原 printf/echo/print 展示，原参数、尾换行与显示命令退出码保持不变。
jobs_prompt_output() {
  local jobs_prompt_status=0 jobs_prompt_stderr=0 jobs_prompt_arg="" jobs_prompt_previous=""
  if [ "${1:-}" = print ]; then
    for jobs_prompt_arg in "$@"; do
      case "$jobs_prompt_arg" in -?*u2*|-u2) jobs_prompt_stderr=1 ;; esac
      if [ "$jobs_prompt_previous" = -u ] && [ "$jobs_prompt_arg" = 2 ]; then jobs_prompt_stderr=1; fi
      jobs_prompt_previous="$jobs_prompt_arg"
      [ "$jobs_prompt_arg" != -- ] || break
    done
  fi
  if [ -n "${ZSH_VERSION:-}" ]; then
    if [ "$jobs_prompt_stderr" = 1 ]; then
      "$@" 2>&1 | jobs_prompt_filter >&2
      jobs_prompt_status=$(( ${pipestatus[1]} != 0 ? ${pipestatus[1]} : ${pipestatus[2]} ))
    else
      "$@" | jobs_prompt_filter
      jobs_prompt_status=$(( ${pipestatus[1]} != 0 ? ${pipestatus[1]} : ${pipestatus[2]} ))
    fi
  elif [ -n "${BASH_VERSION:-}" ]; then
    "$@" | jobs_prompt_filter
    jobs_prompt_status=$(( ${PIPESTATUS[0]} != 0 ? ${PIPESTATUS[0]} : ${PIPESTATUS[1]} ))
  else
    "$@" | jobs_prompt_filter
    jobs_prompt_status=$?
  fi
  return "$jobs_prompt_status"
}
# 仅替换日志 primitive 的 tee：磁盘同步追加纯文，终端保留非选项原色。
jobs_prompt_tee() {
  local jobs_prompt_log="$1" jobs_prompt_line="" jobs_prompt_newline=0
  while :; do
    jobs_prompt_line=""
    if IFS= read -r jobs_prompt_line; then jobs_prompt_newline=1; else jobs_prompt_newline=0; [ -n "$jobs_prompt_line" ] || break; fi
    if [ "$jobs_prompt_newline" = 1 ]; then
      { printf '%s\n' "$jobs_prompt_line"; printf '\001'; } | jobs_prompt_format 0 2 >> "$jobs_prompt_log" || return $?
      printf '%s\n' "$jobs_prompt_line" | jobs_prompt_filter || return $?
    else
      { printf '%s' "$jobs_prompt_line"; printf '\001'; } | jobs_prompt_format 0 2 >> "$jobs_prompt_log" || return $?
      printf '%s' "$jobs_prompt_line" | jobs_prompt_filter || return $?
    fi
  done
}
# JOBS_INPUT_CHOICE_STYLE_END

source "${0:A:h}/ShellSwitcher.zsh"
main --switch-shell
result=$?
if [[ -t 0 ]]; then
  read -r "?$(jobs_prompt_render '按回车结束：')" || true
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
