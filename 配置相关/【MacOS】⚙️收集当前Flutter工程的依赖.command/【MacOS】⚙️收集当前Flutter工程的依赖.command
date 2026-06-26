#!/bin/zsh

set -euo pipefail
setopt NO_NOMATCH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "$0")"
SCRIPT_BASENAME="$(basename "$0" | sed 's/\.[^.]*$//')"
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"
: > "$LOG_FILE"

SELECT_MODE=0
RUN_PUB_GET=1
INPUT_PROJECT=""
PROJECT_ROOT=""
PROJECT_NAME=""
FLUTTER_CMD=()
PACKAGE_CONFIG=""
ZIP_PATH=""
TMP_PARENT=""
STAGE_NAME=""
STAGE=""
ALL_DEPS_TSV=""
SELECTED_DEPS_TSV=""
TOTAL_COUNT=0
SELECTED_COUNT=0

# 同步输出终端信息与日志文件。
log()            { print -r -- "$1" | tee -a "$LOG_FILE"; }
# 输出普通绿色信息。
color_echo()     { log "\033[1;32m$1\033[0m"; }
# 输出蓝色提示信息。
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }
# 输出绿色成功信息。
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }
# 输出黄色警告信息。
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }
# 输出黄色温馨提示。
warm_echo()      { log "\033[1;33m$1\033[0m"; }
# 输出紫色说明信息。
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }
# 输出红色错误信息。
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }
# 输出红色纯文本信息。
err_echo()       { log "\033[1;31m$1\033[0m"; }
# 输出紫色调试信息。
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }
# 输出青色高亮信息。
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }
# 输出灰色次要信息。
gray_echo()      { log "\033[0;90m$1\033[0m"; }
# 输出加粗信息。
bold_echo()      { log "\033[1m$1\033[0m"; }
# 输出下划线信息。
underline_echo() { log "\033[4m$1\033[0m"; }

# 输出错误并终止脚本。
fail() {
  error_echo "$1"
  exit 1
}

# 展示命令行参数说明。
usage() {
  cat <<'USAGE'
用法：
  ./pack_flutter_deps_macos.command
  ./pack_flutter_deps_macos.command --select
  ./pack_flutter_deps_macos.command /path/to/app
  ./pack_flutter_deps_macos.command --no-pub-get

参数：
  -s, --select       使用 fzf 多选 Dart / Flutter 依赖
  --no-pub-get       不询问执行 flutter pub get，直接使用现有解析文件
  -h, --help         显示帮助
USAGE
}

