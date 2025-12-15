#!/usr/bin/env bash
# ================================== 自述 ==================================
# 名称：Android 模拟器 “INSTALL_FAILED_INSUFFICIENT_STORAGE” 一键检测与修复
# 目标：
#   1) 恢复默认安装位置 (pm set-install-location 0)
#   2) 可选卸载旧包 (--uninstall-first 或在交互中选择)
#   3) 检测 /data 剩余空间，自动给出：
#      - ART/Dalvik 编译缓存重置
#      - 可选卸载常见大体积内置应用（仅对当前用户）
#      - 一键扩容 AVD data 分区（修改 ~/.android/avd/<AVD>.avd/config.ini）
#      - 自动冷启动模拟器（找得到 emulator 命令则自动）
# 运行环境：macOS / Linux，需 adb；可选 fzf 与 emulator 命令（Android SDK）
# 日志：/tmp/$(basename "$0").log
# ==========================================================================

set -euo pipefail

# ================================== 全局配置 ==================================
SCRIPT_BASENAME="$(basename "$0")"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE"

# 默认阈值（可用空间低于此数值视为不足）
THRESHOLD_MB=${THRESHOLD_MB:-800}
# 默认目标扩容尺寸
TARGET_DATAPARTITION_SIZE=${TARGET_DATAPARTITION_SIZE:-8G}

# ------- 语义化输出 -------
ESC=$'\033'
RESET="${ESC}[0m"
bold(){ echo "${ESC}[1m$*${RESET}"; }
gray(){ echo "${ESC}[90m$*${RESET}"; }
info_echo(){ echo "ℹ️  $*"; echo "[INFO] $*" >>"$LOG_FILE"; }
success_echo(){ echo "✅ $*"; echo "[OK] $*" >>"$LOG_FILE"; }
warn_echo(){ echo "⚠️  $*"; echo "[WARN] $*" >>"$LOG_FILE"; }
error_echo(){ echo "❌ $*"; echo "[ERR] $*" >>"$LOG_FILE"; }
highlight_echo(){ echo "✨ $*"; echo "[HIGHLIGHT] $*" >>"$LOG_FILE"; }

# ------- 交互确认（支持 --yes 跳过） -------
AUTO_YES=0
confirm() {
  local msg="$1"
  if [[ $AUTO_YES -eq 1 ]]; then
    echo "y"
    return 0
  fi
  read -r -p "❓ ${msg} [y/N] " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

# ================================== 参数解析 ==================================
APP_ID=""
UNINSTALL_FIRST=0

usage() {
  cat <<EOF
用法：
  $SCRIPT_BASENAME [--app-id com.example.app] [--uninstall-first] [--yes]
  可选环境变量：
    THRESHOLD_MB=<int>             # 默认 800
    TARGET_DATAPARTITION_SIZE=8G   # 目标扩容值（如 6G/8G/12G）
示例：
  $SCRIPT_BASENAME --app-id com.xxx.flutter_tiyu_app --uninstall-first --yes
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id) APP_ID="$2"; shift 2;;
    --uninstall-first) UNINSTALL_FIRST=1; shift;;
    --yes|-y) AUTO_YES=1; shift;;
    -h|--help) usage; exit 0;;
    *) warn_echo "未知参数：$1"; shift;;
  esac
done

# ================================== 工具检测 ==================================
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error_echo "缺少命令：$1"
    exit 1
  fi
}
need_cmd adb

if command -v fzf >/dev/null 2>&1; then
  HAS_FZF=1
else
  HAS_FZF=0
fi

# ================================== 设备选择 ==================================
pick_device() {
  local devices
  devices=$(adb devices | awk 'NR>1 && $2=="device"{print $1}')
  if [[ -z "$devices" ]]; then
    error_echo "未检测到已连接/已启动的设备或模拟器。请先启动 AVD 再运行本脚本。"
    adb devices
    exit 1
  fi
  local count
  count=$(echo "$devices" | wc -l | tr -d ' ')
  if [[ "$count" -eq 1 ]]; then
    echo "$devices"
    return
  fi
  info_echo "检测到多个设备："
  echo "$devices" | nl -ba
  if [[ $HAS_FZF -eq 1 ]]; then
    echo "$devices" | fzf --prompt="选择设备> "
  else
    read -r -p "输入要使用的序号： " idx
    echo "$devices" | sed -n "${idx}p"
  fi
}

DEVICE_ID="$(pick_device)"
success_echo "使用设备：$(bold "$DEVICE_ID")"

adb -s "$DEVICE_ID" get-state >/dev/null

# ================================== AVD 名称与路径 ==================================
# 1) 通过系统属性获取 AVD 名称
AVD_NAME="$(adb -s "$DEVICE_ID" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d '\r')"
AVD_DIR="$HOME/.android/avd"
AVD_INI=""

if [[ -n "$AVD_NAME" && -d "$AVD_DIR/${AVD_NAME}.avd" ]]; then
  AVD_INI="$AVD_DIR/${AVD_NAME}.avd/config.ini"
  success_echo "解析到 AVD：$(bold "$AVD_NAME")"
else
  warn_echo "未能从设备解析到 AVD 名称或 AVD 目录不存在，将跳过“自动扩容 AVD”功能。"
fi

# ================================== 恢复安装位置 ==================================
fix_install_location() {
  local cur
  cur=$(adb -s "$DEVICE_ID" shell pm get-install-location | tr -d '\r')
  info_echo "当前安装位置：$cur（0=自动，1=内部，2=外部）"
  if [[ "$cur" != 0* ]]; then
    info_echo "恢复为 0（自动）..."
    adb -s "$DEVICE_ID" shell pm set-install-location 0
    success_echo "已设置为自动。"
  else
    success_echo "安装位置已是自动，无需更改。"
  fi
}

