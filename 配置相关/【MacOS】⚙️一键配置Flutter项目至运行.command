#!/bin/zsh
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
