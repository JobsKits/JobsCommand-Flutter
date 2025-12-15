#!/bin/zsh
set -euo pipefail

# ================================== 基础变量 ==================================
typeset -a flutter_cmd
flutter_cmd=("flutter")

SCRIPT_BASENAME="${${0:t}%.*}"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE" 2>/dev/null || true

# ================================== 日志与彩色输出 ==================================
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

# ================================== 入口自述 ==================================
show_script_intro() {
  cat <<'EOF'
====================================================================
 🛠️  Flutter 开发环境一键初始化脚本（支持 FVM / Homebrew / 自动架构识别）
====================================================================
📌 功能概述：
  1️⃣ 自动检测并安装 Homebrew（ARM64 / x86_64 架构适配）
  2️⃣ 安装并配置 FVM（优先 install.sh：无需 Dart；失败 fallback 到 brew）
  3️⃣ 安装/初始化 stable Flutter（项目内会写入 .fvm）
  4️⃣ 执行 flutter doctor / pub get / precache 等初始化命令
  5️⃣ 自动注入必要环境变量到 shell 配置文件（默认：~/.zshrc 或 ~/.bash_profile）

====================================================================
 按下回车键开始执行，或 Ctrl+C 退出
====================================================================
EOF
  read -r
}

# ================================== Shell Profile 选择 ==================================
detect_profile_file() {
  local shell_name="${SHELL##*/}"
  case "$shell_name" in
    zsh)  PROFILE_FILE="$HOME/.zshrc" ;;
    bash) PROFILE_FILE="$HOME/.bash_profile" ;;
    *)    PROFILE_FILE="$HOME/.profile" ;;
  esac
  [[ -f "$PROFILE_FILE" ]] || touch "$PROFILE_FILE"
  info_echo "🧾 使用配置文件：${PROFILE_FILE}"
}

# ================================== 注入环境变量块（去重） ==================================
inject_shellenv_block() {
  local id="$1"
  local line="$2"

  if [[ -z "${id:-}" || -z "${line:-}" ]]; then
    error_echo "❌ 缺少参数：inject_shellenv_block <id> <line>"
    return 1
  fi

  local start="# >>> ${id} >>>"
  local end="# <<< ${id} <<<"

  if grep -Fq "$start" "$PROFILE_FILE"; then
    warn_echo "📌 已存在配置块：$id（跳过写入）"
  else
    {
      echo ""
      echo "$start"
      echo "$line"
      echo "$end"
    } >> "$PROFILE_FILE"
    success_echo "✅ 已写入：$id"
  fi

  # 当前 shell 立即生效（不依赖重开终端）
  eval "$line" >/dev/null 2>&1 || true
}

# ================================== CPU 架构 ==================================
get_cpu_arch() {
  [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
}

# ================================== Homebrew 定位与注入 ==================================
locate_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi
  [[ -x /opt/homebrew/bin/brew ]] && { echo "/opt/homebrew/bin/brew"; return 0; }
  [[ -x /usr/local/bin/brew ]]     && { echo "/usr/local/bin/brew"; return 0; }
  return 1
}

install_homebrew() {
  local arch
  arch="$(get_cpu_arch)"

  if ! locate_brew_bin >/dev/null 2>&1; then
    warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"
    if [[ "$arch" == "arm64" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（arm64）"
        exit 1
      }
      BREW_BIN="/opt/homebrew/bin/brew"
    else
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（x86_64）"
        exit 1
      }
      BREW_BIN="/usr/local/bin/brew"
    fi
    success_echo "✅ Homebrew 安装成功"
  else
    BREW_BIN="$(locate_brew_bin)"
    info_echo "🍺 Homebrew 已存在：$BREW_BIN"
  fi

  # 注入 brew shellenv（保证 brew 在新终端也可用）
  inject_shellenv_block "homebrew_env" "eval \"\$(${BREW_BIN} shellenv)\""
  eval "$("${BREW_BIN}" shellenv)" >/dev/null 2>&1 || true

  # 更新（doctor 可能返回非 0，别让脚本直接挂）
  info_echo "🔄 Homebrew 更新中..."
  "${BREW_BIN}" update && "${BREW_BIN}" upgrade && "${BREW_BIN}" cleanup
  "${BREW_BIN}" doctor || warn_echo "⚠ brew doctor 报告了一些问题（不致命，可稍后手动处理）"
  success_echo "✅ Homebrew 已更新"
}

