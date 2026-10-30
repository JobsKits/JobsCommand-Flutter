#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】📦双击打包Flutter.Harmony.command
# - 核心用途：使用鸿蒙适配版 Flutter 一次构建 HAP 安装包和 APP 发布包，默认 release。
# - 影响范围：解析工程依赖、执行 Hvigor 构建并写入构建目录；签名沿用工程配置。
# - 运行提示：先打印内置自述；终端回车确认，Ctrl+C / EOF 取消；--help / --check 不构建；缺少工具链时停止。

SCRIPT_SOURCE="$0"
SCRIPT_PATH=""
SCRIPT_DIR=""
SCRIPT_BASENAME=""
LOG_FILE=""
LOG_READY=0
IS_SOURCETREE_RUNTIME=0
PLAIN_OUTPUT=0
PROJECT_ROOT=""
BUILD_BASE=""
BUILD_MODE="${BUILD_MODE:-}"
BUILD_TARGET="all"
SDK_OVERRIDE=""
DEVECO_CONTENTS=""
FLUTTER_CMD=()
BUILD_TARGETS=(hap app)
OUTPUT_ROOTS=()
typeset -a HAP_ARTIFACTS=() APP_ARTIFACTS=()
CHECK_ONLY=0
BUILD_MARKER=""


# 始终按脚本自身路径定位，不依赖启动工作目录。
resolve_script_path() {
  SCRIPT_PATH="${${(%):-%x}:A}"
  SCRIPT_DIR="${SCRIPT_PATH:h}"
  SCRIPT_BASENAME="${SCRIPT_PATH:t:r}"
  LOG_FILE='确认后在系统临时目录 JobsFlutterHarmonyPackager.* 中创建'
}

