# Project workflow, loaded by the .command entrypoint. No work runs when sourced.
JOBS_OFFICIAL_REPO='https://github.com/flutter/flutter.git'
JOBS_HARMONY_REPO='https://gitcode.com/CPF-Flutter/flutter_flutter.git'
JOBS_HARMONY_REF='3.35.7+ohos-1.0.5'

jobs_note() { print -r -- "$*"; [[ -z "${LOG_FILE:-}" ]] || print -r -- "$*" >> "$LOG_FILE"; return 0; }
jobs_error() { jobs_note "✖ $*" >&2; return 1; }
jobs_read() {
  print -u2 -n -r -- "$1"
  IFS= read -r REPLY || { jobs_error '输入结束，已取消。'; return 130; }
}
jobs_optional() {
  jobs_read "$1（回车跳过；任意非空输入执行）：" || return 130
  [[ -n "$REPLY" ]]
}
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
jobs_choose_install_mode() {
  typeset -g JOBS_INSTALL_MODE=fvm
  typeset -g +x JOBS_GLOBAL_AUTHORIZED=0
  jobs_note 'Flutter SDK 默认由 FVM 管理，只绑定所选工程，不向 Shell 配置写 Flutter PATH。'
  jobs_note '如需让它成为当前用户所有终端的默认 Flutter，请精确输入大写 YES。'
  jobs_note 'YES 将使用 FVM global 并写入 ~/.zprofile；这会影响该用户的全局 Flutter。'
  jobs_read '安装方式（YES=全局；回车或其它任何输入=项目 FVM）：' || return $?
  if [[ "$REPLY" == YES ]]; then
    JOBS_INSTALL_MODE=global
    JOBS_GLOBAL_AUTHORIZED=1
  fi
}
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
      for component in .fvm .jobs-flutter .vscode .gitignore .fvmrc; do
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
jobs_config() { "$JOBS_PYTHON_BIN" "$SCRIPT_DIR/Scripts/project_config.py" "$@"; }
jobs_choose_sdk() {
  local current="" old_family=official old_ref="" choice="" default_ref=""
  current="$(jobs_config current "$PROJECT_ROOT")" || return 1
  old_family="${current%%$'\n'*}"
  [[ "$current" != *$'\n'* ]] || old_ref="${current#*$'\n'}"
  jobs_note 'SDK 类型：1 官方 Flutter（iOS / Android / macOS / Web）；2 Flutter 鸿蒙适配版。'
  while true; do
    if [[ "$old_family" == unknown ]]; then
      jobs_read '已有 SDK 来源无法自动沿用，必须输入 1 或 2 明确切换（Ctrl+C 取消）：' || return $?
    else
      jobs_read "选择（回车保留 ${old_family}）：" || return $?
    fi
    choice="$REPLY"
    case "$choice" in
      '') [[ "$old_family" != unknown ]] || continue; JOBS_SDK_FAMILY="$old_family"; break ;;
      1) JOBS_SDK_FAMILY=official; break ;;
      2) JOBS_SDK_FAMILY=harmony; break ;;
      *) jobs_note '请输入 1 或 2。' ;;
    esac
  done
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then
    JOBS_SDK_REPO="$JOBS_HARMONY_REPO"
    default_ref="$JOBS_HARMONY_REF"
  else
    JOBS_SDK_REPO="$JOBS_OFFICIAL_REPO"
    default_ref=stable
  fi
  [[ "$old_family" != "$JOBS_SDK_FAMILY" || -z "$old_ref" ]] || default_ref="$old_ref"
  jobs_note "来源：$JOBS_SDK_REPO"
  while true; do
    jobs_read "版本 / tag / 分支（回车=${default_ref}）：" || return $?
    JOBS_SDK_REF="${REPLY:-$default_ref}"
    if [[ "$JOBS_SDK_REF" =~ '^[a-zA-Z0-9][a-zA-Z0-9._+-]*$' && "$JOBS_SDK_REF" != *..* ]]; then break; fi
    jobs_note '版本只接受英文字母、数字、点、下划线、加减号，不能包含连续点。'
  done
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then
    jobs_note '鸿蒙版本将核对远端 ref 和 commit，使用 FVM 官方支持的 custom_ SDK 方式管理。'
  fi
}
jobs_ensure_fvm() {
  typeset -g JOBS_FVM_BIN="$(command -v fvm 2>/dev/null)"
  if [[ -z "$JOBS_FVM_BIN" ]]; then
    jobs_note '缺少 FVM，将通过官方文档列出的 btwld/fvm tap 安装独立 FVM。'
    jobs_read '回车安装 FVM；任意非空输入取消：' || return $?
    [[ -z "$REPLY" ]] || return 130
    HOMEBREW_NO_AUTO_UPDATE=1 "$JOBS_HOMEBREW_BIN" install btwld/fvm/fvm || return $?
    rehash
    JOBS_FVM_BIN="$(command -v fvm)" || return 1
  fi
  "$JOBS_FVM_BIN" --version || return $?
  local help_text=""
  help_text="$("$JOBS_FVM_BIN" use --help)" || return $?
  [[ "$help_text" == *--skip-pub-get* && "$help_text" == *--skip-setup* ]] || {
    jobs_error 'FVM 版本过旧；请按 README 升级到支持项目配置的 FVM 3/4 后重试。'; return 1
  }
}
jobs_git() { GIT_TERMINAL_PROMPT=0 /usr/bin/git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=60 "$@"; }
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
  jobs_git clone --no-checkout "$JOBS_SDK_REPO" "$stage/sdk" || return $?
  jobs_git -C "$stage/sdk" checkout --detach "$JOBS_SDK_COMMIT" || return $?
  [[ -x "$stage/sdk/bin/flutter" ]] || { jobs_error '下载内容缺少 Flutter 入口。'; return 1; }
  # Atomic, no-clobber publication. Never merge into an existing SDK directory.
  "$JOBS_PYTHON_BIN" - "$stage/sdk" "$target" <<'PY'