# ================================== 可选卸载旧包 ==================================
maybe_uninstall_app() {
  if [[ -z "$APP_ID" ]]; then
    warn_echo "未提供 --app-id，跳过卸载旧包步骤。"
    return
  fi
  if [[ $UNINSTALL_FIRST -eq 1 ]] || confirm "卸载已安装的旧包 ${APP_ID}？"; then
    info_echo "卸载 ${APP_ID} ..."
    if adb -s "$DEVICE_ID" uninstall "$APP_ID"; then
      success_echo "卸载成功。"
    else
      warn_echo "卸载可能失败或本就未安装，继续。"
    fi
  fi
}

# ================================== 空间检测 ==================================
get_free_mb() {
  # 解析 df -k /data 的 available 列（KB → MB）
  local kb
  kb=$(adb -s "$DEVICE_ID" shell df -k /data | awk 'NR==2{print $4}' | tr -d '\r')
  if [[ -z "$kb" ]]; then
    echo 0
  else
    echo $(( kb / 1024 ))
  fi
}

report_space() {
  local free
  free=$(get_free_mb)
  info_echo "/data 可用空间：$(bold "${free} MB")"
  if (( free < THRESHOLD_MB )); then
    warn_echo "可用空间低于阈值 ${THRESHOLD_MB} MB。"
    return 1
  else
    success_echo "空间充足（>= ${THRESHOLD_MB} MB）。"
    return 0
  fi
}

# ================================== 清理动作 ==================================
reset_art_cache() {
  info_echo "重置 ART/Dalvik 编译缓存..."
  adb -s "$DEVICE_ID" shell cmd package compile --reset -a || warn_echo "重置编译缓存可能未完全支持，忽略。"
  success_echo "已尝试重置 ART/Dalvik。"
}

# 风险更高：卸载一些大体积用户态 App（仅 user 0，不影响系统镜像）
maybe_uninstall_bloat() {
  local candidates=(
    "com.android.chrome"
    "com.google.android.youtube"
    "com.google.android.apps.photos"
    "com.google.android.apps.docs"
  )
  if confirm "尝试卸载一些常见大体积 App（仅对当前用户），以回收空间？"; then
    for p in "${candidates[@]}"; do
      info_echo "卸载 $p（--user 0）..."
      adb -s "$DEVICE_ID" shell pm uninstall --user 0 "$p" || true
    done
    success_echo "已尝试卸载候选 App。"
  fi
}

# ================================== 扩容 AVD data 分区 ==================================
expand_avd_datapartition() {
  if [[ -z "$AVD_INI" || ! -f "$AVD_INI" ]]; then
    warn_echo "找不到 AVD config.ini，无法自动扩容。"
    return 1
  fi

  info_echo "准备把 data 分区扩到：$(bold "$TARGET_DATAPARTITION_SIZE")"
  # 修改/添加配置项
  if grep -q '^disk.dataPartition.size=' "$AVD_INI"; then
    sed -i.bak "s/^disk.dataPartition.size=.*/disk.dataPartition.size=${TARGET_DATAPARTITION_SIZE}/" "$AVD_INI"
  else
    echo "disk.dataPartition.size=${TARGET_DATAPARTITION_SIZE}" >> "$AVD_INI"
  fi

  # 顺便确保 sdcard 设置合理（可选）
  if ! grep -q '^hw.sdCard=' "$AVD_INI"; then
    echo "hw.sdCard=yes" >> "$AVD_INI"
  fi
  if ! grep -q '^sdcard.size=' "$AVD_INI"; then
    echo "sdcard.size=512M" >> "$AVD_INI"
  fi

  success_echo "已写入：$AVD_INI"
  warn_echo "扩容后需要冷启动并可能执行 Wipe Data 才能生效。"

  # 关闭当前模拟器
  info_echo "尝试关闭当前模拟器..."
  adb -s "$DEVICE_ID" emu kill || true
  sleep 2

  # 自动启动（若找到 emulator）
  if command -v emulator >/dev/null 2>&1 && [[ -n "$AVD_NAME" ]]; then
    info_echo "尝试以冷启动方式启动 AVD：$AVD_NAME"
    nohup emulator -avd "$AVD_NAME" -no-snapshot-load >/dev/null 2>&1 &
    success_echo "已尝试启动模拟器（后台）。请等待其完全启动后再继续打包运行。"
  else
    warn_echo "未找到 emulator 命令或 AVD 名称未知，请手动从 AVD Manager 冷启动该 AVD。"
  fi
}

# ================================== 主流程 ==================================
main() {
  highlight_echo "开始检测与修复：$DEVICE_ID"
  fix_install_location
  maybe_uninstall_app

  if ! report_space; then
    if confirm "先尝试轻量清理（重置 ART/Dalvik 缓存）？"; then
      reset_art_cache
      sleep 1
      report_space || true
    fi

    if ! report_space; then
      maybe_uninstall_bloat
      sleep 1
      report_space || true
    fi

    if ! report_space; then
      warn_echo "清理后空间仍不足。推荐进行【AVD 扩容 + 冷启动】。"
      if confirm "现在自动修改 AVD 配置为 ${TARGET_DATAPARTITION_SIZE} 并冷启动？"; then
        expand_avd_datapartition
        info_echo "扩容后首次启动可能较慢。启动完成后再执行：flutter run"
      else
        warn_echo "已取消扩容；你也可以在 AVD Manager 手动执行 Wipe Data 或增加 Internal Storage。"
      fi
    fi
  fi

  success_echo "处理完成。若你启用了 --uninstall-first，可直接重跑：flutter run"
  gray "日志：$LOG_FILE"
}

main "$@"

