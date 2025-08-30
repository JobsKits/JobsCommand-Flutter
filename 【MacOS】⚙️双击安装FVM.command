#!/bin/zsh

export PATH="$HOME/.pub-cache/bin:$PATH"

# ✅ 全局变量定义
typeset -g SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # 当前脚本路径
typeset -g CURRENT_VERSION=""       # 当前 .fvmrc 配置版本
typeset -g VERSIONS=""              # Flutter 可用稳定版本列表
typeset -g SELECTED_VERSION=""      # 用户选择的 Flutter 版本

# ✅ 彩色输出函数封装
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径

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

# ================================== 路径&项目根检测 ==================================
# 绝对路径规范化：兼容相对/~/含空格/符号链接
abs_path() {
  local p="$1"
  # 去掉可能的收尾引号与末尾斜杠
  p="${p//\"/}"
  p="${p%/}"
  # 处理 ~
  [[ "$p" == "~"* ]] && p="${p/#\~/$HOME}"
  # 若是相对路径 -> 拼接 CWD
  if [[ "$p" != /* ]]; then
    p="$(pwd)/$p"
  fi
  # 解析真实路径（mac 上无 realpath，用 cd+pwd -P）
  if [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd -P)
  else
    # 若是文件，返回其所在目录的真实路径 + 文件名
    local dir="${p%/*}"
    local base="${p##*/}"
    if (cd "$dir" 2>/dev/null); then
      echo "$(pwd -P)/$base"
    else
      echo "$p"
    fi
  fi
}

# 判断是否为 Flutter 项目根
is_flutter_project_root() {
  [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
}

# 语义包装（保持你写法）
is_ok_root() { is_flutter_project_root "$1"; }

# 交互检测入口目录（拖拽或回车）
detect_entry() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"

  local ok_root=""
  while true; do
    warn_echo "📂 请拖入正确的 Flutter 项目根目录（含 pubspec.yaml 与 lib/），回车使用脚本所在目录："
    read -r user_input
    # 规范化输入
    user_input="${user_input//\"/}"
    user_input="${user_input%/}"

    if [[ -z "$user_input" ]]; then
      # 用户直接回车 -> 尝试脚本目录
      if is_ok_root "$SCRIPT_DIR"; then
        ok_root="$(abs_path "$SCRIPT_DIR")"
        highlight_echo "🎯 检测到脚本所在目录为有效项目根：$ok_root，自动使用。"
        break
      else
        error_echo "❌ 当前目录不是 Flutter 项目根：$SCRIPT_DIR"
        continue
      fi
    fi

    # 用户拖拽了路径
    if [[ -d "$user_input" ]]; then
      local candidate="$(abs_path "$user_input")"
      if is_ok_root "$candidate"; then
        ok_root="$candidate"
        success_echo "✅ 已确认项目根目录：$ok_root"
        break
      else
        error_echo "❌ 无效项目根：$candidate（缺少 pubspec.yaml 或 lib/）"
        continue
      fi
    else
      error_echo "❌ 无效路径：$user_input（不存在或不是目录）"
      continue
    fi
  done

  cd "$ok_root" || { error_echo "❌ 无法进入项目目录：$ok_root"; exit 1; }
  SCRIPT_DIR="$ok_root"
  success_echo "🟢 工作目录已切换到项目根：$ok_root"
}

# ================================== 自述信息 ==================================
print_description() {
  echo ""
  bold_echo "🛠 Flutter SDK 安装助手（支持官方 / brew / fvm）"
  gray_echo "------------------------------------------------------"
  note_echo "1️⃣ 安装或升级 Homebrew / fzf"
  note_echo "2️⃣ 提供三种 Flutter 安装方式（fzf选择）"
  note_echo "3️⃣ 自动写入环境变量到 ~/.bash_profile"
  gray_echo "------------------------------------------------------"
}

# ================================== 项目路径快速校验（保留，以便独立复用） ==================================
check_flutter_project_path() {
  local p="${1:-$PWD}"
  if [[ ! -f "$p/pubspec.yaml" || ! -d "$p/lib" ]]; then
    error_echo "❌ 路径不是 Flutter 项目（缺 pubspec.yaml 或 lib/）：$p"
    return 1
  fi
  success_echo "📂 路径符合 Flutter 项目规范：$p"
}

# ================================== 芯片架构、安装工具等（原逻辑保持） ==================================
get_cpu_arch() {
  [[ $(uname -m) == "arm64" ]] && echo "arm64" || echo "x86_64"
}

install_homebrew() {
  local arch="$(get_cpu_arch)"
  local shell_path="${SHELL##*/}"
  local profile_file=""
  local brew_bin=""
  local shellenv_cmd=""

  if ! command -v brew &>/dev/null; then
    warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"

    if [[ "$arch" == "arm64" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（arm64）"; exit 1; }
      brew_bin="/opt/homebrew/bin/brew"
    else
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（x86_64）"; exit 1; }
      brew_bin="/usr/local/bin/brew"
    fi

    success_echo "✅ Homebrew 安装成功"
    shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""

    case "$shell_path" in
      zsh)   profile_file="$HOME/.zprofile" ;;
      bash)  profile_file="$HOME/.bash_profile" ;;
      *)     profile_file="$HOME/.profile" ;;
    esac

    # 你原来的 inject_shellenv_block 依赖外部 PROFILE_FILE/selected_envs。
    # 这里沿用你的调用方式；如果你没有那两个变量的全局定义，请自行在上方补齐。
    inject_shellenv_block "$profile_file" "$shellenv_cmd"

  else
    info_echo "🔄 Homebrew 已安装，正在更新..."
    brew update && brew upgrade && brew cleanup && brew doctor && brew -v
    success_echo "✅ Homebrew 已更新"
  fi
}

