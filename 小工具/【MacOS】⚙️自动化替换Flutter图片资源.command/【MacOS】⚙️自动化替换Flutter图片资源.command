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
  # =============================================================================
  # 名称：Flutter 启动图 / App 图标自动替换（macOS / Zsh）
  # 说明：从脚本目录的【启动图】与【App图标】复制到目标 Flutter 项目的 ./assets 根目录，
  #      然后执行 clean / 清理平台旧资源 / 替换 iOS LaunchImage.imageset / pub get /
  #      生成图标 / 生成启动图，最后验证产物并自动打开相关目录。失败会回到循环继续问。
  # 依赖：zsh、awk、sed、grep、cp、rsync(可选)、flutter、dart、open(系统)
  # =============================================================================

  set +x +v
  unsetopt XTRACE VERBOSE
  set -o pipefail
  setopt NO_BEEP ERR_RETURN
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8
  export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

  # =============================================================================
  # 日志与彩色输出（记录到 /tmp/<脚本名>.log）
  # =============================================================================
  SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
  LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
  : > "$LOG_FILE" 2>/dev/null || touch "$LOG_FILE"

  if [[ -x /usr/bin/tee ]]; then
    _TEE=/usr/bin/tee
  elif command -v tee >/dev/null 2>&1; then
    _TEE=$(command -v tee)
  else
    _TEE=""
  fi

  _log_write() {
    if [[ -n "$_TEE" ]]; then
      printf "%b\n" "$1" | "$_TEE" -a "$LOG_FILE"
    else
      printf "%b\n" "$1"
      printf "%b\n" "$1" >> "$LOG_FILE"
    fi
  }

  log()            { _log_write "$1"; }
  info_echo()      { _log_write "\033[1;34mℹ $1\033[0m"; }
  success_echo()   { _log_write "\033[1;32m✔ $1\033[0m"; }
  warn_echo()      { _log_write "\033[1;33m⚠ $1\033[0m"; }
  note_echo()      { _log_write "\033[1;35m➤ $1\033[0m"; }
  error_echo()     { _log_write "\033[1;31m✖ $1\033[0m"; }
  highlight_echo() { _log_write "\033[1;36m🔹 $1\033[0m"; }
  gray_echo()      { _log_write "\033[0;90m$1\033[0m"; }
  bold_echo()      { _log_write "\033[1m$1\033[0m"; }

  # =============================================================================
  # 安全读入（子壳静音 trace，从 /dev/tty 读入并输出赋值文本，父壳静默 eval）
  # 用法：safe_read 变量名
  # =============================================================================
  safe_read() {
    local __var="$1"
    [[ -z "$__var" ]] && return 1
    {
      setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
      set +x +v
      exec {__sink_fd}>/dev/null
      typeset -gi XTRACEFD=$__sink_fd
      __line="$(/usr/bin/head -n1 </dev/tty | /usr/bin/sed -e $'s/\r$//')"
      printf '%s=%q\n' "$__var" "$__line"
      exec {__sink_fd}>&-
    } | {
      setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
      set +x +v
      builtin read -r __assign
      eval "$__assign"
    }
  }

  # =============================================================================
  # 路径配置
  # =============================================================================
  SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
  SRC_SPLASH="$SCRIPT_DIR/启动图"
  SRC_ICONS="$SCRIPT_DIR/App图标"
  PROJECT_ROOT=""

  # =============================================================================
  # 自述与配置模板
  # =============================================================================
  print_intro() {
    echo "" > "$LOG_FILE"
    log ""
    bold_echo "══════════════════════════════════════════════════════════════════"
    bold_echo "  Flutter 启动图 / App 图标自动替换（macOS / Zsh）"
    bold_echo "══════════════════════════════════════════════════════════════════"
    log ""
    note_echo "本脚本会执行："
    log "  1) 覆盖 ./assets：删除 icon.png / launch_image.png → 复制脚本同级「App图标」「启动图」顶层文件"
    log "  2) flutter clean（清理构建缓存）"
    log "  3) 清理平台旧资源：iOS AppIcon.appiconset/* 与 Android res/*"
    log "  4) 替换 iOS LaunchImage.imageset 内的图片（保留 Contents.json）"
    log "  5) flutter pub get（下载依赖并生成 .dart_tool 配置）"
    log "  6) flutter pub run flutter_launcher_icons（若配置了，生成 App 图标）"
    log "  7) dart/flutter pub run flutter_native_splash（若配置了，生成启动图）"
    log "  8) 验证并自动打开 iOS / Android 资源目录"
    log ""
    note_echo "请确保 pubspec.yaml 至少包含如下配置："
    gray_echo '
  dev_dependencies:
    flutter_launcher_icons: any
  
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: "assets/icon.png"
    adaptive_icon_background: "#FFFFFF"
    adaptive_icon_foreground: "assets/icon.png"
    adaptive_icon_monochrome: "assets/icon.png"
    min_sdk_android: 19

  flutter:
    uses-material-design: true
    assets:
      - assets/launch_image.png
  '
    highlight_echo "在线取色器：https://photokit.com/colors/color-picker/?lang=zh"
    log ""
    bold_echo "按回车开始..."
    safe_read _
  }

  # =============================================================================
  # 自检资源目录
  # =============================================================================
  check_local_asset_dirs() {
    local ok=1
    [[ -d "$SRC_SPLASH" ]] && success_echo "已检测到：$SRC_SPLASH" || { error_echo "未找到：$SRC_SPLASH"; ok=0; }
    [[ -d "$SRC_ICONS"  ]] && success_echo "已检测到：$SRC_ICONS"  || { error_echo "未找到：$SRC_ICONS";  ok=0; }
    (( ok )) || { error_echo "缺少资源目录，无法继续。"; return 1 }
  }

  # =============================================================================
  # 判断 Flutter 项目根目录
  # =============================================================================
  is_flutter_project_root() {
    local dir="$1"
    [[ -f "$dir/pubspec.yaml" && -d "$dir/lib" ]]
  }

  # =============================================================================
  # 询问 Flutter 项目根目录（干净无回显；q/Q 退出；空输入继续）
  # =============================================================================
  prompt_project_root() {
    while true; do
      printf "请输入 Flutter 项目根目录路径（q 退出）： "
      {
        setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
        set +x +v
        exec {__sink_fd}>/dev/null
        typeset -gi XTRACEFD=$__sink_fd
        __line="$(/usr/bin/head -n1 </dev/tty | /usr/bin/sed -e $'s/\r$//')"
        printf 'path_in=%q\n' "$__line"
        exec {__sink_fd}>&-
      } | {
        setopt LOCALOPTIONS NO_XTRACE NO_VERBOSE
        set +x +v
        builtin read -r __assign
        eval "$__assign"
      }

      if [[ "$path_in" == "q" || "$path_in" == "Q" ]]; then
        return 1
      fi
      if [[ -z "$path_in" ]]; then
        printf "\033[1;33m⚠ 未输入路径，请重试。\033[0m\n"
        continue
      fi

      local path="${~path_in}"
      path="$(cd "$path" 2>/dev/null && pwd || true)"
      if [[ -n "$path" && -d "$path" && -f "$path/pubspec.yaml" && -d "$path/lib" ]]; then
        printf "\033[1;32m✔ 项目根目录：%s\033[0m\n" "$path"
        PROJECT_ROOT="$path"
        return 0
      else
        printf "\033[1;33m⚠ 不是有效的 Flutter 项目根目录（需 pubspec.yaml + lib/）。请重试。\033[0m\n"
      fi
    done
  }

  # =============================================================================
  # 复制资源到 ./assets（覆盖模式）
  # - 先删除 assets/icon.png、assets/launch_image.png
  # - 把「App图标」「启动图」目录下的【顶层文件】复制到 assets 根目录
  # =============================================================================
  copy_assets_into_project() {
    local dest_assets="$PROJECT_ROOT/assets"
    mkdir -p "$dest_assets" || { error_echo "创建目录失败：$dest_assets"; return 1; }

    # 1) 删除旧的关键文件
    local removed=0
    for f in "icon.png" "launch_image.png"; do
      if [[ -e "$dest_assets/$f" ]]; then
        rm -f "$dest_assets/$f" && removed=1
      fi
    done
    (( removed )) && warn_echo "已删除旧文件：$dest_assets/icon.png、$dest_assets/launch_image.png" || gray_echo "未发现旧的 icon.png / launch_image.png"

    # 2) 复制两个源目录的【顶层文件】到 assets 根
    copy_top_files() {
      local src="$1"
      local dst="$2"
      local copied=0
      while IFS= read -r -d '' file; do
        cp -f "$file" "$dst/" && copied=1 && gray_echo "拷贝：$(basename "$file") → $dst"
      done < <(find "$src" -maxdepth 1 -type f -print0 2>/dev/null)
      (( copied )) || warn_echo "未在 $src 找到顶层文件（已跳过）"
    }

    copy_top_files "$SRC_ICONS"  "$dest_assets"
    copy_top_files "$SRC_SPLASH" "$dest_assets"

    # 3) 核验关键文件是否到位
    local miss=0
    [[ -f "$dest_assets/icon.png" ]] || { miss=1; error_echo "缺少：$dest_assets/icon.png（请把 icon.png 放到「App图标」目录顶层）"; }
    [[ -f "$dest_assets/launch_image.png" ]] || { miss=1; error_echo "缺少：$dest_assets/launch_image.png（请把 launch_image.png 放到「启动图」目录顶层）"; }
    (( miss )) && return 1

    success_echo "资源已就位到：$dest_assets（icon.png / launch_image.png 已覆盖）"
  }

  # =============================================================================
  # 清理平台旧资源（在 pub get 之前执行）
  # iOS:   <PROJECT_ROOT>/ios/Runner/Assets.xcassets/AppIcon.appiconset/*     全部删除
  # AND:   只删除 Android 图标相关文件（ic_launcher*），保留 values/、layout/ 等其余资源
  # =============================================================================
  purge_old_platform_assets() {
    cd "$PROJECT_ROOT" || { error_echo "进入项目目录失败，无法清理平台资源。"; return 1; }

    local ios_icons_dir="$PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    local android_res_dir="$PROJECT_ROOT/android/app/src/main/res"

    gray_echo "当前目录：$(pwd)"
    gray_echo "准备清理（Android 仅删除图标文件，不清空 res）："
    gray_echo "  - iOS: $ios_icons_dir/*"
    gray_echo "  - Android: $android_res_dir/**/ic_launcher*（含 .png/.webp/.xml 等）"

    printf "确认执行吗？(y/N)："
    local ans; safe_read ans
    if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
      warn_echo "已跳过清理平台资源。"
      return 0
    fi

    # ---------------- iOS：清空 AppIcon.appiconset（保留目录本身） ----------------
    mkdir -p "$ios_icons_dir"
    if [[ -d "$ios_icons_dir" ]]; then
      find "$ios_icons_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
      success_echo "已清空：$ios_icons_dir"
    else
      warn_echo "未找到 iOS 图标目录，跳过：$ios_icons_dir"
    fi

    # ---------------- Android：只删除 ic_launcher* 相关文件 ----------------
    mkdir -p "$android_res_dir"
    if [[ -d "$android_res_dir" ]]; then
      # 常见图标文件（尽量覆盖所有生成器变体；不会触碰其它业务资源）
      find "$android_res_dir" -type f \( \
          -name "ic_launcher.png"            -o -name "ic_launcher.webp"            -o \
          -name "ic_launcher_round.png"      -o -name "ic_launcher_round.webp"      -o \
          -name "ic_launcher.xml"            -o -name "ic_launcher_round.xml"       -o \
          -name "ic_launcher_monochrome.xml" -o \
          -name "ic_launcher_foreground.png" -o -name "ic_launcher_foreground.xml"  -o \
          -name "ic_launcher_background.png" -o -name "ic_launcher_background.xml"  \
        \) -print -delete 2>/dev/null || true

      # 有些生成器会把前景/背景放进 drawable(-*) 目录，再扫一遍更稳妥
      find "$android_res_dir" -type f -path "*/drawable*/ic_launcher_*" -print -delete 2>/dev/null || true
      # anydpi 变体（Android 8+/13+）
      find "$android_res_dir" -type f -path "*/mipmap-anydpi-*/ic_launcher*.xml" -print -delete 2>/dev/null || true

      success_echo "已删除 Android 旧图标文件（其余 res 未动）：$android_res_dir"
    else
      warn_echo "未找到 Android res 目录，跳过：$android_res_dir"
    fi
  }

  # =============================================================================
  # 替换 iOS 的 LaunchImage.imageset 内的图片（保留 Contents.json）
  # 来源：脚本同级「启动图」目录下的图片（png/jpg/jpeg/pdf，顶层文件）
  # =============================================================================
  replace_ios_launch_imageset() {
    local imageset="$PROJECT_ROOT/ios/Runner/Assets.xcassets/LaunchImage.imageset"
    mkdir -p "$imageset" || { error_echo "创建目录失败：$imageset"; return 1; }

    # 删除旧图片（保留 Contents.json）
    find "$imageset" -type f ! -name 'Contents.json' \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pdf' \) \
      -exec rm -f {} + 2>/dev/null || true

    # 从「启动图」目录复制顶层图片
    local copied=0
    while IFS= read -r -d '' file; do
      cp -f "$file" "$imageset/" && copied=1 && gray_echo "拷贝到 LaunchImage.imageset：$(basename "$file")"
    done < <(find "$SRC_SPLASH" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pdf' \) -print0 2>/dev/null)

    if (( copied )); then
      success_echo "已替换 iOS LaunchImage.imageset 图片资源：$imageset"
    else
      warn_echo "未在 $SRC_SPLASH 找到图片（png/jpg/jpeg/pdf），未替换 LaunchImage.imageset"
    fi
  }

  # =============================================================================
  # 执行 Flutter 构建步骤
  # =============================================================================
  run_flutter_steps() {
    cd "$PROJECT_ROOT" || { error_echo "进入项目目录失败。"; return 1; }
    command -v flutter >/dev/null 2>&1 || { error_echo "未找到 flutter 命令。"; return 1; }

    info_echo "正在清理构建缓存：flutter clean"
    flutter clean || warn_echo "flutter clean 失败"

    info_echo "清理平台旧资源（iOS AppIcon.appiconset 与 Android res）"
    purge_old_platform_assets || { warn_echo "平台资源清理步骤出现问题，已跳过。"; }

    info_echo "替换 iOS LaunchImage.imageset 内的图片资源"
    replace_ios_launch_imageset || { warn_echo "替换 LaunchImage.imageset 失败，已跳过。"; }

    info_echo "下载依赖：flutter pub get"
    flutter pub get || { error_echo "flutter pub get 失败"; return 1; }

    if grep -Eq '^[[:space:]]*flutter_launcher_icons[[:space:]]*:' pubspec.yaml; then
      info_echo "正在构建 App 图标：flutter pub run flutter_launcher_icons"
      flutter pub run flutter_launcher_icons || { error_echo "图标生成失败"; return 1; }
    else
      warn_echo "未检测到 flutter_launcher_icons 配置，跳过图标生成。"
    fi

    if grep -Eq '^[[:space:]]*flutter_native_splash[[:space:]]*:' pubspec.yaml; then
      info_echo "正在构建 App 启动图"
      dart run flutter_native_splash:create || flutter pub run flutter_native_splash:create || { error_echo "启动图生成失败"; return 1; }
    else
      info_echo "未检测到 flutter_native_splash 配置，跳过启动图生成。"
    fi

    success_echo "构建步骤完成"
  }

  # =============================================================================
  # 验证生成的资源 + 自动打开目录
  # =============================================================================
  open_dir_if_exists() {
    local d="$1" label="$2"
    if [[ -d "$d" ]]; then
      if command -v open >/dev/null 2>&1; then
        open "$d" >/dev/null 2>&1 &
        success_echo "已在 Finder 打开：$label（$d）"
      else
        warn_echo "当前环境无 open 命令，路径：$d"
      fi
    else
      warn_echo "未找到目录：$label（$d）"
    fi
  }

  verify_outputs() {
    cd "$PROJECT_ROOT" || return

    local ios_icons_dir="$PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    local ios_launch_dir="$PROJECT_ROOT/ios/Runner/Assets.xcassets/LaunchImage.imageset"
    local android_res_dir="$PROJECT_ROOT/android/app/src/main/res"

    bold_echo "──────── 验证 iOS 资源 ────────"
    gray_echo "(iOS 相关的资源如下，如无输出则可能生成失败)"
    ls -1 "$ios_icons_dir"/*.png 2>/dev/null || true
    ls -1 "$ios_launch_dir"/* 2>/dev/null | grep -v 'Contents.json' || true

    bold_echo "──────── 验证 Android 资源 ────────"
    gray_echo "(Android 相关的资源如下，如无输出则可能生成失败)"
    ls -1 "$android_res_dir"/mipmap-*/ic_launcher.* 2>/dev/null || true

    # 自动打开三个目录（存在则打开）
    open_dir_if_exists "$ios_icons_dir"  "iOS 图标目录 AppIcon.appiconset"
    open_dir_if_exists "$ios_launch_dir" "iOS 启动图目录 LaunchImage.imageset"
    open_dir_if_exists "$android_res_dir" "Android 资源目录 res"

    success_echo "验证与打开目录步骤完成"
  }

  # =============================================================================
  # 主流程
  # =============================================================================
  main() {
    print_intro
    check_local_asset_dirs || return 1

    while true; do
      if ! prompt_project_root; then
        warn_echo "已取消。"
        break
      fi
      copy_assets_into_project || { error_echo "资源复制失败，回到循环。"; continue; }
      run_flutter_steps || { warn_echo "执行失败，回到循环。"; continue; }
      verify_outputs

      printf "是否再次处理其它项目？(y/N)："
      local again; safe_read again
      [[ "$again" == "y" || "$again" == "Y" ]] || { success_echo "全部完成，日志见：$LOG_FILE"; break; }
    done
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