# 解析命令行参数并拒绝未知或重复的项目路径。
parse_arguments() {
  while (( $# > 0 )); do
    case "$1" in
      -s|--select)
        SELECT_MODE=1
        shift
        ;;
      --no-pub-get)
        RUN_PUB_GET=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        [[ $# -le 1 ]] || fail "-- 后只能传入一个 Flutter 项目路径。"
        [[ $# -eq 0 ]] || INPUT_PROJECT="$1"
        break
        ;;
      -*)
        fail "不支持的参数：$1（可使用 --help 查看帮助）"
        ;;
      *)
        [[ -z "$INPUT_PROJECT" ]] || fail "参数过多：$1"
        INPUT_PROJECT="$1"
        shift
        ;;
    esac
  done
}

# 展示同目录 README，并等待用户确认后执行。
show_readme_and_wait() {
  local readme_path="${SCRIPT_DIR}/README.md"
  [[ -t 1 && -n "${TERM:-}" && "${TERM:-}" != "dumb" ]] && clear

  if [[ -f "$readme_path" ]]; then
    highlight_echo "============================== README.md =============================="
    cat "$readme_path" | tee -a "$LOG_FILE"
    highlight_echo "======================================================================="
  else
    fail "未找到配套 README.md：${readme_path}"
  fi
  echo ""

  if [[ -t 0 ]]; then
    read -r "?👉 已阅读脚本说明，按回车继续执行；按 Ctrl+C 取消：" _
  else
    fail "当前标准输入不可交互，无法完成执行前确认。"
  fi
}

# 清理终端拖入路径的首尾引号、换行和常见转义字符。
normalize_input_path() {
  local path_value="$1"
  path_value="${path_value%$'\r'}"
  path_value="${path_value%$'\n'}"
  path_value="${path_value#\"}"
  path_value="${path_value%\"}"
  path_value="${path_value#\'}"
  path_value="${path_value%\'}"
  [[ "$path_value" == '~/'* ]] && path_value="$HOME/${path_value#\~/}"
  path_value="${path_value//\\ / }"
  path_value="${path_value//\\(/(}"
  path_value="${path_value//\\)/)}"
  path_value="${path_value//\\[/[}"
  path_value="${path_value//\\]/]}"
  path_value="${path_value//\\&/&}"
  path_value="${path_value//\\;/;}"
  [[ "$path_value" == "/" ]] || path_value="${path_value%/}"
  print -r -- "$path_value"
}

# 从指定目录逐级向上查找最近的 pubspec.yaml。
find_pubspec_upwards() {
  local current_dir="$1"
  current_dir="$(cd "$current_dir" 2>/dev/null && pwd -P)" || return 1

  while true; do
    [[ -f "$current_dir/pubspec.yaml" ]] && { print -r -- "$current_dir"; return 0; }
    [[ "$current_dir" == "/" ]] && break
    current_dir="$(dirname "$current_dir")"
  done
  return 1
}

# 将用户输入解析成包含 pubspec.yaml 的工程根目录。
resolve_project_root_from_input() {
  local input_path=""
  input_path="$(normalize_input_path "$1")"

  [[ -f "$input_path" && "$(basename "$input_path")" == "pubspec.yaml" ]] && input_path="$(dirname "$input_path")"
  [[ -d "$input_path" && -f "$input_path/pubspec.yaml" ]] || return 1
  (cd "$input_path" && pwd -P)
}

# 循环接收用户路径，直到找到合法的 Flutter / Dart 工程。
ask_project_root_until_valid() {
  local raw_path=""
  local resolved_root=""

  while true; do
    echo "" >&2
    read -r "?没有自动找到 pubspec.yaml，请输入或拖入 Flutter 项目根目录：" raw_path
    if resolved_root="$(resolve_project_root_from_input "$raw_path")"; then
      print -r -- "$resolved_root"
      return 0
    fi
    warn_echo "该目录下没有 pubspec.yaml，请重新输入。" >&2
  done
}

# 根据参数、脚本目录或手动输入确定工程根目录。
resolve_project_root() {
  if [[ -n "$INPUT_PROJECT" ]]; then
    if PROJECT_ROOT="$(resolve_project_root_from_input "$INPUT_PROJECT")"; then
      return 0
    fi
    warn_echo "传入路径不是合法工程根目录：$INPUT_PROJECT"
    PROJECT_ROOT="$(ask_project_root_until_valid)"
  elif PROJECT_ROOT="$(find_pubspec_upwards "$SCRIPT_DIR")"; then
    return 0
  else
    PROJECT_ROOT="$(ask_project_root_until_valid)"
  fi
}

# 检查工程类型并初始化工程相关路径。
prepare_project_context() {
  cd "$PROJECT_ROOT"
  PROJECT_NAME="$(basename "$PROJECT_ROOT")"
  PACKAGE_CONFIG="$PROJECT_ROOT/.dart_tool/package_config.json"
  info_echo "Flutter 工程根目录：$PROJECT_ROOT"

  if ! grep -Eq '^[[:space:]]*flutter:' "$PROJECT_ROOT/pubspec.yaml"; then
    warn_echo "pubspec.yaml 中未检测到 flutter: 配置，将按 Dart 工程继续处理。"
  fi
}

# 按项目 FVM、系统 FVM、全局 Flutter 的顺序选择命令。
resolve_flutter_command() {
  if [[ -x "$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER_CMD=("$PROJECT_ROOT/.fvm/flutter_sdk/bin/flutter")
    info_echo "使用项目内 FVM Flutter。"
  elif command -v fvm >/dev/null 2>&1 && { [[ -f "$PROJECT_ROOT/.fvmrc" ]] || [[ -d "$PROJECT_ROOT/.fvm" ]]; }; then
    FLUTTER_CMD=(fvm flutter)
    info_echo "使用系统 FVM Flutter。"
  elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD=(flutter)
    info_echo "使用全局 Flutter。"
  else
    fail "未找到 Flutter。请先安装 Flutter 或把 flutter 加入 PATH。"
  fi
}

# 询问是否执行普通安装或更新动作，直接回车表示跳过。
ask_any_to_run() {
  local answer=""
  read -r "?$1（直接回车跳过；输入任意字符后回车执行）：" answer
  [[ -n "$answer" ]]
}

# 按交互结果刷新依赖解析文件，或复用工程现有文件。
prepare_package_config() {
  if (( RUN_PUB_GET == 1 )); then
    if ask_any_to_run "是否执行 flutter pub get 以刷新依赖解析文件？"; then
      info_echo "正在执行 flutter pub get..."
      "${FLUTTER_CMD[@]}" pub get 2>&1 | tee -a "$LOG_FILE"
      success_echo "flutter pub get 执行完成。"
    else
      note_echo "已跳过 flutter pub get。"
    fi
  else
    note_echo "已通过 --no-pub-get 跳过 flutter pub get。"
  fi

  [[ -f "$PACKAGE_CONFIG" ]] || fail "未找到 ${PACKAGE_CONFIG}。请重新运行并选择执行 flutter pub get。"
}

# 检查本次执行所需的系统命令和可选工具。
check_environment() {
  command -v ruby >/dev/null 2>&1 || fail "未找到 Ruby，无法解析 package_config.json。"
  command -v rsync >/dev/null 2>&1 || fail "未找到 rsync，无法复制依赖目录。"
  command -v ditto >/dev/null 2>&1 || fail "未找到 macOS ditto，当前脚本仅支持 macOS。"
  if (( SELECT_MODE == 1 )) && ! command -v fzf >/dev/null 2>&1; then
    fail "已启用 --select，但未找到 fzf；可先执行 brew install fzf。"
  fi
}

# 创建本次打包使用的临时目录、清单路径和桌面输出路径。
prepare_output_paths() {
  local timestamp="$(date +%Y%m%d_%H%M%S)"
  local desktop_path="$HOME/Desktop"
  mkdir -p "$desktop_path"

  ZIP_PATH="$desktop_path/${PROJECT_NAME}_flutter_deps_${timestamp}.zip"
  TMP_PARENT="$(mktemp -d "/tmp/${PROJECT_NAME}_flutter_deps_${timestamp}.XXXXXX")"
  STAGE_NAME="${PROJECT_NAME}_flutter_deps_${timestamp}"
  STAGE="$TMP_PARENT/$STAGE_NAME"
  ALL_DEPS_TSV="$STAGE/manifest/all_package_roots.tsv"
  SELECTED_DEPS_TSV="$STAGE/manifest/selected_package_roots.tsv"
  mkdir -p "$STAGE/manifest" "$STAGE/dart_packages" "$STAGE/native" "$STAGE/project_files"
}

# 删除当前脚本创建的临时打包目录。
cleanup_temp_files() {
  [[ -n "${TMP_PARENT:-}" && -d "$TMP_PARENT" && "$TMP_PARENT" == /tmp/* ]] || return 0
  rm -rf -- "$TMP_PARENT"
}

# 从 package_config.json 提取工程实际解析到的依赖根目录。
extract_package_roots() {
  info_echo "正在解析 package_config.json..."
  ruby -rjson -ruri -e '
config = File.expand_path(ARGV[0])
project_root = File.expand_path(ARGV[1])
pub_cache = File.expand_path(ENV["PUB_CACHE"] || File.join(Dir.home, ".pub-cache"))
base_dir = File.dirname(config)
base_uri = "file://#{base_dir}/"

JSON.parse(File.read(config)).fetch("packages", []).each do |pkg|
  name = pkg["name"].to_s
  root_uri = pkg["rootUri"].to_s
  next if name.empty? || root_uri.empty?

  begin
    uri = URI.parse(root_uri)
    if uri.scheme.nil?
      path = URI::DEFAULT_PARSER.unescape(URI.join(base_uri, root_uri).path)
    elsif uri.scheme == "file"
      path = URI::DEFAULT_PARSER.unescape(uri.path)
    else
      next
    end
  rescue URI::InvalidURIError
    path = File.expand_path(root_uri, base_dir)
  end

  path = File.expand_path(path)
  next if path == project_root || !File.directory?(path)

  type = if path.start_with?(pub_cache + "/")
           "pub-cache"
         elsif path.include?("/flutter/") || path.include?("/flutter_sdk/")
           "flutter-sdk"
         else
           "local-or-path"
         end
  puts [name, path, type].join("\t")
end
' "$PACKAGE_CONFIG" "$PROJECT_ROOT" | sort -u > "$ALL_DEPS_TSV"

  TOTAL_COUNT="$(wc -l < "$ALL_DEPS_TSV" | tr -d ' ')"
  (( TOTAL_COUNT > 0 )) || fail "未从 package_config.json 提取到依赖包路径。"
  success_echo "共发现 ${TOTAL_COUNT} 个依赖包根目录。"
}

# 根据运行模式全选依赖，或通过 fzf 接收用户多选结果。
select_package_roots() {
  local selected_lines=""
  if (( SELECT_MODE == 1 )); then
    info_echo "进入 fzf 多选：Tab 选中，Enter 确认，Esc 取消。"
    selected_lines="$(fzf -m \
      --delimiter=$'\t' \
      --with-nth=1,3,2 \
      --header='Tab 多选依赖；Enter 确认；Esc 取消' \
      --preview='printf "%s\n" {} | awk -F"\t" '\''{print "name: " $1 "\ntype: " $3 "\npath: " $2}'\''' \
      < "$ALL_DEPS_TSV" || true)"
    [[ -n "$selected_lines" ]] || fail "没有选择任何依赖，已取消。"
    print -r -- "$selected_lines" > "$SELECTED_DEPS_TSV"
  else
    cp -p "$ALL_DEPS_TSV" "$SELECTED_DEPS_TSV"
  fi

  SELECTED_COUNT="$(wc -l < "$SELECTED_DEPS_TSV" | tr -d ' ')"
  info_echo "本次将打包 ${SELECTED_COUNT} 个 Dart / Flutter 依赖。"
}

# 复制目录并跳过版本库、缓存和构建产物。
copy_dir() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$(dirname "$target_dir")"
  rsync -a \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='Pods/' \
    --exclude='.dart_tool/' \
    --exclude='build/' \
    --exclude='DerivedData/' \
    --exclude='.packages' \
    "$source_dir/" "$target_dir/"
}

# 在源文件存在时保留属性复制到目标路径。
copy_file_if_exists() {
  local source_file="$1"
  local target_file="$2"
  [[ -f "$source_file" ]] || return 0
  mkdir -p "$(dirname "$target_file")"
  cp -p "$source_file" "$target_file"
}

# 在源目录存在时复制原生依赖目录。
copy_dir_if_exists() {
  local source_dir="$1"
  local target_dir="$2"
  [[ -d "$source_dir" ]] || return 0
  info_echo "复制原生依赖目录：${source_dir#$PROJECT_ROOT/}"
  copy_dir "$source_dir" "$target_dir"
}

# 按工程相对路径复制依赖解析文件。
copy_project_file_rel() {
  local source_file="$1"
  [[ -f "$source_file" ]] || return 0
  local relative_path="${source_file#$PROJECT_ROOT/}"
  copy_file_if_exists "$source_file" "$STAGE/project_files/$relative_path"
}

# 复制选中的 Dart / Flutter 包并记录源路径映射。
copy_dart_packages() {
  local copied_manifest="$STAGE/manifest/copied_package_roots.tsv"
  local package_name=""
  local package_path=""
  local package_type=""
  local safe_name=""
  local target_dir=""
  : > "$copied_manifest"

  while IFS=$'\t' read -r package_name package_path package_type; do
    [[ -n "$package_name" && -d "$package_path" ]] || continue
    safe_name="$(print -rn -- "$package_name" | tr -c 'A-Za-z0-9._-' '_')"
    target_dir="$STAGE/dart_packages/$safe_name"
    info_echo "复制依赖：$package_name"
    copy_dir "$package_path" "$target_dir"
    printf '%s\t%s\t%s\t%s\n' "$package_name" "$package_path" "$package_type" "dart_packages/$safe_name" >> "$copied_manifest"
  done < "$SELECTED_DEPS_TSV"
}

# 复制 pub、CocoaPods、SwiftPM 和 Gradle 相关工程文件。
copy_project_dependency_files() {
  local search_root=""
  local found_file=""

  copy_project_file_rel "$PROJECT_ROOT/pubspec.yaml"
  copy_project_file_rel "$PROJECT_ROOT/pubspec.lock"
  copy_project_file_rel "$PROJECT_ROOT/.metadata"
  copy_project_file_rel "$PROJECT_ROOT/analysis_options.yaml"
  copy_project_file_rel "$PROJECT_ROOT/.dart_tool/package_config.json"
  copy_project_file_rel "$PROJECT_ROOT/.dart_tool/package_graph.json"
  copy_project_file_rel "$PROJECT_ROOT/ios/Podfile"
  copy_project_file_rel "$PROJECT_ROOT/ios/Podfile.lock"
  copy_project_file_rel "$PROJECT_ROOT/macos/Podfile"
  copy_project_file_rel "$PROJECT_ROOT/macos/Podfile.lock"

  copy_dir_if_exists "$PROJECT_ROOT/ios/Pods" "$STAGE/native/ios/Pods"
  copy_dir_if_exists "$PROJECT_ROOT/macos/Pods" "$STAGE/native/macos/Pods"
  copy_dir_if_exists "$PROJECT_ROOT/ios/.symlinks" "$STAGE/native/ios/.symlinks"
  copy_dir_if_exists "$PROJECT_ROOT/macos/.symlinks" "$STAGE/native/macos/.symlinks"
  copy_dir_if_exists "$PROJECT_ROOT/build/ios/SwiftPackages" "$STAGE/native/ios/SwiftPackages"
  copy_dir_if_exists "$PROJECT_ROOT/build/macos/SwiftPackages" "$STAGE/native/macos/SwiftPackages"

  for search_root in "$PROJECT_ROOT/ios" "$PROJECT_ROOT/macos"; do
    [[ -d "$search_root" ]] || continue
    while IFS= read -r -d '' found_file; do
      copy_project_file_rel "$found_file"
    done < <(find "$search_root" -name 'Package.resolved' -type f -print0 2>/dev/null)
  done

  if [[ -d "$PROJECT_ROOT/android" ]]; then
    while IFS= read -r -d '' found_file; do
      copy_project_file_rel "$found_file"
    done < <(find "$PROJECT_ROOT/android" \( \
      -name 'build.gradle' -o \
      -name 'build.gradle.kts' -o \
      -name 'settings.gradle' -o \
      -name 'settings.gradle.kts' -o \
      -name 'gradle.properties' -o \
      -name 'libs.versions.toml' \
    \) -type f -print0 2>/dev/null)
  fi
}

# 生成压缩包内的环境清单和使用说明。
write_package_manifest() {
  {
    echo "Project name: $PROJECT_NAME"
    echo "Project root: $PROJECT_ROOT"
    echo "Created at: $(date)"
    echo "Select mode: $SELECT_MODE"
    echo "Package config: $PACKAGE_CONFIG"
    echo "Selected packages: $SELECTED_COUNT / $TOTAL_COUNT"
    echo "Zip path: $ZIP_PATH"
  } > "$STAGE/manifest/project_info.txt"

  ("${FLUTTER_CMD[@]}" --version || true) > "$STAGE/manifest/flutter_version.txt" 2>&1
  ("${FLUTTER_CMD[@]}" pub deps --style=compact || true) > "$STAGE/manifest/flutter_pub_deps_compact.txt" 2>&1

  cat > "$STAGE/README.txt" <<'README'
目录说明：
- dart_packages/：package_config.json 实际解析到的 Dart / Flutter 包源码。
- native/：工程现有的 CocoaPods、旧版插件 symlink 和 SwiftPM 输出。
- project_files/：pubspec、Podfile.lock、Package.resolved、Gradle 声明等文件。
- manifest/：依赖清单、Flutter 版本、pub deps 输出与复制路径映射。

注意：
1. 不复制整个 ~/.gradle/caches，避免压缩包体积失控。
2. Pods 不存在时不会自动执行 pod install。
3. --select 只筛选 Dart / Flutter 包，原生依赖仍按工程现状复制。
README
}

# 使用 macOS ditto 生成保留父目录结构的 Zip 压缩包。
create_zip_archive() {
  local zip_size=""
  info_echo "开始压缩到桌面：$ZIP_PATH"
  (cd "$TMP_PARENT" && ditto -c -k --sequesterRsrc --keepParent "$STAGE_NAME" "$ZIP_PATH")
  [[ -f "$ZIP_PATH" ]] || fail "压缩失败：$ZIP_PATH"
  zip_size="$(du -h "$ZIP_PATH" | awk '{print $1}')"
  success_echo "打包完成：$ZIP_PATH"
  success_echo "压缩包大小：$zip_size"
  gray_echo "执行日志：$LOG_FILE"
}

# 编排完整的依赖解析、复制与压缩流程。
run_main_flow() {
  # 解析运行参数，确定选择模式、pub get 策略和可选工程路径。
  parse_arguments "$@"
  # 展示配套 README，确保用户理解脚本用途和影响范围后再继续。
  show_readme_and_wait
  # 定位包含 pubspec.yaml 的 Flutter / Dart 工程根目录。
  resolve_project_root
  # 初始化工程名称、依赖配置路径并检查工程类型。
  prepare_project_context
  # 按项目 FVM、系统 FVM、全局 Flutter 的顺序选择可用命令。
  resolve_flutter_command
  # 根据用户确认结果刷新或复用 package_config.json。
  prepare_package_config
  # 检查 Ruby、rsync、ditto 以及可选 fzf 是否可用。
  check_environment
  # 创建桌面输出路径、临时工作区和依赖清单路径。
  prepare_output_paths
  # 注册退出清理，确保本次创建的临时目录不会残留。
  trap cleanup_temp_files EXIT
  # 从 package_config.json 提取工程实际解析到的包根目录。
  extract_package_roots
  # 根据全量或 fzf 多选模式生成本次待复制依赖清单。
  select_package_roots
  # 复制选中的 Dart / Flutter 包源码并记录路径映射。
  copy_dart_packages
  # 复制 pub、CocoaPods、SwiftPM 与 Gradle 相关工程文件。
  copy_project_dependency_files
  # 写入环境信息、依赖统计和压缩包目录说明。
  write_package_manifest
  # 使用 macOS ditto 生成最终 Zip 压缩包并输出结果。
  create_zip_archive
}

# 将主入口统一委托给完整业务流程。
main() {
  # 调用完整业务流程，避免入口承载条件判断和业务细节。
  run_main_flow "$@"
}

main "$@"
