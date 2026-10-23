# Project workflow, loaded by the .command entrypoint. No work runs when sourced.
JOBS_HARMONY_REPO='https://gitcode.com/CPF-Flutter/flutter_flutter.git'
JOBS_HARMONY_REF='3.35.7+ohos-1.0.5'

# 同时输出业务状态和可搜索的纯文本日志。
jobs_note() {
  local message="$*" color='0;34'
  case "$message" in
    '✖'*) color='1;31' ;;
    '⚠'*) color='1;33' ;;
    '✔'*) color='1;32' ;;
    '━━━━━━━━━━ 来源'*) color='1;36' ;;
  esac
  if [[ -t 1 && -n "${TERM:-}" && "$TERM" != dumb && -z "${NO_COLOR+x}" ]]; then
    printf '\033[%sm%s\033[0m\n' "$color" "$message"
  else
    print -r -- "$message"
  fi
  [[ -z "${LOG_FILE:-}" ]] || print -r -- "$*" >> "$LOG_FILE"
  return 0
}
# 显示失败原因并返回失败，交由上层保留真实退出码。
jobs_error() {
  jobs_note "✖ $*" >&2
  return 1
}
# 保留标准输入给外部工具，把输出同步落盘且保留原始失败状态。
jobs_run() {
  if [[ -z "${LOG_FILE:-}" ]]; then
    "$@"
    return $?
  fi
  local -a results
  "$@" 2>&1 | /usr/bin/tee -a "$LOG_FILE"
  results=("${pipestatus[@]}")
  (( results[1] == 0 )) || return "${results[1]}"
  return "${results[2]}"
}
# 记录来源和目标后再开始下载，不把凭据或查询参数写入日志。
jobs_source() {
  local object="$1" url="$2" target="$3" safe=''
  safe="${url%%\?*}"
  safe="${safe%%\#*}"
  [[ "$safe" != *://*@* ]] || safe="${safe%%://*}://${safe#*@}"
  jobs_note '━━━━━━━━━━ 来源 ━━━━━━━━━━'
  jobs_note "对象：$object"
  jobs_note "来源地址：$safe"
  jobs_note "目标位置：$target"
}
# 输入只作为数据读取，EOF 必须取消，不能当成默认确认。
jobs_read() {
  print -u2 -n -r -- "$1"
  IFS= read -r REPLY || { jobs_error '输入结束，已取消。'; return 130; }
}
# 可选附加动作默认跳过。
jobs_optional() {
  jobs_read "$1（回车跳过；任意非空输入执行）：" || return 130
  [[ -n "$REPLY" ]]
}
# 解开 Finder 拖入路径的引号和反斜杠，不执行路径内命令。
jobs_normalize_path() {
  setopt LOCAL_OPTIONS EXTENDED_GLOB
  local value="$1"
  # zsh dequoting understands Finder's escaped spaces; it never evaluates commands.
  value="${value##[[:space:]]#}"
  value="${value%%[[:space:]]#}"
  value="${(Q)value}"
  [[ "$value" != '~/'* ]] || value="$HOME/${value#\~/}"
  [[ -n "$value" && "$value" != *[[:cntrl:]]* ]] || return 1
  print -r -- "${value:A}"
}
# 只接受可写现有工程，持续重试空输入并拒绝配置符号链接。
jobs_choose_project() {
  local supplied="${1:-}" candidate=""
  while true; do
    if [[ -z "$supplied" ]]; then
      jobs_read '拖入或输入 Flutter 工程根目录（不能为空；Ctrl+C 取消）：' || return $?
      supplied="$REPLY"
    fi
    candidate="$(jobs_normalize_path "$supplied")" || candidate=""
    if [[ -n "$candidate" && "$candidate" != / && "$candidate" != "${HOME:A}" &&
          -d "$candidate/lib" && -f "$candidate/pubspec.yaml" && -w "$candidate" ]]; then
      # Do not let a project symlink redirect configuration into a different project.
      local component
      for component in .fvm .jobs-flutter .vscode .gitignore .fvmrc ohos; do
        [[ ! -L "$candidate/$component" ]] || { jobs_error "工程配置不可为符号链接：$candidate/$component"; return 1; }
      done
      typeset -g PROJECT_ROOT="$candidate"
      jobs_note "✔ 目标工程：$PROJECT_ROOT"
      return 0
    fi
    jobs_note '请输入可写的 Flutter 工程根目录，须有 pubspec.yaml 和 lib/；不会因连续回车退出。'
    supplied=""
  done
}
# 参数与 JSON 交给本包配置模块处理，避免拼接可执行源码。
jobs_config() {
  "$JOBS_PYTHON_BIN" "$SCRIPT_DIR/Scripts/project_config.py" "$@"
}
# 固定鸿蒙来源，沿用可识别的鸿蒙版本；其它绑定须明确授权切换。
jobs_choose_sdk() {
  local current="" old_family="" old_ref="" default_ref="$JOBS_HARMONY_REF"
  current="$(jobs_config current "$PROJECT_ROOT")" || return 1
  old_family="${current%%$'\n'*}"
  [[ "$current" != *$'\n'* ]] || old_ref="${current#*$'\n'}"
  if [[ "$old_family" == harmony && -n "$old_ref" ]]; then
    default_ref="$old_ref"
  elif [[ -f "$PROJECT_ROOT/.fvmrc" || -f "$PROJECT_ROOT/.fvm/fvm_config.json" ]]; then
    jobs_note '工程已有其它 Flutter / 自定义 SDK 绑定；切换会改变此工程使用的 SDK，先保存源码。'
    jobs_read '精确输入 YES 切换本工程到鸿蒙适配 SDK；其它输入取消：' || return $?
    [[ "$REPLY" == YES ]] || return 130
  fi
  typeset -g JOBS_SDK_FAMILY=harmony JOBS_SDK_REPO="$JOBS_HARMONY_REPO" JOBS_INSTALL_MODE=fvm
  jobs_note "鸿蒙 SDK 来源：$JOBS_SDK_REPO"
  while true; do
    jobs_read "鸿蒙版本 / tag / 分支（回车=${default_ref}）：" || return $?
    JOBS_SDK_REF="${REPLY:-$default_ref}"
    if [[ "$JOBS_SDK_REF" =~ '^[a-zA-Z0-9][a-zA-Z0-9._+-]*$' && "$JOBS_SDK_REF" != *..* ]]; then
      break
    fi
    jobs_note '版本只接受英文字母、数字、点、下划线、加减号，不能包含连续点。'
  done
}
# 验证 FVM 与项目绑定能力，缺失时沿已验证 Homebrew 通道安装一次。
jobs_ensure_fvm() {
  typeset -g JOBS_FVM_BIN="$(command -v fvm 2>/dev/null)"
  if [[ -z "$JOBS_FVM_BIN" ]]; then
    jobs_source 'FVM（btwld/fvm tap）' 'https://github.com/btwld/homebrew-fvm' '当前 Homebrew 前缀'
    jobs_note '缺少 FVM，将通过官方文档列出的 btwld/fvm tap 安装独立 FVM。'
    jobs_read '回车安装 FVM；任意非空输入取消：' || return $?
    [[ -z "$REPLY" ]] || return 130
    jobs_run env HOMEBREW_NO_AUTO_UPDATE=1 "$JOBS_HOMEBREW_BIN" install btwld/fvm/fvm || return $?
    rehash
    JOBS_FVM_BIN="$(command -v fvm)" || return 1
  fi
  jobs_run "$JOBS_FVM_BIN" --version || { jobs_error "FVM 不健康：$JOBS_FVM_BIN；请修复后重试。"; return 1; }
  local help_text=""
  help_text="$("$JOBS_FVM_BIN" use --help)" || return $?
  [[ "$help_text" == *--skip-pub-get* && "$help_text" == *--skip-setup* ]] || {
    jobs_error 'FVM 版本过旧；请按 README 升级到支持项目配置的 FVM 3/4 后重试。'; return 1
  }
}
# Git 不弹出凭据交互，传输无进展时返回失败，不改全局 Git 配置。
jobs_git() {
  GIT_TERMINAL_PROMPT=0 /usr/bin/git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=60 "$@"
}
# 把明确 ref 解析成不可变 commit，拒绝不存在或同名 tag / 分支。
jobs_resolve_harmony_commit() {
  local remote="" sha="" ref="" tag="" peeled="" branch=""
  remote="$(jobs_git ls-remote "$JOBS_SDK_REPO" "refs/tags/$JOBS_SDK_REF" "refs/tags/$JOBS_SDK_REF^{}" "refs/heads/$JOBS_SDK_REF")" || return $?
  while IFS=$'\t' read -r sha ref; do
    case "$ref" in
      "refs/tags/$JOBS_SDK_REF") tag="$sha" ;;
      "refs/tags/$JOBS_SDK_REF^{}") peeled="$sha" ;;
      "refs/heads/$JOBS_SDK_REF") branch="$sha" ;;
    esac
  done <<< "$remote"
  [[ -z "$tag" || -z "$branch" ]] || { jobs_error '远端有同名 tag 与分支，请选无歧义的版本。'; return 1; }
  JOBS_SDK_COMMIT="${peeled:-${tag:-$branch}}"
  [[ "$JOBS_SDK_COMMIT" =~ '^[0-9a-f]{40}$' ]] || { jobs_error '远端不存在所选 ref，未下载 SDK。'; return 1; }
  JOBS_FVM_VERSION="custom_jobs_ohos_$JOBS_SDK_COMMIT"
}
# 原子发布完整 SDK，仅复用来源、commit 与源码状态均匹配的缓存。
jobs_clone_harmony() (
  setopt LOCAL_TRAPS
  local target="$JOBS_FVM_CACHE/versions/$JOBS_FVM_VERSION" stage="" actual="" origin="" dirty=""
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -d "$target/.git" && ! -L "$target" ]] || { jobs_error "缓存目标不是独立 Git SDK：$target"; return 1; }
    actual="$(jobs_git -C "$target" rev-parse HEAD)" || return 1
    origin="$(jobs_git -C "$target" remote get-url origin)" || return 1
    [[ "$actual" == "$JOBS_SDK_COMMIT" && "$origin" == "$JOBS_SDK_REPO" && -x "$target/bin/flutter" ]] || {
      jobs_error "已有缓存的来源或 commit 不符，不覆盖：$target"; return 1
    }
    dirty="$(jobs_git -C "$target" status --porcelain --untracked-files=no)" || {
      jobs_error "无法检查 SDK 缓存状态，不当作干净缓存复用：$target"; return 1
    }
    [[ -z "$dirty" ]] || {
      jobs_error "SDK 缓存有源码改动，不复用：$target"; return 1
    }
    return 0
  fi
  mkdir -p "$JOBS_FVM_CACHE/versions" || return 1
  stage="$(mktemp -d "$JOBS_FVM_CACHE/versions/.jobs-download.XXXXXX")" || return 1
  trap '[[ -z "$stage" ]] || rm -rf -- "$stage"' EXIT
  trap 'exit 130' INT TERM HUP
  # Flutter version detection needs complete refs/history; do not shallow clone.
  jobs_source "Flutter OH $JOBS_SDK_REF / $JOBS_SDK_COMMIT" "$JOBS_SDK_REPO" "$target"
  jobs_run jobs_git clone --no-checkout "$JOBS_SDK_REPO" "$stage/sdk" || return $?
  jobs_run jobs_git -C "$stage/sdk" checkout --detach "$JOBS_SDK_COMMIT" || return $?
  [[ -x "$stage/sdk/bin/flutter" ]] || { jobs_error '下载内容缺少 Flutter 入口。'; return 1; }
  # Atomic, no-clobber publication. Never merge into an existing SDK directory.
  "$JOBS_PYTHON_BIN" - "$stage/sdk" "$target" <<'PY'