install_jq() {
  if ! command -v jq &>/dev/null; then
    note_echo "📦 未检测到 jq，正在通过 Homebrew 安装..."
    brew install jq || { error_echo "❌ jq 安装失败"; exit 1; }
    success_echo "✅ jq 安装成功"
  else
    info_echo "🔄 jq 已安装，升级中..."
    brew upgrade jq
    success_echo "✅ jq 已是最新版"
  fi
}

install_dart() {
  if ! command -v dart &>/dev/null; then
    note_echo "📦 未检测到 dart，正在通过 Homebrew 安装..."
    brew tap dart-lang/dart || warn_echo "⚠️ tap dart-lang/dart 失败（已存在或网络异常）"
    brew install dart || { error_echo "❌ dart 安装失败"; exit 1; }
    success_echo "✅ dart 安装成功"
  else
    info_echo "🔄 dart 已安装，路径为：$(which dart)"
    brew tap dart-lang/dart || warn_echo "⚠️ tap dart-lang/dart 失败（可能已存在）"
    if brew outdated | grep -q "^dart\$"; then
      highlight_echo "⬆️ 检测到 dart 有更新，正在升级..."
      if brew upgrade dart; then
        success_echo "✅ dart 升级成功"
      else
        error_echo "❌ dart 升级失败"
      fi
    else
      success_echo "✅ dart 已是最新版（无需升级）"
    fi
  fi
}

install_fvm() {
  if ! command -v fvm &>/dev/null; then
    note_echo "📦 未检测到 fvm，正在通过 dart pub global 安装..."
    dart pub global deactivate fvm
    dart pub global activate fvm || { error_echo "❌ fvm 安装失败"; exit 1; }
    success_echo "✅ fvm 安装成功"
  else
    info_echo "🔄 fvm 已安装，正在升级..."
    dart pub global activate fvm
    success_echo "✅ fvm 已是最新版"
  fi
  inject_shellenv_block "fvm_env" 'export PATH="$HOME/.pub-cache/bin:$PATH"'
}

get_current_configured_version() {
  if [[ -f .fvmrc ]]; then
    jq -r '.flutterSdkVersion // empty' .fvmrc 2>/dev/null
  elif [[ -f .fvm/fvm_config.json ]]; then
    jq -r '.flutterSdkVersion // empty' .fvm/fvm_config.json 2>/dev/null
  fi
}

fetch_stable_versions() {
  curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json |
    jq -r '.releases[] | select(.channel=="stable") | .version' |
    sort -V | uniq | tac
}

select_flutter_version() {
  local current="$1"
  local versions="$2"
  local choices=""
  if [[ -n "$current" ]]; then
    choices=$(echo "$versions" | awk -v current="$current" '{ if ($0 == current) print "✅ " $0; else print $0 }')
  else
    choices="$versions"
  fi
  local raw=$(echo "$choices" | fzf --prompt="🎯 选择 Flutter 版本：" --height=50% --border --ansi)
  echo "$raw" | sed 's/^✅ //' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+$'
}

prepare_flutter_versions() {
  CURRENT_VERSION=$(get_current_configured_version)
  VERSIONS=$(fetch_stable_versions)
  [[ -z "$VERSIONS" ]] && error_echo "❌ 无法获取 Flutter 版本列表" && exit 1
  SELECTED_VERSION=$(select_flutter_version "$CURRENT_VERSION" "$VERSIONS")
  [[ -z "$SELECTED_VERSION" ]] && SELECTED_VERSION=$(echo "$VERSIONS" | head -n1)
}

write_fvm_config() {
  local version="$1"
  echo "{\"flutterSdkVersion\": \"$version\"}" > .fvmrc
  success_echo "✔ 写入 .fvmrc：$version"
  mkdir -p .fvm
  echo "{\"flutterSdkVersion\": \"$version\"}" > .fvm/fvm_config.json
  note_echo "➤ 写入 .fvm/fvm_config.json"
}

install_flutter_version() {
  local version="$1"
  fvm install "$version"
  fvm use "$version"
}

write_flutter_alias() {
  if ! grep -q 'flutter()' ~/.zshrc; then
    echo '' >> ~/.zshrc
    echo 'flutter() { fvm flutter "$@"; }' >> ~/.zshrc
    success_echo "✔ 写入 flutter 函数别名 ~/.zshrc"
  fi
}

