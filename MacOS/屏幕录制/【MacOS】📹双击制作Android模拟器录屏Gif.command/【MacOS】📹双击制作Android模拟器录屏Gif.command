#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】📹双击制作Android模拟器录屏Gif.command
# - 核心用途：执行“📹双击制作Android模拟器录屏Gif”对应的移动端项目自动化任务。
# - 影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。
# - 运行提示：运行后会先打印内置自述；终端模式按回车确认后继续，按 Ctrl+C 可取消。
# =====================================================================
# Jobs 标准化脚本外壳
# 说明：保留原脚本业务逻辑，补齐 README 防误触、彩色日志、zsh 入口、Homebrew 健康自检标准。
# =====================================================================

# 仅渲染自述：标题红色加粗，编号正文蓝色常规字重；非彩色终端输出纯文本。
# >>> Jobs Homebrew install choice >>>
# 输出安装诊断，避免混入返回的命令路径。
jobs_brew_note() {
  print -u2 -r -- "ℹ $*"
}
# 验证候选能够执行；共享安装只读不代表未安装。
jobs_brew_candidate_ok() {
  local candidate="$1" prefix
  [[ -n "$candidate" && -x "$candidate" ]] || return 1
  HOMEBREW_NO_AUTO_UPDATE=1 "$candidate" --version >/dev/null 2>&1 || return 1
  prefix="$("$candidate" --prefix 2>/dev/null)" || return 1
  [[ "$prefix" == /* && -d "$prefix" ]]
}
# 发现既有健康安装，不以目录可写性决定是否重新安装。
jobs_brew_find() {
  local candidate
  local -a candidates
  candidates=("${JOBS_HOMEBREW_BIN:-}" "$(command -v brew 2>/dev/null)" /opt/homebrew/bin/brew /usr/local/bin/brew
    "${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}/bin/brew" "$HOME/.homebrew/bin/brew")
  for candidate in "${candidates[@]}"; do
    if jobs_brew_candidate_ok "$candidate"; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}
# 计算官方系统目录；实际支持范围和授权交由官方安装器处理。
jobs_brew_system_prefix() {
  case "$(/usr/bin/uname -m)" in
    arm64) print -r -- /opt/homebrew ;;
    *) print -r -- /usr/local ;;
  esac
}
# 缺失时强提示选择安装路径；YES 只表示选择系统目录，不验证密码或权限。
jobs_brew_choose_installation() {
  local answer="" system_prefix="$(jobs_brew_system_prefix)"
  if [[ ! -t 0 || ! -t 2 || "${IS_SOURCETREE_RUNTIME:-0}" == 1 ]]; then
    jobs_brew_note "缺少 Homebrew，需要人工选择安装路径；请在可交互终端重新运行，未执行安装。"
    return 1
  fi
  print -u2 -r -- "⚠ Homebrew 尚未就绪，必须先选择安装路径："
  print -u2 -r -- "1、输入精确大写 YES：选择系统标准目录 $system_prefix（Apple Silicon：/opt/homebrew；Intel：/usr/local）。"
  print -u2 -r -- "   这表示你准备向系统目录安装；官方安装器可能随后要求管理员密码，并自行验证权限。"
  print -u2 -r -- "2、其它输入或直接回车：选择用户目录 ${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}，不使用 sudo；有管理员权限也可选此路径。"
  print -u2 -r -- "本步骤只选择路径，不收集或验证密码；选定路径失败就停止，不自动切换。按 Ctrl+C 取消整个任务。"
  print -u2 -n -r -- "➤ 安装路径选择："
  if ! IFS= read -r answer; then
    jobs_brew_note "输入已取消或结束，停止安装。"
    return 1
  fi
  if [[ "$answer" == YES ]]; then
    typeset -g JOBS_HOMEBREW_INSTALL_MODE=system
  else
    typeset -g JOBS_HOMEBREW_INSTALL_MODE=user
  fi
}
# 将官方系统安装器下载到临时文件后执行，失败不自动改装到用户目录。
jobs_brew_install_system() {
  local installer system_prefix="$(jobs_brew_system_prefix)" installer_result=0
  command -v curl >/dev/null 2>&1 || { jobs_brew_note "缺少 curl，无法获取官方安装器。"; return 1; }
  installer="$(mktemp "${TMPDIR:-/tmp}/jobs-homebrew-install.XXXXXX")" || return 1
  if curl -fsSL --connect-timeout 10 --max-time 120 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
    /bin/bash "$installer" || installer_result=$?
  else
    installer_result=1
  fi
  rm -- "$installer"
  if (( installer_result != 0 )); then
    jobs_brew_note "系统目录安装失败（退出码 $installer_result）；停止，不自动切换安装路径。"
    return 1
  fi
  typeset -g JOBS_HOMEBREW_BIN="$system_prefix/bin/brew"
  jobs_brew_candidate_ok "$JOBS_HOMEBREW_BIN" || { jobs_brew_note "官方安装器结束后未找到健康 Homebrew：$JOBS_HOMEBREW_BIN"; return 1; }
}
# 克隆官方稳定版本到用户目录；不覆盖非空目录，不调用 sudo。
jobs_brew_install_user() {
  local prefix="${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}" stage release_tag git_bin
  [[ "$prefix" == /* && "$prefix" != / && "$prefix" != *[[:space:]:]* ]] || {
    jobs_brew_note "Homebrew 用户前缀须为不含空白或冒号的绝对目录：$prefix"
    return 1
  }
  if [[ -L "$prefix" || ( -e "$prefix" && ! -d "$prefix" ) || ( -d "$prefix" && -n "$(ls -A "$prefix" 2>/dev/null)" ) ]]; then
    jobs_brew_note "用户安装目标非空或不是普通目录，不覆盖：$prefix"
    return 1
  fi
  git_bin="$(command -v git 2>/dev/null)"
  [[ -n "$git_bin" ]] && "$git_bin" --version >/dev/null 2>&1 || { jobs_brew_note "用户目录安装需要可用 Git；请先准备 Git / Command Line Tools。"; return 1; }
  command -v curl >/dev/null 2>&1 || { jobs_brew_note "缺少 curl，无法获取官方稳定版本。"; return 1; }
  export HOMEBREW_NO_SUDO=1
  mkdir -p "${prefix:h}" || return 1
  stage="$(mktemp -d "${prefix:h}/.jobs-homebrew.XXXXXX")" || return 1
  if ! curl -fsSL --connect-timeout 10 --max-time 60 https://api.github.com/repos/Homebrew/brew/releases/latest -o "$stage/release.json"; then
    rm -r -- "$stage"
    jobs_brew_note "获取官方稳定版本失败，停止安装。"
    return 1
  fi
  release_tag="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$stage/release.json" | head -n 1)"
  if [[ ! "$release_tag" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] ||
     ! GIT_TERMINAL_PROMPT=0 "$git_bin" -c http.lowSpeedLimit=1 -c http.lowSpeedTime=60 clone --depth 1 --branch "$release_tag" --single-branch https://github.com/Homebrew/brew.git "$stage/brew" ||
     ! "$git_bin" -C "$stage/brew" checkout -b stable ||
     ! "$git_bin" -C "$stage/brew" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' ||
     ! mkdir -p "$stage/brew/Cellar" "$stage/brew/Caskroom" "$stage/brew/etc" "$stage/brew/var"; then
    rm -r -- "$stage"
    jobs_brew_note "Homebrew 用户目录初始化失败，停止安装。"
    return 1
  fi
  # 空目录也只在下载成功后移除，避免提前改动用户的目标目录。
  if [[ -d "$prefix" ]] && ! rmdir -- "$prefix"; then
    rm -r -- "$stage"
    return 1
  fi
  if ! mv "$stage/brew" "$prefix"; then
    rm -r -- "$stage"
    return 1
  fi
  rm -r -- "$stage"
  typeset -g JOBS_HOMEBREW_BIN="$prefix/bin/brew"
  jobs_brew_candidate_ok "$JOBS_HOMEBREW_BIN" || { jobs_brew_note "用户目录安装后复检失败：$prefix"; return 1; }
}
# 只更新本模块的 shellenv 配置块，并保留配置文件的符号链接和权限。
jobs_brew_save_shellenv() {
  local profile_file="$HOME/.zprofile" profile_stage shellenv_line current_shell="${SHELL:-/bin/zsh}"
  [[ "${current_shell##*/}" != bash ]] || profile_file="$HOME/.bash_profile"
  shellenv_line='eval "$('"${(q)JOBS_HOMEBREW_BIN}"' shellenv)"'
  profile_stage="$(mktemp "${TMPDIR:-/tmp}/jobs-homebrew-profile.XXXXXX")" || return 1
  if [[ -e "$profile_file" || -L "$profile_file" ]]; then
    awk '
      $0 == "# >>> Jobs Homebrew shellenv >>>" { inside = 1; block = $0 ORS; next }
      inside {
        block = block $0 ORS
        if ($0 == "# <<< Jobs Homebrew shellenv <<<") { inside = 0; block = "" }
        next
      }
      { print }
      END { if (inside) printf "%s", block }
    ' "$profile_file" > "$profile_stage" || { rm -- "$profile_stage"; return 1; }
  fi
  {
    print -r -- '# >>> Jobs Homebrew shellenv >>>'
    print -rl -- "$shellenv_line" '# <<< Jobs Homebrew shellenv <<<'
  } >> "$profile_stage"
  if ! cmp -s "$profile_stage" "$profile_file"; then
    cat "$profile_stage" > "$profile_file" || { rm -- "$profile_stage"; jobs_brew_note "无法写入用户配置：$profile_file"; return 1; }
  fi
  rm -- "$profile_stage"
}
# 激活当前进程并验证 Ruby 命令层；只有新安装才持久化 shellenv。
jobs_brew_activate() {
  local brew_env
  brew_env="$("$JOBS_HOMEBREW_BIN" shellenv)" || return 1
  eval "$brew_env" || return 1
  typeset -g JOBS_HOMEBREW_PREFIX="$("$JOBS_HOMEBREW_BIN" --prefix)"
  export PATH="$JOBS_HOMEBREW_PREFIX/bin:$JOBS_HOMEBREW_PREFIX/sbin:$PATH"
  rehash
  HOMEBREW_NO_AUTO_UPDATE=1 "$JOBS_HOMEBREW_BIN" config >/dev/null || { jobs_brew_note "Homebrew 命令层复检失败，停止后续业务。"; return 1; }
  if [[ "${1:-}" == installed ]]; then
    if [[ "${JOBS_HOMEBREW_INSTALL_MODE:-}" == user && -z "${HOMEBREW_CASK_OPTS:-}" ]]; then
      export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
    fi
    jobs_brew_save_shellenv || return 1
  fi
}
# 在原版安装位置复用或安装 Homebrew，安装失败必须终止外层业务。
jobs_brew_install_or_exit() {
  local installed=""
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    jobs_brew_note "演练：Homebrew 系统路径 $(jobs_brew_system_prefix)；用户路径 ${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}；未询问或执行安装。"
    return 0
  fi
  if ! JOBS_HOMEBREW_BIN="$(jobs_brew_find)"; then
    jobs_brew_choose_installation || exit 1
    case "$JOBS_HOMEBREW_INSTALL_MODE" in
      system) jobs_brew_install_system || exit 1 ;;
      user) jobs_brew_install_user || exit 1 ;;
      *) jobs_brew_note "安装路径选择无效，停止。"; exit 1 ;;
    esac
    installed=installed
  fi
  jobs_brew_activate "$installed" || exit 1
}
# <<< Jobs Homebrew install choice <<<
jobs_intro_style() {
  local intro_color=0
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
     [ -z "${NO_COLOR+x}" ] && [ "${PLAIN_OUTPUT:-0}" != 1 ] &&
     [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]; then
    intro_color=1
  fi
  /usr/bin/awk -v color="$intro_color" -v role="${1:-body}" '
    BEGIN { esc = sprintf("%c", 27) }
    {
      gsub(esc "\\[[0-9;]*m", "")
      gsub(/\\(033|e|x1[bB])\[[0-9;]*m/, "")
      if (!color || $0 ~ /^[[:space:]]*$/) { print; next }
      numbered = ($0 ~ /^[[:space:]➤ℹ🔹✔⚠]*([0-9]+[、.)）]|[0-9]+️⃣|[-•])/)
      heading = ($0 ~ /^[[:space:]]*#{1,6}[[:space:]]/ || $0 ~ /[：:][[:space:]]*$/ || $0 ~ /^[[:space:]]*[=━─-]{3}/)
      title = (!numbered && (role == "title" || heading))
      if (role == "auto" && !seen && !numbered) title = 1
      if ($0 !~ /^[[:space:]]*[=━─-]+[[:space:]]*$/) seen = 1
      printf "%s%s%s\n", esc (title ? "[1;31m" : "[0;34m"), $0, esc "[0m"
    }
  '
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME="$(basename "$0" | sed 's/\.[^.]*$//')"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
# 按当前输出级别记录终端信息，并同步写入脚本日志。
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
color_echo()     { log "\033[1;32m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warm_echo()      { log "\033[1;33m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
err_echo()       { log "\033[1;31m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
gray_echo()      { log "\033[0;90m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
bold_echo()      { log "\033[1m$1\033[0m"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
underline_echo() { log "\033[4m$1\033[0m"; }
# ============================= 标准工具函数 =============================
get_cpu_arch() {
  [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
}
# 封装 abs_path 对应的独立处理逻辑。
abs_path() {
  local p="$1"
  [[ -z "$p" ]] && return 1
  p="${p//\"/}"
  [[ "$p" != "/" ]] && p="${p%/}"
  if [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd -P)
  elif [[ -f "$p" ]]; then
    (cd "${p:h}" 2>/dev/null && printf "%s/%s\n" "$(pwd -P)" "${p:t}")
  else
    return 1
  fi
}
# 收集并校验用户输入，决定后续执行路径。
ask_run() {
  echo ""
  note_echo "👉 $1"
  gray_echo "【回车=跳过，输入任意字符后回车=执行】"
  local input=""
  IFS= read -r "input?➤ "
  [[ -n "$input" ]]
}
# 收集并校验用户输入，决定后续执行路径。
confirm_yes() {
  echo ""
  warn_echo "⚠ $1"
  gray_echo "危险操作必须输入 YES 后回车；其它输入一律取消。"
  local input=""
  IFS= read -r "input?➤ "
  [[ "$input" == "YES" ]]
}
# 封装 inject_shellenv_block 对应的独立处理逻辑。
inject_shellenv_block() {
  local profile_file="$1"
  local shellenv_cmd="$2"
  local header="# >>> Homebrew 环境变量 >>>"
  [[ -z "$profile_file" || -z "$shellenv_cmd" ]] && { error_echo "缺少参数：inject_shellenv_block <profile_file> <shellenv_cmd>"; return 1; }
  mkdir -p "$(dirname "$profile_file")"
  touch "$profile_file"
  if grep -Fq "$shellenv_cmd" "$profile_file" 2>/dev/null; then
    info_echo "已存在 Homebrew shellenv：$profile_file"
  elif grep -Fq "$header" "$profile_file" 2>/dev/null; then
    info_echo "已存在 Homebrew 环境变量块：$profile_file"
  else
    {
      echo ""
      echo "$header"
      echo "$shellenv_cmd"
    } >> "$profile_file"
    success_echo "已写入 Homebrew shellenv：$profile_file"
  fi
  eval "$shellenv_cmd" || true
}
# 封装 activate_homebrew_shellenv 对应的独立处理逻辑。
activate_homebrew_shellenv() {
  local arch="$(get_cpu_arch)"
  local brew_bin=""
  brew_bin="$(jobs_brew_find)" || { error_echo "没有健康 Homebrew，停止激活。"; return 1; }
  JOBS_HOMEBREW_BIN="$brew_bin"
  jobs_brew_activate || { error_echo "Homebrew 激活或命令层复检失败。"; return 1; }

  local shell_name="${SHELL##*/}"
  local profile_file=""
  case "$shell_name" in
    zsh)  profile_file="$HOME/.zprofile" ;;
    bash) profile_file="$HOME/.bash_profile" ;;
    *)    profile_file="$HOME/.profile" ;;
  esac
  inject_shellenv_block "$profile_file" "eval \"\$(${brew_bin} shellenv)\"" || return 1
  eval "$(${brew_bin} shellenv)"
}
# 执行已经拆分完成的独立业务步骤。
run_brew_health_update() {
  info_echo "正在执行 Homebrew 健康更新..."
  brew update  || { error_echo "brew update 失败"; return 1; }
  brew upgrade || { error_echo "brew upgrade 失败"; return 1; }
  brew cleanup || { error_echo "brew cleanup 失败"; return 1; }
  brew doctor  || warn_echo "brew doctor 有警告，请按输出处理"
  brew -v      || warn_echo "打印 brew 版本失败，可忽略"
  success_echo "Homebrew 健康更新完成"
}
# 执行对应的环境配置或同步处理。
install_homebrew() {
  local arch="$(get_cpu_arch)"
  local brew_bin=""

  if ! brew_bin="$(jobs_brew_find)"; then
    warn_echo "未检测到 Homebrew，准备按架构安装：$arch"
    if [[ "$arch" == "arm64" ]]; then
      jobs_brew_install_or_exit || { error_echo "Homebrew 安装失败（arm64）"; return 1; }
      brew_bin="${JOBS_HOMEBREW_BIN:-$(jobs_brew_find 2>/dev/null || true)}"
    else
      jobs_brew_install_or_exit || { error_echo "Homebrew 安装失败（x86_64）"; return 1; }
      brew_bin="${JOBS_HOMEBREW_BIN:-$(jobs_brew_find 2>/dev/null || true)}"
    fi
    success_echo "Homebrew 安装完成"
    activate_homebrew_shellenv || exit 1
    return 0
  fi

  activate_homebrew_shellenv || exit 1
  info_echo "Homebrew 已安装。"
  if ask_run "是否执行 Homebrew 更新 / 升级 / 清理 / doctor？"; then
    run_brew_health_update || exit 1
  else
    note_echo "已跳过 Homebrew 更新"
  fi
}
# 封装 brew_install_or_upgrade 对应的独立处理逻辑。
brew_install_or_upgrade() {
  local formula="$1"
  [[ -z "$formula" ]] && return 1
  install_homebrew || return 1
  if ! brew list --formula "$formula" >/dev/null 2>&1 && ! command -v "$formula" >/dev/null 2>&1; then
    note_echo "未检测到 $formula，正在安装..."
    brew install "$formula" || { error_echo "$formula 安装失败"; return 1; }
    success_echo "$formula 安装完成"
  else
    info_echo "$formula 已安装。"
    if ask_run "是否升级 $formula？"; then
      brew upgrade "$formula" || warn_echo "$formula 可能已是最新或升级失败，请检查输出"
      brew cleanup || true
    else
      note_echo "已跳过 $formula 升级"
    fi
  fi
}
# 展示脚本用途和影响范围，并在执行前等待用户确认。
show_script_intro_and_wait() {
  clear
  print -r -- '============================== 脚本内置自述 ==============================' | jobs_intro_style title
  print -r -- '脚本名称：【MacOS】📹双击制作Android模拟器录屏Gif.command' | jobs_intro_style title
  print -r -- '核心用途：执行“📹双击制作Android模拟器录屏Gif”对应的移动端项目自动化任务。' | jobs_intro_style body
  print -r -- '影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。' | jobs_intro_style body
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。' | jobs_intro_style body
  print -r -- '============================================================================' | jobs_intro_style title
  echo "" | jobs_intro_style body
  read -r "?👉 已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：" _
}
# 执行已经拆分完成的独立业务步骤。
run_original_logic() {
  # ============================= 原脚本业务逻辑区 =============================
  set -euo pipefail

  # ✅ 日志与输出函数（注意：这些输出走 stdout，仅用于展示，不参与命令替换）
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  color_echo()     { log "\033[1;32m$1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warm_echo()      { log "\033[1;33m$1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  err_echo()       { log "\033[1;31m$1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  gray_echo()      { log "\033[0;90m$1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  bold_echo()      { log "\033[1m$1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  underline_echo() { log "\033[4m$1\033[0m"; }
  # 封装 pause_enter 对应的独立处理逻辑。
  pause_enter() {
    echo -n $'\n'"按回车继续..."$'\n' | tee -a "$LOG_FILE"
    IFS= read -r _
  }

  # ✅ 参数默认值
  DURATION=""          # 定时模式秒数；为空则可选交互模式
  INTERACTIVE=false    # 交互模式（回车停止）
  SIZE=""              # 例如 1080x1920；空=自动检测
  BITRATE="8000000"    # 8Mbps
  OUTPUT_DIR=""        # 输出目录；空=交互（回车=桌面）
  SERIAL=""            # 指定设备序列号
  SEG_LIMIT=180        # screenrecord 单段上限（秒）
  MERGE_AFTER=false    # 定时分段是否合并
  SKIP_GIF_PROMPT=false  # 若为 true：不询问 GIF（默认询问）

  # ✅ 运行结果（全局输出）
  typeset -ga RECORDED_FILES=()
  typeset -g  RECORD_MAIN_FILE=""
  # ✅ 使用说明（展示用，走 stdout）
  usage() {
    cat <<EOF
  用法: $0 [选项]
    -d <seconds>    定时录制时长（秒）。>180 自动分段
    -i              交互模式：开始后按回车立即停止，并显示计时
    -s <WxH>         分辨率，如 1080x1920；留空自动检测
    -b <bitrate>    码率，默认 8000000（8Mbps）
    -o <dir>        输出目录；不提供将提示输入（回车=桌面）
    -S <serial>     指定设备序列号；不提供则用 fzf 选择
    -m              定时模式分段后自动用 ffmpeg 合并
    -h              显示帮助
EOF
  }
  # ✅ 字符清洗（纯函数，stdout 仅返回值）
  strip_crlf() { printf "%s" "$1" | tr -d '\r\n'; }
  # ✅ 参数解析
  parse_args() {
    while getopts ":d:is:b:o:S:mh" opt; do
      case $opt in
        d) DURATION="$OPTARG" ;;
        i) INTERACTIVE=true ;;
        s) SIZE="$OPTARG" ;;
        b) BITRATE="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        S) SERIAL="$OPTARG" ;;
        m) MERGE_AFTER=true ;;
        h) usage; exit 0 ;;
        \?) error_echo "未知参数: -$OPTARG"; usage; exit 2 ;;
        :) error_echo "参数 -$OPTARG 需要值"; usage; exit 2 ;;
      esac
    done
  }
  # ================================== Homebrew/依赖（为 GIF 与合并服务） ==================================
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }
  # 封装 inject_shellenv_block 对应的独立处理逻辑。
  inject_shellenv_block() {
    local profile_file="$1"
    local shellenv_cmd="$2"
    local header="# >>> Homebrew 环境变量 >>>"
    [[ -z "$profile_file" || -z "$shellenv_cmd" ]] && { error_echo "缺少参数：inject_shellenv_block <profile_file> <shellenv_cmd>"; return 1; }
    mkdir -p "$(dirname "$profile_file")"
    touch "$profile_file"
    if grep -Fq "$shellenv_cmd" "$profile_file" 2>/dev/null; then
      info_echo "已存在 Homebrew shellenv：$profile_file"
    elif grep -Fq "$header" "$profile_file" 2>/dev/null; then
      info_echo "已存在 Homebrew 环境变量块：$profile_file"
    else
      {
        echo ""
        echo "$header"
        echo "$shellenv_cmd"
      } >> "$profile_file"
      success_echo "已写入 Homebrew shellenv：$profile_file"
    fi
    eval "$shellenv_cmd" || true
  }
  # 执行对应的环境配置或同步处理。
  install_homebrew_if_needed() {
    if command -v brew >/dev/null 2>&1; then
      return 0
    fi

    local arch shell_path profile_file brew_bin shellenv_cmd
    arch="$(get_cpu_arch)"
    shell_path="${SHELL##*/}"
    profile_file=""

    warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"

    if [[ "$arch" == "arm64" ]]; then
      jobs_brew_install_or_exit || {
        error_echo "❌ Homebrew 安装失败（arm64）"
        return 1
      }
      brew_bin="${JOBS_HOMEBREW_BIN:-$(jobs_brew_find 2>/dev/null || true)}"
    else
      jobs_brew_install_or_exit || {
        error_echo "❌ Homebrew 安装失败（x86_64）"
        return 1
      }
      brew_bin="${JOBS_HOMEBREW_BIN:-$(jobs_brew_find 2>/dev/null || true)}"
    fi

    success_echo "✅ Homebrew 安装成功"

    shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""
    case "$shell_path" in
      zsh)  profile_file="$HOME/.zprofile" ;;
      bash) profile_file="$HOME/.bash_profile" ;;
      *)    profile_file="$HOME/.profile" ;;
    esac

    inject_shellenv_block "$profile_file" "$shellenv_cmd" || {
      warn_echo "⚠️ brew shellenv 自动注入失败，你可手动执行：$shellenv_cmd"
      eval "$shellenv_cmd" || true
    }

    return 0
  }
  # 封装 brew_install_pkg 对应的独立处理逻辑。
  brew_install_pkg() {
    local pkg="$1"
    install_homebrew_if_needed || return 1
    info_echo "📦 安装依赖：$pkg"
    brew install "$pkg" || return 1
    success_echo "✅ 已安装：$pkg"
  }
  # 检查当前运行条件是否满足后续流程要求。
  ensure_ffmpeg() {
    if command -v ffmpeg >/dev/null 2>&1; then
      return 0
    fi
    warn_echo "🧩 未检测到 ffmpeg，将通过 Homebrew 安装..."
    brew_install_pkg ffmpeg || { error_echo "❌ ffmpeg 安装失败"; return 1; }
  }
  # 检查当前运行条件是否满足后续流程要求。
  ensure_gifski() {
    if command -v gifski >/dev/null 2>&1; then
      return 0
    fi
    warn_echo "🧩 未检测到 gifski，将通过 Homebrew 安装..."
    brew_install_pkg gifski || { error_echo "❌ gifski 安装失败"; return 1; }
  }
  # ================================== 基础依赖检查 ==================================
  require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
      error_echo "未找到命令：$1"
      return 1
    fi
    return 0
  }
  # 检查当前运行条件是否满足后续流程要求。
  check_requirements() {
    require_cmd adb || { error_echo "请先安装 Android Platform Tools（adb）"; exit 1; }
    if ! command -v fzf >/dev/null 2>&1; then
      warn_echo "未找到 fzf，将在多设备时使用首个设备。建议：brew install fzf"
    fi
    # 合并需要 ffmpeg：缺失则尝试自动安装
    if $MERGE_AFTER; then
      ensure_ffmpeg || exit 1
    fi
  }
  # ✅ 设备选择（stdout 只输出 serial；其余提示走 stderr 或由外层打印）
  pick_device() {
    if [[ -n "$SERIAL" ]]; then
      printf "%s" "$SERIAL"
      return
    fi
    local list count
    list=$(adb devices | awk 'NR>1 && $2=="device"{print $1}')
    count=$(echo "$list" | wc -l | tr -d ' ')
    if [[ "$count" -eq 0 ]]; then
      echo >&2 "✖ 未发现在线设备/模拟器，请先启动 Android 模拟器。"
      exit 1
    fi
    if [[ "$count" -eq 1 ]] || ! command -v fzf >/dev/null 2>&1; then
      printf "%s" "$(echo "$list" | head -n1)"
      return
    fi
    printf "%s" "$(echo "$list" | fzf --prompt="选择设备> " --height=40% --reverse)"
  }
  # ✅ 清理路径（stdout 只输出路径）
  sanitize_path() {
    local p="$1"
    p=${p//$'\r'/}; p=${p//$'\n'/}; p=${p/#file:\/\//}; p=${p//\\ / }; p=${p%/}
    p=${p#\'}; p=${p%\'}
    p=${p#\"}; p=${p%\"}
    printf "%s" "$p"
  }
  # ✅ 输出目录提示（提示走 stderr；stdout 只输出路径）
  prompt_output_dir() {
    if [[ -n "$OUTPUT_DIR" ]]; then
      printf "%s" "$(sanitize_path "$OUTPUT_DIR")"
      return
    fi
    echo >&2
    echo >&2 "📁 将保存目录【拖入此窗口】或回车用桌面："
    local input
    IFS= read -r input
    if [[ -z "$input" ]]; then
      printf "%s" "$HOME/Desktop"
    else
      printf "%s" "$(sanitize_path "$input")"
    fi
  }
  # ✅ 自动检测分辨率（stdout 只输出尺寸）
  detect_size() {
    local s="$1"
    local res
    res=$(adb -s "$s" shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' '/Physical size:/ {print $2}')
    [[ -z "$res" ]] && { printf "%s" "1080x1920"; return; }
    printf "%s" "$res"
  }
  # ✅ 向上取整（纯函数）
  ceil_div() { local a=$1 b=$2; echo $(( (a + b - 1) / b )); }
  # ✅ 单段录制（定时模式，用 --time-limit）
  record_one_timed() {
    local serial="$1" time_limit_raw="$2" size="$3" bitrate="$4" local_path_raw="$5"
    local time_limit local_path
    time_limit="$(strip_crlf "$time_limit_raw")"
    local_path="$(strip_crlf "$local_path_raw")"
    info_echo "开始录制：${time_limit}s，分辨率=${size}，码率=${bitrate} → $local_path"
    adb -s "$serial" shell rm -f "/sdcard/tmp_record.mp4" >/dev/null 2>&1 || true
    adb -s "$serial" shell -- screenrecord \
      --time-limit "$time_limit" \
      --size "$size" \
      --bit-rate "$bitrate" \
      /sdcard/tmp_record.mp4
    info_echo "导出文件..."
    adb -s "$serial" pull /sdcard/tmp_record.mp4 "$local_path" >/dev/null
    adb -s "$serial" shell rm -f /sdcard/tmp_record.mp4 >/dev/null 2>&1 || true
    success_echo "保存：$local_path"
  }
  # ✅ 单段录制（交互模式：回车停止 + 实时计时）
  record_one_interactive() {
    local serial="$1" size="$2" bitrate="$3" local_path_raw="$4"
    local local_path; local_path="$(strip_crlf "$local_path_raw")"
    info_echo "开始录制（按回车即可停止） → $local_path"
    adb -s "$serial" shell rm -f "/sdcard/tmp_record.mp4" >/dev/null 2>&1 || true
    adb -s "$serial" shell -- screenrecord \
      --size "$size" \
      --bit-rate "$bitrate" \
      /sdcard/tmp_record.mp4 &
    local rec_pid=$!

    local start_time=$(date +%s)
    {
      while kill -0 $rec_pid 2>/dev/null; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        printf "\r⏱ 已录制：%3d 秒  按回车停止..." "$elapsed" >&2
        sleep 1
      done
    } &
    local timer_pid=$!

    IFS= read -r  # 回车停止
    kill $rec_pid 2>/dev/null || true
    wait $rec_pid 2>/dev/null || true
    kill $timer_pid 2>/dev/null || true
    wait $timer_pid 2>/dev/null || true
    echo >&2 ""  # 换行（stderr）

    info_echo "导出文件..."
    adb -s "$serial" pull /sdcard/tmp_record.mp4 "$local_path" >/dev/null
    adb -s "$serial" shell rm -f /sdcard/tmp_record.mp4 >/dev/null 2>&1 || true
    success_echo "保存：$local_path"
  }
  # ✅ 选择时长或进入交互模式（提示走 stderr，设置全局变量，不返回）
  read_or_choose_mode() {
    if $INTERACTIVE; then
      typeset -g DURATION=""
      return
    fi
    echo >&2
    local d=""
    echo >&2 "⏱ 录制时长（秒；直接回车=进入交互模式）："
    IFS= read -r d
    d=$(printf "%s" "${d:-}" | tr -d '\r\n\t ')
    if [[ -z "$d" ]]; then
      typeset -g INTERACTIVE=true
      typeset -g DURATION=""
      return
    fi
    if ! [[ "$d" =~ ^[0-9]+$ ]]; then
      echo >&2 "✖ 时长必须是数字秒数。"
      exit 2
    fi
    typeset -g INTERACTIVE=false
    typeset -g DURATION="$d"
  }
  # ✅ 执行录制（定时/交互 + 合并）
  do_record() {
    local serial="$1" output_dir_raw="$2" size="$3" duration_raw="$4"
    local output_dir duration ts outfile
    local -a files=()

    output_dir="$(sanitize_path "$output_dir_raw")"
    duration="$(strip_crlf "$duration_raw")"
    mkdir -p "$output_dir"

    if $INTERACTIVE; then
      ts="$(date +%Y%m%d_%H%M%S)"
      printf -v outfile "%s/emulator_%s_interactive.mp4" "$output_dir" "$ts"
      record_one_interactive "$serial" "$size" "$BITRATE" "$outfile"
      files+=("$outfile")
    else
      if (( duration <= SEG_LIMIT )); then
        ts="$(date +%Y%m%d_%H%M%S)"
        printf -v outfile "%s/emulator_%s_%ss.mp4" "$output_dir" "$ts" "$duration"
        record_one_timed "$serial" "$duration" "$size" "$BITRATE" "$outfile"
        files+=("$outfile")
      else
        warn_echo "时长 $duration 秒 > ${SEG_LIMIT} 秒，自动分段"
        local segments remain this_len i
        segments=$(ceil_div "$duration" "$SEG_LIMIT")
        remain="$duration"; i=1
        while (( i <= segments )); do
          this_len=$(( remain > SEG_LIMIT ? SEG_LIMIT : remain ))
          ts="$(date +%Y%m%d_%H%M%S)"
          printf -v outfile "%s/emulator_%s_part%d_of_%d_%ss.mp4" \
            "$output_dir" "$ts" "$i" "$segments" "$this_len"
          record_one_timed "$serial" "$this_len" "$size" "$BITRATE" "$outfile"
          files+=("$outfile")
          remain=$(( remain - this_len ))
          (( i++ ))
        done
      fi

      # 合并分段
      if $MERGE_AFTER && ((${#files[@]} > 1)); then
        ensure_ffmpeg || { error_echo "❌ 缺少 ffmpeg，无法合并"; exit 1; }

        info_echo "开始合并 ${#files[@]} 个分段..."
        local list_file="$output_dir/files.txt"
        : > "$list_file"
        for f in "${files[@]}"; do
          printf "file '%s'\n" "$(basename "$f")" >> "$list_file"
        done

        local merge_ts merged_file
        merge_ts="$(date +%Y%m%d_%H%M%S)"
        merged_file="$output_dir/emulator_${merge_ts}_merged.mp4"

        (cd "$output_dir" && ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i files.txt -c copy "$(basename "$merged_file")")
        success_echo "合并完成：$merged_file"
        # 如需删除分段文件与 files.txt：rm -f "${files[@]}" "$list_file"

        # 合并后将主文件指向 merged_file
        files+=("$merged_file")
        typeset -g RECORD_MAIN_FILE="$merged_file"
      fi
    fi

    typeset -ga RECORDED_FILES=("${files[@]}")

    # 若尚未设置主文件：优先单文件，否则取最后一个
    if [[ -z "${RECORD_MAIN_FILE:-}" ]]; then
      if ((${#files[@]} == 1)); then
        typeset -g RECORD_MAIN_FILE="${files[1]}"
      elif ((${#files[@]} > 1)); then
        typeset -g RECORD_MAIN_FILE="${files[-1]}"
      else
        typeset -g RECORD_MAIN_FILE=""
      fi
    fi
  }
  # ================================== GIF 转换（可选） ==================================
  pick_video_for_gif() {
    # 输入：RECORDED_FILES；输出：选择的视频路径（stdout）
    local -a candidates=("${RECORDED_FILES[@]}")
    if ((${#candidates[@]} == 0)); then
      printf "%s" ""
      return
    fi
    if ((${#candidates[@]} == 1)); then
      printf "%s" "${candidates[1]}"
      return
    fi

    # 多文件：优先给 fzf 选择，否则默认主文件 / 最后一个
    if command -v fzf >/dev/null 2>&1; then
      local chosen
      chosen="$(printf "%s\n" "${candidates[@]}" | fzf --prompt="选择要转 GIF 的视频> " --height=40% --reverse)"
      printf "%s" "${chosen:-$RECORD_MAIN_FILE}"
    else
      printf "%s" "${RECORD_MAIN_FILE:-${candidates[-1]}}"
    fi
  }
  # 封装 convert_recording_to_gif 对应的独立处理逻辑。
  convert_recording_to_gif() {
    # 仅在用户确认后安装依赖、转换
    local input_file="$1"

    if [[ -z "${input_file:-}" || ! -f "$input_file" ]]; then
      warn_echo "⚠️ 未找到可转换的视频文件，跳过 GIF 生成"
      return 0
    fi

    local answer="Y"
    if ! $SKIP_GIF_PROMPT; then
      echo ""
      echo -n "✨ 是否将该视频转换为 GIF？(Y/n)： "
      IFS= read -r answer
      answer="${answer:-Y}"
    fi

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      info_echo "⏭️ 用户选择不生成 GIF"
      return 0
    fi

    # 确保依赖
    ensure_ffmpeg || return 1
    ensure_gifski || return 1

    # 询问 GIF 参数
    local gif_width gif_fps
    echo -n "📏 GIF 宽度（默认 540）： "
    IFS= read -r gif_width
    gif_width="${gif_width:-540}"

    echo -n "🎞 GIF 帧率 fps（默认 20）： "
    IFS= read -r gif_fps
    gif_fps="${gif_fps:-20}"

    # 规范化输入路径
    local input_abs input_dir input_base frame_dir output_gif
    input_abs="$(cd "$(dirname "$input_file")" && pwd)/$(basename "$input_file")"
    input_dir="$(dirname "$input_abs")"
    input_base="$(basename "$input_abs" .mp4)"
    frame_dir="${input_dir}/${input_base}_frames_$(date +%s)"
    output_gif="${input_dir}/${input_base}.gif"

    mkdir -p "$frame_dir" || { error_echo "❌ 创建帧目录失败：$frame_dir"; return 1; }

    info_echo "🔧 使用 ffmpeg 导出 PNG 帧..."
    (
      cd "$frame_dir" || exit 1
      ffmpeg -y -hide_banner -loglevel error -i "$input_abs" -vf "fps=${gif_fps},scale=${gif_width}:-1:flags=lanczos" frame_%04d.png
    ) || { error_echo "❌ ffmpeg 导出帧失败"; return 1; }

    info_echo "✨ 使用 gifski 合成高质量 GIF..."
    (
      cd "$frame_dir" || exit 1
      gifski -o "$output_gif" --fps "$gif_fps" frame_*.png
    ) || { error_echo "❌ gifski 生成 GIF 失败"; return 1; }

    success_echo "🎉 GIF 生成完成：$output_gif"

    # 询问是否清理帧目录
    local clean_answer="Y"
    echo -n "🧹 是否删除临时帧文件夹？(Y/n)： "
    IFS= read -r clean_answer
    clean_answer="${clean_answer:-Y}"
    if [[ "$clean_answer" =~ ^[Yy]$ ]]; then
      rm -rf "$frame_dir"
      info_echo "🧼 已删除临时帧目录：$frame_dir"
    else
      note_echo "📂 已保留帧目录：$frame_dir"
    fi

    open "$output_gif" >/dev/null 2>&1 || true
  }
  # 封装 open_video_file 对应的独立处理逻辑。
  open_video_file() {
    local f="$1"
    [[ -z "$f" || ! -f "$f" ]] && return 0
    open "$f" >/dev/null 2>&1 || true
  }
  # ================================== 主流程 ==================================
  main() {
    highlight_echo "Android 模拟器录屏 | 定时/交互 / fzf 选择 / 拖拽目录 / 分段与合并 / 可选转 GIF"

    # 1) 解析参数与依赖检查
    parse_args "$@"
    check_requirements

    # 2) 选择设备（pick_device 的 stdout 仅 serial）
    local serial
    serial="$(pick_device)"
    info_echo "选择设备：$serial"

    # 3) 确定输出目录（prompt_output_dir 的 stdout 仅路径）
    local output_dir
    output_dir="$(prompt_output_dir)"
    success_echo "输出目录：$output_dir"

    # 4) 获取分辨率（detect_size 的 stdout 仅尺寸）
    local size
    if [[ -z "$SIZE" ]]; then
      size="$(detect_size "$serial")"
    else
      size="$SIZE"
    fi
    success_echo "使用分辨率：$size"

    # 5) 选择模式：-i 交互；否则询问时长（提示走 stderr，更新全局变量）
    if [[ -n "$DURATION" && "$DURATION" =~ ^[0-9]+$ ]]; then
      INTERACTIVE=false
    else
      read_or_choose_mode
    fi

    # 6) 执行录制（交互或定时；合并仅在定时模式生效）
    do_record "$serial" "$output_dir" "$size" "$DURATION"

    # 7) 打开录制结果（优先主文件）
    if [[ -n "${RECORD_MAIN_FILE:-}" && -f "$RECORD_MAIN_FILE" ]]; then
      success_echo "🎉 录制完成：$RECORD_MAIN_FILE"
      open_video_file "$RECORD_MAIN_FILE"
    elif ((${#RECORDED_FILES[@]} > 0)); then
      success_echo "🎉 录制完成：${RECORDED_FILES[1]}"
      open_video_file "${RECORDED_FILES[1]}"
    else
      warn_echo "⚠️ 未找到录制输出文件（可能导出失败）"
    fi

    # 8) 可选：转 GIF（像 iOS 脚本一样，录屏结束后再询问）
    local gif_input
    gif_input="$(pick_video_for_gif)"
    convert_recording_to_gif "$gif_input" || warn_echo "GIF 生成失败（已保留视频）"

    # 9) 收尾
    success_echo "全部完成 ✅"
  }

  main "$@"

  # =========================== 原脚本业务逻辑区结束 ===========================
}
# 编排脚本的高层业务流程。
# 初始化脚本运行环境，并集中承载原有的顶层执行逻辑。
initialize_script_runtime() {
  : > "$LOG_FILE"
}
# 编排脚本的高层业务流程。
main() {
  # 展示脚本内置自述，并按运行入口完成防误触确认。
  show_script_intro_and_wait
  # 初始化 Shell 选项、日志、依赖和入口运行状态。
  initialize_script_runtime
  # 执行 run_original_logic 对应的核心业务步骤。
  run_original_logic "$@"
  # 输出脚本执行结果、摘要和日志位置。
  success_echo "脚本执行结束。日志：$LOG_FILE"
}

main "$@"
