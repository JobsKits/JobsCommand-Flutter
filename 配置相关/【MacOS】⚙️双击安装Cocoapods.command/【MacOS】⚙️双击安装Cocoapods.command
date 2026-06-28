#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】⚙️双击安装Cocoapods.command
# - 核心用途：执行“⚙️双击安装Cocoapods”对应的移动端项目自动化任务。
# - 影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。
# - 运行提示：运行后会先打印内置自述；终端模式按回车确认后继续，按 Ctrl+C 可取消。
# =====================================================================
# Jobs 标准化脚本外壳
# 说明：保留原脚本业务逻辑，补齐 README 防误触、彩色日志、zsh 入口、Homebrew 健康自检标准。
# =====================================================================

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
  if command -v brew >/dev/null 2>&1; then
    brew_bin="$(command -v brew)"
  elif [[ "$arch" == "arm64" && -x "/opt/homebrew/bin/brew" ]]; then
    brew_bin="/opt/homebrew/bin/brew"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    brew_bin="/usr/local/bin/brew"
  fi
  [[ -z "$brew_bin" ]] && return 1

  local shell_name="${SHELL##*/}"
  local profile_file=""
  case "$shell_name" in
    zsh)  profile_file="$HOME/.zprofile" ;;
    bash) profile_file="$HOME/.bash_profile" ;;
    *)    profile_file="$HOME/.profile" ;;
  esac
  inject_shellenv_block "$profile_file" "eval \"\$(${brew_bin} shellenv)\""
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

  if ! command -v brew >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/brew" && ! -x "/usr/local/bin/brew" ]]; then
    warn_echo "未检测到 Homebrew，准备按架构安装：$arch"
    if [[ "$arch" == "arm64" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { error_echo "Homebrew 安装失败（arm64）"; return 1; }
      brew_bin="/opt/homebrew/bin/brew"
    else
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { error_echo "Homebrew 安装失败（x86_64）"; return 1; }
      brew_bin="/usr/local/bin/brew"
    fi
    success_echo "Homebrew 安装完成"
    activate_homebrew_shellenv || true
    return 0
  fi

  activate_homebrew_shellenv || true
  info_echo "Homebrew 已安装。"
  if ask_run "是否执行 Homebrew 更新 / 升级 / 清理 / doctor？"; then
    run_brew_health_update
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
  print -r -- '============================== 脚本内置自述 =============================='
  print -r -- '脚本名称：【MacOS】⚙️双击安装Cocoapods.command'
  print -r -- '核心用途：执行“⚙️双击安装Cocoapods”对应的移动端项目自动化任务。'
  print -r -- '影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。'
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。'
  print -r -- '============================================================================'
  echo ""
  read -r "?👉 已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：" _
}
# 执行已经拆分完成的独立业务步骤。
run_original_logic() {
  # ============================= 原脚本业务逻辑区 =============================
  # ✅ 全局变量定义
  START_TIME=$(date +%s)
  LOG_FILE="$HOME/Desktop/Jobs_Installer_$(date +%Y%m%d_%H%M%S).log"

  typeset -g HOMEBREW_PATH_M_SERIES="/opt/homebrew"
  typeset -g HOMEBREW_PATH_X86="/usr/local"
  typeset -g CONFIG_FILES=(".zshrc" ".bash_profile")
  typeset -g FZF_PROMPT='👉 请选择操作：'

  # ✅ 彩色输出函数（带日志）
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  color_echo()     { log "\033[1;32m$1\033[0m"; }        # ✅ 正常绿色输出
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }      # ℹ 信息
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }      # ✔ 成功
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }      # ⚠ 警告
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  warm_echo()      { log "\033[1;33m$1\033[0m"; }        # 🟡 温馨提示（无图标）
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  note_echo()      { log "\033[1;35m➤ $1\033[0m"; }      # ➤ 说明
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  error_echo()     { log "\033[1;31m✖ $1\033[0m"; }      # ✖ 错误
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  err_echo()       { log "\033[1;31m$1\033[0m"; }        # 🔴 错误纯文本
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }     # 🐞 调试
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }     # 🔹 高亮
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  gray_echo()      { log "\033[0;90m$1\033[0m"; }        # ⚫ 次要信息
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  bold_echo()      { log "\033[1m$1\033[0m"; }           # 📝 加粗
  # 按当前输出级别记录终端信息，并同步写入脚本日志。
  underline_echo() { log "\033[4m$1\033[0m"; }           # 🔗 下划线
  # ✅ 打印 LOGO
  print_logo() {
    highlight_echo "======================="
    highlight_echo "     Jobs Installer    "
    highlight_echo "======================="
  }
  # ✅ 打印耗时
  print_duration() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    info_echo "⚙️ 脚本总耗时：${DURATION}s"
  }
  # ✅ 获取 CPU 架构
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }
  # ✅ fzf 菜单选择器
  fzf_select() {
    printf "%s\n" "$@" | fzf --prompt="$FZF_PROMPT" --height=15 --reverse
  }
  # ✅ 备份配置文件
  backup_configs() {
    for file in "$HOME/.zshrc" "$HOME/.bash_profile"; do
      [[ -f "$file" ]] && cp "$file" "$file.bak"
    done
    success_echo "📦 已备份配置文件到 .bak"
  }
  # ✅ 判断芯片架构（ARM64 / x86_64）
  get_cpu_arch() {
    [[ $(uname -m) == "arm64" ]] && echo "arm64" || echo "x86_64"
  }
  # ✅ 安装 Homebrew（芯片架构兼容、含环境注入）
  install_homebrew() {
    local arch="$(get_cpu_arch)"
    local shell_name="${SHELL##*/}"
    local profile_file=""
    local brew_bin=""

    if ! command -v brew >/dev/null 2>&1 && [[ ! -x "/opt/homebrew/bin/brew" && ! -x "/usr/local/bin/brew" ]]; then
      warn_echo "未检测到 Homebrew，准备安装（架构：$arch）"
      if [[ "$arch" == "arm64" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { error_echo "Homebrew 安装失败（arm64）"; return 1; }
        brew_bin="/opt/homebrew/bin/brew"
      else
        arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { error_echo "Homebrew 安装失败（x86_64）"; return 1; }
        brew_bin="/usr/local/bin/brew"
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
  # ✅ 安装 fzf（支持交互）
  install_fzf() {
    if ! command -v fzf &>/dev/null; then
      method=$(fzf_select "通过 Homebrew 安装" "通过 Git 安装")
      case $method in
        *Homebrew*) brew install fzf ;;
        *Git*)
          git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all ;;
        *) error_echo "❌ 取消安装 fzf" ;;
      esac
    else
      success_echo "✅ fzf 已安装"
    fi
  }
  # ✅ 安装 Ruby（多方式）
  install_ruby() {
    method=$(fzf_select "通过 Homebrew 安装 Ruby" "通过 Rbenv 安装 Ruby" "通过 RVM 安装 Ruby")
    case $method in
      *Homebrew*)
        brew install ruby
        echo 'export PATH="$(brew --prefix ruby)/bin:$PATH"' >> ~/.zshrc ;;
      *Rbenv*)
        brew install rbenv ruby-build
        echo 'eval "$(rbenv init -)"' >> ~/.zshrc
        eval "$(rbenv init -)"
        rbenv install 3.3.0
        rbenv global 3.3.0 ;;
      *RVM*)
        \curl -sSL https://get.rvm.io | bash -s stable --ruby
        source ~/.rvm/scripts/rvm ;;
      *) error_echo "❌ 未选择安装 Ruby" ;;
    esac
  }
  # ✅ 设置 Ruby 镜像源（IP 判断）
  is_in_china() {
    local country
    country=$(curl -s --max-time 3 https://ipinfo.io | jq -r '.country' 2>/dev/null)

    if [[ "$country" == "CN" ]]; then
      return 0  # 是中国，true
    else
      return 1  # 不是中国，false
    fi
  }
  # 封装 set_gem_source 对应的独立处理逻辑。
  set_gem_source() {
    if is_in_china; then
      gem sources --remove https://rubygems.org/ 2>/dev/null
      gem sources --add https://gems.ruby-china.com/ 2>/dev/null
      note_echo "🇨🇳 当前在中国，已切换为 Ruby 中国镜像源"
    else
      gem sources --remove https://gems.ruby-china.com/ 2>/dev/null
      gem sources --add https://rubygems.org/ 2>/dev/null
      note_echo "🌐 当前不在中国，已切换为官方 Ruby 镜像源"
    fi

    info_echo "📦 当前 RubyGem 源列表："
    gem sources -l | tee -a "$LOG_FILE"
  }
  # ✅ 安装 CocoaPods（gem/brew）
  install_cocoapods() {
    method=$(fzf_select "通过 gem 安装 CocoaPods" "通过 Homebrew 安装 CocoaPods")
    case $method in
      *gem*) sudo gem install cocoapods ;;
      *Homebrew*) brew install cocoapods ;;
      *) error_echo "❌ 未选择安装方式" ;;
    esac
    pod setup
    success_echo "✅ CocoaPods 安装完成"
    pod --version | tee -a "$LOG_FILE"
  }
  # ✅ 主流程入口
  main() {
    print_logo                # 🎨 打印脚本头部 Logo
    backup_configs            # 🛡️ 备份 zshrc / bash_profile
    install_homebrew          # 🍺 自动安装 Homebrew（芯片架构兼容、含环境注入）
    install_fzf               # 🔍 安装 fzf（支持 git/homebrew 二选）
    install_ruby              # 💎 Ruby 安装（Homebrew / rbenv / RVM）
    set_gem_source            # 🌐 根据 IP 判断并设置 gem 源
    install_cocoapods         # 📦 安装 CocoaPods（gem/brew 二选）
    print_duration            # ⏱️ 打印脚本耗时
    success_echo "🎉 所有步骤已完成，安装日志保存在：$LOG_FILE"
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
