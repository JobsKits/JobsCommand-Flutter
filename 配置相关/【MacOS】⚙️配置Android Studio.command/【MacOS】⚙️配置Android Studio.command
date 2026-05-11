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
  # ✅ 全局变量配置
  SDK_DIR="$HOME/Library/Android/sdk"
  CMDLINE_TOOLS_DIR="$SDK_DIR/cmdline-tools/latest"
  AVD_NAME="Pixel_5_API_34"
  CMDLINE_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-mac-10406996_latest.zip"

  # ✅ 彩色输出函数
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

  # ✅ 自述信息
  print_banner() {
    clear
    echo ""
    highlight_echo "📦 准备开始自动化安装 Android SDK + 模拟器，请保持网络通畅..."
    echo ""
  }

  # ✅ 下载并安装 Command-line Tools
  install_cmdline_tools() {
    mkdir -p "$CMDLINE_TOOLS_DIR"
    if [[ ! -f "$CMDLINE_TOOLS_DIR/bin/sdkmanager" ]]; then
      info_echo "📥 正在下载 Android Command-line Tools..."
      curl -Lo commandlinetools.zip "$CMDLINE_ZIP_URL"
      unzip -q commandlinetools.zip -d "$CMDLINE_TOOLS_DIR"
      rm commandlinetools.zip
      success_echo "✔ 解压完成：cmdline-tools 已就绪"
    else
      note_echo "➤ 已存在 cmdline-tools，跳过下载"
    fi
  }

  # ✅ 配置当前环境变量
  setup_env() {
    export ANDROID_HOME="$SDK_DIR"
    export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$CMDLINE_TOOLS_DIR/bin:$PATH"
    success_echo "✔ 环境变量已就绪（当前会话）"
  }

  # ✅ 安装 SDK 必备组件
  install_sdk_components() {
    info_echo "🔧 安装 platform-tools、emulator、系统镜像等组件..."
    yes | sdkmanager --sdk_root="$SDK_DIR" \
      "platform-tools" \
      "emulator" \
      "platforms;android-34" \
      "system-images;android-34;google_apis;x86_64" \
      "cmdline-tools;latest"
  }

  # ✅ 创建 Android 模拟器
  create_avd() {
    echo ""
    if ! avdmanager list avd | grep -q "$AVD_NAME"; then
      info_echo "🛠️ 创建模拟器 $AVD_NAME..."
      echo "no" | avdmanager create avd -n "$AVD_NAME" -k "system-images;android-34;google_apis;x86_64" --device "pixel_5"
      success_echo "✔ 模拟器已创建：$AVD_NAME"
    else
      note_echo "➤ 已存在模拟器：$AVD_NAME"
    fi
  }

  # ✅ 启动 Android 模拟器（fzf 选择 + 等待 ready）
  start_emulator() {
    if adb devices | grep -q "device$"; then
      success_echo "✅ 已检测到设备或模拟器"
      return
    fi

    warm_echo "🖥️ 当前无模拟器运行，准备启动 AVD..."

    if ! command -v fzf &>/dev/null; then
      error_echo "❌ 未安装 fzf，请先安装：brew install fzf"
      exit 1
    fi

    avds=($("$ANDROID_HOME/emulator/emulator" -list-avds))
    if [[ ${#avds[@]} -eq 0 ]]; then
      error_echo "❌ 未找到任何 AVD，请先使用 avdmanager 创建模拟器"
      exit 1
    fi

    selected_avd=$(printf "%s\n" "${avds[@]}" | fzf --prompt="📱 选择要启动的模拟器：")
    if [[ -z "$selected_avd" ]]; then
      error_echo "❌ 未选择 AVD，已取消"
      exit 1
    fi

    highlight_echo "🚀 启动模拟器：$selected_avd ..."
    nohup "$ANDROID_HOME/emulator/emulator" -avd "$selected_avd" >/dev/null 2>&1 &

    info_echo "⏳ 等待模拟器启动中，请稍候..."
    for i in {1..30}; do
      if adb devices | grep -q "device$"; then
        success_echo "✅ 模拟器已就绪"
        return
      fi
      sleep 2
    done

    error_echo "❌ 模拟器启动失败，请手动检查 AVD 是否可用"
    exit 1
  }

  # ✅ 输出添加环境变量提示
  print_env_instructions() {
    echo ""
    note_echo "📌 若要永久使用 emulator 命令，请将以下内容添加到 ~/.zshrc 或 ~/.bash_profile："
    echo "export ANDROID_HOME=\"$SDK_DIR\""
    echo "export PATH=\"\$ANDROID_HOME/emulator:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\""
  }

  # ✅ 主流程入口函数
  main() {
    print_banner              # 🎯 自述信息
    install_cmdline_tools     # 📦 下载并解压 cmdline-tools
    setup_env                 # 🧭 设置临时环境变量
    install_sdk_components    # 🔧 安装 SDK 核心组件
    create_avd                # 🛠️ 创建 AVD 模拟器
    start_emulator            # 🚀 启动模拟器并检查状态
    print_env_instructions    # 📎 输出持久化配置路径
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
