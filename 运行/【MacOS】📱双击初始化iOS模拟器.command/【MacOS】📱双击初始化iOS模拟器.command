#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】📱双击初始化iOS模拟器.command
# - 核心用途：执行“📱双击初始化iOS模拟器”对应的移动端项目自动化任务。
# - 影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。
# - 运行提示：运行后会先打印内置自述；终端模式按回车确认后继续，按 Ctrl+C 可取消。

# ✅ 日志输出函数
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径
# 按当前输出级别记录终端信息，并同步写入脚本日志。
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
# 按当前输出级别记录终端信息，并同步写入脚本日志。
color_echo()     { log "\033[1;32m$1\033[0m"; }         # ✅ 正常绿色输出
# 按当前输出级别记录终端信息，并同步写入脚本日志。
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }       # ℹ 信息
# 按当前输出级别记录终端信息，并同步写入脚本日志。
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }       # ✔ 成功
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }       # ⚠ 警告
# 按当前输出级别记录终端信息，并同步写入脚本日志。
warm_echo()      { log "\033[1;33m$1\033[0m"; }         # 🟡 温馨提示（无图标）
# 按当前输出级别记录终端信息，并同步写入脚本日志。
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }       # ➤ 说明
# 按当前输出级别记录终端信息，并同步写入脚本日志。
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }       # ✖ 错误
# 按当前输出级别记录终端信息，并同步写入脚本日志。
err_echo()       { log "\033[1;31m$1\033[0m"; }         # 🔴 错误纯文本
# 按当前输出级别记录终端信息，并同步写入脚本日志。
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }      # 🐞 调试
# 按当前输出级别记录终端信息，并同步写入脚本日志。
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }      # 🔹 高亮
# 按当前输出级别记录终端信息，并同步写入脚本日志。
gray_echo()      { log "\033[0;90m$1\033[0m"; }         # ⚫ 次要信息
# 按当前输出级别记录终端信息，并同步写入脚本日志。
bold_echo()      { log "\033[1m$1\033[0m"; }            # 📝 加粗
# 按当前输出级别记录终端信息，并同步写入脚本日志。
underline_echo() { log "\033[4m$1\033[0m"; }            # 🔗 下划线
# ✅ 自述信息
print_banner() {
  highlight_echo "═════════════════════════════════════════════════════════════════════"
  highlight_echo "📱 iOS 模拟器创建器 - 使用 fzf 选择设备与系统版本"
  highlight_echo "═════════════════════════════════════════════════════════════════════"
}
# ✅ 彻底关闭所有模拟器
shutdown_simulators() {
  warn_echo "🛑 正在彻底关闭所有 iOS 模拟器..."
  xcrun simctl shutdown all >/dev/null 2>&1
  osascript -e 'quit app "Simulator"' >/dev/null 2>&1
  sleep 1
  pgrep -f Simulator >/dev/null && pkill -f Simulator && success_echo "已彻底关闭模拟器" || success_echo "模拟器已关闭"
}
# ✅ 单行写文件（避免重复写入）
inject_shellenv_block() {
    local id="$1"           # 参数1：环境变量块 ID，如 "homebrew_env"
    local shellenv="$2"     # 参数2：实际要写入的 shellenv 内容，如 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    local header="# >>> ${id} 环境变量 >>>"  # 自动生成注释头

    # 参数校验
    if [[ -z "$id" || -z "$shellenv" ]]; then
    error_echo "❌ 缺少参数：inject_shellenv_block <id> <shellenv>"
    return 1
    fi

    # 若用户未选择该 ID，则跳过写入
    if [[ ! " ${selected_envs[*]} " =~ " $id " ]]; then
    warn_echo "⏭️ 用户未选择写入环境：$id，跳过"
    return 0
    fi

    # 避免重复写入
    if grep -Fq "$header" "$PROFILE_FILE"; then
      info_echo "📌 已存在 header：$header"
    elif grep -Fq "$shellenv" "$PROFILE_FILE"; then
      info_echo "📌 已存在 shellenv：$shellenv"
    else
      echo "" >> "$PROFILE_FILE"
      echo "$header" >> "$PROFILE_FILE"
      echo "$shellenv" >> "$PROFILE_FILE"
      success_echo "✅ 已写入：$header"
    fi

    # 当前 shell 生效
    eval "$shellenv"
    success_echo "🟢 shellenv 已在当前终端生效"
}
# ✅ 判断芯片架构（ARM64 / x86_64）
get_cpu_arch() {
  [[ $(uname -m) == "arm64" ]] && echo "arm64" || echo "x86_64"
}
# ✅ 自检安装 🍺 Homebrew（自动架构判断）
install_homebrew() {
  local arch="$(get_cpu_arch)"                   # 获取当前架构（arm64 或 x86_64）
  local shell_path="${SHELL##*/}"                # 获取当前 shell 名称（如 zsh、bash）
  local profile_file=""
  local brew_bin=""
  local shellenv_cmd=""
  local user_input=""

  if ! command -v brew &>/dev/null; then
    warn_echo "🧩 未检测到 Homebrew，正在安装中...（架构：$arch）"

    if [[ "$arch" == "arm64" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（arm64）"
        exit 1
      }
      brew_bin="/opt/homebrew/bin/brew"
    else
      arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error_echo "❌ Homebrew 安装失败（x86_64）"
        exit 1
      }
      brew_bin="/usr/local/bin/brew"
    fi

    success_echo "✅ Homebrew 安装成功"

    # ==== 注入 shellenv 到对应配置文件（自动生效） ====
    shellenv_cmd="eval \"\$(${brew_bin} shellenv)\""

    case "$shell_path" in
      zsh)   profile_file="$HOME/.zprofile" ;;
      bash)  profile_file="$HOME/.bash_profile" ;;
      *)     profile_file="$HOME/.profile" ;;
    esac

    PROFILE_FILE="$profile_file"
    selected_envs=("homebrew_env")
    inject_shellenv_block "homebrew_env" "$shellenv_cmd"

  else
    echo ""
    note_echo "📦 检测到 Homebrew 已安装"
    gray_echo "直接回车：跳过更新"
    gray_echo "输入任意字符后回车：执行更新升级"
    read "?👉 是否更新 Homebrew：" user_input

    if [[ -n "$user_input" ]]; then
      info_echo "🔄 开始更新 Homebrew..."
      brew update && brew upgrade && brew cleanup && brew doctor && brew -v
      success_echo "✅ Homebrew 已更新"
    else
      warn_echo "⏭️ 已跳过 Homebrew 更新"
    fi
  fi
}
# ✅ 自检安装 Homebrew.fzf
install_fzf() {
  local user_input=""

  if ! command -v fzf &>/dev/null; then
    note_echo "📦 未检测到 fzf，正在通过 Homebrew 安装..."
    brew install fzf || { error_echo "❌ fzf 安装失败"; exit 1; }
    success_echo "✅ fzf 安装成功"
  else
    echo ""
    note_echo "📦 检测到 fzf 已安装"
    gray_echo "直接回车：跳过更新"
    gray_echo "输入任意字符后回车：执行更新升级"
    read "?👉 是否更新 fzf：" user_input

    if [[ -n "$user_input" ]]; then
      info_echo "🔄 开始升级 fzf..."
      brew upgrade fzf && brew cleanup
      success_echo "✅ fzf 已是最新版"
    else
      warn_echo "⏭️ 已跳过 fzf 更新"
    fi
  fi
}
# 收集并校验用户输入，决定后续执行路径。
select_device_type() {
  info_echo "📦 获取可用设备类型..."
  device_options=("${(@f)$(xcrun simctl list devicetypes | grep '^iPhone' | sed -E 's/^(.+) \((.+)\)$/📱 \1|\2/')}")
  [[ ${#device_options[@]} -eq 0 ]] && error_echo "❌ 未找到设备类型" && exit 1

  selected_device_display=$(printf "%s\n" "${device_options[@]}" | cut -d'|' -f1 | fzf --prompt="👉 选择设备型号 > " --height=40% --reverse)
  [[ -z "$selected_device_display" ]] && warn_echo "⚠️ 未选择设备，正在退出..." && exit 0

  for entry in "${device_options[@]}"; do
    [[ "${entry%%|*}" == "$selected_device_display" ]] && selected_device_id="${entry##*|}" && break
  done

  success_echo "✔ 你选择的设备是：$selected_device_display"
  success_echo "🔗 设备 ID：$selected_device_id"
}
# 收集并校验用户输入，决定后续执行路径。
select_runtime() {
  info_echo "🧬 获取可用系统版本..."

  runtime_options=()
  typeset -A seen_runtime_displays

  local runtime_display=""
  local runtime_id=""
  local entry=""
  local duplicate_runtime_count=0

  # xcrun simctl list runtimes 有时会返回多个 Runtime 记录，但展示名同为 “iOS x.y”。
  # 原脚本只把展示名交给 fzf，所以会出现同一个系统版本显示两次。
  # 这里按展示名去重，保留第一条可用 Runtime ID。
  while IFS='|' read -r runtime_display runtime_id; do
    [[ -z "$runtime_display" || -z "$runtime_id" ]] && continue

    if [[ -n "${seen_runtime_displays[$runtime_display]}" ]]; then
      duplicate_runtime_count=$((duplicate_runtime_count + 1))
      continue
    fi

    seen_runtime_displays[$runtime_display]=1
    runtime_options+=("${runtime_display}|${runtime_id}")
  done < <(
    xcrun simctl list runtimes |
      grep "iOS" |
      grep -v "unavailable" |
      sed -En 's/^.*(iOS [0-9.]+) \([^)]+\) - (com\.apple\.CoreSimulator\.SimRuntime\.iOS-[^[:space:]]+).*$/🧬 \1|\2/p'
  )

  [[ ${#runtime_options[@]} -eq 0 ]] && error_echo "❌ 未找到 Runtime" && exit 1

  if [[ $duplicate_runtime_count -gt 0 ]]; then
    gray_echo "已自动去重 ${duplicate_runtime_count} 条重复系统版本"
  fi

  if [[ ${#runtime_options[@]} -eq 1 ]]; then
    selected_runtime_display="${runtime_options[1]%%|*}"
    selected_runtime_id="${runtime_options[1]##*|}"
    success_echo "✔ 仅检测到一个可用系统版本，已自动选择：$selected_runtime_display"
    success_echo "🔗 Runtime ID：$selected_runtime_id"
    return 0
  fi

  selected_runtime_display=$(printf "%s\n" "${runtime_options[@]}" | cut -d'|' -f1 | fzf --prompt="👉 选择系统版本 > " --height=40% --reverse)
  [[ -z "$selected_runtime_display" ]] && warn_echo "⚠️ 未选择系统版本，正在退出..." && exit 0

  for entry in "${runtime_options[@]}"; do
    [[ "${entry%%|*}" == "$selected_runtime_display" ]] && selected_runtime_id="${entry##*|}" && break
  done

  success_echo "✔ 你选择的系统版本是：$selected_runtime_display"
  success_echo "🔗 Runtime ID：$selected_runtime_id"
}
# 封装 create_and_boot_simulator 对应的独立处理逻辑。
create_and_boot_simulator() {
  device_name="${selected_device_display#📱 }"
  datetime=$(date "+%Y.%m.%d %H:%M:%S")
  sim_name="${device_name}@${datetime}"
  info_echo "🚀 正在创建模拟器 $sim_name ..."
  sim_create_output=$(xcrun simctl create "$sim_name" "$selected_device_id" "$selected_runtime_id" 2>&1)

  if [[ "$sim_create_output" == *"Unable to create a device for device type"* ]]; then
    error_echo "❌ 创建失败：该组合不受支持"
    note_echo "💡 设备：$device_name"
    note_echo "💡 系统：${selected_runtime_display#🧬 }"
    warm_echo "🔁 请重新选择有效组合..."
    sleep 2
    return 1
  elif [[ -z "$sim_create_output" ]]; then
    error_echo "❌ 模拟器创建失败（未知错误）"
    sleep 1
    return 1
  else
    sim_id="$sim_create_output"
    success_echo "✔ 模拟器创建成功：$sim_name"
    success_echo "🆔 模拟器 ID：$sim_id"
    info_echo "🚀 启动模拟器中..."
    xcrun simctl boot "$sim_id" >/dev/null 2>&1
    open -a Simulator
    success_echo "✅ 模拟器已打开：$sim_name"
    return 0
  fi
}
# ✅ 启动交互式模拟器创建循环
interactive_simulator_creation_loop() {
  while true; do
    echo ""
    note_echo "📌 如果你想复制上面命令，请现在复制完再按回车继续..."
    read "?⏸️ 按回车继续选择设备和系统："

    select_device_type                      # ✅ 选择设备型号
    echo ""
    select_runtime                          # ✅ 选择系统版本
    echo ""

    create_and_boot_simulator && break      # ✅ 创建成功则退出循环，否则重新选择
  done
}
# 打印脚本内置自述，并按运行入口决定是否等待用户确认。
show_script_intro_and_wait() {
  print -r -- '============================== 脚本内置自述 =============================='
  print -r -- '脚本名称：【MacOS】📱双击初始化iOS模拟器.command'
  print -r -- '核心用途：执行“📱双击初始化iOS模拟器”对应的移动端项目自动化任务。'
  print -r -- '影响范围：可能修改项目依赖、生成文件、构建产物或开发工具配置。'
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。'
  print -r -- '============================================================================'
  if [[ ! -t 0 ]]; then
    print -u2 -r -- '当前没有可交互输入，请在终端中重新运行。'
    return 1
  fi
  read -r "?👉 已了解脚本用途与影响，按回车继续；按 Ctrl+C 取消：" _
}
# 编排脚本的高层业务流程。
main() {
  # 展示脚本内置自述，并按运行入口完成防误触确认。
  show_script_intro_and_wait
  # 执行 print_banner 对应的独立业务步骤。
  print_banner
  # 执行 shutdown_simulators 对应的独立业务步骤。
  shutdown_simulators
  # 执行 install_homebrew 对应的核心业务步骤。
  install_homebrew
  # 执行 install_fzf 对应的核心业务步骤。
  install_fzf
  # 执行 interactive_simulator_creation_loop 对应的独立业务步骤。
  interactive_simulator_creation_loop
}

main "$@"
