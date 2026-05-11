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
  setopt +o nomatch
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

  # ✅ 彩色输出
  cecho() {
    local color="$1"; shift
    local text="$*"
    case "$color" in
      red) echo "\033[31m$text\033[0m" ;;
      green) echo "\033[32m$text\033[0m" ;;
      yellow) echo "\033[33m$text\033[0m" ;;
      blue) echo "\033[34m$text\033[0m" ;;
      *) echo "$text" ;;
    esac
  }

  # ✅ 环境命令依赖校验
  require_commands() {
    local cmds=("grep" "awk" "xargs" "git" "curl")
    for cmd in "${cmds[@]}"; do
      if ! command -v "$cmd" >/dev/null; then
        cecho red "❌ 缺少命令：$cmd，请先安装或修复 PATH"
        exit 1
      fi
    done
  }

  # ✅ 自述信息
  show_description() {
    clear
    cecho blue "🛠 Flutter SDK 升级助手（支持 FVM / 系统 Flutter）"
    echo ""
    cecho yellow "📌 功能说明："
    echo "1️⃣ 检查当前路径是否为 Flutter 项目（pubspec.yaml + lib/）"
    echo "2️⃣ 自动识别 flutter 命令是否由 FVM 转发"
    echo "3️⃣ 如果是 FVM："
    echo "   - 获取实际 SDK 路径"
    echo "   - 检查是否存在本地修改（git status）"
    echo "   - 提供 stash / force / cancel 三种交互处理"
    echo "   - 支持切换 channel（fzf 选择）"
    echo "   - 升级对应 SDK（fvm flutter upgrade）"
    echo "4️⃣ 如果是系统 flutter："
    echo "   - 若为 Homebrew 安装，使用 brew upgrade flutter"
    echo "   - 否则直接 flutter upgrade（并支持 channel 选择）"
    echo ""
    cecho yellow "📦 自动安装并自检依赖工具："
    echo "✅ Homebrew"
    echo "✅ fzf（交互式选择 Flutter channel）"
    echo ""
    cecho green "📂 当前执行路径：$(pwd)"
    echo ""
    echo "🔍 请按回车继续（或 Ctrl+C 退出）"
    read -rs
  }

  # ✅ 智能切换 Homebrew 源
  check_and_set_homebrew_mirror() {
    local test_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
      cecho yellow "🌐 正在测试 Homebrew 官方源可达性..."

    if curl --connect-timeout 3 -s --head "$test_url" | /usr/bin/grep -q "200 OK"; then
      cecho green "✅ Homebrew 官方源可访问，继续使用默认源"
    else
      cecho red "⚠️ 官方源访问失败，仅设置清华 Bottle 镜像（Git 仓库镜像已停用）"
      export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
    fi
  }

  # ✅ 自检工具
  ensure_brew() {
    if ! command -v brew >/dev/null; then
      cecho red "🧰 未安装 Homebrew，正在安装..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      cecho green "✅ Homebrew 已安装，更新中..."
      ask_run "执行 Homebrew 更新 / 升级 / 清理？" && run_brew_health_update
    fi
  }

  ensure_fzf() {
    cecho blue "📢 正在检查 fzf..."
    if ! command -v fzf >/dev/null; then
      cecho yellow "🧰 安装 fzf 中..."
      brew install fzf || {
        cecho red "❌ 安装 fzf 失败，终止"
        exit 1
      }
    else
      cecho green "✅ fzf 已安装"
    fi
  }

  # ✅ 判断方法
  is_flutter_fvm_proxy() {
    if type flutter | /usr/bin/grep -q 'fvm flutter'; then return 0; fi
    [[ "$(which flutter)" == *".fvm/"* ]] && return 0
    return 1
  }

  get_sdk_path_from_fvm() {
    fvm flutter --version --verbose 2>/dev/null \
      | /usr/bin/grep "Flutter root" \
      | /usr/bin/awk -F'at ' '{print $2}' \
      | /usr/bin/xargs || true
  }

  get_sdk_path_from_system() {
    local path
    path=$(flutter --version --verbose 2>/dev/null \
      | /usr/bin/grep "Flutter root" \
      | /usr/bin/awk -F'at ' '{print $2}' \
      | /usr/bin/xargs || true)
    if [[ -z "$path" ]]; then
      for p in /opt/homebrew/Caskroom/flutter/*/flutter /usr/local/Caskroom/flutter/*/flutter; do
        [[ -x "$p/bin/flutter" ]] && path="$p" && break
      done
    fi
    echo "$path"
  }

  check_sdk_git_changes() {
    [[ -d "$1/.git" ]] && [[ -n "$(cd "$1" && git status --porcelain)" ]]
  }

  prompt_git_action() {
    local sdk_path="$1"
    cecho red "⚠️ 检测到 Flutter SDK（$sdk_path）有本地修改："
    cd "$sdk_path"
    git status -s
    echo ""

    while true; do
      cecho yellow "请选择如何处理这些修改："
      echo "1) git stash 后继续升级（推荐）"
      echo "2) 强制升级（--force，会清除本地修改）"
      echo "3) 取消升级"
      read "?👉 输入选项数字 (默认 1): " choice
      choice=${choice:-1}
      case "$choice" in
        1) cecho blue "📦 正在 stash 本地修改..." && git stash && return 0 ;;
        2) cecho yellow "🚨 将强制升级 Flutter SDK..." && return 2 ;;
        3) cecho red "🚫 已取消升级" && exit 0 ;;
        *) cecho red "❌ 无效输入，请重新输入 1 / 2 / 3（回车默认 1）" ;;
      esac
    done
  }

  select_channel() {
    echo -e "stable\nbeta\nmain\nmaster" | fzf --prompt="切换 Channel > "
  }

  # ✅ 执行升级
  perform_upgrade() {
    local sdk_cmd="$1"
    local sdk_path="$2"

    if check_sdk_git_changes "$sdk_path"; then
      prompt_git_action "$sdk_path"
      [[ $? -eq 2 ]] && "$sdk_cmd" upgrade --force && return
    fi

    if [[ "$sdk_path" == *"/Caskroom/flutter/"* ]]; then
      cecho blue "🍺 检测到 Flutter 是通过 Homebrew 安装，使用 brew 升级方式"
      brew upgrade flutter || {
        cecho red "❌ brew upgrade flutter 失败"
        exit 1
      }
      return
    fi

    local channel=$(select_channel)
    [[ -n "$channel" ]] && "$sdk_cmd" channel "$channel"
    cecho yellow "🚀 开始升级 Flutter SDK..."
    "$sdk_cmd" upgrade
  }

  # ✅ 判断 flutter 命令来源与 SDK 路径
  detect_flutter_cmd_and_sdk_path() {
    # 显示当前 flutter 路径信息
    cecho yellow "🧩 当前 flutter 路径：$(which flutter)"
    type flutter

    flutter_cmd="flutter"
    sdk_path=""

    # 判断是否为 FVM 转发
    if is_flutter_fvm_proxy; then
      flutter_cmd="fvm flutter"
      sdk_path=$(get_sdk_path_from_fvm)
      cecho green "✅ flutter 命令是由 FVM 转发"
    else
      sdk_path=$(get_sdk_path_from_system)
      cecho yellow "⚠️ flutter 命令是系统 Flutter"
    fi

    # SDK 路径 fallback 判断
    if [[ -z "$sdk_path" ]]; then
      cecho red "❌ 无法识别 Flutter SDK 路径，尝试 fallback"
      sdk_path=$(get_sdk_path_from_fvm)
      if [[ -n "$sdk_path" ]]; then
        cecho green "✅ fallback 成功：$sdk_path"
      else
        cecho red "❌ fallback 也失败，终止"
        cecho yellow "📋 flutter --version --verbose 输出如下（供调试）："
        echo "--------------------"
        flutter --version --verbose
        echo "--------------------"
        exit 1
      fi
    fi

    # 最终确认的 SDK 路径
    cecho blue "📁 当前 Flutter SDK 路径：$sdk_path"
  }

  # ✅ 主函数入口
  main() {
    show_description                            # ✅ 自述信息
    require_commands                            # ✅ 检查必要命令依赖（如 grep、awk、git、curl 等）
    check_and_set_homebrew_mirror               # ✅ 检查 Homebrew 源可达性，必要时切换为国内镜像
    ensure_brew                                 # ✅ 自检 Homebrew，如未安装则自动安装并升级
    ensure_fzf                                  # ✅ 检查并安装 fzf 工具（用于 channel 选择等交互）
    detect_flutter_cmd_and_sdk_path             # ✅ 检测 flutter 是否通过 FVM 管理，并获取 SDK 路径
    perform_upgrade "$flutter_cmd" "$sdk_path"  # ✅ 执行 Flutter SDK 升级流程（支持 FVM / 系统 flutter）

    echo ""
    cecho green "✅ Flutter SDK 升级完成"         # ✅ 最终成功提示
    read "?⏎ 按回车关闭窗口"                       # ✅ 提示用户手动关闭窗口（适用于 GUI 脚本或 Terminal 自动退出）
  }

  main

  # =========================== 原脚本业务逻辑区结束 ===========================
}

main() {
  show_readme_and_wait
  run_original_logic "$@"
  success_echo "脚本执行结束。日志：$LOG_FILE"
}

main "$@"
