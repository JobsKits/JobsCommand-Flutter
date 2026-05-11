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
  # ✅ 日志与语义输出
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

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

  # ✅ 全局变量
  flutter_cmd=(flutter)  # 默认使用系统 flutter

  # ✅ Flutter 项目目录初始化
  init_project_dir() {
    BASE_DIR="$(cd "$(dirname "$0")" && pwd -P)"
    readonly BASE_DIR
    gray_echo "📂 当前脚本路径: $BASE_DIR"

    project_dir="$BASE_DIR"
    while [[ ! -f "$project_dir/pubspec.yaml" || ! -d "$project_dir/lib" ]]; do
      error_echo "❌ 当前目录不是 Flutter 项目（缺少 pubspec.yaml 或 lib/）"
      read "input_path?📂 请拖入 Flutter 项目根目录或按回车重试："
      input_path="${input_path/#\~/$HOME}"
      input_path="${input_path//\\/}"
      [[ -n "$input_path" ]] && project_dir="$input_path"
    done

    cd "$project_dir" || { error_echo "❌ 进入项目失败"; exit 1; }
    success_echo "📁 已定位 Flutter 项目目录：$project_dir"
  }

  # ✅ 检查是否使用 FVM
  detect_flutter_command() {
    if [[ -f "$project_dir/.fvm/fvm_config.json" ]]; then
      warn_echo "🧩 检测到 FVM 管理，将使用 fvm flutter"
      flutter_cmd=(fvm flutter)
    else
      info_echo "📦 使用系统 Flutter 命令"
      flutter_cmd=(flutter)
    fi
  }

  # ✅ 判断芯片架构（ARM64 / x86）
  get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
  }

  # ✅ 自检安装 🍺 Homebrew
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

  # ✅ fzf 安装检查
  ensure_fzf_installed() {
    if ! command -v fzf >/dev/null 2>&1; then
      warn_echo "📦 未安装 fzf，开始安装..."
      brew install fzf
    else
      info_echo "🔄 fzf 已安装，尝试升级..."
      ask_run "升级 fzf？" && brew upgrade fzf || true
    fi
  }

  # ✅ 清空缓存并重新拉包
  clear_and_regenerate() {
    warn_echo "⚠️ 即将清空 ~/.pub-cache/hosted/pub.dev"
    read "?🔁 是否继续执行？输入 y 确认：" confirm
    if [[ "$confirm" == "y" ]]; then
      rm -rf ~/.pub-cache/hosted/pub.dev/*
      success_echo "✅ 已清空缓存"
      info_echo "📦 正在重新拉取依赖..."
      "${flutter_cmd[@]}" pub get
      success_echo "🎉 全量升级完成！"
      exit 0
    else
      warn_echo "⏭️ 跳过清空缓存"
    fi
  }

  # ✅ 升级策略选择
  select_upgrade_strategy() {
    echo ""
    info_echo "🎯 请选择升级策略"
    strategy=$(printf "🧹 全量清空 .pub-cache 并重新拉取依赖\n⚙️ 逐个升级 pubspec.yaml 中的依赖" | \
      fzf --prompt="📦 选择升级方式 > " --height=10 --reverse)

    if [[ "$strategy" == *全量清空* ]]; then
      clear_and_regenerate
    fi
  }

  # ✅ 逐个升级逻辑
  upgrade_dependencies_interactive() {
    echo ""
    warn_echo "📋 当前依赖状态："
    "${flutter_cmd[@]}" pub outdated
    echo ""
    read "?📈 是否进入逐个升级流程？（回车跳过，输入任意字符执行，其他跳过）" input
    [[ -n "$input" ]] && return

    dependencies=($(awk '/^dependencies:/,/^dev_dependencies:/ {if ($0 ~ /^[[:space:]]+[a-zA-Z0-9_-]+:/) print $1}' pubspec.yaml | cut -d: -f1))
    dev_dependencies=($(awk '/^dev_dependencies:/ {flag=1; next} /^$/ {flag=0} flag && $0 ~ /^[[:space:]]+[a-zA-Z0-9_-]+:/ {print $1}' pubspec.yaml | cut -d: -f1))

    declare -A sources
    for d in "${dependencies[@]}"; do sources["$d"]="dependencies"; done
    for d in "${dev_dependencies[@]}"; do sources["$d"]="dev_dependencies"; done

    transitives=$("${flutter_cmd[@]}" pub outdated --json | grep -oE '"package":"[^"]+"' | cut -d'"' -f4)
    for t in $transitives; do [[ -z "${sources["$t"]}" ]] && sources["$t"]="transitive"; done

    for pkg in ${(k)sources}; do
      echo ""; warn_echo "🔍 正在处理：$pkg（来源：${sources[$pkg]}）"
      output=$("${flutter_cmd[@]}" pub outdated "$pkg" --json 2>/dev/null)
      current=$(echo "$output" | grep -oE '"current":"[^"]+"' | cut -d'"' -f4)
      latest=$(echo "$output" | grep -oE '"latest":"[^"]+"' | cut -d'"' -f4)

      [[ -z "$current" || -z "$latest" ]] && error_echo "❌ 无法获取版本信息" && continue
      [[ "$current" == "$latest" ]] && success_echo "✔ $pkg 已是最新版 $current" && continue

      echo "📌 当前版本：$current"
      echo "🆕 最新版本：$latest"

      if [[ "${sources[$pkg]}" != "transitive" ]]; then
        read "?🚀 升级 $pkg 到 ^$latest？（y 升级）" confirm
        if [[ "$confirm" == "y" ]]; then
          matched_line=$(grep -E "^\s*$pkg:" pubspec.yaml)
          if [[ "$matched_line" =~ (git:|path:|sdk:) ]]; then
            warn_echo "⚠️ $pkg 为 git/path/sdk 类型依赖，跳过"
          else
            new_line=$(echo "$matched_line" | sed -E "s/(\s*$pkg:\s*)\^?[0-9]+\.[0-9]+\.[0-9]+/\1^$latest/")
            if [[ "$matched_line" != "$new_line" ]]; then
              sed -i '' "s|$matched_line|$new_line|" pubspec.yaml
              success_echo "✔ $pkg 已更新为：$new_line"
            else
              warn_echo "⏭️ 无法替换该行，格式异常"
            fi
          fi
        else
          warn_echo "⏭️ 跳过 $pkg"
        fi
      else
        info_echo "📦 $pkg 是间接依赖，无法直接升级"
      fi
    done
  }

  # ✅ 自述信息
  print_intro() {
    success_echo "📦 Flutter 项目依赖升级助手（支持 FVM + fzf）"
    echo "===================================================================="
    note_echo "➤ 自动检测 Flutter 项目目录（含 pubspec.yaml + lib/）"
    note_echo "➤ 自动安装或升级 fzf"
    note_echo "➤ 支持全清空缓存 or 逐个依赖升级"
    echo "===================================================================="
    echo ""
  }

  # ✅ flutter pub get 提示执行
  maybe_run_pub_get() {
    echo ""
    read "?📦 是否执行 flutter pub get？（回车跳过，输入任意字符执行）" input
    if [[ -z "$input" ]]; then
      "${flutter_cmd[@]}" pub get
      success_echo "✔ 依赖拉取完成"
    else
      warn_echo "⏭️ 已跳过 flutter pub get，请手动执行"
    fi
  }

  # ✅ 主函数入口
  main() {
    print_intro                               # ✅ 自述信息
    init_project_dir                          # ✅ 自动识别 Flutter 项目根目录
    detect_flutter_command                    # ✅ 判断是否使用 FVM，设置 flutter_cmd
    install_homebrew                          # ✅ 自动安装或更新 Homebrew
    ensure_fzf_installed                      # ✅ 安装或升级 fzf
    select_upgrade_strategy                   # ✅ fzf 选择升级策略（全清空 or 逐个升级）
    upgrade_dependencies_interactive          # ✅ 如果逐个升级则进行每个依赖的交互处理
    maybe_run_pub_get                         # ✅ 提示执行 flutter pub get

    echo ""
    warn_echo "🔁 最终依赖状态如下："
    "${flutter_cmd[@]}" pub outdated          # ✅ 展示最终状态
    success_echo "🎉 脚本执行完毕"
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
