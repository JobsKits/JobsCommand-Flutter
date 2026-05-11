#!/bin/zsh
# =====================================================================
# Jobs 标准化脚本外壳
# 说明：保留原脚本业务逻辑，补齐 README 防误触、彩色日志、zsh 入口、Homebrew 健康自检标准。
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME="$(basename "$0" | sed 's/\.[^.]*$//')"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE"

log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
warm_echo()      { log "\033[1;33m$1\033[0m"; }
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
err_echo()       { log "\033[1;31m$1\033[0m"; }
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
gray_echo()      { log "\033[0;90m$1\033[0m"; }
bold_echo()      { log "\033[1m$1\033[0m"; }
underline_echo() { log "\033[4m$1\033[0m"; }

# ============================= 标准工具函数 =============================
get_cpu_arch() {
  [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
}

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

ask_run() {
  echo ""
  note_echo "👉 $1"
  gray_echo "【回车=跳过，输入任意字符后回车=执行】"
  local input=""
  IFS= read -r "input?➤ "
  [[ -n "$input" ]]
}

confirm_yes() {
  echo ""
  warn_echo "⚠ $1"
  gray_echo "危险操作必须输入 YES 后回车；其它输入一律取消。"
  local input=""
  IFS= read -r "input?➤ "
  [[ "$input" == "YES" ]]
}

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

run_brew_health_update() {
  info_echo "正在执行 Homebrew 健康更新..."
  brew update  || { error_echo "brew update 失败"; return 1; }
  brew upgrade || { error_echo "brew upgrade 失败"; return 1; }
  brew cleanup || { error_echo "brew cleanup 失败"; return 1; }
  brew doctor  || warn_echo "brew doctor 有警告，请按输出处理"
  brew -v      || warn_echo "打印 brew 版本失败，可忽略"
  success_echo "Homebrew 健康更新完成"
}

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

show_readme_and_wait() {
  clear
  local readme_path="${SCRIPT_DIR}/README.md"
  if [[ -f "$readme_path" ]]; then
    highlight_echo "正在显示脚本自述文件：$readme_path"
    echo ""
    cat "$readme_path" | tee -a "$LOG_FILE"
  else
    warn_echo "未找到 README.md：$readme_path"
  fi
  echo ""
  read "?👉 请先阅读上面的自述文件，按回车继续执行，或按 Ctrl+C 取消..."
}

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

  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  color_echo()     { log "\033[1;32m$1\033[0m"; }        # ✅ 正常绿色输出
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }      # ℹ 信息
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }      # ✔ 成功
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }      # ⚠ 警告
  warm_echo()      { log "\033[1;33m$1\033[0m"; }        # 🟡 温馨提示（无图标）
  note_echo()      { log "\033[1;35m➤ $1\033[0m"; }      # ➤ 说明
  error_echo()     { log "\033[1;31m✖ $1\033[0m"; }      # ✖ 错误
  err_echo()       { log "\033[1;31m$1\033[0m"; }        # 🔴 错误纯文本
  debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }     # 🐞 调试
  highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }     # 🔹 高亮
  gray_echo()      { log "\033[0;90m$1\033[0m"; }        # ⚫ 次要信息
  bold_echo()      { log "\033[1m$1\033[0m"; }           # 📝 加粗
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

main() {
  show_readme_and_wait
  run_original_logic "$@"
  success_echo "脚本执行结束。日志：$LOG_FILE"
}

main "$@"
