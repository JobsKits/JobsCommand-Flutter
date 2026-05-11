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
  SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
  cd "$SCRIPT_DIR" || {
    echo "❌ 无法进入脚本目录：$SCRIPT_DIR"
    exit 1
  }

  SCRIPT_BASENAME="$(basename "${(%):-%x}" | sed 's/\.[^.]*$//')"
  LOG_FILE="$SCRIPT_DIR/${SCRIPT_BASENAME}.log"

  PROJECT_REPO_URL="https://github.com/JobsKits/VSCodeConfigByFlutter.git"
  GLOBAL_REPO_URL="https://github.com/JobsKits/JobsConfigByVSCode.git"

  PROJECT_VSCODE_DIR="$SCRIPT_DIR/.vscode"
  VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
  VSCODE_PARENT_DIR="$HOME/Library/Application Support/Code"

  # ================================== 统一输出 ==================================
  log()           { echo -e "$1" | tee -a "$LOG_FILE"; }
  info_echo()     { log "\033[1;34mℹ $1\033[0m"; }
  success_echo()  { log "\033[1;32m✔ $1\033[0m"; }
  warn_echo()     { log "\033[1;33m⚠ $1\033[0m"; }
  error_echo()    { log "\033[1;31m✖ $1\033[0m"; }
  note_echo()     { log "\033[1;36m➜ $1\033[0m"; }

  pause_enter() {
    echo -n $'\n'"按回车继续..."$'\n' | tee -a "$LOG_FILE"
    IFS= read -r _
  }

  require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error_echo "缺少命令：$cmd"
      exit 1
    fi
  }

  # ================================== 工具函数 ==================================
  dir_has_content() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)" ]]
  }

  backup_dir_to_zip_and_remove() {
    local source_dir="$1"
    local backup_prefix="$2"

    [[ -d "$source_dir" ]] || return 0
    dir_has_content "$source_dir" || return 0

    local ts
    ts="$(date +"%Y%m%d-%H%M%S")"

    local parent_dir
    parent_dir="$(dirname "$source_dir")"

    local backup_dir="${parent_dir}/${backup_prefix}_${ts}"
    local zip_path="${parent_dir}/${backup_prefix}_${ts}.zip"

    warn_echo "检测到已有目录且非空：$source_dir"
    info_echo "开始备份到：$zip_path"

    mv "$source_dir" "$backup_dir"

    if ditto -c -k --sequesterRsrc --keepParent "$backup_dir" "$zip_path"; then
      success_echo "备份完成：$zip_path"
      rm -rf "$backup_dir"
      success_echo "旧目录已移除：$source_dir"
    else
      error_echo "压缩备份失败：$zip_path"
      warn_echo "已保留备份目录：$backup_dir"
      exit 1
    fi
  }

  copy_repo_contents() {
    local repo_dir="$1"
    local target_dir="$2"

    mkdir -p "$target_dir"

    (
      setopt local_options dot_glob null_glob
      cp -R "$repo_dir"/* "$target_dir"/
    )

    rm -rf \
      "$target_dir/.git" \
      "$target_dir/.github" \
      "$target_dir/.gitignore"
  }

  replace_dir_with_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local backup_prefix="$3"

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    {
      backup_dir_to_zip_and_remove "$target_dir" "$backup_prefix"

      info_echo "下载仓库：$repo_url"
      git clone --depth=1 "$repo_url" "$tmp_dir/repo"
      success_echo "仓库下载完成"

      rm -rf "$target_dir"
      mkdir -p "$target_dir"

      info_echo "写入目标目录：$target_dir"
      copy_repo_contents "$tmp_dir/repo" "$target_dir"
      success_echo "替换完成：$target_dir"
    } always {
      rm -rf "$tmp_dir"
    }
  }

  wait_for_vscode_user_parent() {
    local url="https://code.visualstudio.com/"

    while [[ ! -d "$VSCODE_PARENT_DIR" ]]; do
      warn_echo "未检测到 VS Code 目录：$VSCODE_PARENT_DIR"
      note_echo "将打开 VS Code 官网。请先安装 VS Code，安装完成后回到这里按回车继续检测。"
      open "$url" >/dev/null 2>&1 || true
      pause_enter
    done

    success_echo "已检测到 VS Code 目录：$VSCODE_PARENT_DIR"
  }

  print_readme() {
    clear
    cat <<EOF | tee -a "$LOG_FILE"
  ==================== VSCode 配置初始化脚本 ====================

  将执行以下操作：

  1) 处理脚本所在目录的 .vscode
     - 若 .vscode 已存在且非空：先压缩备份
     - 再用仓库内容完整替换：
       $PROJECT_REPO_URL

  2) 处理 VS Code 全局 User 目录
     - 目标目录：
       $VSCODE_USER_DIR
     - 若 User 已存在且非空：先压缩备份
     - 再用仓库内容完整替换：
       $GLOBAL_REPO_URL

  注意：
  - 这是破坏性替换，不是增量合并
  - 不会打开 VS Code
  - 不会重启 VS Code
  - 日志文件：
    $LOG_FILE

  ==============================================================
  EOF
  }

  setup_project_vscode() {
    info_echo "开始配置项目 .vscode"
    replace_dir_with_repo "$PROJECT_REPO_URL" "$PROJECT_VSCODE_DIR" ".vscode_backup"
  }

  setup_global_vscode_user() {
    info_echo "开始配置 VS Code 全局 User"
    wait_for_vscode_user_parent
    replace_dir_with_repo "$GLOBAL_REPO_URL" "$VSCODE_USER_DIR" "Code_User_backup"
  }

  main() {
    : > "$LOG_FILE"

    require_cmd git
    require_cmd ditto

    print_readme
    pause_enter

    setup_project_vscode
    setup_global_vscode_user

    success_echo "全部完成 ✅"
    note_echo "项目配置目录：$PROJECT_VSCODE_DIR"
    note_echo "全局配置目录：$VSCODE_USER_DIR"
    note_echo "日志文件：$LOG_FILE"

    pause_enter
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