# 在第一屏及正式执行前同步初始化纯文本环境。
configure_output_mode() {
  if [[ "$IS_SOURCETREE_RUNTIME" == 1 || ! -t 1 || -z "${TERM:-}" || "${TERM:-}" == dumb || -n "${NO_COLOR+x}" ]]; then
    PLAIN_OUTPUT=1
    export NO_COLOR=1 FORCE_COLOR=0 CLICOLOR=0 ANSI_COLORS_DISABLED=1 npm_config_color=false
  fi
}
# 过滤脚本和外部命令输出中的 ANSI 颜色与控制序列。
strip_ansi_stream() {
  /usr/bin/perl -pe 's/\e\][^\a]*(?:\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\\(?:033|e|x1[bB])\[[0-9;]*m//g'
}
# 终端和日志同步记录；日志始终保存可检索的纯文本。
log() {
  local line="$1"
  if [[ "$PLAIN_OUTPUT" == 1 ]]; then
    print -r -- "$line" | strip_ansi_stream
  else
    print -r -- "$line"
  fi
  if [[ "$LOG_READY" == 1 ]]; then
    print -r -- "$line" | strip_ansi_stream >> "$LOG_FILE" || return 1
  fi
}
# 颜色仅用于终端展示，避免把路径内反斜杠当转义字符。
color_log() {
  if [[ "$PLAIN_OUTPUT" == 1 ]]; then
    log "$2"
  else
    log "$(printf '\033[%sm%s\033[0m' "$1" "$2")"
  fi
}
# 输出构建步骤与环境信息。
info_echo() { color_log '1;34' "ℹ $1"; }
# 输出已经核验的结果。
success_echo() { color_log '1;32' "✔ $1"; }
# 输出需要人工处理的条件。
warn_echo() { color_log '1;33' "⚠ $1"; }
# 输出失败原因。
error_echo() { color_log '1;31' "✖ $1"; }
# 自述标题红色加粗，正文蓝色常规字重。
intro_line() {
  local style='0;34'
  [[ "$1" == title ]] && style='1;31'
  color_log "$style" "$2"
}
# 首先展示固定自述，确认之前不写日志或改动工程。
show_script_intro_and_wait() {
  resolve_script_path || exit 1
  configure_output_mode
  intro_line title "================ 鸿蒙 Flutter 打包 ================"
  intro_line title "脚本名称：${SCRIPT_BASENAME}.command"
  intro_line body '1、用途：构建已有 Flutter 鸿蒙工程，默认 release，一次生成 HAP 安装包和 APP 发布包。'
  intro_line body '2、依赖：鸿蒙适配 Flutter → Dart / 鸿蒙 SDK → Node / ohpm / Hvigor / Java。'
  intro_line body '3、影响：联网解析依赖、执行工程构建与现有签名配置，写入缓存和构建目录。'
  intro_line body '4、策略：不自动安装、升级工具链，不创建 ohos 平台，不修改证书或系统环境配置。'
  intro_line body '5、先确认工程根目录，再回车开始；Ctrl+C / EOF 取消，--check 只检查工程清单。'
  intro_line body "日志：$LOG_FILE"
  intro_line title '===================================================='
  [[ "${1:-}" == --help || "${1:-}" == --check ]] && return 0
  if [[ ! -t 0 ]]; then
    error_echo '没有交互输入，请在终端运行，或使用 --check 只读检查。'
    exit 1
  fi
  local answer=""
  IFS= read -r 'answer?👉 按回车继续；Ctrl+C 取消：' || exit 1
}
# 确认后配置当前进程和日志，保留调用者 PATH 优先级。
initialize_script_runtime() {
  setopt NO_NOMATCH PIPE_FAIL
  export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin:$HOME/.pub-cache/bin:$HOME/.fvm/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  configure_output_mode
  umask 077
  local run_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/JobsFlutterHarmonyPackager.XXXXXX")" || return 1
  LOG_FILE="$run_dir/$SCRIPT_BASENAME.log"
  : > "$LOG_FILE" || { print -u2 -r -- "日志不可写：$LOG_FILE"; exit 1; }
  LOG_READY=1
}
# 先校验全部参数，再进入 SDK 或联网操作。
parse_build_options() {
  BUILD_MODE="release"
  BUILD_TARGET="all"
  SDK_OVERRIDE="${FLUTTER_OHOS_SDK:-}"
  while (( $# > 0 )); do
    case "$1" in
      --mode|--flutter-sdk|--project)
        (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] || { error_echo "$1 缺少参数值。"; return 2; }
        case "$1" in
          --mode) BUILD_MODE="$2" ;;
          --project) [[ -z "$BUILD_BASE" ]] || return 2; BUILD_BASE="$2" ;;
          --flutter-sdk) SDK_OVERRIDE="$2" ;;
        esac
        shift 2
        ;;
      --)
        shift
        (( $# <= 1 )) && [[ -z "$BUILD_BASE" ]] || { error_echo '只能指定一个工程目录。'; return 2; }
        BUILD_BASE="${1:-}"
        break
        ;;
      -*) error_echo "未知参数：$1"; return 2 ;;
      *) [[ -z "$BUILD_BASE" ]] || { error_echo '只能指定一个工程目录。'; return 2; }; BUILD_BASE="$1"; shift ;;
    esac
  done
  case "$BUILD_MODE" in release|debug|profile) ;; *) error_echo "无效构建模式：$BUILD_MODE"; return 2 ;; esac
  case "$BUILD_TARGET" in hap|app|all) ;; *) error_echo "无效鸿蒙产物类型：$BUILD_TARGET"; return 2 ;; esac
  [[ "${OPEN_AFTER_BUILD:-1}" == [01] ]] || { error_echo 'OPEN_AFTER_BUILD 只能是 0 或 1。'; return 2; }
  BUILD_TARGETS=("$BUILD_TARGET")
  [[ "$BUILD_TARGET" == all ]] && BUILD_TARGETS=(hap app)
  return 0
}
# 解除拖入路径的外层引号和转义，保留有效文件名中的原有字符。
normalize_input_path() {
  local input_value="$1"
  if [[ ! -e "$input_value" ]]; then
    input_value="${input_value%$'\r'}"
    input_value="${input_value%$'\n'}"
    [[ "$input_value" == \"*\" || "$input_value" == \'*\' ]] && input_value="${input_value[2,-2]}"
    [[ "$input_value" == '~/'* ]] && input_value="$HOME/${input_value#\~/}"
    [[ -e "$input_value" ]] || input_value="${(Q)input_value}"
  fi
  print -r -- "$input_value"
}
project_data() {
    /usr/bin/osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('Foundation');
function run(args) {
    function read(path) {
        var data = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
        if (!data) throw Error('无法读取文件：' + path);
        return ObjC.unwrap(data);
    }
    function clean(value) {
        if (typeof value !== 'string' || /[\x00-\x1f\x7f]/.test(value)) throw Error('字段包含控制字符或类型错误');
        return value;
    }
    function scalar(value) {
        value = value.trim();
        if (/^'[^']*'$/.test(value) || /^"[^"\\]*"$/.test(value)) return value.slice(1, -1);
        return value;
    }
    function uncomment(line) {
        var quote = '', result = '';
        for (var i = 0; i < line.length; i++) {
            var c = line[i];
            if (quote) {
                result += c;
                if (c === '\\' && quote === '"') { result += line[++i] || ''; continue; }
                if (c === quote) {
                    if (quote === "'" && line[i + 1] === "'") { result += line[++i]; continue; }
                    quote = '';
                }
            } else if (c === '#' && (i === 0 || /\s/.test(line[i - 1]))) break;
            else { result += c; if (c === "'" || c === '"') quote = c; }
        }
        return result.replace(/\s+$/, '');
    }
    function flow(text) {
        var pos = 0;
        function space() { while (/\s/.test(text[pos] || '') && pos < text.length) pos++; }
        function token() {
            space(); var start = pos, quote = text[pos];
            if (quote === '"' || quote === "'") {
                pos++; while (pos < text.length && text[pos] !== quote) { if (text[pos] === '\\') throw Error('不支持转义 flow scalar'); pos++; }
                if (text[pos++] !== quote) throw Error('引号未闭合');
                return text.slice(start + 1, pos - 1);
            }
            while (pos < text.length && !/[,:{}\[\]]/.test(text[pos])) pos++;
            var result = text.slice(start, pos).trim();
            if (!result || /[&*!|>]/.test(result)) throw Error('不支持该 YAML flow 写法');
            return result;
        }
        function map() {
            space(); if (text[pos++] !== '{') throw Error('要求 flow map');
            var result = Object.create(null); space();
            while (text[pos] !== '}') {
                var key = token(); space(); if (text[pos++] !== ':') throw Error('缺少冒号'); space();
                if (Object.prototype.hasOwnProperty.call(result, key)) throw Error('重复 YAML key：' + key);
                result[key] = text[pos] === '{' ? map() : token(); space();
                if (text[pos] === ',') { pos++; space(); } else if (text[pos] !== '}') throw Error('flow map 格式无效');
            }
            pos++; return result;
        }
        var result = map(); space(); if (pos !== text.length) throw Error('flow map 末尾有额外内容');
        return result;
    }
    // 读全部可读的 key: value 行；Tab 缩进与多文档标记直接拒绝，避免猜错层级。
    function loadEntries(path) {
        var lines = read(path).replace(/^\uFEFF/, '').split(/\r?\n/), entries = [];
        lines.forEach(function (line, i) {
            var cleanLine = uncomment(line);
            if (!cleanLine) return;
            if (/^[ \t]*\t/.test(cleanLine)) throw Error('缩进含 Tab，无法安全识别');
            if (/^\s*(?:---|\.\.\.)(?:\s|$)/.test(cleanLine)) throw Error('不支持 YAML 文档分隔标记');
            var indent = cleanLine.length - cleanLine.replace(/^ +/, '').length;
            var match = /^([^:]+):(?:\s+(.*)|\s*)$/.exec(cleanLine.slice(indent));
            if (!match) return;
            entries.push({ index: i, indent: indent, key: scalar(match[1]), value: (match[2] || '').trim() });
        });
        return entries;
    }
    // 取某节点的直接子节点：大于父缩进且取最小缩进，遇到回缩即截断。
    function childrenOf(entries, parent) {
        var result = [];
        if (!parent) {
            return entries.filter(function (entry) { return entry.indent === 0; });
        }
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].index <= parent.index) continue;
            if (entries[i].indent <= parent.indent) break;
            result.push(entries[i]);
        }
        if (result.length === 0) return [];
        var minimum = Math.min.apply(null, result.map(function (entry) { return entry.indent; }));
        return result.filter(function (entry) { return entry.indent === minimum; });
    }
    // 根级 key 必须唯一，否则不参与后续判定。
    function uniqueRoot(entries, key) {
        var roots = childrenOf(entries, null).filter(function (entry) { return entry.key === key; });
        return roots.length === 1 ? roots[0] : null;
    }
    // 逐层确认 dependencies.flutter.sdk 是 flutter，支持 block 与单行 flow 两种常见写法。
    function assertFlutterSDKDependency(entries, dependencies) {
        if (dependencies.value) {
            var flattened = flow(dependencies.value);
            if (!flattened.flutter) throw Error('缺少 dependencies.flutter');
            // 嵌套 flow map 已被解析成对象，只有仍是字符串的单行写法才需要二次解析。
            var nested = typeof flattened.flutter === 'string' ? flow(flattened.flutter) : flattened.flutter;
            if (!nested || nested.sdk !== 'flutter') throw Error('dependencies.flutter.sdk 不是 flutter');
            return true;
        }
        var declarations = childrenOf(entries, dependencies).filter(function (entry) { return entry.key === 'flutter'; });
        if (declarations.length !== 1) throw Error('缺少唯一直接依赖 flutter');
        var declaration = declarations[0];
        if (declaration.value) {
            if (flow(declaration.value).sdk !== 'flutter') throw Error('dependencies.flutter.sdk 不是 flutter');
            return true;
        }
        var fields = childrenOf(entries, declaration).filter(function (entry) { return entry.key === 'sdk'; });
        if (fields.length !== 1) throw Error('缺少唯一 sdk 声明');
        if (scalar(fields[0].value) !== 'flutter') throw Error('dependencies.flutter.sdk 不是 flutter');
        return true;
    }
    if (args[0] === 'directory-kind') {
        var url = $.NSURL.fileURLWithPath(args[1]);
        var properties = ObjC.deepUnwrap(url.resourceValuesForKeysError($([$.NSURLIsDirectoryKey, $.NSURLIsPackageKey, $.NSURLIsAliasFileKey, $.NSURLIsSymbolicLinkKey]), null));
        if (!properties || properties.NSURLIsDirectoryKey !== true || properties.NSURLIsPackageKey !== false ||
            properties.NSURLIsAliasFileKey !== false || properties.NSURLIsSymbolicLinkKey !== false) throw Error('目标不是普通目录，或是 package / Alias / 符号链接');
        return 'directory';
    }
    if (args[0] === 'pubspec') {
        if (read(args[1]).indexOf(String.fromCharCode(0)) !== -1) throw Error('清单含 NUL');
        var manifestEntries = loadEntries(args[1]);
        var dependencies = uniqueRoot(manifestEntries, 'dependencies');
        if (!dependencies) throw Error('必须有唯一根级 dependencies');
        if (assertFlutterSDKDependency(manifestEntries, dependencies)) return 'flutter';
        throw Error('未识别到 Flutter SDK 依赖');
    }
    throw Error('未知数据操作');
}
JXA
}
# 仅处理用户指定的工程根目录，不扫描或猜测其它工程。
resolve_flutter_project() {
  local base="$(normalize_input_path "$BUILD_BASE")" item="" size=""
  while [[ "$base" == */ && "$base" != / ]]; do
    base="${base%/}"
  done
  [[ -n "$base" && "$base" != / && "$base" != *[[:cntrl:]]* && -d "$base" && ! -L "$base" ]] || {
    error_echo '请指定当前层的普通 Flutter 鸿蒙工程根目录，不接受链接或控制字符。'; return 1
  }
  PROJECT_ROOT="${base:A}"
  for item in pubspec.yaml ohos/build-profile.json5 ohos/oh-package.json5; do
    [[ -f "$PROJECT_ROOT/$item" && ! -L "$PROJECT_ROOT/$item" && -s "$PROJECT_ROOT/$item" ]] || {
      error_echo "工程缺少普通非空清单：$item"; return 1
    }
  done
  [[ -d "$PROJECT_ROOT/lib" && ! -L "$PROJECT_ROOT/lib" && ! -L "$PROJECT_ROOT/ohos" ]] || {
    error_echo '工程需有普通 lib/ 和 ohos/ 目录'; return 1
  }
  size="$(/usr/bin/stat -f %z "$PROJECT_ROOT/pubspec.yaml")" || return 1
  [[ "$size" == <-> && "$size" -le 1048576 ]] || { error_echo 'pubspec.yaml 超过 1 MiB'; return 1; }
  project_data directory-kind "$PROJECT_ROOT" >/dev/null || return 1
  project_data pubspec "$PROJECT_ROOT/pubspec.yaml" >/dev/null || { error_echo '无法确认 Flutter SDK 依赖'; return 1; }
  info_echo "工程目录：$PROJECT_ROOT"
}

