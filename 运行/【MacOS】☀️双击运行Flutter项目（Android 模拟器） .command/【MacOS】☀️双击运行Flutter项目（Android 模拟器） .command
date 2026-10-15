#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command
# - 核心用途：执行“☀️双击运行Flutter项目（Android 模拟器）”对应的移动端项目自动化任务。
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
# 初始化本次运行使用的日志文件。
initialize_script_runtime() {
  : > "$LOG_FILE"
}
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
  print -r -- '脚本名称：【MacOS】☀️双击运行Flutter项目（Android 模拟器） .command' | jobs_intro_style title
  print -r -- '核心用途：执行“☀️双击运行Flutter项目（Android 模拟器）”对应的移动端项目自动化任务。' | jobs_intro_style body
  print -r -- '影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。' | jobs_intro_style body
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。' | jobs_intro_style body
  print -r -- '============================================================================' | jobs_intro_style title
  echo "" | jobs_intro_style body
  read -r "?👉 已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：" _
}
# 执行已经拆分完成的独立业务步骤。
run_original_logic() {
  # ============================= 原脚本业务逻辑区 =============================
  # ✅ 变量定义
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
  cd "$script_path"
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
  script_file="$(basename "$0")"
  flutter_cmd=("flutter")
  entry_file="" # Flutter项目的入口

   # ✅ 彩色输出函数
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  color_echo()     { log "\033[1;32m$1\033[0m"; }         # ✅ 正常绿色输出
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }       # ℹ 信息
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }       # ✔ 成功
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }       # ⚠ 警告
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warm_echo()      { log "\033[1;33m$1\033[0m"; }         # 🟡 温馨提示（无图标）
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  note_echo()      { log "\033[1;35m➤ $1\033[0m"; }       # ➤ 说明
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  error_echo()     { log "\033[1;31m✖ $1\033[0m"; }       # ✖ 错误
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  err_echo()       { log "\033[1;31m$1\033[0m"; }         # 🔴 错误纯文本
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }      # 🐞 调试
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }      # 🔹 高亮
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  gray_echo()      { log "\033[0;90m$1\033[0m"; }         # ⚫ 次要信息
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  bold_echo()      { log "\033[1m$1\033[0m"; }            # 📝 加粗
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  underline_echo() { log "\033[4m$1\033[0m"; }            # 🔗 下划线
  # ✅ 自述信息
  show_intro() {
    echo "" | jobs_intro_style body
    bold_echo "====================================================================" | jobs_intro_style title
    note_echo "🛠️ 脚本功能说明：" | jobs_intro_style title
    bold_echo "====================================================================" | jobs_intro_style title
    note_echo "📌 脚本用途：" | jobs_intro_style title
    note_echo "将 Dart 文件运行到 Android 模拟器" | jobs_intro_style body
    echo "" | jobs_intro_style body
    note_echo "📦 功能列表：" | jobs_intro_style title
    success_echo " ✅ 拖入 Dart 文件或 Flutter 项目目录（含 lib/main.dart）" | jobs_intro_style body
    success_echo " ✅ 自动判断是否使用 FVM" | jobs_intro_style body
    success_echo " ✅ 自动检测和安装 Android SDK 工具" | jobs_intro_style body
    success_echo " ✅ 自动创建和启动 AVD（支持 fzf 多选 + arm64 优化）" | jobs_intro_style body
    success_echo " ✅ 支持构建模式（debug/release/profile）与 --flavor" | jobs_intro_style body
    success_echo " ✅ 自动修复 adb / sdkmanager / namespace 等问题" | jobs_intro_style body
    echo "" | jobs_intro_style body
    warm_echo "🔁 可选步骤：[任意键=执行, 回车=跳过]" | jobs_intro_style body
    bold_echo "====================================================================" | jobs_intro_style title
    echo "" | jobs_intro_style body

    # ✅ 等待用户输入，回车跳过，其他继续
    print -n "⚙️  现在是否执行可选操作？（回车跳过 / 任意键执行）："
    read user_choice

    if [[ -z "$user_choice" ]]; then
      return 1   # 跳过
    else
      return 0   # 执行
    fi
  }
  # ✅ 启动 Android 模拟器
  # 检查模拟器是否存在；
  # 启动一个可用的；
  # 设置并返回 $device_id
  get_or_start_android_emulator() {
    # ✅ 全局声明变量 device_id
    typeset -g device_id

    device_id=$(eval "${flutter_cmd[@]}" devices | grep -iE 'emulator|android' | awk -F '•' '{print $2}' | head -n1 | xargs)

    if [[ -n "$device_id" ]]; then
      success_echo "📱 已找到 Android 模拟器设备：$device_id"
      return 0
    fi

    warn_echo "⚠️ 未找到 Android 模拟器，尝试自动启动..."

    if ! command -v emulator &>/dev/null; then
      error_echo "❌ 未找到 emulator 命令，请检查 ANDROID_HOME 设置"
      return 1
    fi

    local avd_name
    avd_name=$(avdmanager list avd | grep "Name:" | head -n1 | awk -F': ' '{print $2}' | xargs)

    if [[ -z "$avd_name" ]]; then
      error_echo "❌ 没有可用的 AVD，请先创建模拟器"
      echo "你可以运行：avdmanager create avd -n your_avd_name -k \"system-images;android-30;google_apis;x86_64\""
      return 1
    fi

    note_echo "🚀 启动模拟器：$avd_name"
    nohup emulator -avd "$avd_name" >/dev/null 2>&1 &

    local timeout=60
    while [[ $timeout -gt 0 ]]; do
      device_id=$(eval "${flutter_cmd[@]}" devices | grep -iE 'emulator|android' | awk -F '•' '{print $2}' | head -n1 | xargs)
      if [[ -n "$device_id" ]]; then
        success_echo "✅ 模拟器启动成功：$device_id"
        return 0
      fi
      sleep 2
      ((timeout-=2))
    done

    error_echo "❌ 模拟器启动超时（60秒）"
    return 1
  }
  # ✅ 日志输出（日志文件名 == 脚本文件名）
  init_logging() {
    local custom_log_name="$1"

    # 获取脚本路径（兼容 Finder 双击和终端执行）
    local resolved_path="${(%):-%x}"
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"

    local default_log_name="$(basename "$resolved_path" | sed 's/\.[^.]*$//').log"
    local log_file_name="${custom_log_name:-$default_log_name}"

    LOG_FILE="${script_path}/${log_file_name}"

    # 清空旧日志
    : > "$LOG_FILE"
    # 打印路径（彩色输出后才重定向）
    info_echo "日志记录启用：$LOG_FILE"
    # 重定向所有输出到终端 + 日志
    exec 1> >(tee -a "$LOG_FILE") 2>&1
  }
  # ✅ 创建桌面快捷方式
  create_shortcut() {
    if [[ -f "$flutter_project_root/pubspec.yaml" ]]; then
      flutter_project_name=$(grep -m1 '^name:' "$flutter_project_root/pubspec.yaml" | awk '{print $2}')
    else
      flutter_project_name="Flutter项目"
    fi
    shortcut_name="${flutter_project_name}.command"
    shortcut_path="$HOME/Desktop/$shortcut_name"
    if [[ ! -f "$shortcut_path" ]]; then
      ln -s "$script_path/$script_file" "$shortcut_path"
      chmod +x "$shortcut_path"
      success_echo "📎 已在桌面创建快捷方式：$shortcut_name"
    fi
  }
  # ✅ 判断芯片架构（ARM64/ x86_64）
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }
  # ✅ 单行写文件（避免重复写入）
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
  # ✅ 自检安装：🍺Homebrew
  install_homebrew() {
    local arch="$(get_cpu_arch)"
    local shell_name="${SHELL##*/}"
    local profile_file=""
    local brew_bin=""

    if ! command -v brew >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/brew" && ! -x "/usr/local/bin/brew" ]]; then
      warn_echo "未检测到 Homebrew，准备安装（架构：$arch）"
      if [[ "$arch" == "arm64" ]]; then
        jobs_brew_install_or_exit || { error_echo "Homebrew 安装失败（arm64）"; return 1; }
        brew_bin="${JOBS_HOMEBREW_BIN:-$(jobs_brew_find 2>/dev/null || true)}"
      else
        jobs_brew_install_or_exit || { error_echo "Homebrew 安装失败（x86_64）"; return 1; }
        brew_bin="${JOBS_HOMEBREW_BIN:-$(jobs_brew_find 2>/dev/null || true)}"
      fi
      success_echo "Homebrew 安装完成"
    else
      command -v brew >/dev/null 2>&1 && brew_bin="$(command -v brew)"
      [[ -z "$brew_bin" && -x "/opt/homebrew/bin/brew" ]] && brew_bin="/opt/homebrew/bin/brew"
      [[ -z "$brew_bin" && -x "/usr/local/bin/brew" ]] && brew_bin="/usr/local/bin/brew"
    fi

    case "$shell_name" in
      zsh) profile_file="$HOME/.zprofile" ;;
      bash) profile_file="$HOME/.bash_profile" ;;
      *) profile_file="$HOME/.profile" ;;
    esac
    inject_shellenv_block "$profile_file" "eval \"\$(${brew_bin} shellenv)\""
    eval "$(${brew_bin} shellenv)" || true

    info_echo "Homebrew 已安装。"
    if ask_run "是否执行 Homebrew 更新 / 升级 / 清理 / doctor？"; then
      brew update  || { error_echo "brew update 失败"; return 1; }
      brew upgrade || { error_echo "brew upgrade 失败"; return 1; }
      brew cleanup || { error_echo "brew cleanup 失败"; return 1; }
      brew doctor  || warn_echo "brew doctor 有警告，请按输出处理"
      brew -v      || warn_echo "打印 brew 版本失败，可忽略"
      success_echo "Homebrew 健康更新完成"
    else
      note_echo "已跳过 Homebrew 更新"
    fi
  }
  # ✅ 自检安装：🍺Homebrew.jenv
  install_jenv() {
    if ! command -v jenv &>/dev/null; then
      info_echo "📦 未检测到 jenv，正在通过 Homebrew 安装..."
      brew install jenv || { error_echo "❌ jenv 安装失败"; exit 1; }
      success_echo "✅ jenv 安装成功"
    else
      info_echo "🔄 jenv 已安装，升级中..."
      brew upgrade jenv && brew cleanup
      success_echo "✅ jenv 已是最新版"
    fi

    # ✅ 设置 jenv 环境变量（追加到 .zshrc 或 .bash_profile）
    local shellrc="$HOME/.zshrc"
    [[ -n "$ZSH_VERSION" ]] || shellrc="$HOME/.bash_profile"

    if ! grep -q 'jenv init' "$shellrc"; then
      info_echo "📎 正在写入 jenv 初始化配置到：$shellrc"
      {
        echo ''
        echo '# >>> jenv 初始化 >>>'
        echo 'export PATH="$HOME/.jenv/bin:$PATH"'
        echo 'eval "$(jenv init -)"'
        echo '# <<< jenv 初始化 <<<'
      } >> "$shellrc"
      success_echo "✅ jenv 初始化配置已写入 $shellrc"
    else
      info_echo "📌 jenv 初始化配置已存在于 $shellrc"
    fi

    # ✅ 当前 shell 生效
    export PATH="$HOME/.jenv/bin:$PATH"
    eval "$(jenv init -)"
    success_echo "🟢 jenv 初始化完成并在当前终端生效"
  }
  # ✅ 初始化 jenv 并注入 JAVA_HOME（优先读取 .java-version）
  select_and_set_java_version() {
    export PATH="$HOME/.jenv/bin:$PATH"
    eval "$(jenv init - zsh)"

    local java_version

    # === 检查项目中的 .java-version 文件 ===
      if [[ -f ".java-version" ]]; then
        java_version=$(jenv version-name 2>/dev/null)

        if [[ -n "$java_version" && -d "$HOME/.jenv/versions/$java_version" ]]; then
          success_echo "📌 项目中存在 .java-version：$java_version"

          print -n "⚠️ 检测到已有 Java 版本 $java_version，按回车默认使用，输入任意字符重新选择："
          read confirm

          if [[ -n "$confirm" ]]; then
            note_echo "🔁 将忽略当前 .java-version，重新选择 Java 版本..."
          else
            export JAVA_HOME="$HOME/.jenv/versions/$java_version"
            export PATH="$JAVA_HOME/bin:$PATH"
            success_echo "✅ JAVA_HOME 设置为：$JAVA_HOME"
            return
          fi
        else
          warn_echo "⚠️ .java-version 存在但无效，将重新选择 Java 版本..."
        fi
      fi

    # === fzf 手动选择流程 ===
    local available_versions
    available_versions=$(jenv versions --bare --verbose | grep -v '^$' || true)

    if [[ -z "$available_versions" ]]; then
      error_echo "❌ jenv 中未检测到任何 Java 版本，请先添加"
      exit 1
    fi

    local selected_version
    selected_version=$(echo "$available_versions" | fzf --prompt="🧩 选择 Java 版本: ")

    if [[ -z "$selected_version" ]]; then
      warn_echo "⚠️ 用户未选择 Java 版本，退出"
      exit 1
    fi

    success_echo "📌 已选择 Java 版本：$selected_version"
    jenv local "$selected_version" || {
      error_echo "❌ 设置 jenv local 失败"
      exit 1
    }

    export JAVA_HOME="$HOME/.jenv/versions/$selected_version"
    export PATH="$JAVA_HOME/bin:$PATH"
    success_echo "✅ JAVA_HOME 设置为：$JAVA_HOME"
  }
  # ✅ Android 构建环境完整性检查
  check_android_environment() {
    warm_echo "🔍 正在检查 Android 构建环境..."
    eval "$flutter_cmd --version"

    # === JDK 检查 ===
    if ! command -v java &>/dev/null; then
      error_echo "❌ 未安装 Java（JDK），请先安装 JDK 17 或以上"
      exit 1
    fi

    JAVA_VERSION=$(java -version 2>&1 | grep 'version' | awk -F '"' '{print $2}')
    JAVA_HOME_PATH=$(dirname "$(dirname "$(which java)")")

    note_echo "📦 当前使用 JDK 版本为：$JAVA_VERSION"
    note_echo "📂 JAVA_HOME 推断路径：$JAVA_HOME_PATH"

    if [[ "$JAVA_HOME_PATH" == *Android\ Studio* ]]; then
      warn_echo "⚠️ 当前使用的是 Android Studio 自带的 JDK"
    fi

    # === sdkmanager 检查 + 版本 ===
    if ! command -v sdkmanager &>/dev/null; then
      error_echo "❌ 未找到 sdkmanager，可能缺少 Android cmdline-tools"
      warn_echo "🛠️ 可尝试执行：sdkmanager --install 'cmdline-tools;latest'"
      exit 1
    else
      sdk_version=$(sdkmanager --version 2>/dev/null | head -n1)
      success_echo "✅ sdkmanager 版本：$sdk_version"
    fi

    # === adb 检查 + 版本 ===
    if ! command -v adb &>/dev/null; then
      error_echo "❌ 未安装 adb，缺失 platform-tools"
      warn_echo "🛠️ 可执行：sdkmanager 'platform-tools'"
      exit 1
    else
      adb_version=$(adb version | grep -oE 'version [0-9.]+' | awk '{print $2}')
      success_echo "✅ adb 版本：$adb_version"
    fi

    # === build-tools 检查 ===
    if [[ ! -d "$ANDROID_HOME/build-tools" ]] || [[ -z "$(ls "$ANDROID_HOME/build-tools")" ]]; then
      warn_echo "⚠️ 未检测到任何 build-tools，尝试安装中..."
      sdkmanager "build-tools;34.0.0" || warn_echo "⚠️ build-tools 安装可能失败，请手动检查"
    else
      latest_build_tools=$(ls "$ANDROID_HOME/build-tools" | sort -V | tail -n1)
      success_echo "✅ 已检测到 build-tools：$latest_build_tools"
    fi

    # === platforms 检查 ===
    if [[ ! -d "$ANDROID_HOME/platforms" ]] || [[ -z "$(ls "$ANDROID_HOME/platforms")" ]]; then
      warn_echo "⚠️ 未检测到任何 Android 平台 SDK，尝试安装中..."
      sdkmanager "platforms;android-34" || warn_echo "⚠️ Android 平台 SDK 安装可能失败，请手动检查"
    else
      latest_platform=$(ls "$ANDROID_HOME/platforms" | sort -V | tail -n1)
      success_echo "✅ 已检测到平台 SDK：$latest_platform"
    fi

    # === flutter doctor 全量输出 ===
    note_echo "🩺 正在执行 flutter doctor 检查环境..."
    "${flutter_cmd[@]}" doctor
    "${flutter_cmd[@]}" doctor | tee -a "$LOG_FILE"
  
    # === Gradle Wrapper 检查 ===
    local wrapper_file="android/gradle/wrapper/gradle-wrapper.properties"
    if [[ -f "$wrapper_file" ]]; then
      gradle_url=$(grep distributionUrl "$wrapper_file" | cut -d= -f2 | xargs)
      gradle_version=$(echo "$gradle_url" | grep -oE 'gradle-[0-9.]+' || true)
      if [[ -n "$gradle_version" ]]; then
        success_echo "✅ 检测到 Gradle Wrapper：$gradle_version"
      else
        warn_echo "⚠️ 未能解析 Gradle 版本：$gradle_url"
      fi
    else
      warn_echo "⚠️ 未检测到 gradle-wrapper.properties，可能不是标准 Flutter 项目结构"
    fi

    # === Android NDK 检查 ===
    local ndk_dir="$ANDROID_HOME/ndk"
    if [[ -d "$ndk_dir" ]] && [[ -n "$(ls -A "$ndk_dir")" ]]; then
      latest_ndk=$(ls "$ndk_dir" | sort -V | tail -n1)
      success_echo "✅ 检测到 Android NDK：$latest_ndk"
    else
      warn_echo "⚠️ 未检测到 Android NDK（$ndk_dir），如项目使用 native C/C++，请通过 sdkmanager 安装"
      note_echo "➤ 示例命令：sdkmanager 'ndk;26.3.11579264'"
    fi

    warm_echo "🔍 Android 构建环境监察完毕"
  }
  # ✅ Flutter 命令检测
  detect_flutter_cmd() {
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
    local fvm_config_path="$script_path/.fvm/fvm_config.json"
    if command -v fvm >/dev/null 2>&1 && [[ -f "$fvm_config_path" ]]; then
      flutter_cmd=("fvm" "flutter")
      info_echo "🧩 检测到 FVM 项目，使用命令：fvm flutter"
    else
      flutter_cmd=("flutter")
      info_echo "📦 使用系统 Flutter 命令：flutter"
    fi
  }
  # ✅ 修复缺失 namespace
  fix_missing_namespace() {
    local project_root="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
    local gradle_files=($(find "$project_root/android" -type f -name "build.gradle" -not -path "*/build/*"))
    for gradle_file in "${gradle_files[@]}"; do
      if [[ "$(basename "$(dirname "$gradle_file")")" == "android" ]]; then continue; fi
      local module_dir=$(dirname "$gradle_file")
      if grep -q "namespace\s\+" "$gradle_file"; then
        success_echo "✅ 已有 namespace：$gradle_file"
        continue
      fi
      local manifest_file="$module_dir/src/main/AndroidManifest.xml"
      if [[ -f "$manifest_file" ]]; then
        local package_name=$(grep -oP 'package="\K[^"]+' "$manifest_file")
        if [[ -n "$package_name" ]]; then
          if grep -q "android\s*{" "$gradle_file"; then
            sed -i '' "/android\s*{/a\\
            \ \ \ \ namespace \"$package_name\"
            " "$gradle_file"
            success_echo "🚀 已插入 namespace \"$package_name\" 到：$gradle_file"
          else
            warn_echo "⚠️ 未找到 android {} 块，跳过：$gradle_file"
          fi
        else
          error_echo "❌ 无法从 Manifest 提取 package：$manifest_file"
        fi
      else
        warn_echo "⚠️ 未找到 AndroidManifest.xml：$manifest_file"
      fi
    done
  }
  # ✅ 判断当前目录是否为Flutter项目根目录
  is_flutter_project_root() {
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }
  # ✅ 转换路径为绝对路径
  abs_path() {
    local p="$1"
    [[ -z "$p" ]] && return 1
    p="${p//\"/}"                                                         # ✅ 移除双引号，防止参数传递误差
    [[ "$p" != "/" ]] && p="${p%/}"                                                               # ✅ 去除末尾斜杠，标准化路径形式

    if [[ -d "$p" ]]; then
      (cd "$p" 2>/dev/null && pwd -P)                                     # ✅ 子 shell，避免污染当前目录
    elif [[ -f "$p" ]]; then
      (cd "${p:h}" 2>/dev/null && printf "%s/%s\n" "$(pwd -P)" "${p:t}")  # ✅ 精准拼接
    else
      return 1
    fi
  }
  # ✅ 检测入口文件
  detect_entry() {
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
  
    while true; do
      warn_echo "📂 请拖入 Flutter 项目根目录或 Dart 单文件路径（回车即表示当前脚本的执行路径）："
      read -r user_input
      user_input="${user_input//\"/}"
      user_input="${user_input%/}"

      if [[ -z "$user_input" ]]; then
        if is_flutter_project_root "$script_path"; then
          flutter_root=$(abs_path "$script_path")
          entry_file="$flutter_root/lib/main.dart"
          highlight_echo "🎯 检测到脚本所在目录即 Flutter 根目录，自动使用。"
          break
        else
          error_echo "❌ 当前目录不是 Flutter 项目根目录，请重新拖入。"
          continue
        fi
      fi

      if [[ -d "$user_input" ]]; then
        if is_flutter_project_root "$user_input"; then
          flutter_root=$(abs_path "$user_input")
          entry_file="$flutter_root/lib/main.dart"
          break
        fi
      elif [[ -f "$user_input" ]]; then
        if is_dart_entry_file "$user_input"; then
          entry_file=$(abs_path "$user_input")
          flutter_root="${entry_file:h}"
          break
        fi
      fi

      error_echo "❌ 无效路径，请重新拖入 Flutter 根目录或 Dart 单文件。"
    done

    cd "$flutter_root" || { error_echo "无法进入项目目录：$flutter_root"; exit 1; }
    success_echo "✅ 项目路径：$flutter_root"
    success_echo "🎯 入口文件：$entry_file"
  }
  # ✅ 询问执行 flutter pub upgrade
  replace_connectivity_dependency() {
    echo ""
    warn_echo "有些时候执行此命令，会造成代码无法构建。"
    warn_echo "默认不执行，请谨慎操作！"
    read "?🔧 是否执行 flutter pub upgrade ？输入 y 执行，其它跳过: " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
      note_echo "⏩ 已跳过依赖替换操作"
      return
    fi

    note_echo "📦 自动执行：flutter pub upgrade"
    eval "${flutter_cmd[@]}" pub upgrade

    local yaml_path="$flutter_project_root/pubspec.yaml"
    if grep -q "connectivity:" "$yaml_path"; then
      if grep -q "connectivity_plus:" "$yaml_path"; then
        warn_echo "⚠️ 已存在 connectivity_plus，跳过重复添加"
        sed -i '' '/^\s*connectivity[: ].*/d' "$yaml_path"
      else
        highlight_echo "🔁 自动替换 connectivity → connectivity_plus"
        sed -i '' 's/^\s*connectivity:/  connectivity_plus:/g' "$yaml_path"
      fi
      eval "${flutter_cmd[@]}" pub get
    else
      info_echo "ℹ️ 未检测到 connectivity，无需替换"
    fi
  }
  # ✅ 执行 flutter run
  run_flutter() {
    note_echo "🧹 自动执行：flutter clean"
    eval "${flutter_cmd[@]}" clean

    replace_connectivity_dependency  # 询问是否 pub upgrade 并替换依赖

    # ================================== 构建命令 ==================================
    cmd=("${flutter_cmd[@]}" run -d "$device_id" -t "$entry_file")
    [[ -n "$FLAVOR" ]] && cmd+=("--flavor" "$FLAVOR")
    [[ "$BUILD_MODE" == "release" ]] && cmd+=("--release")
    [[ "$BUILD_MODE" == "profile" ]] && cmd+=("--profile")

    # ================================== 添加 --android-skip-build-dependency-validation ==================================
    read "?🔧 是否跳过 Android 构建依赖验证？按回车添加，输入任意字符不添加: " confirm
    if [[ -z "$confirm" ]]; then
      cmd+=("--android-skip-build-dependency-validation")
      note_echo "✅ 已添加参数：--android-skip-build-dependency-validation"
    else
      note_echo "⏩ 未添加该参数"
    fi

    # ================================== 前台/后台运行选择 ==================================
    echo ""
    read "?🎮 是否后台运行？按回车前台运行，输入任意字符后台运行（关闭终端不影响）: " run_mode
    if [[ -z "$run_mode" ]]; then
        # ✅ 回车 → 前台运行
        "${cmd[@]}"
        if [[ $? -ne 0 ]]; then
          warn_echo "⚠️ 构建失败，执行自动修复流程..."
          note_echo "🧹 清除项目构建产物和 pubspec.lock..."
          rm -rf "$flutter_project_root/.dart_tool"
          rm -rf "$flutter_project_root/build"
          rm -f "$flutter_project_root/pubspec.lock"

          eval "${flutter_cmd[@]}" clean
          eval "${flutter_cmd[@]}" pub get

          note_echo "🔁 正在重试 flutter run..."
          "${cmd[@]}"
      fi
    else
      # ❗ 任意字符 → 前台运行
      nohup "${cmd[@]}" > /tmp/flutter_run.log 2>&1 &
      disown
      success_echo "✅ Flutter 已后台运行，日志写入：/tmp/flutter_run.log"
    fi
  }
  # ✅ 询问用户是否用VSCode打开此Flutter项目
  maybe_open_in_vscode() {
    print -n "🧭 是否用 VS Code 打开项目？（回车 = 跳过，输入任意字符 = 打开）："
    read confirm

    if [[ -z "$confirm" ]]; then
      if command -v code >/dev/null 2>&1; then
        open_path="$script_path"
        success_echo "🚀 正在用 VS Code 打开项目目录：$open_path"
        code "$open_path"
      else
        error_echo "❌ 未找到 VS Code 的命令行工具 code，请先在 VS Code 中启用 'Shell Command: Install code in PATH'"
        color_echo '🔥配置 VSCode 环境变量 👉 export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"'
      fi
    else
      note_echo "⏩ 已跳过 VS Code 打开操作"
    fi
  }
  # ✅ 主函数
  main() {
      init_logging                             # ✅ 日志输出（日志文件名 == 脚本文件名）
      detect_flutter_cmd                       # ✅ Flutter 命令检测
      show_intro                               # ✅ 自述信息
      get_or_start_android_emulator || exit 1  # ✅ 启动 Android 模拟器

      install_homebrew                         # ✅ 自检安装：🍺Homebrew
      install_jenv                             # ✅ 自检安装：🍺Homebrew.jenv
      select_and_set_java_version              # ✅ Java 环境注入
      check_android_environment                # ✅ Android 构建环境完整性检查

      fix_missing_namespace                    # ✅ 修复缺失 namespace
      detect_entry                             # ✅ 检测入口文件
      run_flutter                              # ✅ 执行 flutter run（运行前先清理）
 
      maybe_open_in_vscode                     # ✅ 询问用户是否用VSCode打开此Flutter项目
      create_shortcut                          # ✅ 创建桌面快捷方式
  }

  main "$@"

  # =========================== 原脚本业务逻辑区结束 ===========================
}
# 编排脚本的高层业务流程。
main() {
  # 展示脚本内置自述，并按运行入口完成防误触确认。
  show_script_intro_and_wait
  # 初始化本次运行使用的日志文件。
  initialize_script_runtime
  # 执行 run_original_logic 对应的核心业务步骤。
  run_original_logic "$@"
  # 输出脚本执行结果、摘要和日志位置。
  success_echo "脚本执行结束。日志：$LOG_FILE"
}

main "$@"
