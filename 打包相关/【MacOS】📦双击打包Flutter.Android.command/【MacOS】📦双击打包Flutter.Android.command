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
    clear
    color_echo "🛠️ Flutter Android 打包脚本（支持 FVM / fzf / flavor / JDK 选择）"
    echo ""
    note_echo "📌 功能说明："
    note_echo "1️⃣ 自动识别当前 Flutter 项目路径（或拖入路径）"
    note_echo "2️⃣ 自动检测是否使用 FVM，并用 fvm flutter 构建"
    note_echo "3️⃣ 支持选择构建类型（仅 APK、仅 AAB、同时构建）"
    note_echo "4️⃣ 支持 flavor 参数和构建模式（release/debug/profile）"
    note_echo "5️⃣ 自动检测并配置 Java（openjdk），可选择版本"
    note_echo "6️⃣ 自动记忆上次使用的 JDK（保存在 .java-version）"
    note_echo "7️⃣ 构建前输出 📦 JDK / 📦 Gradle / 📦 AGP 三个版本信息"
    note_echo "8️⃣ 构建后自动打开输出产物目录"
    note_echo "9️⃣ 所有命令均统一交互：回车 = 执行，任意键 + 回车 = 跳过"
    note_echo "🔟 构建日志自动保存到 /tmp/flutter_build_log.txt"
    echo ""
    warm_echo "👉 回车 = 执行默认 / 任意键 + 回车 = 跳过（统一交互）"
    echo ""
    read "?📎 按回车开始："
  }

  # ✅ 初始化路径与工具
  init_environment() {
    cd "$(cd "$(dirname "$0")" && pwd -P)" || exit 1

    # 添加 sdkmanager 路径
    export PATH="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin:$PATH"

    # jenv 初始化
    if [[ -d "$HOME/.jenv" ]]; then
      export PATH="$HOME/.jenv/bin:$PATH"
      eval "$(jenv init -)"
    fi
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
 
  # ✅ 判断芯片架构（ ARM64 / x86_64）
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }

  # ✅ 自检 Homebrew
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

  # ✅ 自检 Homebrew.fzf
  install_fzf() {
    if ! command -v fzf &>/dev/null; then
      note_echo "📦 未检测到 fzf，正在通过 Homebrew 安装..."
      brew install fzf || { error_echo "❌ fzf 安装失败"; exit 1; }
      success_echo "✅ fzf 安装成功"
    else
      info_echo "🔄 fzf 已安装。是否执行升级？"
      echo "👉 按 [Enter] 继续：将依次执行  brew upgrade fzf && brew cleanup"
      echo "👉 输入任意字符后回车：执行升级"

      local confirm
      IFS= read -r confirm
      if [[ -z "$confirm" ]]; then
        info_echo "⏳ 正在升级 fzf..."
        brew upgrade fzf       || { error_echo "❌ fzf 升级失败"; return 1; }
        brew cleanup           || { warn_echo  "⚠️  brew cleanup 执行时有警告"; }
        success_echo "✅ fzf 已升级到最新版本"
      else
        note_echo "⏭️ 已选择跳过 fzf 升级"
      fi
    fi
  }

  # ✅ 转换路径为绝对路径
  _abs_path() {
    local p="$1"
    [[ -z "$p" ]] && return 1
    p="${p//\"/}"                                                         # ✅ 移除双引号，防止参数传递误差
    [[ "$p" != "/" ]] && p="${p%/}"                                                               # ✅ 去除末尾斜杠，标准化路径形式

    if [[ -d "$p" ]]; then
      (cd "$p" 2>/dev/null && pwd -P)                                     # ✅ 子 shell，避免污染当前目录
    elif [[ -f "$p" ]]; then
      (cd "${p:h}" 2>/dev/null && printf "%s/%s\n" "$(pwd -P)" "${p:t}")  # ✅ 精准拼接
    else
      return 1
    fi
  }

  # ✅ 是否为 Flutter 项目的根目录
  _is_flutter_project_root() {
    debug_echo "🔎 判断目录：$1"
    debug_echo "📄 pubspec.yaml 是否存在：$(ls -l "$1/pubspec.yaml" 2>/dev/null || echo ❌)"
    debug_echo "📁 lib 目录是否存在：$(ls -ld "$1/lib" 2>/dev/null || echo ❌)"
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ✅ Flutter 项目路径识别（回车默认用脚本目录）
  resolve_flutter_root() {

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
    debug_echo "🔍 脚本目录：$script_dir"

    if _is_flutter_project_root "$script_dir"; then
      flutter_root="$script_dir"
      cd "$flutter_root"
      highlight_echo "📌 使用脚本所在目录作为 Flutter 项目根目录"
      return
    fi

    if _is_flutter_project_root "$script_dir"; then
      flutter_root="$script_dir"
      cd "$flutter_root"
      highlight_echo "📌 使用当前工作目录作为 Flutter 项目根目录"
      return
    fi

    while true; do
      warn_echo "📂 请拖入 Flutter 项目根目录（包含 pubspec.yaml 和 lib/）："
      read -r input_path
      input_path="${input_path//\"/}"
      input_path=$(echo "$input_path" | xargs)

      # ✅ 如果用户什么都不输入，就使用脚本所在目录
      if [[ -z "$input_path" ]]; then
        input_path="$script_dir"
        info_echo "📎 未输入路径，默认使用脚本目录：$input_path"
      fi

      local abs=$(_abs_path "$input_path")
      debug_echo "🧪 用户输入路径解析为：$abs"

      if _is_flutter_project_root "$abs"; then
        flutter_root="$abs"
        cd "$flutter_root"
        success_echo "✅ 识别成功：$flutter_root"
        return
      fi
      error_echo "❌ 无效路径：$abs，请重试"
    done
  }

  # ✅  构建参数选择
  select_build_target() {
    warn_echo "📦 请选择构建类型："
    local options=("只构建 APK" "只构建 AAB" "同时构建 APK 和 AAB")
    local selected=$(printf '%s\n' "${options[@]}" | fzf)
    case "$selected" in
      "只构建 APK") build_target="apk" ;;
      "只构建 AAB") build_target="appbundle" ;;
      "同时构建 APK 和 AAB") build_target="all" ;;
      *) build_target="apk" ;;
    esac
    success_echo "✅ 构建类型：$selected"
  }
  
  # ✅ 选择 flavor 和构建模式（release/debug/profile）
  prompt_flavor_and_mode() {
    read "flavor_name?📎 请输入 flavor（可留空）: "
    local modes=("release" "debug" "profile")
    warn_echo "⚙️ 请选择构建模式："
    build_mode=$(printf '%s\n' "${modes[@]}" | fzf)
    success_echo "✅ 模式：$build_mode"
    [[ -n "$flavor_name" ]] && success_echo "✅ 使用 flavor：$flavor_name" || info_echo "📎 未指定 flavor"
  }

  # ✅ FVM 检测与 Flutter 命令
  detect_flutter_command() {
    if command -v fvm >/dev/null && [[ -f "$flutter_root/.fvm/fvm_config.json" ]]; then
      flutter_cmd=("fvm" "flutter")
      warn_echo "🧩 检测到 FVM：使用 fvm flutter"
    else
      flutter_cmd=("flutter")
      info_echo "📦 使用系统 flutter"
    fi
  }

  # ✅ Java 环境配置
  fix_jenv_java_version() {
    local jdk_path="/opt/homebrew/opt/openjdk@17"
    if command -v jenv >/dev/null 2>&1 && [[ -d "$jdk_path" ]]; then
      if ! jenv versions --bare | grep -q "^17"; then
        warn_echo "📦 openjdk@17 未注册到 jenv，尝试添加..."
        jenv add "$jdk_path"
      fi
    fi
  }
  # ✅ 配置 Java 环境（支持记忆）
  configure_java_env() {
    local record_file="$flutter_root/.java-version"
    local selected=""
    local last_used=""
    [[ -f "$record_file" ]] && last_used=$(cat "$record_file")

    local available_versions=$(brew search openjdk@ | grep -E '^openjdk@\d+$' | sort -Vr)
    if [[ -z "$available_versions" ]]; then
      error_echo "❌ 未找到可用的 openjdk"
      exit 1
    fi

    if [[ -n "$last_used" && "$available_versions" == *"$last_used"* ]]; then
      success_echo "📦 上次使用的 JDK：$last_used"
      read "?👉 是否继续使用？回车=是 / 任意键+回车=重新选择: "
      [[ -z "$REPLY" ]] && selected="$last_used"
    fi

    if [[ -z "$selected" ]]; then
      selected=$(echo "$available_versions" | fzf --prompt="☑️ 选择 openjdk 版本：" --height=40%)
      [[ -z "$selected" ]] && error_echo "❌ 未选择 JDK" && exit 1
    fi

    local version_number="${selected#*@}"
    brew list --formula | grep -q "^$selected$" || brew install "$selected"
    sudo ln -sfn "/opt/homebrew/opt/$selected/libexec/openjdk.jdk" "/Library/Java/JavaVirtualMachines/${selected}.jdk" 2>/dev/null
    export JAVA_HOME=$(/usr/libexec/java_home -v"$version_number")
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "$selected" > "$record_file"
    success_echo "✅ JAVA_HOME 已设置为：$JAVA_HOME"
  }

  # ✅ 打印 AGP 版本
  print_agp_version() {
    local build_file=""
    local agp_version=""

    # 优先检查 build.gradle.kts
    if [[ -f android/build.gradle.kts ]]; then
      build_file="android/build.gradle.kts"
      agp_version=$(grep -Eo 'com\.android\.tools\.build:gradle:\S+' "$build_file" | cut -d: -f3 | tr -d '"' | head -n1)
    elif [[ -f android/build.gradle ]]; then
      build_file="android/build.gradle"
      agp_version=$(grep -E "^classpath\s+['\"]com\.android\.tools\.build:gradle:\S+['\"]" "$build_file" | sed -E "s/.*:gradle:([^'\"]+).*/\1/" | head -n1)
    fi

    if [[ -n "$agp_version" ]]; then
      success_echo "✔ 检测到 AGP 版本：$agp_version（来源：$build_file）"
    else
      warn_echo "⚠️ 未在 build.gradle 中检测到 AGP 版本"
    fi
  }

  # ✅ 构建信息打印
  print_agp_version() {
    local agp_version=""
    if [[ -f android/settings.gradle ]]; then
      agp_version=$(grep -oE "com\\.android\\.application['\"]?\\s+version\\s+['\"]?[0-9.]+" android/settings.gradle |
        head -n1 |
        grep -oE "[0-9]+\\.[0-9]+(\\.[0-9]+)?")
    fi
    if [[ -z "$agp_version" && -f android/build.gradle ]]; then
      agp_version=$(grep -oE "com\\.android\\.tools\\.build:gradle:[0-9.]+" android/build.gradle |
        head -n1 |
        cut -d: -f3)
    fi
    [[ -n "$agp_version" ]] && success_echo "📦 当前使用 AGP 版本：$agp_version" || warn_echo "📦 未检测到 AGP 版本"
  }

  print_sdk_versions() {
    local file=""
    for file in android/app/build.gradle android/app/build.gradle.kts; do
      [[ -f "$file" ]] || continue
      local compile_sdk=$(grep -E "compileSdk\s*[:=]\s*['\"]?[0-9]+['\"]?" "$file" | head -n1 | grep -oE "[0-9]+")
      local target_sdk=$(grep -E "targetSdk\s*[:=]\s*['\"]?[0-9]+['\"]?" "$file" | head -n1 | grep -oE "[0-9]+")
      local min_sdk=$(grep -E "minSdk\s*[:=]\s*['\"]?[0-9]+['\"]?" "$file" | head -n1 | grep -oE "[0-9]+")
      [[ -n "$compile_sdk" ]] && info_echo "compileSdk：$compile_sdk" || warn_echo "未检测到 compileSdk"
      [[ -n "$target_sdk" ]] && info_echo "targetSdk：$target_sdk" || warn_echo "未检测到 targetSdk"
      [[ -n "$min_sdk" ]] && info_echo "minSdk：$min_sdk" || warn_echo "未检测到 minSdk"
      break
    done
  }

  # ✅ 使用指定 JAVA_HOME 执行 Flutter 命令，确保构建环境一致
  run_flutter_with_java() {
    JAVA_HOME="$JAVA_HOME" \
    PATH="$JAVA_HOME/bin:$PATH" \
    FVM_JAVA_HOME="$JAVA_HOME" \
    JAVA_TOOL_OPTIONS="" \
    env JAVA_HOME="$JAVA_HOME" PATH="$JAVA_HOME/bin:$PATH" "${flutter_cmd[@]}" "$@"
  }

  # ✅ 打开输出目录
  open_output_folder() {
    local base="build/app/outputs"
    if [[ "$build_target" == "apk" || "$build_target" == "all" ]]; then
      open "$base/flutter-apk" 2>/dev/null
    fi
    if [[ "$build_target" == "appbundle" || "$build_target" == "all" ]]; then
      open "$base/bundle/$build_mode" 2>/dev/null
    fi
  }

  # ✅ 判断是否使用 FVM
  _detect_flutter_cmd() {
    if command -v fvm >/dev/null 2>&1 && [[ -f ".fvm/fvm_config.json" ]]; then
      flutter_cmd=("fvm" "flutter")
      info_echo "🧩 检测到 FVM 项目，使用命令：fvm flutter"
    else
      flutter_cmd=("flutter")
      info_echo "📦 使用系统 Flutter 命令：flutter"
    fi
  }

  # ✅ 确认步骤函数
  confirm_step() {
    local step="$1"
    read "REPLY?👉 是否执行【$step】？回车=跳过 / 任意字符+回车=执行: "
    [[ -z "$REPLY" ]]
  }

  # ✅ 执行 flutter clean🧹 与 pub get
  maybe_flutter_clean_and_get() {
    if confirm_step "flutter clean"; then
      "${flutter_cmd[@]}" clean
    fi

    if confirm_step "flutter pub get"; then
      "${flutter_cmd[@]}" pub get
    fi
  }

  # ✅ 在 Flutter 根目录下的 plugins/htprotect 执行 flutter pub get
  ensure_htprotect_pub_get() {
    local plugin_dir="$flutter_root/plugins/htprotect"
    if [[ ! -d "$plugin_dir" ]]; then
      note_echo "⏭️ 未找到插件目录：$plugin_dir，跳过"
      return 0
    fi
    if [[ ! -f "$plugin_dir/pubspec.yaml" ]]; then
      warn_echo "⚠️ 插件目录存在，但缺少 pubspec.yaml：$plugin_dir，跳过"
      return 0
    fi

    if confirm_step "在 plugins/htprotect 执行 flutter pub get"; then
      pushd "$plugin_dir" >/dev/null || { error_echo "❌ 进入目录失败：$plugin_dir"; return 1; }
      # 继承当前 JAVA_HOME 与 flutter_cmd（支持 FVM）
      JAVA_HOME="$JAVA_HOME" PATH="$JAVA_HOME/bin:$PATH" "${flutter_cmd[@]}" pub get \
        && success_echo "✅ plugins/htprotect 依赖拉取完成" \
        || { error_echo "✖ plugins/htprotect pub get 失败"; popd >/dev/null; return 1; }
      popd >/dev/null
    else
      note_echo "⏭️ 已选择跳过 plugins/htprotect 的 pub get"
    fi
  }

  # ✅ 环境信息输出
  print_env_diagnostics() {
    local log_file="/tmp/flutter_build_log.txt"
    rm -f "$log_file"
    local java_env_cmd=(env JAVA_HOME="$JAVA_HOME" PATH="$JAVA_HOME/bin:$PATH")

    {
      color_echo "🩺 运行 flutter doctor -v 检查环境..."
      "${flutter_cmd[@]}" doctor -v | tee -a "$log_file"
    }

    {
      color_echo "📦 当前使用 JDK 版本："
      java -version 2>&1 | tee -a "$log_file"
    }

    {
      info_echo "📦 当前使用 Gradle wrapper（./android/gradlew）版本："
      if [[ -x ./android/gradlew ]]; then
        ./android/gradlew -v | tee -a "$log_file"
      else
        warn_echo "❌ 未找到 gradlew 脚本"
      fi

      info_echo "📦 当前系统 gradle（可能已劫持）版本："
      if command -v gradle &>/dev/null; then
        gradle -v | tee -a "$log_file"
        info_echo "📦 gradle 路径：$(which gradle)" | tee -a "$log_file"
      else
        warn_echo "⚠️ 系统未安装 gradle"
      fi
    }

    {
      color_echo "📦 当前使用 AGP（Android Gradle Plugin）版本："
      print_agp_version | tee -a "$log_file"
    }

    {
      color_echo "📦 当前使用 sdkmanager 版本："
      sdkmanager --list > /dev/null 2>&1 && sdkmanager --version | tee -a "$log_file" || err_echo "❌ sdkmanager 执行失败"

      color_echo "📦 sdkmanager 来源路径："
      which sdkmanager | tee -a "$log_file"
    }

    {
      color_echo "📦 实际使用的 Android SDK 路径："
      "${flutter_cmd[@]}" config --machine | grep -o '"androidSdkPath":"[^"]*"' | cut -d':' -f2- | tr -d '"' | tee -a "$log_file"
    }

    {
      success_echo "🚀 构建命令：${flutter_cmd[*]} build $build_target ${flavor_name:+--flavor $flavor_name} --$build_mode"
      "${flutter_cmd[@]}" build $build_target ${flavor_name:+--flavor $flavor_name} --$build_mode | tee -a "$log_file"
    }
  }

  # ✅ 执行构建阶段
  run_flutter_build() {
    local log_file="/tmp/flutter_build_log.txt"
    success_echo "🚀 开始构建：${flutter_cmd[*]} build $build_target ${flavor_name:+--flavor $flavor_name} --$build_mode"
    run_flutter_with_java build "$build_target" ${flavor_name:+--flavor "$flavor_name"} --"$build_mode" | tee -a "$log_file"
  }

  # ✅ 🚀 main 函数入口
  main() {
      cd "$(cd "$(dirname "$0")" && pwd -P)"      # ✅ 切换到脚本目录
      show_intro                                  # ✅ 自述信息
      install_homebrew                            # ✅ 自检 Homebrew
      install_fzf                                 # ✅ 自检 Homebrew.fzf
      resolve_flutter_root                        # ✅ 获取 Flutter 根目录
      select_build_target                         # ✅ 选择 APK / AAB / All 构建类型
      prompt_flavor_and_mode                      # ✅ 选择 flavor 和构建模式（release/debug/profile）
      detect_flutter_command                      # ✅ 判断是否使用 FVM
      configure_java_env                          # ✅ 配置 Java 环境（支持记忆）
    
      print_env_diagnostics                       # ✅ 第一阶段：环境信息检查
      maybe_flutter_clean_and_get                 # ✅ 第二阶段：flutter clean 与 pub get
      ensure_htprotect_pub_get                    # ✅ 插件 htprotect 依赖拉取
      run_flutter_build                           # ✅ 第三阶段：执行构建
    
      open_output_folder                          # ✅ 打开构建产物目录
      success_echo "🎉 构建完成，日志保存在 /tmp/flutter_build_log.txt"
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
