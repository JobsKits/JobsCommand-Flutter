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
  # ✅ 彩色输出函数
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')     # 当前脚本名（去掉扩展名）
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                    # 设置日志输出路径

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

  # ✅ 判断芯片架构（ARM64 / x86_64）
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }

  # ✅ 自检安装 🍺 Homebrew （自动架构判断）
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

  # ✅ 自检安装 fzf
  install_fzf() {
      if ! command -v fzf >/dev/null 2>&1; then
          note_echo "📦 fzf 未安装，正在通过 Homebrew 安装..."
          brew install fzf
          success_echo "✅ fzf 安装完成"
      else
          info_echo "🔄 fzf 已安装，正在升级..."
          ask_run "升级 fzf？" && brew upgrade fzf || true
          success_echo "✅ fzf 升级完成"
      fi
  }

  # ✅ 项目类型判断
  is_flutter_project() {
      [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ✅ 系统级 Flutter 清理菜单
  show_global_menu() {
      local CHOICE
      CHOICE=$(cat <<EOF | fzf --prompt="📌 请选择要执行的系统清理操作：" --height=15 --border --reverse
  【清除 Pub 缓存】rm -rf ~/.pub-cache/*
  【清除 Android 缓存】rm -rf ~/.gradle
  【修复依赖缓存】flutter pub cache repair
  【加载 Flutter 项目】拖入 pubspec.yaml 所在路径
  EOF
    )

      [[ -z "$CHOICE" ]] && error_echo "❌ 操作取消" && exit 0
      echo ""
      success_echo "▶️ 执行中：$CHOICE"

      case "$CHOICE" in
          *Pub\ 缓存*)
            open "$HOME/.pub-cache"
            read "?⏎ 按回车清除 .pub-cache，其他键跳过："
            [[ -z "$REPLY" ]] && rm -rf "$HOME/.pub-cache"/* && success_echo "✅ Pub 缓存已清除" || info_echo "🚫 跳过"
            ;;
          *Android\ 缓存*)
            rm -rf "$HOME/.gradle"
            success_echo "✅ Android 缓存已清除"
            ;;
          *依赖缓存*)
            fvm flutter pub cache repair || flutter pub cache repair
            success_echo "✅ Flutter 依赖缓存已修复"
            ;;
          *加载\ Flutter\ 项目*)
            prompt_flutter_path
            ;;
      esac
  }

  # ✅ Flutter 项目路径交互
  prompt_flutter_path() {
      while true; do
          note_echo "📂 请拖入 Flutter 项目目录（含 pubspec.yaml 和 lib/）"
          read "?👉 输入路径（回车返回）："
          local user_input="$REPLY"

          if [[ -z "$user_input" || "$user_input" != /* ]]; then
              warn_echo "↩️ 返回系统菜单"
              show_global_menu
              return
          fi

          if [[ ! -d "$user_input" ]]; then
              error_echo "❌ 不是有效目录，请重新拖入"
              continue
          fi

          if is_flutter_project "$user_input"; then
              cd "$user_input"
              success_echo "✅ 已识别 Flutter 项目：$user_input"
              show_flutter_project_menu
              return
          else
              error_echo "❌ 非有效 Flutter 项目（缺 pubspec.yaml / lib）"
          fi
      done
  }

  # ✅ Flutter 项目清理菜单
  show_flutter_project_menu() {
      local CHOICE
      CHOICE=$(cat <<EOF | fzf --prompt="📦 Flutter 项目操作菜单：" --height=15 --border --reverse
  【刷新依赖】flutter pub get
  【项目清理】flutter clean && pub get && pub upgrade
  【清除 Flutter 缓存】rm -rf bin/cache
  【清除 iOS 缓存】rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter .dart_tool build pubspec.lock ~/Library/Developer/Xcode/DerivedData/*
  【返回上级菜单】
  EOF
      )

      [[ -z "$CHOICE" ]] && error_echo "❌ 操作取消" && return
      success_echo "▶️ 执行中：$CHOICE"

      case "$CHOICE" in
          *刷新依赖*) fvm flutter pub get || flutter pub get ;;
          *项目清理*)
            fvm flutter clean || flutter clean
            rm -rf .idea .dart_tool
            fvm flutter pub get || flutter pub get
            fvm flutter pub upgrade --major-versions || flutter pub upgrade --major-versions
            success_echo "✅ 项目清理完成"
            ;;
          *Flutter\ 缓存*)
            local sdk_path
            sdk_path="$(dirname "$(dirname "$(command -v flutter)")")"
            if [[ -f ".fvm/fvm_config.json" && -d ".fvm/flutter_sdk/bin/cache" ]]; then
              sdk_path="$(cd .fvm/flutter_sdk && pwd)"
            fi
            local flutter_cache="$sdk_path/bin/cache"
            note_echo "📁 缓存路径：$flutter_cache"
            open "$flutter_cache"
            read "?⏎ 按回车清除缓存，其他键跳过："
            [[ -z "$REPLY" ]] && rm -rf "$flutter_cache"/* && success_echo "✅ 缓存清除完成" || info_echo "🚫 跳过"
            ;;
          *iOS\ 缓存*)
            rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter
            rm -rf .dart_tool build pubspec.lock
            rm -rf ~/Library/Developer/Xcode/DerivedData/*
            success_echo "✅ iOS 缓存清除完成"
            ;;
          *返回*) show_global_menu ;;
      esac
  }

  # ✅ 主交互流程封装
  enter_interactive_mode() {
      echo ""
      read "?👉 按下回车键继续，或 Ctrl+C 退出..."

      install_homebrew
      install_fzf

      if is_flutter_project "$(pwd)"; then
          success_echo "📁 当前目录为 Flutter 项目"
          show_flutter_project_menu
      else
          warn_echo "📁 当前不是 Flutter 项目，将进入系统菜单"
          show_global_menu
      fi
  }

  # ✅ 主函数入口
  main() {
      clear
      highlight_echo "🧹 Flutter 清理工具"
      info_echo "• 支持系统缓存与项目缓存清理"
      info_echo "• 支持拖入项目路径进入操作菜单"
      enter_interactive_mode
      success_echo "🎉 所有操作执行完毕"
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
