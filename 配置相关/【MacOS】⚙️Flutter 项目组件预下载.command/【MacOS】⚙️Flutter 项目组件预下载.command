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
  # ✅ 日志与彩色输出
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')     # 当前脚本名（去掉扩展名）
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                    # 日志输出路径

  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  color_echo()     { log "\033[1;32m$1\033[0m"; }           # ✅ 正常绿色输出
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }         # ℹ 信息
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }         # ✔ 成功
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }         # ⚠ 警告
  warm_echo()      { log "\033[1;33m$1\033[0m"; }           # 🟡 温馨提示（无图标）
  note_echo()      { log "\033[1;35m➤ $1\033[0m"; }         # ➤ 说明
  error_echo()     { log "\033[1;31m✖ $1\033[0m"; }         # ✖ 错误
  err_echo()       { log "\033[1;31m$1\033[0m"; }           # 🔴 错误纯文本
  debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }        # 🐞 调试
  highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }        # 🔹 高亮
  gray_echo()      { log "\033[0;90m$1\033[0m"; }           # ⚫ 次要信息
  bold_echo()      { log "\033[1m$1\033[0m"; }              # 📝 加粗
  underline_echo() { log "\033[4m$1\033[0m"; }              # 🔗 下划线

  # ✅ 自述信息
  print_intro() {
    clear
    success_echo "📦 Flutter 项目组件预下载脚本"
    bold_echo "==================================================================="
    success_echo "该脚本将帮助你一次性或分类预下载 Flutter 的所有支持平台工具"
    success_echo "包括：Android 所有架构、iOS、macOS、Windows、Linux、Web、Dart SDK"
    success_echo "支持离线缓存功能，预备无法联网时直接恢复"
    success_echo "请在 Flutter 项目根目录（含 pubspec.yaml 和 lib/）中运行此脚本"
    bold_echo "==================================================================="
    read "?📎 按回车继续（或 Ctrl+C 退出）："
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

  # ✅ 判断芯片架构
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }

  # ✅ 自检安装 Homebrew
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

  # ✅ 自检安装 Homebrew.coreutils
  install_coreutils() {
    if ! command -v realpath &>/dev/null; then
      info_echo "🔍 安装 coreutils（提供 realpath）"
      brew install coreutils
    else
      info_echo "🔄 coreutils 已安装，正在升级..."
      ask_run "升级 coreutils？" && brew upgrade coreutils || true
      success_echo "✅ coreutils 可用"
    fi
    export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
  }

  # ✅ 自检安装 Homebrew.fzf
  install_fzf() {
    if ! command -v fzf &>/dev/null; then
      success_echo "📦 未安装 fzf，正在通过 Homebrew 安装..."
      brew install fzf
    else
      info_echo "🔄 fzf 已安装，正在升级..."
      ask_run "升级 fzf？" && brew upgrade fzf || true
      success_echo "✅ fzf 可用"
    fi
  }

  # ✅ 验证 Flutter 项目根目录
  ensure_flutter_project_root() {
    script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    cd "$script_dir"
    while [[ ! -f "pubspec.yaml" || ! -d "lib" ]]; do
      error_echo "当前目录不是 Flutter 项目根目录（缺少 pubspec.yaml 或 lib/）"
      info_echo "📁 当前目录为：$(pwd)"
      read "?📂 请拖入项目根目录后回车：" project_path
      project_path="${project_path/#\"/}"; project_path="${project_path/%\"/}"
      [[ -z "$project_path" ]] && continue
      [[ ! -e "$project_path" ]] && error_echo "❌ 路径不存在" && continue
      cd "$(realpath "$project_path")"
    done
  }

  # ✅ 检测 Flutter 环境变量
  detect_flutter_env() {
    if [[ -d ".fvm" ]]; then
      success_echo "✅ 检测到 FVM 管理项目"
      CMD_PREFIX="fvm "
      FLUTTER_BIN="$(realpath .fvm/flutter_sdk/bin/flutter)"
    else
      info_echo "ℹ️ 使用全局 Flutter"
      CMD_PREFIX=""
      FLUTTER_BIN="$(command -v flutter)"
    fi

    FLUTTER_SDK="$(dirname "$(dirname "$FLUTTER_BIN")")"
    CACHE_DIR="$FLUTTER_SDK/bin/cache"
    BACKUP_DIR="$HOME/.flutter_cache_backups/$(basename "$PWD")"
  }

  # ✅ 离线缓存备份
  backup_flutter_cache() {
    mkdir -p "$BACKUP_DIR"
    warn_echo "📁 正在备份缓存至：$BACKUP_DIR"
    rsync -a --delete "$CACHE_DIR/" "$BACKUP_DIR/"
  }

  # ✅ 执行平台工具下载
  run_precache() {
    echo ""
    success_echo "请选择下载方式："
    echo "1. 下载全部平台工具（推荐）"
    echo "2. 分类选择平台（fzf 多选）"
    read "?👉 请输入 1 或 2：" mode

    if [[ "$mode" == "1" ]]; then
      info_echo "🚀 下载全部平台工具..."
      eval "${CMD_PREFIX}flutter precache --universal"
    else
      while true; do
        success_echo "✅ 请选择需要下载的平台（空格多选，回车确认）"
        platforms=$(echo "
  --ios
  --android-arm-profile
  --android-arm-release
  --android-arm64-profile
  --android-arm64-release
  --android-x64-profile
  --android-x64-release
  --web
  --macos
  --linux
  --windows
  --force
  " | fzf --multi)

        if [[ -z "$platforms" ]]; then
          warn_echo "⚠️ 未选择平台，请重新选择"
        else
          break
        fi
      done

      info_echo "🚀 下载所选平台工具：$platforms"
      eval "${CMD_PREFIX}flutter precache $platforms"
    fi
  }

  # ✅ 下载完成提示
  show_result() {
    if [[ -d "$CACHE_DIR" ]]; then
      success_echo "✅ 所有下载任务已完成！"
      note_echo "📁 缓存目录如下："
      echo "$CACHE_DIR"
      read "?📎 按回车打开该目录（或 Ctrl+C 退出）：" _
      open "$CACHE_DIR"
    else
      error_echo "❌ 缓存目录不存在：$CACHE_DIR"
      exit 1
    fi
  }

  # ✅ 主函数入口
  main() {
    print_intro                  # 🖨️ 自述信息
    install_homebrew             # 🍺 自检安装 Homebrew
    install_coreutils            # 🔧 自检安装 Homebrew.coreutils（提供 realpath）
    install_fzf                  # 🔍 自检安装 Homebrew.fzf 工具
    ensure_flutter_project_root  # 📁 验证 Flutter 项目根目录
    detect_flutter_env           # 🧭 检测是否为 FVM 管理的 Flutter 项目，并设置缓存路径
    backup_flutter_cache         # 💾 备份现有缓存目录
    run_precache                 # 🚀 下载 Flutter 平台工具（全选或 fzf 多选）
    show_result                  # 📂 展示缓存目录并提示打开
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