# 显式指定 SDK 优先，其次项目固定 SDK，最后当前 PATH；不默默替换固定版本。
choose_flutter_sdk() {
  if [[ -n "$SDK_OVERRIDE" ]]; then
    SDK_OVERRIDE="$(normalize_input_path "$SDK_OVERRIDE")"
    [[ -x "$SDK_OVERRIDE/bin/flutter" ]] || { error_echo "指定 SDK 中没有可执行 bin/flutter：$SDK_OVERRIDE"; return 1; }
    FLUTTER_CMD=("${SDK_OVERRIDE:A}/bin/flutter")
  elif [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER_CMD=("$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter")
  elif [[ -e "$PROJECT_ROOT/.fvmrc" || -e "$PROJECT_ROOT/.fvm/fvm_config.json" || -L "$PROJECT_ROOT/.fvm/flutter_sdk" ]]; then
    error_echo '工程固定了 FVM，但 .fvm/flutter_sdk 尚不可用。请先恢复该 SDK，或显式指定 --flutter-sdk；入口不自动下载 SDK。'
    return 1
  elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD=("${commands[flutter]:A}")
  else
    error_echo '没有 Flutter SDK。请用 --flutter-sdk 或 FLUTTER_OHOS_SDK 指定鸿蒙适配版 SDK 根目录。'
    return 1
  fi
  info_echo "Flutter 命令：${(j: :)FLUTTER_CMD}"
}
# 仅配置本进程的 DevEco 路径，保留显式 SDK 和 Java 设置。
prepare_deveco_environment() {
  local candidate="" requested="${DEVECO_STUDIO_HOME:-${TOOL_HOME:-}}"
  local -a candidates=()
  if [[ -z "${DEVECO_SDK_HOME:-}" && -n "${HOS_SDK_HOME:-}" ]]; then
    export DEVECO_SDK_HOME="$HOS_SDK_HOME"
  fi
  if [[ -n "$requested" ]]; then
    requested="$(normalize_input_path "$requested")"
    [[ -d "$requested/Contents" ]] && requested="$requested/Contents"
    [[ -d "$requested" ]] || { error_echo "DevEco 路径不存在：$requested"; return 1; }
    DEVECO_CONTENTS="$requested"
  elif [[ -z "${DEVECO_SDK_HOME:-}" ]]; then
    for candidate in /Applications/DevEco*.app/Contents(N) "$HOME"/Applications/DevEco*.app/Contents(N); do
      [[ -d "$candidate/sdk" ]] && candidates+=("$candidate")
    done
    if (( ${#candidates[@]} == 1 )); then
      DEVECO_CONTENTS="${candidates[1]}"
    elif (( ${#candidates[@]} > 1 )); then
      error_echo '发现多个 DevEco Studio，请用 DEVECO_STUDIO_HOME 明确选择。'
      return 1
    fi
  fi
  if [[ -n "$DEVECO_CONTENTS" ]]; then
    export TOOL_HOME="$DEVECO_CONTENTS"
    [[ -n "${DEVECO_SDK_HOME:-}" ]] || export DEVECO_SDK_HOME="$DEVECO_CONTENTS/sdk"
    export PATH="$DEVECO_CONTENTS/tools/node/bin:$DEVECO_CONTENTS/tools/ohpm/bin:$DEVECO_CONTENTS/tools/hvigor/bin:$DEVECO_CONTENTS/tool/node/bin:$DEVECO_CONTENTS/ohpm/bin:$DEVECO_CONTENTS/hvigor/bin:$PATH"
    if [[ -z "${JAVA_HOME:-}" && -x "$DEVECO_CONTENTS/jbr/Contents/Home/bin/java" ]]; then
      export JAVA_HOME="$DEVECO_CONTENTS/jbr/Contents/Home"
    fi
  fi
  if [[ -n "${JAVA_HOME:-}" ]]; then
    [[ -x "$JAVA_HOME/bin/java" ]] || { error_echo "JAVA_HOME 没有可执行 bin/java：$JAVA_HOME"; return 1; }
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  if [[ -n "${NODE_HOME:-}" ]]; then
    [[ -x "$NODE_HOME/bin/node" ]] || { error_echo "NODE_HOME 没有可执行 bin/node：$NODE_HOME"; return 1; }
    export PATH="$NODE_HOME/bin:$PATH"
  fi
  rehash
  [[ -n "${DEVECO_SDK_HOME:-}" && -d "$DEVECO_SDK_HOME" ]] || {
    error_echo '没有有效 DEVECO_SDK_HOME。请先准备 DevEco Studio / HarmonyOS SDK；不将 OHOS_SDK_HOME 当作同义路径。'
    return 1
  }
  info_echo "HarmonyOS SDK：$DEVECO_SDK_HOME"
}
# 外部输出同步过滤和落盘，启用 PIPE_FAIL 后任何阶段失败均会停止。
run_step() {
  local title="$1" command_ec=0
  shift
  info_echo "开始：$title" || return 1
  if "$@" 2>&1 | strip_ansi_stream | /usr/bin/tee -a "$LOG_FILE"; then
    success_echo "完成：$title"
  else
    command_ec=$?
    error_echo "$title 失败，退出码 $command_ec；日志：$LOG_FILE"
    return "$command_ec"
  fi
}
# 验证实际命令可执行，不安装或升级工程工具链。
check_build_toolchain() {
  local tool=""
  for tool in node npm ohpm java; do
    command -v "$tool" >/dev/null 2>&1 || { error_echo "缺少 $tool，请检查 DevEco 工具目录和 PATH。"; return 1; }
  done
  run_step 'Node.js 健康检查' node --version || return $?
  run_step 'npm 健康检查' npm --version || return $?
  run_step 'ohpm 健康检查' ohpm --version || return $?
  run_step 'Java 健康检查' java -version || return $?
  if command -v hvigorw >/dev/null 2>&1; then
    run_step 'Hvigor 健康检查' hvigorw --version || return $?
  else
    error_echo '缺少 hvigorw，请把 DevEco tools/hvigor/bin 加入 PATH。'
    return 1
  fi
  run_step 'Flutter 健康检查' "${FLUTTER_CMD[@]}" --version || return $?
  local target="" help_text=""
  for target in "${BUILD_TARGETS[@]}"; do
    if ! help_text="$("${FLUTTER_CMD[@]}" build "$target" --help 2>&1)"; then
      log "$help_text"
      error_echo "此 SDK 不支持 flutter build $target，请切换匹配工程的鸿蒙适配版 SDK。"
      return 1
    fi
    if ! print -r -- "$help_text" | strip_ansi_stream | /usr/bin/grep -Fq "flutter build $target"; then
      error_echo "未确认 flutter build $target 能力；当前 SDK 可能是普通 Android / iOS 版本。"
      return 1
    fi
  done
}
# 从 Flutter 汇总目录和 DevEco 模块输出目录收集实际产物。
report_build_outputs() {
  local target="$1" output_root="" artifact="" found=0
  local -a artifacts=()
  OUTPUT_ROOTS=("$PROJECT_ROOT/build/ohos" "$PROJECT_ROOT/ohos/build")
  for output_root in "$PROJECT_ROOT"/ohos/*/build(N/); do
    OUTPUT_ROOTS+=("$output_root")
  done
  for output_root in "${OUTPUT_ROOTS[@]}"; do
    [[ -d "$output_root" && ! -L "$output_root" ]] || continue
    while IFS= read -r -d '' artifact; do
      [[ -s "$artifact" ]] || continue
      [[ ! -L "$artifact" ]] || continue
      if [[ -n "$BUILD_MARKER" && ! "$artifact" -nt "$BUILD_MARKER" ]]; then
        info_echo "保留历史 .$target，未计入本轮产物：$artifact"
        continue
      fi
      artifacts+=("$artifact")
    done < <(/usr/bin/find "$output_root" \( -type d \( -name node_modules -o -name intermediates \) -prune \) -o \( -type f -name "*.$target" \( -path '*/outputs/*' -o -path '*/build/ohos/*' \) -print0 \))
  done
  for artifact in "${artifacts[@]}"; do
    found=1
    if [[ "$artifact" == *-unsigned.* ]]; then
      warn_echo "未签名产物：$artifact；安装或上架前必须完成对应签名。"
    else
      success_echo "产物：$artifact（签名有效性由工程工具另行验证）"
    fi
  done
  (( found == 1 )) || { error_echo "构建命令结束，但未发现本轮非空 .$target 产物；旧包保留，请检查增量构建输出。"; return 1; }
  if [[ "$target" == hap ]]; then
    HAP_ARTIFACTS=("${artifacts[@]}")
  else
    APP_ARTIFACTS=("${artifacts[@]}")
  fi
  if [[ "${OPEN_AFTER_BUILD:-1}" == 1 ]]; then
    /usr/bin/open -R "${artifacts[1]}" 2>/dev/null || warn_echo "无法在 Finder 定位：${artifacts[1]}"
  fi
}
# 第二步可能重写输出目录，最终重新确认两类包同时存在。
verify_both_outputs() {
  local artifact="" hap_count=0 app_count=0
  for artifact in "${HAP_ARTIFACTS[@]}"; do
    [[ -f "$artifact" && -s "$artifact" && ! -L "$artifact" ]] && hap_count=$((hap_count + 1))
  done
  for artifact in "${APP_ARTIFACTS[@]}"; do
    [[ -f "$artifact" && -s "$artifact" && ! -L "$artifact" ]] && app_count=$((app_count + 1))
  done
  (( hap_count > 0 && app_count > 0 )) || { error_echo '最终检查失败：HAP 与 APP 未同时保留在输出目录。'; return 1; }
}
# 全部前置检查通过后，按顺序解析依赖和构建所选包型。
run_build_flow() {
  resolve_flutter_project || return $?
  cd "$PROJECT_ROOT" || return 1
  choose_flutter_sdk || return $?
  prepare_deveco_environment || return $?
  check_build_toolchain || return $?
  info_echo '依赖来源：沿用工程 pubspec.yaml / 锁文件和当前 Pub、ohpm 软件源配置。'
  run_step 'flutter pub get' "${FLUTTER_CMD[@]}" pub get || return $?
  local target=""
  for target in "${BUILD_TARGETS[@]}"; do
    BUILD_MARKER="$(/usr/bin/mktemp "${LOG_FILE:h}/build-start.XXXXXX")" || return 1
    run_step "flutter build $target --$BUILD_MODE" "${FLUTTER_CMD[@]}" build "$target" "--$BUILD_MODE" || return $?
    report_build_outputs "$target" || return $?
  done
  verify_both_outputs || return $?
  success_echo "HAP + APP 构建与双产物检查完成；签名是否满足发布要求需结合工程配置核对。日志：$LOG_FILE"
}
# 保留失败退出码，避免尾部日志掩盖构建错误。
run_checked_build() {
  local build_ec=0
  if run_build_flow "$@"; then
    return 0
  else
    build_ec=$?
    error_echo "脚本已停止，退出码 $build_ec。日志：$LOG_FILE"
    exit "$build_ec"
  fi
}
# 以唯一入口编排确认、初始化和构建。
main() {
  # 自述与参数检查不运行工程命令；日志在确认后创建。
  if [[ "${1:-}" == --help || "${1:-}" == --check ]]; then
    show_script_intro_and_wait "$1"
    if [[ "$1" == --help ]]; then
      print -r -- '用法：/bin/zsh <本脚本> [--project <Flutter根目录>] [--mode release|debug|profile] [--flutter-sdk <鸿蒙SDK根目录>]'
      print -r -- '--check --project <目录>：只检查清单，不调用工具、不创建日志、不联网。'
      print -r -- '始终同时构建 HAP + APP；可用 FLUTTER_OHOS_SDK 指定 SDK，OPEN_AFTER_BUILD=0 禁止定位产物。'
      return 0
    fi
    shift
    parse_build_options "$@" || return $?
    resolve_flutter_project || return $?
    info_echo "工程清单检查通过；计划 HAP + APP / $BUILD_MODE；未验证工具链、签名或执行构建。"
    return 0
  fi
  show_script_intro_and_wait
  parse_build_options "$@" || return $?
  if [[ -z "$BUILD_BASE" ]]; then
    IFS= read -r 'BUILD_BASE?👉 输入或拖入 Flutter 鸿蒙工程根目录；Ctrl+C 取消：' || return 130
  fi
  initialize_script_runtime || return $?
  # 使用已解析的配置，避免重复解析丢失交互输入。
  run_checked_build
}


