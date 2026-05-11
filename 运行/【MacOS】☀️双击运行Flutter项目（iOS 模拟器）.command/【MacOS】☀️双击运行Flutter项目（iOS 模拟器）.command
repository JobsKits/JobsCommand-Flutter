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

  # ✅ 路径工具函数
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

  is_flutter_project_root() {
    local p="$1"
    local abs=$(abs_path "$p") || return 1
    [[ -f "$abs/pubspec.yaml" && -d "$abs/lib" ]]
  }

  is_dart_entry_file() {
    local f="$1"
    local abs=$(abs_path "$f") || return 1
    [[ $abs == *.dart ]] || return 1
    if grep -Ev '^\s*//' "$abs" | grep -Eq '\b(Future\s*<\s*void\s*>|void)?\s*main\s*\(\s*\)\s*(async\s*)?(\{|=>)' ; then
      return 0
    fi
    return 1
  }

  # ✅ 自述信息
  show_banner() {
    clear
    highlight_echo '                                                                                       '
    highlight_echo '88888888888 88         88        88 888888888888 888888888888 88888888888 88888888ba   '
    highlight_echo '88          88         88        88      88           88      88          88      "8b  '
    highlight_echo '88          88         88        88      88           88      88          88      ,8P  '
    highlight_echo '88aaaaa     88         88        88      88           88      88aaaaa     88aaaaaa8P''  '
    highlight_echo '88""""""     88         88        88      88           88      88""""""     88""""""88''  '
    highlight_echo '88          88         88        88      88           88      88          88     `8b   '
    highlight_echo '88          88         Y8a.    .a8P      88           88      88          88      8b   '
    highlight_echo '88          88888888888 `"Y8888Y"`       88           88      88888888888 88      `8b  '
    warn_echo    "                        🛠️ FLUTTER iOS 模拟器 启动脚本"
    echo ""
    success_echo "🛠️ 本脚本用于将 Dart 或 Flutter 项目运行到 iOS 模拟器"
    success_echo "===================================================================="
    success_echo "👉 支持："
    success_echo "   1. 拖入 Flutter 项目根目录（含 pubspec.yaml 和 lib/main.dart）或 Dart 单文件（含 void main）"
    success_echo "   2. 自动识别 FVM、构建模式、flavor 参数"
    success_echo "   3. 自动启动 iOS 模拟器，处理假后台问题"
    success_echo "   4. 支持 fzf 模拟器选择与创建（设备 + 系统组合）"
    success_echo "   5. flutter run 日志异常时自动修复 CocoaPods"
    success_echo "   6. 自动创建桌面 .command 快捷方式"
    success_echo "===================================================================="
    error_echo   "📌 如需运行断点调试，请使用 VSCode / Android Studio / Xcode 等 IDE。终端运行不支持断点。"
    echo ""
  }

  # ✅ 项目入口识别
  detect_entry() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"

    while true; do
      warn_echo "📂 请拖入 Flutter 项目根目录或 Dart 单文件路径："
      read -r user_input
      user_input="${user_input//\"/}"
      user_input="${user_input%/}"

      if [[ -z "$user_input" ]]; then
        if is_flutter_project_root "$SCRIPT_DIR"; then
          flutter_root=$(abs_path "$SCRIPT_DIR")
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

  # ✅ 构建参数交互
  prompt_build_config() {
    echo ""
    info_echo "🌶️ 请输入构建的 flavor 名称（回车=无 --flavor）："
    read -r flavor
    if [[ -n "$flavor" ]]; then
      flavor_args=(--flavor "$flavor")
    else
      flavor_args=()
    fi

    echo ""
    info_echo "🚧 请选择构建模式："
    build_mode=$(printf "debug\nrelease\nprofile" | fzf --prompt="👉 选择构建模式 > " --height=40% --reverse)
    build_mode="${build_mode:-debug}"
    success_echo "✅ 已选择构建模式：$build_mode"
  }

  # ✅ FVM 检测
  detect_fvm() {
    if [[ -f "$flutter_root/.fvm/fvm_config.json" ]]; then
      note_echo "🧩 检测到 FVM，将使用 fvm flutter。"
      flutter_cmd=(fvm flutter)
    else
      flutter_cmd=(flutter)
    fi
  }

  # ✅ 执行 pub get
  pub_get() {
    read '?📦 执行 flutter pub get？(回车=执行 / 任意键=跳过) ' run_get
    if [[ -z "$run_get" ]]; then
      "${flutter_cmd[@]}" pub get
    else
      warn_echo "⏭️ 跳过 pub get。"
    fi
  }

  # ✅  修复模拟器假后台
  fix_fake_simulator() {
    warn_echo "🕵️ 检测模拟器是否处于假后台..."
    booted_check=$(xcrun simctl list devices | grep "(Booted)") # ✅ 使用 simctl 检查当前是否有已启动（Booted）状态的模拟器设备
    simulator_running=$(pgrep -f Simulator)                     # ✅ 检查是否存在 Simulator 应用的后台进程（即进程存在但可能界面未显示）
  
    # 🧠 如果没有任何 Booted 状态的设备，但检测到 Simulator 进程，说明是“假后台”
    if [[ -z "$booted_check" && -n "$simulator_running" ]]; then
      error_echo "❗️ 模拟器处于假后台状态，正在强制关闭..."
      xcrun simctl shutdown all >/dev/null 2>&1                 # 🧹 使用 simctl 关闭所有模拟器实例（防止残留）
      osascript -e 'quit app "Simulator"' >/dev/null 2>&1       # 🧼 使用 AppleScript 关闭 Simulator 应用（用于 GUI 层面的强制退出）
      pkill -f Simulator >/dev/null 2>&1                        # 🧯 最后保险措施：通过进程名强制终止 Simulator 进程
      success_echo "✅ 已强制关闭假后台模拟器。"
    else
      success_echo "✅ 模拟器状态正常，无需关闭。"
    fi
  }

  # ✅ 创建桌面快捷方式
  create_shortcut() {
    project_name=$(grep -m1 '^name:' "$flutter_root/pubspec.yaml" | awk '{print $2}')
    [[ -z "$project_name" ]] && project_name="FlutterProject"

    desktop_path="$HOME/Desktop"
    shortcut_path="$desktop_path/${project_name}.command"
    count=1

    while [[ -e "$shortcut_path" ]]; do
      shortcut_path="$desktop_path/${project_name} ($count).command"
      ((count++))
    done

    mkdir -p "$desktop_path" 2>/dev/null

    if [[ ! -L "$shortcut_path" || "$(readlink "$shortcut_path" 2>/dev/null)" != "$SCRIPT_PATH" ]]; then
      ln -sf "$SCRIPT_PATH" "$shortcut_path"
      chmod +x "$shortcut_path"
      success_echo "✅ 已创建桌面快捷方式：$shortcut_path"
    else
      warn_echo "⚠️ 快捷方式已存在，跳过创建。"
    fi
  }

  # ✅ 启动模拟器
  launch_simulator() {
    local sim_check=$(xcrun simctl list devices | grep Booted)
    if [[ -n "$sim_check" ]]; then
      success_echo "📱 模拟器已启动。"
      return
    fi

    local sim_running=$(pgrep -f Simulator)
    if [[ -z "$sim_running" ]]; then
      info_echo "🚀 正在启动 Simulator 应用..."
      open -a Simulator
      sleep 3
    fi
  }

  # ✅ 选择 iOS 模拟器（fzf），并启动该设备
  select_or_create_device() {
    local device_list selected_device

    # 获取所有可用 iOS 模拟器设备（不含 unavailable）
    device_list=$(xcrun simctl list devices available | grep -E 'iPhone|iPad' | awk -F'[()]' '{gsub(/^[ \t]+/, "", $1); print $1 " (" $2 ")"}')

    selected_device=$(echo "$device_list" | fzf --prompt="📱 选择 iOS 模拟器设备 > " --height=50% --reverse)

    if [[ -z "$selected_device" ]]; then
      error_echo "❌ 未选择模拟器设备，无法继续。"
      exit 1
    fi

    ios_device_id=$(echo "$selected_device" | grep -oE '[0-9A-Fa-f\-]{36}')
    ios_device_name=$(echo "$selected_device" | sed -E 's/\s+\([0-9A-Fa-f\-]+\)$//')

    if [[ -n "$ios_device_id" ]]; then
      highlight_echo "📱 启动模拟器：$ios_device_name"
      xcrun simctl boot "$ios_device_id" >/dev/null 2>&1
      open -a Simulator
      sleep 2
      success_echo "✅ 设备启动完成：$ios_device_name"
    else
      error_echo "❌ 解析设备 UDID 失败：$selected_device"
      exit 1
    fi
  }

  # ✅ 运行 Flutter 项目
  run_flutter_app() {
    if [[ -z "$ios_device_id" ]]; then
      error_echo "❌ 没有有效的 iOS 模拟器设备 ID，无法运行。"
      exit 1
    fi

    local run_cmd=("${flutter_cmd[@]}" run -d "$ios_device_id" "$entry_file" --$build_mode "${flavor_args[@]}")

    highlight_echo "🚀 正在运行到 iOS 模拟器：$ios_device_name"
    highlight_echo "💻 执行命令：${run_cmd[*]}"

    "${run_cmd[@]}" || {
      warn_echo "⚠️ flutter run 失败，尝试自动修复 CocoaPods..."
      pod install --project-directory=ios || true
      sleep 1
      "${run_cmd[@]}"
    }
  }

  # ✅  主流程函数
  main() {
    clear
    show_banner                   # 自述信息
    detect_entry                  # 项目入口识别
    prompt_build_config           # 构建参数交互
    detect_fvm                    # FVM 检测
    pub_get                       # 执行 pub get
    fix_fake_simulator            # 修复模拟器假后台
    launch_simulator              # 启动模拟器
    select_or_create_device       # 选择或创建模拟器设备
    run_flutter_app               # 运行 Flutter 项目
    create_shortcut               # 创建桌面快捷方式
  }

  # ✅ 脚本执行入口
  main "$@"

  # =========================== 原脚本业务逻辑区结束 ===========================
}

main() {
  show_readme_and_wait
  run_original_logic "$@"
  success_echo "脚本执行结束。日志：$LOG_FILE"
}

main "$@"
