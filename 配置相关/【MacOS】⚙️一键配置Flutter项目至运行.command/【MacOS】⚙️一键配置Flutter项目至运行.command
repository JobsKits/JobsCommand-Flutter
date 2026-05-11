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

  # ================================== 基础变量 ==================================
  get_script_path() {
    # ✅ 兼容 Finder 双击：${(%):-%x} 才是脚本真实路径（$0 可能是 zsh）
    local p="${(%):-%x}"
    [[ -z "$p" ]] && p="$0"
    echo "${p:A}"
  }

  SCRIPT_PATH="$(get_script_path)"
  SCRIPT_DIR="${SCRIPT_PATH:h}"
  SCRIPT_BASENAME="${${SCRIPT_PATH:t}%.*}"
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

  # 只清一次日志（避免 Rosetta -> arm64 重新执行导致日志被清空）
  if [[ "${JOBS_LOG_CLEARED:-0}" != "1" ]]; then
    : > "$LOG_FILE" 2>/dev/null || true
    export JOBS_LOG_CLEARED=1
  fi

  # 默认 flutter_cmd（后续会切成 fvm flutter）
  typeset -a flutter_cmd
  flutter_cmd=("flutter")

  # ================================== 日志与彩色输出 ==================================
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

  ts() { date +"%Y%m%d_%H%M%S"; }

  # ================================== 自述 ==================================
  show_script_intro() {
    cat <<EOF | tee -a "$LOG_FILE"
  ====================================================================
   🛠️  Flutter 开发环境一键初始化脚本（FVM + VSCode + iOS 预缓存）
  ====================================================================
  📌 会做什么：
    1) Apple Silicon 下检测 Rosetta(x86_64) 并切换 arm64 重新执行（避免下载 darwin-x64）
    2) 确保 Homebrew 可用（Finder 双击时 PATH 常常找不到 brew）
    3) 安装/检测 FVM，并绑定到“Flutter 项目根目录”（只在 pubspec.yaml + lib/ 的目录生效）
    4) 预下载 iOS 缓存：fvm flutter precache --ios（第一次会下载很多东西，属正常）
    5) 写入 VSCode 项目级配置：
       - .vscode/settings.json：dart.flutterSdkPath = .fvm/flutter_sdk，并移除 dart.sdkPath（防止 IDE 误判）
       - .vscode/launch.json：自动选择 iOS Simulator 作为默认 deviceId（F5 直接跑，不用 Select Device）
  ====================================================================
  EOF
  }

  press_enter_to_continue() {
    echo "" | tee -a "$LOG_FILE"
    echo "按下回车键开始执行，或 Ctrl+C 退出" | tee -a "$LOG_FILE"
    read -r _
  }

  # ================================== Apple Silicon 下避免 Rosetta ==================================
  ensure_native_arm64() {
    local machine_arch current_arch
    machine_arch="$(uname -m 2>/dev/null || echo "")"
    current_arch="$(arch 2>/dev/null || echo "")"

    # 只在 Apple Silicon 上处理
    if [[ "$machine_arch" == "arm64" && "$current_arch" == "x86_64" && "${JOBS_FORCE_ARM64:-0}" != "1" ]]; then
      warn_echo "检测到当前进程在 Rosetta(x86_64) 下运行，自动切换到 arm64 重新执行脚本..."
      export JOBS_FORCE_ARM64=1
      /usr/bin/arch -arm64 /bin/zsh "$SCRIPT_PATH" "$@"
      exit $?
    fi

    success_echo "当前架构：$(arch)（machine: $(uname -m)）"
  }

  # ================================== Flutter 项目根目录判断（按你给的规则） ==================================
  is_flutter_project_root() {
    [[ -f "$1/pubspec.yaml" && -d "$1/lib" ]]
  }

  # ================================== 从某目录向上递归找根目录 ==================================
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

  # Finder 双击会带 -psn_xxx 参数，过滤掉
  pick_user_path_arg() {
    local a
    for a in "$@"; do
      [[ "$a" == -psn_* ]] && continue
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

  # ================================== Homebrew & FVM ==================================
  ensure_brew_in_path() {
    # Finder 环境 PATH 很“干净”，brew 常常找不到；补齐常见路径
    local brew_paths=(
      "/opt/homebrew/bin"
      "/usr/local/bin"
      "/usr/local/sbin"
      "/opt/homebrew/sbin"
    )
    local p
    for p in "${brew_paths[@]}"; do
      [[ -d "$p" ]] && export PATH="$p:$PATH"
    done
  }

  ensure_homebrew() {
    ensure_brew_in_path

    if command -v brew >/dev/null 2>&1; then
      success_echo "Homebrew 已存在：$(command -v brew)"
      return 0
    fi

    error_echo "❌ 未检测到 Homebrew（brew）。请先安装 Homebrew 再运行此脚本。"
    gray_echo "👉 安装： https://brew.sh/"
    exit 1
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

  # ================================== FVM 绑定项目 + iOS 预缓存 ==================================
  setup_fvm_and_precache() {
    local project_root="$1"
    cd "$project_root"

    info_echo "项目根目录：$project_root"
    info_echo "开始绑定 FVM 到项目（写入 $project_root/.fvm）"

    local channel_or_version="stable"

    fvm install "$channel_or_version"
    fvm use "$channel_or_version"

    success_echo "FVM 已绑定：$channel_or_version"
    gray_echo "当前项目 Flutter：$(fvm flutter --version 2>/dev/null | head -n 1 || true)"

    # 后续统一用 fvm flutter（避免用到系统 flutter）
    flutter_cmd=("fvm" "flutter")

    info_echo "开始预下载 iOS 相关缓存（第一次下载很多东西是正常现象）"
    "${flutter_cmd[@]}" precache --ios || warn_echo "precache --ios 失败（可能 Xcode 未就绪），可稍后再跑：fvm flutter precache --ios"

    info_echo "初始化 doctor / pub get（确保 cache 与依赖完整）"
    "${flutter_cmd[@]}" doctor -v || true
    "${flutter_cmd[@]}" pub get

    success_echo "Flutter 缓存与依赖初始化完成"
  }

  # ================================== 写入 VSCode settings（项目级） ==================================
  write_vscode_settings() {
    local project_root="$1"
    local vscode_dir="$project_root/.vscode"
    local settings="$vscode_dir/settings.json"
    mkdir -p "$vscode_dir"

    if [[ -f "$settings" ]]; then
      cp "$settings" "${settings}.bak.$(ts)"
      warn_echo "已备份：${settings}.bak.$(ts)"
    fi

    # ✅ 必做：写 dart.flutterSdkPath，并移除 dart.sdkPath（避免 IDE 因 cache 路径不存在而“找不到 SDK”）
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
  data.pop("dart.sdkPath", None)  # 关键：移除
  data["dart.flutterRememberSelectedDevice"] = True

  with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
  PY
    else
      cat > "$settings" <<'JSON'
  {
    "dart.flutterSdkPath": ".fvm/flutter_sdk",
    "dart.flutterRememberSelectedDevice": true
  }
  JSON
    fi

    success_echo "已写入 VSCode 配置：$settings"
    gray_echo "dart.flutterSdkPath -> .fvm/flutter_sdk（并移除 dart.sdkPath）"
  }

  # ================================== 自动选择默认设备（优先 iOS Simulator） ==================================
  detect_default_device_id() {
    local project_root="$1"
    cd "$project_root"

    # 确保使用 fvm flutter
    local out
    if ! out="$("${flutter_cmd[@]}" devices --machine 2>/dev/null)"; then
      echo ""
      return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
      python3 - <<PY
  import json, sys
  try:
    devices = json.loads('''$out''')
  except Exception:
    print("")
    sys.exit(0)

  def pick(pred):
    for d in devices:
      try:
        if pred(d):
          return d.get("id","")
      except Exception:
        pass
    return ""

  # 1) iOS 模拟器
  did = pick(lambda d: d.get("platform")=="ios" and d.get("emulator")==True)
  # 2) iOS 真机
  did = did or pick(lambda d: d.get("platform")=="ios" and d.get("emulator")==False)
  # 3) macOS
  did = did or pick(lambda d: d.get("platform")=="macos")
  print(did)
  PY
    else
      echo ""
    fi
  }

  # ================================== 写入 VSCode launch.json（固定 deviceId，F5 直接跑） ==================================
  write_vscode_launch() {
    local project_root="$1"
    local vscode_dir="$project_root/.vscode"
    local launch="$vscode_dir/launch.json"
    mkdir -p "$vscode_dir"

    local device_id
    device_id="$(detect_default_device_id "$project_root" | tr -d '\n\r')"

    if [[ -n "$device_id" ]]; then
      success_echo "默认设备已选定：$device_id（以后 F5 不用 Select Device）"
    else
      warn_echo "未检测到可用设备，launch.json 将不写 deviceId（你可稍后再生成或手选）"
    fi

    if command -v python3 >/dev/null 2>&1; then
      python3 - <<PY
  import json
  device_id = "${device_id}"
  cfg = {
    "version": "0.2.0",
    "configurations": [
      {
        "name": "Flutter iOS (Auto Device)",
        "type": "dart",
        "request": "launch",
        "program": "lib/main.dart",
      }
    ]
  }
  if device_id:
    cfg["configurations"][0]["deviceId"] = device_id

  with open("${launch}", "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
  PY
    else
      if [[ -n "$device_id" ]]; then
        cat > "$launch" <<JSON
  {
    "version": "0.2.0",
    "configurations": [
      {
        "name": "Flutter iOS (Auto Device)",
        "type": "dart",
        "request": "launch",
        "program": "lib/main.dart",
        "deviceId": "${device_id}"
      }
    ]
  }
  JSON
      else
        cat > "$launch" <<'JSON'
  {
    "version": "0.2.0",
    "configurations": [
      {
        "name": "Flutter iOS (Auto Device)",
        "type": "dart",
        "request": "launch",
        "program": "lib/main.dart"
      }
    ]
  }
  JSON
      fi
    fi

    success_echo "已写入：$launch"
  }

  # ================================== 安全检查（防止写到奇怪目录） ==================================
  safety_check_project_root() {
    local project_root="$1"

    if [[ -z "$project_root" || "$project_root" == "/" ]]; then
      error_echo "❌ 项目根目录不合法：$project_root"
      exit 1
    fi

    # 防止误把 $HOME 当项目根
    if [[ "$project_root" == "$HOME" ]]; then
      error_echo "❌ 项目根目录误判为 HOME：$project_root（已终止，避免污染）"
      exit 1
    fi

    if ! is_flutter_project_root "$project_root"; then
      error_echo "❌ 目录不满足 Flutter 项目根目录条件（需要 pubspec.yaml + lib/）：$project_root"
      exit 1
    fi
  }

  # ================================== 主流程 ==================================
  main() {
    show_script_intro
    # 你想全自动就注释掉下一行
    # press_enter_to_continue

    ensure_native_arm64 "$@"

    local project_root
    project_root="$(resolve_flutter_project_root "$@")" || {
      error_echo "❌ 未检测到 Flutter 项目根目录（需要同时存在：pubspec.yaml + lib/）"
      note_echo "👉 请在 Flutter 项目根目录运行脚本，或传入路径："
      gray_echo "   ./${SCRIPT_BASENAME}.command /path/to/flutter_project"
      exit 1
    }

    safety_check_project_root "$project_root"

    ensure_homebrew
    ensure_fvm

    setup_fvm_and_precache "$project_root"
    write_vscode_settings "$project_root"
    write_vscode_launch "$project_root"

    success_echo "✅ 全部完成"
    note_echo "建议：在 VS Code 执行 Developer: Reload Window，然后直接按 F5 运行（无需 Select Device）"
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
