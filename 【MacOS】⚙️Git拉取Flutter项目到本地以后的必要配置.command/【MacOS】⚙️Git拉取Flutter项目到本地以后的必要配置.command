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
  set -euo pipefail

  # ================================== 基础信息 ==================================
  get_script_path() {
    # zsh 下拿脚本真实路径（Finder 双击时 $0 可能不可靠）
    local p="${(%):-%x}"
    [[ -z "$p" ]] && p="$0"
    echo "${p:A}"
  }

  SCRIPT_PATH="$(get_script_path)"
  SCRIPT_DIR="${SCRIPT_PATH:h}"
  SCRIPT_BASENAME="$(basename "$SCRIPT_PATH" | sed 's/\.[^.]*$//')"
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

  # ================================== 日志与语义输出 ==================================
  log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
  color_echo()     { log "\033[1;32m$1\033[0m"; }
  info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
  success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
  warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
  warm_echo()      { log "\033[1;33m$1\033[0m"; }
  note_echo()      { log "\033[1;36m✦ $1\033[0m"; }
  error_echo()     { log "\033[1;31m✘ $1\033[0m"; }
  err_echo()       { error_echo "$1"; }
  debug_echo()     { log "\033[0;90m🐞 $1\033[0m"; }
  highlight_echo() { log "\033[1;35m★ $1\033[0m"; }
  gray_echo()      { log "\033[0;90m$1\033[0m"; }
  bold_echo()      { log "\033[1m$1\033[0m"; }
  underline_echo() { log "\033[4m$1\033[0m"; }

  ts() { date +"%Y%m%d_%H%M%S"; }

  # ================================== Flutter 项目根目录判断（按你给的规则） ==================================
  is_flutter_project_root() {
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ================================== 从某个目录向上找 Flutter 项目根目录 ==================================
  find_root_from() {
    local start="${1:A}"
    [[ ! -d "$start" ]] && return 1

    local d="$start"
    while [[ "$d" != "/" ]]; do
      if is_flutter_project_root "$d"; then
        echo "$d"
        return 0
      fi
      d="${d:h}"
    done
    return 1
  }

  # ================================== 解析用户传参（过滤 Finder 的 -psn_0_xxx） ==================================
  pick_user_path_arg() {
    local a
    for a in "$@"; do
      [[ "$a" == -psn_* ]] && continue
      # 如果传的是文件路径，就取其目录；目录就直接用
      if [[ -d "$a" ]]; then
        echo "$a"
        return 0
      elif [[ -f "$a" ]]; then
        echo "${a:A:h}"
        return 0
      fi
    done
    return 1
  }

  # ================================== 定位项目根目录（优先：传参 > 当前目录 > 脚本目录） ==================================
  resolve_flutter_project_root() {
    local candidate root

    if candidate="$(pick_user_path_arg "$@" 2>/dev/null)"; then
      root="$(find_root_from "$candidate" 2>/dev/null || true)"
      [[ -n "$root" ]] && { echo "$root"; return 0; }
    fi

    root="$(find_root_from "$PWD" 2>/dev/null || true)"
    [[ -n "$root" ]] && { echo "$root"; return 0; }

    root="$(find_root_from "$SCRIPT_DIR" 2>/dev/null || true)"
    [[ -n "$root" ]] && { echo "$root"; return 0; }

    return 1
  }

  # ================================== 依赖检测：Homebrew / fvm ==================================
  ensure_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
      error_echo "❌ 未检测到 Homebrew（brew）。请先安装 Homebrew 再运行此脚本。"
      gray_echo "   https://brew.sh/"
      exit 1
    fi
    success_echo "Homebrew 已存在：$(command -v brew)"
  }

  ensure_fvm() {
    if command -v fvm >/dev/null 2>&1; then
      success_echo "fvm 已安装：$(command -v fvm)"
      return 0
    fi

    warn_echo "未检测到 fvm，开始安装（brew install fvm）..."
    brew install fvm
    success_echo "fvm 安装完成：$(command -v fvm)"
  }

  # ================================== 配置项目级 FVM（只在项目根目录生效） ==================================
  setup_fvm_for_project() {
    local project_root="$1"
    cd "$project_root"

    info_echo "项目根目录：$project_root"
    info_echo "开始配置项目级 FVM（写入 $project_root/.fvm）"

    # 你可以把 stable 换成你想固定的版本号，比如 3.24.5
    local channel_or_version="stable"

    fvm install "$channel_or_version"
    fvm use "$channel_or_version"

    success_echo "FVM 已绑定到项目：$channel_or_version"
    gray_echo "当前项目 Flutter：$(fvm flutter --version | head -n 1 || true)"
  }

  # ================================== 写入项目级 VSCode 设置，让 VSCode 跟随 .fvm/flutter_sdk ==================================
  ensure_vscode_settings() {
    local project_root="$1"
    local vscode_dir="$project_root/.vscode"
    local settings="$vscode_dir/settings.json"

    mkdir -p "$vscode_dir"

    if [[ -f "$settings" ]]; then
      cp "$settings" "${settings}.bak.$(ts)"
      warn_echo "已备份：${settings}.bak.$(ts)"
    fi

    # 用 python 合并/写入，尽量保留其他设置
    if command -v python3 >/dev/null 2>&1; then
      python3 - <<PY
  import json, os
  p = "${settings}"
  data = {}
  if os.path.exists(p):
      try:
          with open(p, "r", encoding="utf-8") as f:
              data = json.load(f)
      except Exception:
          data = {}
  data["dart.flutterSdkPath"] = ".fvm/flutter_sdk"
  with open(p, "w", encoding="utf-8") as f:
      json.dump(data, f, ensure_ascii=False, indent=2)
  PY
    else
      cat > "$settings" <<'JSON'
  {
    "dart.flutterSdkPath": ".fvm/flutter_sdk"
  }
  JSON
    fi

    success_echo "已写入 VSCode 配置：$settings"
    gray_echo "dart.flutterSdkPath -> .fvm/flutter_sdk"
  }

  # ================================== 入口 ==================================
  main() {
    : > "$LOG_FILE"
    bold_echo "==================== Flutter 项目必要配置（项目级 FVM + VSCode）===================="
    gray_echo "LOG_FILE: $LOG_FILE"
    gray_echo "SCRIPT: $SCRIPT_PATH"
    gray_echo "CWD:    $PWD"

    local project_root
    project_root="$(resolve_flutter_project_root "$@")" || {
      error_echo "❌ 未检测到 Flutter 项目根目录（需要同时存在：pubspec.yaml + lib/）"
      note_echo "👉 解决方式："
      gray_echo "   1) 请在 Flutter 项目根目录运行脚本；或"
      gray_echo "   2) 传入项目路径："
      gray_echo "      ./${SCRIPT_BASENAME}.command /path/to/flutter_project"
      exit 1
    }

    ensure_homebrew
    ensure_fvm
    setup_fvm_for_project "$project_root"
    ensure_vscode_settings "$project_root"

    success_echo "✅ 全部完成。建议重启 VS Code 或执行：Developer: Reload Window"
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
