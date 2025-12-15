#!/bin/zsh
set -euo pipefail

# ================================== 基础信息 ==================================
SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_BASENAME="$(basename "$SCRIPT_PATH" | sed 's/\.[^.]*$//')"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

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
    note_echo "请先安装 $cmd 后再运行（macOS 通常通过 Xcode Command Line Tools 提供 git）。"
    exit 1
  fi
}

git_clone_or_pull() {
  local repo="$1"
  local dest_dir="$2"

  if [[ -d "$dest_dir/.git" ]]; then
    info_echo "已存在仓库：$dest_dir，执行更新..."
    git -C "$dest_dir" pull --rebase
    success_echo "更新完成：$dest_dir"
  elif [[ -e "$dest_dir" ]]; then
    warn_echo "目标路径已存在但不是 git 仓库：$dest_dir"
    warn_echo "为避免覆盖，跳过 clone。你可以手动处理该目录后重试。"
  else
    info_echo "开始 clone：$repo"
    git clone "$repo" "$dest_dir"
    success_echo "clone 完成：$dest_dir"
  fi
}

# ================================== 安全备份：.vscode 非空则打包 ==================================
backup_vscode_dir_if_non_empty() {
  local vscode_dir="$1"
  [[ -d "$vscode_dir" ]] || return 0

  if [[ -z "$(find "$vscode_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)" ]]; then
    return 0
  fi

  local ts
  ts="$(date +"%Y%m%d-%H%M%S")" # YYYYMMDD-HHMMSS（更易读）

  local backup_dir="${SCRIPT_DIR}/.vscode_backup_${ts}"
  local zip_path="${SCRIPT_DIR}/.vscode_backup_${ts}.zip"

  warn_echo ".vscode 目录已存在且非空，将进行安全备份..."
  info_echo "备份目录：$backup_dir"
  info_echo "备份压缩包：$zip_path"

  mkdir -p "$backup_dir"

  (
    setopt local_options dot_glob null_glob
    mv "$vscode_dir"/* "$backup_dir"/
  )

  if ditto -c -k --sequesterRsrc --keepParent "$backup_dir" "$zip_path"; then
    success_echo "压缩备份完成：$zip_path"
    rm -rf "$backup_dir"
    success_echo "已清空 .vscode，继续后续配置。"
  else
    error_echo "压缩失败：$zip_path"
    warn_echo "将尝试把文件恢复回 .vscode，并保留备份目录：$backup_dir"

    (
      setopt local_options dot_glob null_glob
      mkdir -p "$vscode_dir"
      mv "$backup_dir"/* "$vscode_dir"/ 2>/dev/null || true
    )

    error_echo "已终止执行（请检查磁盘空间/权限/ditto）。"
    exit 1
  fi
}

# ================================== 1、准备阶段 ==================================
print_readme() {
  clear
  cat <<'EOF' | tee -a "$LOG_FILE"
==================== VSCode 配置初始化脚本 ====================

步骤：
1) 若脚本目录下 .vscode 已存在且非空 -> 先备份打包（YYYYMMDD-HHMMSS），随后删除旧 .vscode
2) 在脚本目录下拉取仓库 https://github.com/JobsKits/VScodeConfigByFlutter
   拉取到的文件夹会改名为 .vscode（即 .vscode 本身就是该仓库）
3) 检测 VS Code 用户目录：
   ~/Library/Application Support/Code/User
   - 不存在：打开官网并循环等待你安装完成
   - 存在：拉取 https://github.com/JobsKits/JobsConfigByVSCode
4) 最后会自动打开 VS Code 用户目录（Finder）

说明：
- 需要联网 / git
- 可随时 Ctrl+C 退出
- 日志：/tmp/<脚本名>.log
==============================================================

EOF
}

# ================================== 2、配置 .vscode ==================================
setup_project_vscode_dir() {
  local vscode_dir="$SCRIPT_DIR/.vscode"
  local repo="https://github.com/JobsKits/VScodeConfigByFlutter"
  local clone_name="VScodeConfigByFlutter"
  local clone_dir="$SCRIPT_DIR/$clone_name"

  info_echo "脚本目录：$SCRIPT_DIR"

  # 确保在脚本目录执行（双击运行时，默认工作目录可能不是脚本所在目录）
  cd "$SCRIPT_DIR"

  # 1) 若已存在 .vscode：先备份（若非空）-> 再删除 .vscode
  if [[ -d "$vscode_dir" ]]; then
    success_echo "找到 .vscode：$vscode_dir"
    backup_vscode_dir_if_non_empty "$vscode_dir"
    info_echo "删除旧 .vscode：$vscode_dir"
    rm -rf "$vscode_dir"
    success_echo "已删除：$vscode_dir"
  fi

  # 2) 避免残留同名 clone 目录导致 clone 失败（尽量安全处理：备份后移除）
  if [[ -e "$clone_dir" ]]; then
    local ts
    ts="$(date +"%Y%m%d-%H%M%S")"
    local conflict_dir="${SCRIPT_DIR}/${clone_name}_backup_${ts}"
    local conflict_zip="${SCRIPT_DIR}/${clone_name}_backup_${ts}.zip"

    warn_echo "发现残留目录：$clone_dir"
    warn_echo "将先备份再移除，避免影响本次拉取..."

    mv "$clone_dir" "$conflict_dir"

    if ditto -c -k --sequesterRsrc --keepParent "$conflict_dir" "$conflict_zip"; then
      success_echo "残留目录已备份：$conflict_zip"
      rm -rf "$conflict_dir"
    else
      warn_echo "残留目录压缩失败：$conflict_zip"
      warn_echo "已保留备份目录：$conflict_dir（请自行处理）"
    fi
  fi

  # 3) 在脚本目录下拉取仓库（生成文件夹 VScodeConfigByFlutter）
  info_echo "拉取仓库到当前目录：$repo"
  git clone "$repo" "$clone_dir"
  success_echo "拉取完成：$clone_dir"

  # 4) 将拉取到的文件夹改名为 .vscode
  info_echo "重命名为 .vscode"
  mv "$clone_dir" "$vscode_dir"
  success_echo "已生成：$vscode_dir"
}

# ================================== 3、配置 VS Code 用户核心目录 ==================================
wait_for_vscode_user_dir() {
  local vscode_user_dir="$HOME/Library/Application Support/Code/User"
  local url="https://code.visualstudio.com/"

  while [[ ! -d "$vscode_user_dir" ]]; do
    warn_echo "未检测到 VS Code 用户目录：$vscode_user_dir"
    note_echo "将打开官网，请安装 VS Code。安装完成后回到这里不断回车即可继续。"
    open "$url" >/dev/null 2>&1 || true
    pause_enter
  done

  success_echo "已检测到 VS Code 用户目录：$vscode_user_dir"
}

setup_vscode_user_repo() {
  local vscode_user_dir="$HOME/Library/Application Support/Code/User"
  local repo="https://github.com/JobsKits/JobsConfigByVSCode"
  local dest="$vscode_user_dir/JobsConfigByVSCode"

  info_echo "定位到 VS Code 用户目录：$vscode_user_dir"
  git_clone_or_pull "$repo" "$dest"
}

open_vscode_user_dir() {
  local vscode_user_dir="$HOME/Library/Application Support/Code/User"
  info_echo "打开目录：$vscode_user_dir"
  open "$vscode_user_dir" >/dev/null 2>&1 || true
}

# ================================== main ==================================
main() {
  # 0) 初始化日志文件
  : > "$LOG_FILE"

  # 1) 依赖检查
  require_cmd git

  # 2) 自述 + 等待用户确认
  print_readme
  pause_enter

  # 3) 配置脚本目录下的 .vscode（含安全备份逻辑）
  setup_project_vscode_dir

  # 4) 等待 VS Code 用户目录出现 + 拉取用户配置仓库
  wait_for_vscode_user_dir
  setup_vscode_user_repo

  # 5) 最后打开 VS Code 用户目录（Finder）
  open_vscode_user_dir

  # 6) 收尾
  success_echo "全部完成 ✅"
  note_echo "日志已写入：$LOG_FILE"
  pause_enter
}

main "$@"
