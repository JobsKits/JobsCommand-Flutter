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
  # ✅ 配置参数
  DEFAULT_SDK="$HOME/Library/Android/sdk"
  CMDLINE_DIR="$DEFAULT_SDK/cmdline-tools/latest"
  flutter_cmd=(flutter)  # 默认使用 flutter 命令
  flutter_root=""         # 将在 resolve_flutter_root 中初始化

  # ✅ 彩色输出函数
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

  # ✅ 判断当前目录是否为 Flutter 项目根目录
  _is_flutter_project_root() {
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ✅ 解析 Flutter 项目根目录（支持脚本目录、当前目录、拖入路径）
  resolve_flutter_root() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
    SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"

    debug_echo "🐞 SCRIPT_DIR: $SCRIPT_DIR"
    debug_echo "🐞 SCRIPT_PATH: $SCRIPT_PATH"
    debug_echo "🐞 当前工作目录：$(pwd -P)"

    flutter_root=""
    entry_file=""

    while true; do
      warn_echo "📂 请拖入 Flutter 项目根目录或 Dart 单文件路径："
      read -r user_input
      user_input="${user_input//\"/}"
      user_input=$(echo "$user_input" | xargs)
      debug_echo "🐞 用户输入路径：$user_input"

      # ✅ 用户直接回车：尝试脚本目录是否为 Flutter 项目
      if [[ -z "$user_input" ]]; then
        debug_echo "🐞 用户未输入路径，尝试使用 SCRIPT_DIR 检测"
        if _is_flutter_project_root "$SCRIPT_DIR"; then
          flutter_root="$SCRIPT_DIR"
          entry_file="$flutter_root/lib/main.dart"
          highlight_echo "🎯 检测到脚本所在目录是 Flutter 根目录，自动使用"
          break
        else
          error_echo "❌ SCRIPT_DIR ($SCRIPT_DIR) 不是有效 Flutter 项目"
          continue
        fi
      fi

      # ✅ 用户拖入路径
      if [[ -d "$user_input" ]]; then
        debug_echo "🐞 检测到输入是目录"
        if _is_flutter_project_root "$user_input"; then
          flutter_root="$user_input"
          entry_file="$flutter_root/lib/main.dart"
          highlight_echo "🎯 成功识别 Flutter 根目录：$flutter_root"
          break
        else
          error_echo "❌ 目录中未找到 pubspec.yaml 或 lib/：$user_input"
        fi
      elif [[ -f "$user_input" ]]; then
        debug_echo "🐞 检测到输入是文件"
        if grep -q 'main()' "$user_input"; then
          entry_file="$user_input"
          flutter_root="$(dirname "$user_input")"
          highlight_echo "🎯 成功识别 Dart 单文件：$entry_file"
          break
        else
          error_echo "❌ 文件不是 Dart 主程序：$user_input"
        fi
      else
        error_echo "❌ 输入路径无效：$user_input"
      fi
    done

    cd "$flutter_root" || {
      error_echo "❌ 无法进入项目目录：$flutter_root"
      exit 1
    }

    success_echo "✅ 项目路径：$flutter_root"
    success_echo "🎯 入口文件：$entry_file"
  }

  # ✅ 初始化 Flutter 命令
  init_flutter_command() {
    if [[ -f "$flutter_root/.fvm/fvm_config.json" ]]; then
      warn_echo "🧩 检测到 FVM，将使用 fvm flutter。"
      flutter_cmd=(fvm flutter)
    fi
  }

  # ✅ 确保 Android SDK 存在
  prepare_android_sdk() {
    info_echo "🛠️ 开始修复 Android SDK 缺失或 platform 目录为空的问题..."

    if [[ -d "$DEFAULT_SDK" ]]; then
      success_echo "✔ Android SDK 路径存在：$DEFAULT_SDK"
    else
      warn_echo "⚠️ 未检测到 Android SDK，正在创建目录：$DEFAULT_SDK"
      mkdir -p "$DEFAULT_SDK"
    fi
  }

  # ✅ 安装 Android cmdline-tools
  install_cmdline_tools() {
    if [[ ! -d "$CMDLINE_DIR" ]]; then
      info_echo "📦 正在下载 cmdline-tools 最新版..."
      mkdir -p "$DEFAULT_SDK/cmdline-tools"
      cd "$DEFAULT_SDK/cmdline-tools"

      curl -LO https://dl.google.com/android/repository/commandlinetools-mac-10406996_latest.zip
      unzip -q commandlinetools-mac-*.zip
      rm commandlinetools-mac-*.zip
      mv cmdline-tools latest

      success_echo "✔ cmdline-tools 安装成功"
    else
      success_echo "✔ cmdline-tools 已存在"
    fi
  }

  # ✅ 安装 Android SDK 组件
  install_sdk_components() {
    export ANDROID_SDK_ROOT="$DEFAULT_SDK"
    export PATH="$DEFAULT_SDK/cmdline-tools/latest/bin:$DEFAULT_SDK/platform-tools:$PATH"

    yes | sdkmanager --licenses > /dev/null

    info_echo "📦 安装 platform-tools、platforms;android-34、build-tools..."
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
  }

  # ✅ 配置 Flutter 使用的 SDK 路径
  configure_flutter_sdk() {
    "${flutter_cmd[@]}" config --android-sdk "$DEFAULT_SDK"
  }

  # ✅ 检查 Flutter 状态
  run_flutter_doctor() {
    echo ""
    "${flutter_cmd[@]}" doctor --android-licenses
    "${flutter_cmd[@]}" doctor
  }

  # ✅ 可选执行 pub get
  maybe_run_pub_get() {
    echo ""
    read '?📦 执行 flutter pub get？(回车=执行 / 任意键=跳过) ' run_get
    if [[ -z "$run_get" ]]; then
      "${flutter_cmd[@]}" pub get
    else
      warn_echo "⏭️ 跳过 pub get。"
    fi
  }

  # ✅ 主入口
  main() {
    clear
    resolve_flutter_root                                           # 识别并切换到 Flutter 根目录
    init_flutter_command                                           # 检查 FVM 使用情况
    prepare_android_sdk                                            # 确保 SDK 路径存在
    install_cmdline_tools                                          # 安装 cmdline-tools
    install_sdk_components                                         # 安装必要组件
    configure_flutter_sdk                                          # 配置 Flutter Android SDK 路径
    run_flutter_doctor                                             # 执行 doctor 检查
    maybe_run_pub_get                                              # 可选 pub get
    success_echo "✅ Android SDK 修复完成！请重新运行项目或继续开发。"
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
