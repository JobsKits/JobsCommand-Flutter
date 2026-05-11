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
  # ✅ 全局变量
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
  SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
  flutter_cmd=("flutter")

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

  # ✅ Flutter 项目识别函数
  is_flutter_project_root() {
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ✅ 判断Flutter文件是否是入口
  is_dart_entry_file() {
    [[ "$1" == *.dart && -f "$1" ]]
  }

  # ✅ 转换路径为绝对路径
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

  # ✅ 自述信息
  print_self_intro() {
    bold_echo "🛠️ Flutter iOS 打包脚本"
    note_echo "功能说明："
    gray_echo  "  1️⃣ 检查 Xcode 与 CocoaPods 环境（自动安装缺失组件）"
    gray_echo  "  2️⃣ 调用 Flutter 构建 iOS Release 产物"
    gray_echo  "  3️⃣ 构建完成后自动打开 IPA 输出文件夹"
    gray_echo  "  4️⃣ 记录完整日志到：$LOG_FILE"
    note_echo "注意事项："
    gray_echo  "  ⚠ 请提前在 Xcode 中配置好签名证书和 Provisioning Profile"
    echo ""
  }

  # ✅ 入口检测（支持传参）
  detect_entry() {
    local input_path="$1"

    if [[ -n "$input_path" ]]; then
      input_path="${input_path//\"/}"
      input_path="${input_path%/}"
      if is_flutter_project_root "$input_path"; then
        flutter_root=$(abs_path "$input_path")
        entry_file="$flutter_root/lib/main.dart"
        highlight_echo "🎯 使用传入路径作为 Flutter 根目录：$flutter_root"
      else
        error_echo "❌ 参数路径不是有效 Flutter 项目：$input_path"
        exit 1
      fi
    else
      while true; do
        warn_echo "📂 请拖入 Flutter 项目根目录或 Dart 单文件路径（直接回车 = 使用脚本所在目录）："
        read -r user_input
        user_input="${user_input//\"/}"
        user_input="${user_input%/}"

        if [[ -z "$user_input" ]]; then
          if is_flutter_project_root "$SCRIPT_DIR"; then
            flutter_root=$(abs_path "$SCRIPT_DIR")
            entry_file="$flutter_root/lib/main.dart"
            highlight_echo "🎯 脚本所在目录为 Flutter 项目，自动使用：$flutter_root"
            break
          else
            error_echo "❌ 当前目录不是 Flutter 项目，请重新拖入。"
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

        error_echo "❌ 无效路径，请重新拖入 Flutter 项目或 Dart 文件。"
      done
    fi

    IPA_OUTPUT_DIR="$flutter_root/build/ios/ipa"
    cd "$flutter_root" || { error_echo "❌ 无法进入项目目录：$flutter_root"; exit 1; }
    success_echo "✅ 项目路径：$flutter_root"
    success_echo "🎯 入口文件：$entry_file"
  }

  # ✅ 环境检查
  check_env() {
    info_echo "检查环境..."
    if ! command -v xcodebuild &>/dev/null; then
      error_echo "未找到 Xcode，请安装后重试。"
      exit 1
    fi
    if ! command -v pod &>/dev/null; then
      error_echo "未找到 CocoaPods，请安装后重试。"
      exit 1
    fi
    success_echo "环境检查通过 ✅"
  }

  # ✅ 构建 Flutter iOS
  flutter_build_ios() {
    cd "$flutter_root" || {
      error_echo "❌ 无法进入项目目录：$flutter_root"
      exit 1
    }
    info_echo "开始构建 Flutter iOS Release 产物..."
    "${flutter_cmd[@]}" clean
    "${flutter_cmd[@]}" pub get
    "${flutter_cmd[@]}" build ipa --release
    success_echo "✔ Flutter 构建完成"
  }

  # ✅ 验证输出
  verify_ipa_output() {
    if [[ -d "$IPA_OUTPUT_DIR" && -n "$(ls "$IPA_OUTPUT_DIR"/*.ipa 2>/dev/null)" ]]; then
      success_echo "📦 成功生成 IPA 文件："
      ls -lh "$IPA_OUTPUT_DIR"/*.ipa | tee -a "$LOG_FILE"
    else
      error_echo "❌ 未找到 IPA 文件，请检查构建日志"
      exit 1
    fi
  }

  # ✅ 打开目录
  open_output_dir() {
    info_echo "📂 打开 IPA 文件夹..."
    open "$IPA_OUTPUT_DIR"
  }

  # ✅ 耗时统计
  print_duration() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    success_echo "⏱️ 脚本总耗时：${DURATION}s"
  }

  # ✅ 等待开始
  wait_for_user_to_start() {
    echo ""
    read "?👉 按下回车开始执行，或 Ctrl+C 取消..."
    echo ""
  }

  # ✅ 主函数
  main() {
    print_self_intro               # ✅ 💬自述信息
    wait_for_user_to_start         # ✅ 🚀等待开始
    detect_entry "$1"              # ✅ 🚪入口检测（支持传参）
    START_TIME=$(date +%s)         # ✅ 耗时统计：⌛️计时开始
    check_env                      # ✅ ♻️环境检查
    flutter_build_ios              # ✅ 构建 Flutter iOS
    verify_ipa_output              # ✅ 验证输出
    open_output_dir                # ✅ 📁打开目录
    print_duration                 # ✅ 耗时统计：⌛️计时结束
    success_echo "✅ 全部完成 🎉"
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
