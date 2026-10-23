#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】⚙️自动化替换Flutter图片资源.command
# - 核心用途：执行“⚙️自动化替换Flutter图片资源”对应的移动端项目自动化任务。
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
  print -r -- '脚本名称：【MacOS】⚙️自动化替换Flutter图片资源.command' | jobs_intro_style title
  print -r -- '核心用途：执行“⚙️自动化替换Flutter图片资源”对应的移动端项目自动化任务。' | jobs_intro_style body
  print -r -- '影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。' | jobs_intro_style body
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。' | jobs_intro_style body
  print -r -- '============================================================================' | jobs_intro_style title
  echo "" | jobs_intro_style body
  read -r "?👉 已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：" _ || exit 1
}
# 执行已经拆分完成的独立业务步骤。
run_original_logic() {
  # ============================= 原脚本业务逻辑区 =============================
  # =============================================================================
  # 名称：Flutter 启动图 / App 图标自动替换（macOS / Zsh）
  # 说明：从脚本目录的【启动图】与【App图标】复制到目标 Flutter 项目的 ./assets 根目录，
  #      然后执行 clean / 清理平台旧资源 / 替换 iOS LaunchImage.imageset / pub get /
  #      生成图标 / 生成启动图，最后验证产物并自动打开相关目录。失败会回到循环继续问。
  # 依赖：zsh、awk、sed、grep、cp、rsync(可选)、flutter、dart、open(系统)
  # =============================================================================

  set +x +v
  unsetopt XTRACE VERBOSE
  set -o pipefail
  setopt NO_BEEP ERR_RETURN
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8
  export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

  # =============================================================================
  # 日志与彩色输出（记录到 /tmp/<脚本名>.log）
  # =============================================================================
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
  : > "$LOG_FILE" 2>/dev/null || touch "$LOG_FILE"

  if [[ -x /usr/bin/tee ]]; then
    _TEE=/usr/bin/tee
  elif command -v tee >/dev/null 2>&1; then
    _TEE=$(command -v tee)
  else
    _TEE=""
  fi
  # 封装 _log_write 对应的独立处理逻辑。
  _log_write() {
    if [[ -n "$_TEE" ]]; then
      printf "%b\n" "$1" | "$_TEE" -a "$LOG_FILE"
    else
      printf "%b\n" "$1"
      printf "%b\n" "$1" >> "$LOG_FILE"
    fi
  }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  log()            { _log_write "$1"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  info_echo()      { _log_write "\033[1;34mℹ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  success_echo()   { _log_write "\033[1;32m✔ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warn_echo()      { _log_write "\033[1;33m⚠ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  note_echo()      { _log_write "\033[1;35m➤ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  error_echo()     { _log_write "\033[1;31m✖ $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  highlight_echo() { _log_write "\033[1;36m🔹 $1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  gray_echo()      { _log_write "\033[0;90m$1\033[0m"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  bold_echo()      { _log_write "\033[1m$1\033[0m"; }
  # =============================================================================
  # 安全读入（子壳静音 trace，从 /dev/tty 读入并输出赋值文本，父壳静默 eval）
  # 用法：safe_read 变量名
  # =============================================================================
  safe_read() {
    local __var="$1"
    [[ -z "$__var" ]] && return 1
    {
      setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
      set +x +v
      # 封装 exec 对应的独立处理逻辑。
      exec {__sink_fd}>/dev/null
      typeset -gi XTRACEFD=$__sink_fd
      __line="$(/usr/bin/head -n1 </dev/tty | /usr/bin/sed -e $'s/\r$//')"
      printf '%s=%q\n' "$__var" "$__line"
      # 封装 exec 对应的独立处理逻辑。
      exec {__sink_fd}>&-
    } | {
      setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
      set +x +v
      builtin read -r __assign
      eval "$__assign"
    }
  }

  # =============================================================================
  # 路径配置
  # =============================================================================
  SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
  SRC_SPLASH="$SCRIPT_DIR/启动图"
  SRC_ICONS="$SCRIPT_DIR/App图标"
  PROJECT_ROOT=""
  # =============================================================================
  # 自述与配置模板
  # =============================================================================
  print_intro() {
    echo "" > "$LOG_FILE"
    log "" | jobs_intro_style body
    bold_echo "══════════════════════════════════════════════════════════════════" | jobs_intro_style title
    bold_echo "  Flutter 启动图 / App 图标自动替换（macOS / Zsh）" | jobs_intro_style title
    bold_echo "══════════════════════════════════════════════════════════════════" | jobs_intro_style title
    log "" | jobs_intro_style body
    note_echo "本脚本会执行：" | jobs_intro_style title
    log "  1) 覆盖 ./assets：删除 icon.png / launch_image.png → 复制脚本同级「App图标」「启动图」顶层文件" | jobs_intro_style body
    log "  2) flutter clean（清理构建缓存）" | jobs_intro_style body
    log "  3) 清理平台旧资源：iOS AppIcon.appiconset/* 与 Android res/*" | jobs_intro_style body
    log "  4) 替换 iOS LaunchImage.imageset 内的图片（保留 Contents.json）" | jobs_intro_style body
    log "  5) flutter pub get（下载依赖并生成 .dart_tool 配置）" | jobs_intro_style body
    log "  6) flutter pub run flutter_launcher_icons（若配置了，生成 App 图标）" | jobs_intro_style body
    log "  7) dart/flutter pub run flutter_native_splash（若配置了，生成启动图）" | jobs_intro_style body
    log "  8) 验证并自动打开 iOS / Android 资源目录" | jobs_intro_style body
    log "" | jobs_intro_style body
    note_echo "请确保 pubspec.yaml 至少包含如下配置：" | jobs_intro_style title
    gray_echo '
  dev_dependencies:
    flutter_launcher_icons: any
  
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: "assets/icon.png"
    adaptive_icon_background: "#FFFFFF"
    adaptive_icon_foreground: "assets/icon.png"
    adaptive_icon_monochrome: "assets/icon.png"
    min_sdk_android: 19

  flutter:
    uses-material-design: true
    assets:
      - assets/launch_image.png
  ' | jobs_intro_style body
    highlight_echo "在线取色器：https://photokit.com/colors/color-picker/?lang=zh" | jobs_intro_style title
    log "" | jobs_intro_style body
    bold_echo "按回车开始..." | jobs_intro_style body
    safe_read _
  }
  # =============================================================================
  # 自检资源目录
  # =============================================================================
  check_local_asset_dirs() {
    local ok=1
    [[ -d "$SRC_SPLASH" ]] && success_echo "已检测到：$SRC_SPLASH" || { error_echo "未找到：$SRC_SPLASH"; ok=0; }
    [[ -d "$SRC_ICONS"  ]] && success_echo "已检测到：$SRC_ICONS"  || { error_echo "未找到：$SRC_ICONS";  ok=0; }
    (( ok )) || { error_echo "缺少资源目录，无法继续。"; return 1 }
  }
  # =============================================================================
  # 判断 Flutter 项目根目录
  # =============================================================================
  is_flutter_project_root() {
    local dir="$1"
    [[ -f "$dir/pubspec.yaml" && -d "$dir/lib" ]]
  }
  # =============================================================================
  # 询问 Flutter 项目根目录（干净无回显；q/Q 退出；空输入继续）
  # =============================================================================
  prompt_project_root() {
    while true; do
      printf "请输入 Flutter 项目根目录路径（q 退出）： "
      {
        setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
        set +x +v
        # 封装 exec 对应的独立处理逻辑。
        exec {__sink_fd}>/dev/null
        typeset -gi XTRACEFD=$__sink_fd
        __line="$(/usr/bin/head -n1 </dev/tty | /usr/bin/sed -e $'s/\r$//')"
        printf 'path_in=%q\n' "$__line"
        # 封装 exec 对应的独立处理逻辑。
        exec {__sink_fd}>&-
      } | {
        setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
        set +x +v
        builtin read -r __assign
        eval "$__assign"
      }

      if [[ "$path_in" == "q" || "$path_in" == "Q" ]]; then
        return 1
      fi
      if [[ -z "$path_in" ]]; then
        printf "\033[1;33m⚠ 未输入路径，请重试。\033[0m\n"
        continue
      fi

      local target_path="${~path_in}"
      target_path="$(cd "$target_path" 2>/dev/null && pwd || true)"
      if [[ -n "$target_path" && -d "$target_path" && -f "$target_path/pubspec.yaml" && -d "$target_path/lib" ]]; then
        printf "\033[1;32m✔ 项目根目录：%s\033[0m\n" "$target_path"
        PROJECT_ROOT="$target_path"
        return 0
      else
        printf "\033[1;33m⚠ 不是有效的 Flutter 项目根目录（需 pubspec.yaml + lib/）。请重试。\033[0m\n"
      fi
    done
  }
  # =============================================================================
  # 复制资源到 ./assets（覆盖模式）
  # - 先删除 assets/icon.png、assets/launch_image.png
  # - 把「App图标」「启动图」目录下的【顶层文件】复制到 assets 根目录
  # =============================================================================
  copy_assets_into_project() {
    local dest_assets="$PROJECT_ROOT/assets"
    mkdir -p "$dest_assets" || { error_echo "创建目录失败：$dest_assets"; return 1; }

    # 1) 删除旧的关键文件
    local removed=0
    for f in "icon.png" "launch_image.png"; do
      if [[ -e "$dest_assets/$f" ]]; then
        rm -f "$dest_assets/$f" && removed=1
      fi
    done
    (( removed )) && warn_echo "已删除旧文件：$dest_assets/icon.png、$dest_assets/launch_image.png" || gray_echo "未发现旧的 icon.png / launch_image.png"
    # 2) 复制两个源目录的【顶层文件】到 assets 根
    copy_top_files() {
      local src="$1"
      local dst="$2"
      local copied=0
      while IFS= read -r -d '' file; do
        cp -f "$file" "$dst/" && copied=1 && gray_echo "拷贝：$(basename "$file") → $dst"
      done < <(find "$src" -maxdepth 1 -type f -print0 2>/dev/null)
      (( copied )) || warn_echo "未在 $src 找到顶层文件（已跳过）"
    }

    copy_top_files "$SRC_ICONS"  "$dest_assets"
    copy_top_files "$SRC_SPLASH" "$dest_assets"

    # 3) 核验关键文件是否到位
    local miss=0
    [[ -f "$dest_assets/icon.png" ]] || { miss=1; error_echo "缺少：$dest_assets/icon.png（请把 icon.png 放到「App图标」目录顶层）"; }
    [[ -f "$dest_assets/launch_image.png" ]] || { miss=1; error_echo "缺少：$dest_assets/launch_image.png（请把 launch_image.png 放到「启动图」目录顶层）"; }
    (( miss )) && return 1

    success_echo "资源已就位到：$dest_assets（icon.png / launch_image.png 已覆盖）"
  }
  # =============================================================================
  # 清理平台旧资源（在 pub get 之前执行）
  # iOS:   <PROJECT_ROOT>/ios/Runner/Assets.xcassets/AppIcon.appiconset/*     全部删除
  # AND:   只删除 Android 图标相关文件（ic_launcher*），保留 values/、layout/ 等其余资源
  # =============================================================================
  purge_old_platform_assets() {
    cd "$PROJECT_ROOT" || { error_echo "进入项目目录失败，无法清理平台资源。"; return 1; }

    local ios_icons_dir="$PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    local android_res_dir="$PROJECT_ROOT/android/app/src/main/res"

    gray_echo "当前目录：$(pwd)"
    gray_echo "准备清理（Android 仅删除图标文件，不清空 res）："
    gray_echo "  - iOS: $ios_icons_dir/*"
    gray_echo "  - Android: $android_res_dir/**/ic_launcher*（含 .png/.webp/.xml 等）"

    printf "确认执行吗？(y/N)："
    local ans; safe_read ans
    if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
      warn_echo "已跳过清理平台资源。"
      return 0
    fi

    # ---------------- iOS：清空 AppIcon.appiconset（保留目录本身） ----------------
    mkdir -p "$ios_icons_dir"
    if [[ -d "$ios_icons_dir" ]]; then
      find "$ios_icons_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
      success_echo "已清空：$ios_icons_dir"
    else
      warn_echo "未找到 iOS 图标目录，跳过：$ios_icons_dir"
    fi

    # ---------------- Android：只删除 ic_launcher* 相关文件 ----------------
    mkdir -p "$android_res_dir"
    if [[ -d "$android_res_dir" ]]; then
      # 常见图标文件（尽量覆盖所有生成器变体；不会触碰其它业务资源）
      find "$android_res_dir" -type f \( \
          -name "ic_launcher.png"            -o -name "ic_launcher.webp"            -o \
          -name "ic_launcher_round.png"      -o -name "ic_launcher_round.webp"      -o \
          -name "ic_launcher.xml"            -o -name "ic_launcher_round.xml"       -o \
          -name "ic_launcher_monochrome.xml" -o \
          -name "ic_launcher_foreground.png" -o -name "ic_launcher_foreground.xml"  -o \
          -name "ic_launcher_background.png" -o -name "ic_launcher_background.xml"  \
        \) -print -delete 2>/dev/null || true

      # 有些生成器会把前景/背景放进 drawable(-*) 目录，再扫一遍更稳妥
      find "$android_res_dir" -type f -path "*/drawable*/ic_launcher_*" -print -delete 2>/dev/null || true
      # anydpi 变体（Android 8+/13+）
      find "$android_res_dir" -type f -path "*/mipmap-anydpi-*/ic_launcher*.xml" -print -delete 2>/dev/null || true

      success_echo "已删除 Android 旧图标文件（其余 res 未动）：$android_res_dir"
    else
      warn_echo "未找到 Android res 目录，跳过：$android_res_dir"
    fi
  }
  # =============================================================================
  # 替换 iOS 的 LaunchImage.imageset 内的图片（保留 Contents.json）
  # 来源：脚本同级「启动图」目录下的图片（png/jpg/jpeg/pdf，顶层文件）
  # =============================================================================
  replace_ios_launch_imageset() {
    local imageset="$PROJECT_ROOT/ios/Runner/Assets.xcassets/LaunchImage.imageset"
    mkdir -p "$imageset" || { error_echo "创建目录失败：$imageset"; return 1; }

    # 删除旧图片（保留 Contents.json）
    find "$imageset" -type f ! -name 'Contents.json' \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pdf' \) \
      -exec rm -f {} + 2>/dev/null || true

    # 从「启动图」目录复制顶层图片
    local copied=0
    while IFS= read -r -d '' file; do
      cp -f "$file" "$imageset/" && copied=1 && gray_echo "拷贝到 LaunchImage.imageset：$(basename "$file")"
    done < <(find "$SRC_SPLASH" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pdf' \) -print0 2>/dev/null)

    if (( copied )); then
      success_echo "已替换 iOS LaunchImage.imageset 图片资源：$imageset"
    else
      warn_echo "未在 $SRC_SPLASH 找到图片（png/jpg/jpeg/pdf），未替换 LaunchImage.imageset"
    fi
  }
  # =============================================================================
  # 执行 Flutter 构建步骤
  # =============================================================================
  run_flutter_steps() {
    cd "$PROJECT_ROOT" || { error_echo "进入项目目录失败。"; return 1; }
    command -v flutter >/dev/null 2>&1 || { error_echo "未找到 flutter 命令。"; return 1; }

    info_echo "正在清理构建缓存：flutter clean"
    flutter clean || warn_echo "flutter clean 失败"

    info_echo "清理平台旧资源（iOS AppIcon.appiconset 与 Android res）"
    purge_old_platform_assets || { warn_echo "平台资源清理步骤出现问题，已跳过。"; }

    info_echo "替换 iOS LaunchImage.imageset 内的图片资源"
    replace_ios_launch_imageset || { warn_echo "替换 LaunchImage.imageset 失败，已跳过。"; }

    info_echo "下载依赖：flutter pub get"
    flutter pub get || { error_echo "flutter pub get 失败"; return 1; }

    if grep -Eq '^[[:space:]]*flutter_launcher_icons[[:space:]]*:' pubspec.yaml; then
      info_echo "正在构建 App 图标：flutter pub run flutter_launcher_icons"
      flutter pub run flutter_launcher_icons || { error_echo "图标生成失败"; return 1; }
    else
      warn_echo "未检测到 flutter_launcher_icons 配置，跳过图标生成。"
    fi

    if grep -Eq '^[[:space:]]*flutter_native_splash[[:space:]]*:' pubspec.yaml; then
      info_echo "正在构建 App 启动图"
      dart run flutter_native_splash:create || flutter pub run flutter_native_splash:create || { error_echo "启动图生成失败"; return 1; }
    else
      info_echo "未检测到 flutter_native_splash 配置，跳过启动图生成。"
    fi

    success_echo "构建步骤完成"
  }
  # =============================================================================
  # 验证生成的资源 + 自动打开目录
  # =============================================================================
  open_dir_if_exists() {
    local d="$1" label="$2"
    if [[ -d "$d" ]]; then
      if command -v open >/dev/null 2>&1; then
        open "$d" >/dev/null 2>&1 &
        success_echo "已在 Finder 打开：$label（$d）"
      else
        warn_echo "当前环境无 open 命令，路径：$d"
      fi
    else
      warn_echo "未找到目录：$label（$d）"
    fi
  }
  # 检查当前运行条件是否满足后续流程要求。
  verify_outputs() {
    cd "$PROJECT_ROOT" || return

    local ios_icons_dir="$PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    local ios_launch_dir="$PROJECT_ROOT/ios/Runner/Assets.xcassets/LaunchImage.imageset"
    local android_res_dir="$PROJECT_ROOT/android/app/src/main/res"

    bold_echo "──────── 验证 iOS 资源 ────────"
    gray_echo "(iOS 相关的资源如下，如无输出则可能生成失败)"
    ls -1 "$ios_icons_dir"/*.png 2>/dev/null || true
    ls -1 "$ios_launch_dir"/* 2>/dev/null | grep -v 'Contents.json' || true

    bold_echo "──────── 验证 Android 资源 ────────"
    gray_echo "(Android 相关的资源如下，如无输出则可能生成失败)"
    ls -1 "$android_res_dir"/mipmap-*/ic_launcher.* 2>/dev/null || true

    # 自动打开三个目录（存在则打开）
    open_dir_if_exists "$ios_icons_dir"  "iOS 图标目录 AppIcon.appiconset"
    open_dir_if_exists "$ios_launch_dir" "iOS 启动图目录 LaunchImage.imageset"
    open_dir_if_exists "$android_res_dir" "Android 资源目录 res"

    success_echo "验证与打开目录步骤完成"
  }
  # =============================================================================
  # 主流程
  # =============================================================================
  main() {
    print_intro
    check_local_asset_dirs || return 1

    while true; do
      if ! prompt_project_root; then
        warn_echo "已取消。"
        break
      fi
      copy_assets_into_project || { error_echo "资源复制失败，回到循环。"; continue; }
      run_flutter_steps || { warn_echo "执行失败，回到循环。"; continue; }
      verify_outputs

      printf "是否再次处理其它项目？(y/N)："
      local again; safe_read again
      [[ "$again" == "y" || "$again" == "Y" ]] || { success_echo "全部完成，日志见：$LOG_FILE"; break; }
    done
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
  show_script_intro_and_wait # 展示脚本内置自述，并按运行入口完成防误触确认。
  initialize_script_runtime # 初始化 Shell 选项、日志、依赖和入口运行状态。
  run_original_logic "$@" # 执行 run_original_logic 对应的核心业务步骤。
  success_echo "脚本执行结束。日志：$LOG_FILE" # 输出脚本执行结果、摘要和日志位置。
}

main "$@"
