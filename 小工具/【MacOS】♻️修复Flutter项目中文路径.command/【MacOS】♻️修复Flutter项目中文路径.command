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

  # ✅ 判断当前目录是否为Flutter项目根目录
  _is_flutter_project_root() {
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ✅ 项目路径与环境初始化
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

  # ✅ 自述信息
  print_banner() {
    echo ""
    highlight_echo "📦 脚本用途：修复 Flutter 项目中 import 语句中被 URI 编码的中文路径"
    echo ""
    info_echo "📁 判断 Flutter 项目根目录的依据："
    info_echo "   ✅ 当前目录下存在 pubspec.yaml"
    info_echo "   ✅ 当前目录下存在 lib/ 文件夹"
    echo ""
    info_echo "🔧 本脚本将自动执行以下步骤："
    info_echo "1️⃣ 检测 Flutter 项目根目录"
    info_echo "2️⃣ 自动识别 Flutter 命令（FVM 优先）"
    info_echo "3️⃣ 安装/升级工具（brew、perl、URI::Escape）"
    info_echo "4️⃣ 替换所有 Dart 文件中 URI 编码路径为中文路径"
    info_echo "5️⃣ 所有修改文件备份至 .import_backup/"
    info_echo "6️⃣ 自动生成说明文件"
    info_echo "7️⃣ 询问是否执行 flutter analyze"
    info_echo "8️⃣ 询问是否执行 flutter upgrade"
    echo ""
    read "?🔑 按下回车开始执行..."
  }

  # ✅ 检查 Flutter 项目根目录
  is_flutter_project_root() {
    [[ -f "pubspec.yaml" && -d "lib" ]]
  }

  check_flutter_project_root() {
    until is_flutter_project_root; do
      error_echo "❌ 当前目录不是 Flutter 项目根目录（缺 pubspec.yaml 或 lib/）"
      read "?📂 请输入 Flutter 项目路径：" proj_path
      cd "$proj_path" 2>/dev/null || {
        error_echo "❌ 路径无效：$proj_path"
        continue
      }
    done
  }

  # ✅ Flutter 命令识别
  detect_flutter_command() {
    if command -v fvm &>/dev/null && [[ -x ".fvm/flutter_sdk/bin/flutter" ]]; then
      FLUTTER_CMD=".fvm/flutter_sdk/bin/flutter"
      info_echo "🧭 检测到 FVM，使用 fvm flutter"
    else
      FLUTTER_CMD="flutter"
      info_echo "🧭 使用全局 flutter"
    fi
  }

  # ✅ 判断芯片架构（ARM64 / x86_64）
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
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

  # ✅ 安装 Homebrew（芯片架构兼容、含环境注入）
  install_homebrew() {
    local arch="$(get_cpu_arch)"                    # 获取当前架构（arm64 或 x86_64）
    local shell_path="${SHELL##*/}"                # 获取当前 shell 名称（如 zsh、bash）
    local profile_file=""
    local brew_bin=""
    local shellenv_cmd=""

    if ! command -v brew &>/dev/null; then
      warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"

      if [[ "$arch" == "arm64" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
          error_echo "❌ Homebrew 安装失败（arm64）"
          exit 1
        }
        brew_bin="/opt/homebrew/bin/brew"
      else
        arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
          error_echo "❌ Homebrew 安装失败（x86_64）"
          exit 1
        }
        brew_bin="/usr/local/bin/brew"
      fi

      success_echo "✅ Homebrew 安装成功"

      # ==== 注入 shellenv 到对应配置文件（自动生效） ====
      shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""

      case "$shell_path" in
        zsh)   profile_file="$HOME/.zprofile" ;;
        bash)  profile_file="$HOME/.bash_profile" ;;
        *)     profile_file="$HOME/.profile" ;;
      esac

      inject_shellenv_block "$profile_file" "$shellenv_cmd"

    else
      info_echo "🔄 Homebrew 已安装，正在更新..."
      ask_run "执行 Homebrew 更新 / 升级 / 清理？" && run_brew_health_update
      success_echo "✅ Homebrew 已更新"
    fi
  }

  ensure_perl_installed() {
    if ! brew list perl &>/dev/null; then
      warn_echo "📦 未检测到 Homebrew 安装的 Perl，正在安装..."
      brew install perl || {
        error_echo "❌ Perl 安装失败，请检查网络或更换镜像"
        exit 1
      }
    else
      info_echo "🔄 检测到 Perl，正在升级..."
      ask_run "升级 perl？" && brew upgrade perl
    fi
  }

  ensure_uri_escape_installed() {
    if ! perl -MURI::Escape -e 1 &>/dev/null; then
      info_echo "📦 安装 URI::Escape 模块..."
      cpan install URI::Escape || {
        error_echo "❌ 安装 URI::Escape 失败，请检查 Perl 配置"
        exit 1
      }
    fi
  }

  # ✅ 替换 import 路径
  replace_uri_imports() {
    echo ""
    info_echo "🔍 正在扫描 Dart 文件..."
    BACKUP_DIR=".import_backup"
    mkdir -p "$BACKUP_DIR"

    find . -name "*.dart" | while read -r file; do
      if grep -q "import 'package:[^']*%[0-9A-Fa-f]\{2\}" "$file"; then
        info_echo "🔧 修复 import：$file"
        cp "$file" "$BACKUP_DIR/$(basename "$file")"
        perl -i -pe "use URI::Escape; s|(import\\s+'package:[^']*)|uri_unescape(\$1)|ge" "$file"
      fi
    done

    cat > "$BACKUP_DIR/README.txt" <<EOF
  该目录包含被替换前的 Dart 文件备份。
  路径替换时间：$(date)
  EOF

    success_echo "✅ 所有 import 路径修复完成"
    info_echo "📦 备份文件位置：$(pwd)/$BACKUP_DIR"
  }

  # ✅ 后续操作：分析与升级
  ask_flutter_analyze() {
    echo ""
    read "?🔍 是否运行 $FLUTTER_CMD analyze？（回车跳过，输入任意字符执行，Ctrl+C 跳过）"
    $FLUTTER_CMD analyze
  }

  ask_flutter_upgrade() {
    echo ""
    read "?⬆️ 是否执行 $FLUTTER_CMD upgrade？（回车跳过，输入任意字符执行，Ctrl+C 跳过）"
    $FLUTTER_CMD upgrade
  }

  # ✅ 主流程入口
  main() {
    clear
    resolve_flutter_root          # 🧭 初始化并切换到脚本目录
    print_banner                  # ✅ 自述信息
    check_flutter_project_root    # 🔍 检查并进入 Flutter 项目根目录
    detect_flutter_command        # 🧩 检测 Flutter 命令（fvm 或全局）
    install_homebrew              # 🍺 确保 Homebrew 已安装并更新
    ensure_perl_installed         # 🐪 安装或升级 perl
    ensure_uri_escape_installed   # 📦 安装 URI::Escape 模块
    replace_uri_imports           # 🔧 修复 import 中的中文 URI 编码路径
    ask_flutter_analyze           # 🔍 是否执行 flutter analyze 分析
    ask_flutter_upgrade           # ⬆️ 是否执行 flutter upgrade 升级 SDK
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