check_flutter_state_files() {
  [[ -f .packages ]] && note_echo "📦 检测到 .packages" || warn_echo "⚠️ 缺 .packages"
  [[ -f .flutter-plugins ]] && note_echo "📦 检测到 .flutter-plugins" || warn_echo "⚠️ 缺 .flutter-plugins"
  [[ -f .metadata ]] && note_echo "📦 检测到 .metadata" || warn_echo "⚠️ 缺 .metadata"
  [[ -d .dart_tool ]] && note_echo "📁 检测到 .dart_tool" || warn_echo "⚠️ 缺 .dart_tool"
}

check_duplicate_dependencies() {
  local list=$(awk '
    $1=="dependencies:" {mode="dep"; next}
    $1=="dev_dependencies:" {mode="dev"; next}
    /^[a-zA-Z0-9_]+:/ {
      pkg=$1; sub(":", "", pkg)
      if (mode == "dep") dep[pkg]++
      if (mode == "dev") dev[pkg]++
    }
    END {
      for (pkg in dep)
        if (dev[pkg]) print pkg
    }
  ' pubspec.yaml)

  if [[ -n "$list" ]]; then
    error_echo "⚠️ 同时出现在 dependencies 与 dev_dependencies："
    for pkg in $list; do
      err_echo "  - $pkg"
    done
  fi
}

ask_feature_toggle() {
  echo ""
  note_echo "👉 $1"
  gray_echo "【回车跳过，y 回车启用】"
  read "input?➤ "
  [[ "$input" == "y" || "$input" == "Y" ]]
}

run_optional_commands() {
  ask_feature_toggle "是否执行 flutter clean？" && fvm flutter clean
  ask_feature_toggle "是否执行 flutter pub get？" && fvm flutter pub get
  ask_feature_toggle "是否执行 flutter doctor？" && fvm flutter doctor
  ask_feature_toggle "是否执行 flutter analyze？" && fvm flutter analyze
}

show_final_summary() {
  local version="$1"
  local sdk_path="$HOME/.fvm/versions/$version"
  echo ""
  highlight_echo "🎉 Flutter 环境配置完成"
  gray_echo "------------------------------------------"
  info_echo "Flutter 版本：$version"
  info_echo "FVM 路径：$(which fvm)"
  info_echo "项目路径：$SCRIPT_DIR"
  info_echo "SDK 路径：$sdk_path"
  gray_echo "------------------------------------------"
}

# ✅ 通用：回车跳过，任意字符执行
ask_run() {
  echo ""
  note_echo "👉 $1"
  gray_echo "【回车=跳过，任意字符=执行】"
  local input
  read "input?➤ "
  [[ -n "$input" ]]
}

# ================================== 主执行入口 ==================================
main() {
  clear                                                # ✅ 清屏，保持终端输出整洁
  print_description                                    # ✅ 打印脚本自述信息（功能简介）

  detect_entry                                         # ✅ 检测或让用户拖拽正确的 Flutter 项目根目录（循环交互）
  check_flutter_project_path "$PWD"                    # ✅ 再做一次快速校验，确保当前目录真的是 Flutter 项目（非致命，仅提示）

  # ===== 工具依赖自检（用户可选择执行/跳过） =====
  ask_run "安装/更新 Homebrew？"   && install_homebrew   # ✅ 回车跳过，输入任意字符后执行 Homebrew 安装/更新
  ask_run "安装/升级 jq？"         && install_jq         # ✅ 回车跳过，输入任意字符后执行 jq 安装/升级
  ask_run "安装/升级 dart？"       && install_dart       # ✅ 回车跳过，输入任意字符后执行 dart 安装/升级
  ask_run "安装/升级 fvm？"        && install_fvm        # ✅ 回车跳过，输入任意字符后执行 fvm 安装/升级

  # ===== Flutter 版本管理流程 =====
  prepare_flutter_versions                             # ✅ 获取当前配置版本 + 在线稳定版本列表，并通过 fzf 选择
  write_fvm_config "$SELECTED_VERSION"                 # ✅ 写入 .fvmrc 与 .fvm/fvm_config.json 配置
  install_flutter_version "$SELECTED_VERSION"          # ✅ fvm 安装并切换到选中的 Flutter 版本
  write_flutter_alias                                  # ✅ 写 flutter() 函数别名，方便直接调用

  # ===== 项目状态检查 =====
  check_flutter_state_files                            # ✅ 检查 .packages、.metadata、.dart_tool 等状态文件是否存在
  check_duplicate_dependencies                         # ✅ 检查 pubspec.yaml 是否有重复依赖（dependencies 与 dev_dependencies）

  # ===== 可选操作 =====
  run_optional_commands                                # ✅ 额外交互：flutter clean / pub get / doctor / analyze（回车跳过、y 执行）

  # ===== 总结信息输出 =====
  show_final_summary "$SELECTED_VERSION"               # ✅ 展示最终 Flutter 环境配置总结
}

main "$@"