# ================================== FVM 安装（无 Dart 也能装） ==================================
ensure_fvm_path() {
  # install.sh 模式：~/.fvm_flutter/bin
  if [[ -d "$HOME/.fvm_flutter/bin" ]]; then
    export PATH="$HOME/.fvm_flutter/bin:$PATH"
    inject_shellenv_block "fvm_path" 'export PATH="$HOME/.fvm_flutter/bin:$PATH"'
    info_echo "🧩 已确保 PATH 包含：~/.fvm_flutter/bin"
  fi

  # dart pub 模式：~/.pub-cache/bin（仅在目录存在时注入）
  if [[ -d "$HOME/.pub-cache/bin" ]]; then
    export PATH="$HOME/.pub-cache/bin:$PATH"
    inject_shellenv_block "pub_cache_path" 'export PATH="$HOME/.pub-cache/bin:$PATH"'
    info_echo "🧩 已确保 PATH 包含：~/.pub-cache/bin"
  fi
}

install_fvm() {
  ensure_fvm_path

  if command -v fvm >/dev/null 2>&1; then
    info_echo "🔄 fvm 已安装：$(command -v fvm)"
    # 尝试升级：优先 brew upgrade；否则重跑 install.sh（等价更新）
    if command -v brew >/dev/null 2>&1 && brew list fvm >/dev/null 2>&1; then
      brew upgrade fvm || true
      success_echo "✅ fvm（brew）已尝试升级"
    else
      curl -fsSL https://fvm.app/install.sh | bash || true
      success_echo "✅ fvm（install.sh）已尝试升级"
    fi
  else
    note_echo "📦 未检测到 fvm，开始安装（优先 install.sh：无需 Dart）..."

    if curl -fsSL https://fvm.app/install.sh | bash; then
      success_echo "✅ fvm 安装成功（install.sh）"
    else
      warn_echo "⚠ install.sh 安装失败，fallback 使用 Homebrew 安装..."
      command -v brew >/dev/null 2>&1 || { error_echo "❌ brew 不存在，无法 fallback"; exit 1; }
      brew tap leoafarias/fvm
      brew install fvm
      success_echo "✅ fvm 安装成功（Homebrew）"
    fi
  fi

  ensure_fvm_path

  if ! command -v fvm >/dev/null 2>&1; then
    error_echo "❌ fvm 仍不可用（PATH/权限问题）。请新开终端或检查 ${PROFILE_FILE}"
    exit 1
  fi

  fvm --version | tee -a "$LOG_FILE"
}

# ================================== 项目根目录定位（可在任意目录运行） ==================================
find_flutter_project_root() {
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -f "$d/pubspec.yaml" ]]; then
      echo "$d"
      return 0
    fi
    d="${d:h}"
  done

  # fallback：脚本所在目录
  local script_dir="${0:A:h}"
  if [[ -f "$script_dir/pubspec.yaml" ]]; then
    echo "$script_dir"
    return 0
  fi

  return 1
}

# ================================== 初始化 Flutter 版本 ==================================
init_flutter_sdk() {
  if find_flutter_project_root >/dev/null 2>&1; then
    PROJECT_ROOT="$(find_flutter_project_root)"
    success_echo "📁 Flutter 项目根目录：$PROJECT_ROOT"
    cd "$PROJECT_ROOT"
    success_echo "🚀 初始化 stable Flutter（写入 .fvm）..."
    fvm install stable
    fvm use stable
  else
    warn_echo "⚠ 未找到 pubspec.yaml：将只安装 stable 到 FVM 缓存，不写入项目配置"
    fvm install stable || true
  fi
}

# ================================== Flutter 命令选择（FVM / 系统） ==================================
detect_flutter_cmd() {
  local root="${PROJECT_ROOT:-$PWD}"
  local fvm_config_path="$root/.fvm/fvm_config.json"
  if command -v fvm >/dev/null 2>&1 && [[ -f "$fvm_config_path" ]]; then
    flutter_cmd=("fvm" "flutter")
    info_echo "🧩 检测到 FVM 项目，使用命令：fvm flutter"
  else
    flutter_cmd=("flutter")
    info_echo "📦 使用系统 Flutter 命令：flutter"
  fi
}

# ================================== 执行初始化命令 ==================================
run_flutter_commands() {
  "${flutter_cmd[@]}" doctor -v
  "${flutter_cmd[@]}" --version
  "${flutter_cmd[@]}" pub get
  "${flutter_cmd[@]}" precache
  success_echo "✅ Flutter 初始化流程完成"
}

# ================================== 主函数入口 ==================================
main() {
  clear
  show_script_intro
  detect_profile_file
  install_homebrew
  install_fvm
  init_flutter_sdk
  detect_flutter_cmd
  run_flutter_commands
}

main "$@"