import os, sys
if os.path.lexists(sys.argv[2]):
    raise SystemExit('SDK 目标已被其它进程创建，请重试')
os.rename(sys.argv[1], sys.argv[2])
PY
)
jobs_setup_sdk_impl() {
  cd -- "$PROJECT_ROOT" || return 1
  JOBS_FVM_CACHE="$HOME/Library/Caches/JobsFlutter/fvm/$JOBS_SDK_FAMILY"
  JOBS_SDK_COMMIT=""
  JOBS_FVM_VERSION="$JOBS_SDK_REF"
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then jobs_resolve_harmony_commit || return $?; fi
  jobs_note "将下载 / 复用 $JOBS_SDK_FAMILY：$JOBS_SDK_REF；模式：$JOBS_INSTALL_MODE"
  jobs_note "FVM 缓存：$JOBS_FVM_CACHE；工程：$PROJECT_ROOT"
  jobs_read '回车确认本次 SDK 准备；任意非空输入取消：' || return $?
  [[ -z "$REPLY" ]] || return 130
  jobs_config fvm "$PROJECT_ROOT" "$JOBS_FVM_CACHE" "$JOBS_SDK_REPO" || return $?
  # Explicit environment agrees with project config, overriding inherited FVM globals.
  export FVM_CACHE_PATH="$JOBS_FVM_CACHE" FVM_FLUTTER_URL="$JOBS_SDK_REPO" FVM_USE_GIT_CACHE=false
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then
    jobs_clone_harmony || return $?
  fi
  local -a pin=()
  [[ "$JOBS_SDK_FAMILY" != official || ( "$JOBS_SDK_REF" != stable && "$JOBS_SDK_REF" != beta ) ]] || pin=(--pin)
  # use installs missing versions itself. Installing stable first would duplicate the pinned SDK.
  "$JOBS_FVM_BIN" use "$JOBS_FVM_VERSION" --skip-setup --skip-pub-get "${pin[@]}" || return $?
  [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]] || { jobs_error 'FVM 未生成可用的工程 SDK 链接。'; return 1; }
  JOBS_SDK_PATH="${PROJECT_ROOT}/.fvm/flutter_sdk"
  JOBS_SDK_PATH="${JOBS_SDK_PATH:A}"
  [[ "$JOBS_SDK_PATH" == "${JOBS_FVM_CACHE:A}/versions/"* ]] || { jobs_error 'FVM 链接未指向所选隔离缓存。'; return 1; }
  JOBS_FVM_VERSION="${JOBS_SDK_PATH:t}"
  JOBS_SDK_COMMIT="$(jobs_git -C "$JOBS_SDK_PATH" rev-parse HEAD)" || return $?
  "$JOBS_SDK_PATH/bin/flutter" --version || return $?
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then
    local build_help=""
    build_help="$("$JOBS_SDK_PATH/bin/flutter" build -h)" || return $?
    [[ "$build_help" == *hap* ]] || { jobs_error '所选 Flutter 未提供 build hap，停止鸿蒙配置。'; return 1; }
  fi
  if [[ "$JOBS_INSTALL_MODE" == global ]]; then jobs_enable_global || return $?; fi
}
jobs_restore_binding() {
  jobs_config binding-restore "$PROJECT_ROOT" "$JOBS_BINDING_BACKUP" || return 1
  jobs_note '已恢复本次操作前的 .fvmrc、FVM 元数据和 SDK 链接；下载缓存及备份保留。'
}
jobs_finish_binding() {
  local result="$1"
  if (( result != 0 )) && ! jobs_restore_binding; then
    jobs_note "⚠ 自动恢复失败，完整恢复快照已保留：$JOBS_BINDING_BACKUP"
    return "$result"
  fi
  rm -rf -- "$JOBS_BINDING_BACKUP"
  return "$result"
}
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
jobs_enable_global() {
  [[ "${JOBS_GLOBAL_AUTHORIZED:-0}" == 1 && "$JOBS_INSTALL_MODE" == global ]] || {
    jobs_error '缺少精确 YES 的全局安装授权。'; return 1
  }
  "$JOBS_FVM_BIN" global "$JOBS_FVM_VERSION" || return $?
  jobs_config profile "$HOME/.zprofile" "$JOBS_FVM_CACHE/default" || return $?
  jobs_note '✔ 已配置当前用户全局 Flutter；新登录终端生效。鸿蒙构建环境仍按工程加载。'
}
jobs_prepare_harmony() {
  emulate -L zsh
  setopt PIPE_FAIL NO_NOMATCH
  source "$SCRIPT_DIR/Scripts/vendor/CreateHarmonySimulator.zsh" || return $?
  hs_show_intro
  hs_check_host || return $?
  hs_initialize_log || return $?
  jobs_read '鸿蒙工具：回车准备工具及镜像；输入 device 仅准备工具（使用真机）；其它输入取消：' || return $?
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
      [[ ! -x "$item/bin/java" ]] || { java="$item"; break; }
    done
    [[ -n "$java" ]] || java="$(/usr/libexec/java_home -v 17 2>/dev/null)"
  fi
  while [[ ! -x "$java/bin/java" || ! -x "$java/bin/javac" ]]; do
    jobs_note '该 CLT 不一定附带 JDK。请安装匹配所选 SDK 的 JDK（当前默认组合建议 17），不自动改全局 Java。'
    jobs_read '输入 JAVA_HOME 目录（不能为空；Ctrl+C 取消）：' || return $?
    java="$(jobs_normalize_path "$REPLY")" || java=""
  done
  typeset -g JOBS_JAVA_HOME="$java"
  export TOOL_HOME="$root" DEVECO_SDK_HOME="$root/sdk" HOS_SDK_HOME="$root/sdk" OHOS_SDK_HOME="$root/sdk"
  export HDC_HOME="$root/sdk/default/openharmony/toolchains" JAVA_HOME="$java"
  export PATH="$node:$ohpm:$hvigor:$HDC_HOME:$JAVA_HOME/bin:$PATH"
  "$node/node" --version || return $?
  "$ohpm/ohpm" --version || return $?
  "$JAVA_HOME/bin/java" -version || return $?
  "$JAVA_HOME/bin/javac" -version || return $?
  "$HDC_HOME/hdc" -v || return $?
  jobs_note "✔ 鸿蒙构建工具路径已在当前进程激活：$root"
}
jobs_prepare_project() {
  local flutter="$JOBS_SDK_PATH/bin/flutter" answer="" platform="" result=0
  if [[ "$JOBS_SDK_FAMILY" == harmony && ! -d "$PROJECT_ROOT/ohos" ]]; then
    jobs_note '工程没有 ohos/。生成平台目录会修改工程；已有签名、包名和插件适配需在 DevEco 中核对。'
    jobs_read '输入 YES 执行 flutter create --platforms=ohos .；其它输入保留原工程：' || return $?
    if [[ "$REPLY" == YES ]]; then
      "$flutter" create --platforms=ohos . || return $?
    else
      jobs_note '尚未生成 ohos/，本次仅完成环境准备；暂不能运行鸿蒙应用。'
    fi
  fi
  if [[ "$JOBS_SDK_FAMILY" == official ]]; then
    jobs_read '预缓存目标（回车跳过；ios / android / macos / web）：' || return $?
    platform="$REPLY"
    case "$platform" in
      '') ;;
      ios|android|macos|web) "$flutter" precache "--$platform" || return $? ;;
      *) jobs_error '预缓存目标无效。'; return 1 ;;
    esac
  fi
  jobs_config runtime "$PROJECT_ROOT" "$JOBS_SDK_FAMILY" "$JOBS_SDK_REF" "$JOBS_FVM_VERSION" \
    "$JOBS_SDK_COMMIT" "$JOBS_SDK_PATH" "${JOBS_TOOL_ROOT:-}" "${JOBS_JAVA_HOME:-}" || return $?
  "$flutter" doctor -v || jobs_note '⚠ doctor 报告了未就绪项，请按输出处理；不等同于构建成功。'
  "$flutter" pub get || return $?
  if [[ "$JOBS_SDK_FAMILY" == harmony && ! -d "$PROJECT_ROOT/ohos" ]]; then return 0; fi
  jobs_optional '是否选择已连接设备并运行 Flutter 工程' || { result=$?; (( result == 1 )) && return 0; return "$result"; }
  local devices="" rows="" selected="" i=1
  devices="$("$flutter" devices --machine)" || return $?
  rows="$(print -r -- "$devices" | jobs_config devices "$JOBS_SDK_FAMILY")" || return $?
  [[ -n "$rows" ]] || { jobs_error '没有符合目标平台的设备。先启动模拟器或连接已授权真机。'; return 1; }
  local -a choices=("${(@f)rows}")
  for selected in "${choices[@]}"; do jobs_note "$i、$selected"; (( i += 1 )); done
  jobs_read '设备编号（回车=1）：' || return $?
  answer="${REPLY:-1}"
  [[ "$answer" == <-> ]] && (( answer >= 1 && answer <= ${#choices[@]} )) || { jobs_error '设备编号无效。'; return 1; }
  selected="${choices[$answer]%%$'\t'*}"
  "$PROJECT_ROOT/.jobs-flutter/flutter" run -d "$selected"
}
jobs_workflow() {
  jobs_choose_install_mode || return $?
  jobs_choose_project "${1:-}" || return $?
  jobs_flutterrun_python_preflight confirmed || return $?
  jobs_choose_sdk || return $?
  jobs_ensure_fvm || return $?
  if [[ "$JOBS_SDK_FAMILY" == harmony ]]; then jobs_prepare_harmony || return $?; fi
  jobs_setup_sdk || return $?
  jobs_prepare_project || return $?
  jobs_note "✔ 配置流程完成。工程命令入口：$PROJECT_ROOT/.jobs-flutter/flutter"
  jobs_note '可执行：.jobs-flutter/flutter doctor -v / devices / run；构建与签名是否就绪以实际输出为准。'
}
