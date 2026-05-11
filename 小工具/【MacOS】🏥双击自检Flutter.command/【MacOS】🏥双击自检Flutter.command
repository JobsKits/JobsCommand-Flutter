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
  # ✅ 日志与输出函数
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径

  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  color_echo()     { log "\033[1;32m$1\033[0m"; }         # ✅ 正常绿色输出
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }       # ℹ 信息
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }       # ✔ 成功
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }       # ⚠ 警告
  warm_echo()      { log "\033[1;33m$1\033[0m"; }         # 🟡 温馨提示（无图标）
  note_echo()      { log "\033[1;35m➤ $1\033[0m"; }       # ➤ 说明
  error_echo()     { log "\033[1;31m✖ $1\033[0m"; }       # ✖ 错误
  err_echo()       { log "\033[1;31m$1\033[0m"; }         # 🔴 错误纯文本
  debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }      # 🐞 调试
  highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }      # 🔹 高亮
  gray_echo()      { log "\033[0;90m$1\033[0m"; }         # ⚫ 次要信息
  bold_echo()      { log "\033[1m$1\033[0m"; }            # 📝 加粗
  underline_echo() { log "\033[4m$1\033[0m"; }            # 🔗 下划线

  # ✅ 自述信息
  show_intro() {
    bold_echo ""
    highlight_echo "🧾 本脚本用于一键检测 Flutter 开发环境"

    note_echo "
  ✔ 检查内容包括：
    • 系统版本 / 用户信息
    • Flutter / FVM / Dart / Java / Xcode / Android SDK
    • 环境变量（PATH、JAVA_HOME、ANDROID_SDK_ROOT）
    • 当前 iOS 模拟器与可用设备
    • flutter doctor -v 和 flutter analyze 输出
    "

    read "?👉 按回车开始执行环境检测，或输入任意字符退出： " go
    if [[ -n "$go" ]]; then
      error_echo "✖ 用户取消执行，已退出。"
      exit 0
    fi
  }

  # ✅ 工作目录初始化 📂
  init_directory() {
    WORK_DIR=$(cd "$(dirname "$0")" && pwd)
    gray_echo "📂 当前脚本路径：$WORK_DIR"
    cd "$WORK_DIR" || exit 1
  }

  # ✅ 检测 Flutter 命令 🧩
  detect_flutter_command() {
    flutter_root="$PWD"
    if [[ -f "$flutter_root/.fvm/fvm_config.json" ]]; then
      warn_echo "🧩 检测到 FVM，将使用 fvm flutter"
      flutter_cmd=(fvm flutter)
    else
      info_echo "📦 使用系统 Flutter"
      flutter_cmd=(flutter)
    fi
  }

  # ✅ 系统基本信息 🧠
  print_system_info() {
    highlight_echo "🧠 系统基本信息"
    info_echo "系统版本：$(sw_vers | grep ProductVersion | awk '{print $2}')"
    info_echo "Shell：$SHELL"
    info_echo "当前用户：$USER"
  }

  # ✅ Flutter & FVM 🐦
  print_flutter_info() {
    highlight_echo "📦 Flutter / FVM 信息"
    if [[ "${flutter_cmd[*]}" == "fvm flutter" ]]; then
      success_echo "检测到 FVM：使用 fvm flutter"
      info_echo "fvm 路径：$(command -v fvm)"
    else
      info_echo "使用系统 Flutter"
    fi
    "${flutter_cmd[@]}" --version
  }

  # ✅ Dart 信息 🎯
  print_dart_info() {
    highlight_echo "🎯 Dart 信息"
    if command -v dart >/dev/null 2>&1; then
      dart --version
    else
      warn_echo "未检测到 dart 命令"
    fi
  }

  # ✅ Xcode 信息 🍏
  print_xcode_info() {
    highlight_echo "🍏 Xcode 信息"
    if command -v xcodebuild >/dev/null 2>&1; then
      info_echo "Xcode 版本：$(xcodebuild -version | head -n 1)"
      info_echo "Xcode 路径：$(xcode-select -p)"
    else
      error_echo "未检测到 xcodebuild"
    fi
  }

  # ✅ Java 信息 ☕
  print_java_info() {
    highlight_echo "☕ Java 环境"
    if command -v java >/dev/null 2>&1; then
      java -version 2>&1 | head -n 1
      info_echo "JAVA_HOME：${JAVA_HOME:-[未设置]}"
    else
      error_echo "未安装 Java"
    fi
  }

  # ✅ Android SDK 🤖
  print_android_sdk_info() {
    highlight_echo "🤖 Android SDK"
    if [[ -n "$ANDROID_SDK_ROOT" ]]; then
      info_echo "ANDROID_SDK_ROOT：$ANDROID_SDK_ROOT"
      if [[ -d "$ANDROID_SDK_ROOT" ]]; then
        success_echo "SDK 目录存在"
        if [[ -f "$ANDROID_SDK_ROOT/tools/bin/sdkmanager" ]]; then
          "$ANDROID_SDK_ROOT/tools/bin/sdkmanager" --version
        elif [[ -f "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
          "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --version
        else
          warn_echo "未找到 sdkmanager"
        fi
      else
        error_echo "ANDROID_SDK_ROOT 路径不存在"
      fi
    else
      warn_echo "未设置 ANDROID_SDK_ROOT 环境变量"
    fi
  }

  # ✅ 环境变量格式化 🌐
  print_env_variables() {
    highlight_echo "🌐 环境变量"
    echo -e "\033[1;33mPATH:\033[0m"
    IFS=':' read -rA paths <<< "$PATH"
    for p in "${paths[@]}"; do echo "  $p"; done
    echo -e "\033[1;33mJAVA_HOME:\033[0m\n  ${JAVA_HOME:-[未设置]}"
    echo -e "\033[1;33mANDROID_SDK_ROOT:\033[0m\n  ${ANDROID_SDK_ROOT:-[未设置]}"
  }

  # ✅ 模拟器与设备 📱
  print_devices() {
    highlight_echo "📱 iOS 模拟器设备（Booted）"
    xcrun simctl list devices | grep -E "Booted" || warn_echo "暂无运行中的 iOS 模拟器"

    highlight_echo "🧩 Flutter 可用设备"
    "${flutter_cmd[@]}" devices
  }

  # ✅ flutter doctor 🩺
  run_flutter_doctor() {
    highlight_echo "🩺 flutter doctor"
    "${flutter_cmd[@]}" doctor -v
    "${flutter_cmd[@]}" analyze
  }

  # ✅ 主函数入口 🚀
  main() {
      show_intro                        # 🖨️ 自述信息
      init_directory                    # ✅ 切换到当前脚本所在目录
      detect_flutter_command            # ✅ 判断是否为 FVM 项目并设置 flutter_cmd

      print_system_info                 # 🧠 显示 macOS 系统基本信息（版本、shell、用户）
      print_flutter_info                # 📦 显示 Flutter 与 FVM 安装状态及版本
      print_dart_info                   # 🎯 显示 Dart SDK 安装状态及版本
      print_xcode_info                  # 🍏 显示 Xcode 版本与路径
      print_java_info                   # ☕ 显示 Java 环境与 JAVA_HOME 设置
      print_android_sdk_info            # 🤖 显示 Android SDK 状态、版本与 sdkmanager 检测
      print_env_variables               # 🌐 格式化输出 PATH、JAVA_HOME、ANDROID_SDK_ROOT 等环境变量

      print_devices                     # 📱 列出运行中的 iOS 模拟器与 Flutter 可用设备
      run_flutter_doctor                # 🩺 执行 flutter doctor -v 以及 flutter analyze 分析项目环境

      echo ""
      success_echo "🧩 环境检测完成"      # ✅ 输出最终成功提示
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