import os, sys
if os.path.lexists(sys.argv[2]):
    raise SystemExit('SDK 目标已被其它进程创建，请重试')
os.rename(sys.argv[1], sys.argv[2])
PY
)
# 只绑定项目 FVM，不执行 fvm global 或写 Flutter 全局 PATH。
jobs_setup_sdk_impl() {
  cd -- "$PROJECT_ROOT" || return 1
  JOBS_FVM_CACHE="$HOME/Library/Caches/JobsFlutter/fvm/$JOBS_SDK_FAMILY"
  JOBS_SDK_COMMIT=""
  JOBS_FVM_VERSION="$JOBS_SDK_REF"
  jobs_source "Flutter OH $JOBS_SDK_REF" "$JOBS_SDK_REPO" "$JOBS_FVM_CACHE"
  jobs_resolve_harmony_commit || return $?
  jobs_note "核实 commit：$JOBS_SDK_COMMIT"
  jobs_note "将下载 / 复用 $JOBS_SDK_FAMILY：$JOBS_SDK_REF；模式：$JOBS_INSTALL_MODE"
  jobs_note "FVM 缓存：$JOBS_FVM_CACHE；工程：$PROJECT_ROOT"
  jobs_read '回车确认本次 SDK 准备；任意非空输入取消：' || return $?
  [[ -z "$REPLY" ]] || return 130
  jobs_config fvm "$PROJECT_ROOT" "$JOBS_FVM_CACHE" "$JOBS_SDK_REPO" || return $?
  # Explicit environment agrees with project config, overriding inherited FVM globals.
  export FVM_CACHE_PATH="$JOBS_FVM_CACHE" FVM_FLUTTER_URL="$JOBS_SDK_REPO" FVM_USE_GIT_CACHE=false
  jobs_clone_harmony || return $?
  # use installs missing versions itself. Installing stable first would duplicate the pinned SDK.
  jobs_config binding-check "$PROJECT_ROOT" || return $?
  jobs_run "$JOBS_FVM_BIN" use "$JOBS_FVM_VERSION" --skip-setup --skip-pub-get || return $?
  [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]] || { jobs_error 'FVM 未生成可用的工程 SDK 链接。'; return 1; }
  JOBS_SDK_PATH="${PROJECT_ROOT}/.fvm/flutter_sdk"
  JOBS_SDK_PATH="${JOBS_SDK_PATH:A}"
  [[ "$JOBS_SDK_PATH" == "${JOBS_FVM_CACHE:A}/versions/"* ]] || { jobs_error 'FVM 链接未指向所选隔离缓存。'; return 1; }
  JOBS_FVM_VERSION="${JOBS_SDK_PATH:t}"
  JOBS_SDK_COMMIT="$(jobs_git -C "$JOBS_SDK_PATH" rev-parse HEAD)" || return $?
  jobs_run "$JOBS_SDK_PATH/bin/flutter" --version || return $?
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then
    local build_help=""
    build_help="$("$JOBS_SDK_PATH/bin/flutter" build -h)" || return $?
    [[ "$build_help" == *hap* ]] || { jobs_error '所选 Flutter 未提供 build hap，停止鸿蒙配置。'; return 1; }
  fi
}
# SDK 准备失败时恢复原工程绑定，下载缓存留作诊断和重试。
jobs_restore_binding() {
  jobs_config binding-restore "$PROJECT_ROOT" "$JOBS_BINDING_BACKUP" || return 1
  jobs_note '已恢复本次操作前的 .fvmrc、FVM 元数据和 SDK 链接；下载缓存及备份保留。'
}
# 恢复失败保留完整快照，只有已完成恢复或成功绑定才移除临时快照。
jobs_finish_binding() {
  local result="$1"
  if (( result != 0 )) && ! jobs_restore_binding; then
    jobs_note "⚠ 自动恢复失败，完整恢复快照已保留：$JOBS_BINDING_BACKUP"
    return "$result"
  fi
  rm -rf -- "$JOBS_BINDING_BACKUP"
  return "$result"
}
# 在下载与 FVM 改写前留存绑定快照，并处理信号中断。
jobs_setup_sdk() {
  setopt LOCAL_TRAPS
  local JOBS_BINDING_BACKUP="" result=0
  JOBS_BINDING_BACKUP="$(mktemp -d "${TMPDIR:-/tmp}/JobsFlutterBinding.XXXXXX")" || return 1
  if ! jobs_config binding-save "$PROJECT_ROOT" "$JOBS_BINDING_BACKUP"; then
    rm -rf -- "$JOBS_BINDING_BACKUP"
    return 1
  fi
  # `return` in a zsh signal trap can make the interrupted caller report success.
  # Cancellation must terminate the script after exactly one recovery attempt.
  trap 'trap "" INT TERM HUP; jobs_finish_binding 130; exit 130' INT TERM HUP
  jobs_setup_sdk_impl || result=$?
  jobs_finish_binding "$result"
}
# 复用随包参考实现，分别准备真机工具或模拟器工具及镜像。
jobs_prepare_harmony() {
  emulate -L zsh
  setopt PIPE_FAIL NO_NOMATCH
  source "$SCRIPT_DIR/Scripts/CreateHarmonySimulator.zsh" || return $?
  hs_show_intro
  hs_check_host || return $?
  hs_initialize_log || return $?
  jobs_read '鸿蒙工具：回车准备工具及镜像；输入 device 仅准备工具（使用真机）；其它输入取消：' || return $?
  typeset -g JOBS_DEVICE_MODE="$REPLY"
  case "$REPLY" in
    '') hs_prepare_environment || return $? ;;
    device)
      # Reuse discovery/download logic without downloading a simulator system image.
      hs_find_emulator || {
        if (( HS_CAN_BOOTSTRAP )); then hs_install_clt || return $?;
        else hs_preparation_prompt tools || return $?; hs_find_emulator || return $?; fi
      }
      ;;
    *) return 130 ;;
  esac
  [[ -n "$HS_BIN" ]] || { jobs_error '鸿蒙工具准备未完成。'; return 1; }
  local root="${HS_BIN:h:h}"
  [[ "${root:t}" != tools ]] || root="${root:h}"
  typeset -g JOBS_TOOL_ROOT="$root"
  jobs_harmony_environment || return $?
  [[ "$JOBS_DEVICE_MODE" != device ]] || return 0
  local optional_result=0
  jobs_optional '是否新建并启动一个鸿蒙模拟器' || optional_result=$?
  (( optional_result != 130 )) || return 130
  if (( optional_result == 0 )); then
    hs_query_state || return $?
    (( ${#HS_ROWS[@]} )) || hs_install_image || return $?
    hs_select_image || return $?
    hs_create_and_verify || return $?
  fi
  return 0
}
# 同时核实编译器与运行时的 17 主版本，避免继承旧 JDK 后延迟到构建才失败。
jobs_java_17_ok() {
  local java_home="$1" compiler='' runtime=''
  [[ -x "$java_home/bin/java" && -x "$java_home/bin/javac" ]] || return 1
  compiler="$("$java_home/bin/javac" -version 2>&1)" || return 1
  runtime="$("$java_home/bin/java" -version 2>&1)" || return 1
  [[ "$compiler" == 'javac 17' || "$compiler" == 'javac 17.'* ]] || return 1
  [[ "$runtime" == *'version "17"'* || "$runtime" == *'version "17.'* || "$runtime" == 'openjdk 17 '* || "$runtime" == 'openjdk 17.'* ]]
}
# 发现匹配 SDK 的构建工具并逐项健康检查，仅激活当前进程环境。
jobs_harmony_environment() {
  local root="$JOBS_TOOL_ROOT" node="" ohpm="" hvigor="" item="" java="${JAVA_HOME:-}"
  [[ -x "$root/sdk/default/openharmony/toolchains/hdc" &&
     -d "$root/sdk/default/openharmony/ets" && -d "$root/sdk/default/openharmony/native" ]] || {
    jobs_error "所选工具包缺少 SDK / HDC / ETS / native：$root"; return 1
  }
  for item in "$root/tools/node/bin" "$root/tool/node/bin"; do [[ ! -x "$item/node" ]] || node="$item"; done
  for item in "$root/tools/ohpm/bin" "$root/ohpm/bin"; do [[ ! -x "$item/ohpm" ]] || ohpm="$item"; done
  for item in "$root/tools/hvigor/bin" "$root/hvigor/bin"; do [[ ! -f "$item/hvigorw" && ! -f "$item/hvigor" ]] || hvigor="$item"; done
  [[ -n "$node" && -n "$ohpm" && -n "$hvigor" ]] || { jobs_error '缺少同包 Node / ohpm / Hvigor。'; return 1; }
  if [[ -z "$java" ]]; then
    for item in "$root/jbr/Contents/Home" "$root/jbr" "$root/jre/Contents/Home"; do
      jobs_java_17_ok "$item" && { java="$item"; break; }
    done
    [[ -n "$java" ]] || java="$(/usr/libexec/java_home -v 17 2>/dev/null)"
  fi
  if ! jobs_java_17_ok "$java"; then
    jobs_note "JDK 未就绪（当前候选：${java:-无}）；默认基线需要 JDK 17。"
    jobs_read '回车通过 Homebrew 准备 openjdk@17；或输入已有 JDK 根目录；q 取消：' || return $?
    case "$REPLY" in
      '')
        local prefix=''
        jobs_source 'openjdk@17' 'https://formulae.brew.sh/formula/openjdk@17' '当前 Homebrew 前缀'
        if ! prefix="$("$JOBS_HOMEBREW_BIN" --prefix openjdk@17 2>/dev/null)" || ! jobs_java_17_ok "$prefix/libexec/openjdk.jdk/Contents/Home"; then
          jobs_run env HOMEBREW_NO_AUTO_UPDATE=1 "$JOBS_HOMEBREW_BIN" install openjdk@17 || return $?
          prefix="$("$JOBS_HOMEBREW_BIN" --prefix openjdk@17)" || return $?
        fi
        java="$prefix/libexec/openjdk.jdk/Contents/Home"
        ;;
      q|Q) return 130 ;;
      *) java="$(jobs_normalize_path "$REPLY")" || return 1 ;;
    esac
  fi
  jobs_java_17_ok "$java" || { jobs_error "JDK 安装或选择后仍不是健康 JDK 17：$java"; return 1; }
  typeset -g JOBS_JAVA_HOME="$java"
  export TOOL_HOME="$root" DEVECO_SDK_HOME="$root/sdk" HOS_SDK_HOME="$root/sdk" OHOS_SDK_HOME="$root/sdk" OHOS_HOME="$root/sdk"
  export HDC_HOME="$root/sdk/default/openharmony/toolchains" JAVA_HOME="$java"
  export PATH="$node:$ohpm:$hvigor:$HDC_HOME:$JAVA_HOME/bin:$PATH"
  jobs_run "$node/node" --version || return $?
  jobs_run "$ohpm/ohpm" --version || return $?
  jobs_run "$JAVA_HOME/bin/java" -version || return $?
  jobs_run "$JAVA_HOME/bin/javac" -version || return $?
  jobs_run "$HDC_HOME/hdc" -v || return $?
  typeset -g JOBS_HVIGOR_BIN="$hvigor/hvigorw"
  [[ -f "$JOBS_HVIGOR_BIN" ]] || JOBS_HVIGOR_BIN="$hvigor/hvigor"
  typeset -g JOBS_OHPM_BIN="$ohpm/ohpm"
  jobs_note "✔ 鸿蒙构建工具路径已在当前进程激活：$root"
}
# 不启动 SDK 或网络工具的离线盘点，缺失项返回失败而不是伪报已就绪。
jobs_readonly_check() {
  local project="${1:-}" candidate='' root='' missing=0 found=0 item=''
  [[ "$(/usr/bin/uname -s)" == Darwin && "$(/usr/bin/uname -m)" == arm64 ]] || { jobs_note '⚠ 宿主需要原生 Apple Silicon macOS。'; missing=1; }
  for item in brew fvm; do
    candidate="$(command -v "$item" 2>/dev/null)"
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      jobs_note "候选 $item：$candidate（未执行健康检查）"
    else
      jobs_note "⚠ PATH 中缺少 $item；正常运行时再检查标准位置并准备。"
      missing=1
    fi
  done
  if [[ -n "${HARMONY_EMULATOR_BIN:-}" ]]; then
    candidate="$HARMONY_EMULATOR_BIN"
    [[ -x "$candidate" ]] && found=1
  else
    for root in "${DEVECO_STUDIO_HOME:-}" "${TOOL_HOME:-}" /Applications/DevEco-Studio.app "$HOME/Applications/DevEco-Studio.app" "$HOME/Library/Application Support/JobsHarmonySimulator"/clt-*(N); do
      [[ -n "$root" ]] || continue
      for candidate in "$root/Contents/tools/emulator/Emulator" "$root/tools/emulator/Emulator" "$root/emulator/Emulator"; do
        [[ -x "$candidate" ]] || continue
        jobs_note "Emulator 候选：$candidate（未执行或接受许可）"
        found=1
      done
    done
  fi
  (( found )) || { jobs_note '⚠ 未发现所选 DevEco / CLT Emulator；正常运行可准备工具。'; missing=1; }
  if [[ -n "$project" ]]; then
    project="$(jobs_normalize_path "$project")" || return 1
    [[ -f "$project/pubspec.yaml" && -d "$project/lib" ]] || { jobs_error "不是现有 Flutter 工程：$project"; return 1; }
    jobs_note "工程：$project"
    [[ -f "$project/ohos/build-profile.json5" && -f "$project/ohos/oh-package.json5" ]] || { jobs_note '⚠ 缺少完整 ohos/ 平台标记；需本人确认生成或修复。'; missing=1; }
    [[ -x "$project/.fvm/flutter_sdk/bin/flutter" ]] || { jobs_note '⚠ 未发现可用项目 FVM SDK 入口。'; missing=1; }
  fi
  jobs_note '离线盘点结束；SDK 版本能力、JDK、插件、签名和设备连接仍需正常流程验证。'
  return "$missing"
}
# 在平台目录内执行构建工具，保持外层工程工作目录。
jobs_run_in_ohos() (
  cd -- "$PROJECT_ROOT/ohos" || return 1
  jobs_run "$@"
)
# 保留已有平台与签名；缺目录只有精确 YES 才生成，再准备两侧依赖。
jobs_prepare_project() {
  local flutter="$JOBS_SDK_PATH/bin/flutter"
  typeset -g JOBS_PLATFORM_READY=0
  if [[ ! -e "$PROJECT_ROOT/ohos" ]]; then
    jobs_note '工程没有 ohos/；生成平台会修改工程元数据、包名模板与平台文件。'
    jobs_read '精确输入 YES 执行 flutter create --platforms=ohos .；其它输入仅准备环境：' || return $?
    if [[ "$REPLY" == YES ]]; then
      jobs_run "$flutter" create --platforms=ohos . || return $?
    else
      jobs_note '仅完成环境准备，未生成 ohos/，不会解析原生依赖或运行。'
    fi
  fi
  jobs_config runtime "$PROJECT_ROOT" harmony "$JOBS_SDK_REF" "$JOBS_FVM_VERSION" \
    "$JOBS_SDK_COMMIT" "$JOBS_SDK_PATH" "$JOBS_TOOL_ROOT" "$JOBS_JAVA_HOME" || return $?
  jobs_run "$flutter" doctor -v || jobs_note '⚠ doctor 存在未就绪项；其它平台告警可忽略，鸿蒙错误仍须解决。'
  [[ -e "$PROJECT_ROOT/ohos" ]] || return 0
  [[ -d "$PROJECT_ROOT/ohos" && ! -L "$PROJECT_ROOT/ohos" && -f "$PROJECT_ROOT/ohos/build-profile.json5" && -f "$PROJECT_ROOT/ohos/oh-package.json5" ]] || {
    jobs_error '已有 ohos/ 结构不完整；保留原文件，请在 DevEco 修复，不重新生成覆盖。'; return 1
  }
  jobs_run "$flutter" pub get || return $?
  jobs_run_in_ohos "$JOBS_OHPM_BIN" install || return $?
  jobs_run_in_ohos "$JOBS_HVIGOR_BIN" --version || { jobs_error 'Hvigor 健康检查失败，请核对工程插件和配套工具版本。'; return 1; }
  JOBS_PLATFORM_READY=1
}
# 设备列表来自当前鸿蒙 SDK，空列表提供重试或创建入口，运行失败原样上报。
jobs_select_and_run() {
  (( JOBS_PLATFORM_READY )) || return 0
  local answer='' devices='' rows='' selected='' i=1
  local -a choices
  jobs_read '回车选择鸿蒙设备并运行；任意非空输入仅完成配置：' || return $?
  [[ -z "$REPLY" ]] || { jobs_note '工程已配置，按选择暂未运行。'; return 0; }
  while true; do
    devices="$("$JOBS_SDK_PATH/bin/flutter" devices --machine)" || { jobs_error '设备查询失败，请核对 HDC / Flutter SDK；可重新运行入口。'; return 1; }
    rows="$(print -r -- "$devices" | jobs_config devices harmony)" || return $?
    if [[ -z "$rows" ]]; then
      jobs_note '暂无鸿蒙设备。请启动已有模拟器，或连接真机并在设备上允许调试。'
      jobs_read '回车重新加载；s 新建并启动模拟器；q 仅完成配置：' || return $?
      case "$REPLY" in
        '') continue ;;
        s|S) hs_prepare_environment && hs_select_image && hs_create_and_verify || return $?; continue ;;
        q|Q) jobs_note '工程已配置，尚未在设备运行。'; return 0 ;;
        *) jobs_note '请输入回车、s 或 q。'; continue ;;
      esac
    fi
    choices=("${(@f)rows}")
    i=1
    for selected in "${choices[@]}"; do
      jobs_note "$i、$selected"
      (( i += 1 ))
    done
    jobs_read '鸿蒙设备编号（回车=1；r 重新加载；q 仅配置）：' || return $?
    answer="${REPLY:-1}"
    case "$answer" in
      r|R) continue ;;
      q|Q) jobs_note '工程已配置，尚未在设备运行。'; return 0 ;;
    esac
    [[ "$answer" == <-> ]] && (( answer >= 1 && answer <= ${#choices[@]} )) || { jobs_note '设备编号无效，请重新选择。'; continue; }
    selected="${choices[$answer]%%$'\t'*}"
    jobs_note "运行目标：$selected；首次签名请在 DevEco 配置，r 热重载，q 停止 Flutter。"
    # run 需要真实终端处理热重载，不接管它的 stdin / stdout。
    if [[ -n "${JOBS_LOG_DIR:-}" && -x /usr/bin/script ]]; then
      /usr/bin/script -q "$JOBS_LOG_DIR/run.typescript" "$PROJECT_ROOT/.jobs-flutter/flutter" run -d "$selected"
    else
      "$PROJECT_ROOT/.jobs-flutter/flutter" run -d "$selected"
    fi
    local result=$?
    jobs_note "Flutter 运行会话结束，退出码：$result；交互记录：${JOBS_LOG_DIR:-终端}/run.typescript"
    return "$result"
  done
}
# 按依赖顺序准备项目工具与 SDK，最终状态区分仅配置和实际运行。
jobs_workflow() {
  jobs_choose_project "${1:-}" || return $?
  jobs_python_mark_confirmed
  jobs_python_ensure 3.11 python@3.13 || return $?
  jobs_choose_sdk || return $?
  jobs_ensure_fvm || return $?
  jobs_prepare_harmony || return $?
  jobs_setup_sdk || return $?
  jobs_prepare_project || return $?
  jobs_select_and_run || return $?
  jobs_note "✔ 工程环境已保存：$PROJECT_ROOT/.jobs-flutter/flutter"
  jobs_note '后续可用 .jobs-flutter/flutter devices / run / build hap --debug；能否安装由实际签名和设备结果决定。'
}
