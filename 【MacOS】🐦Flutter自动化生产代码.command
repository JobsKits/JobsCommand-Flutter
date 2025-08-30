#!/bin/zsh
# ================================== 自述 / 说明 ==================================
print_description() {
  cat <<'DESC'
[目的]
1) 自述：脚本会确保你在 Flutter 项目根目录。
2) 交互：等待你按下回车再开始执行。
3) 校验：判定“Flutter 根目录”的标准为：
   - 当前目录包含 lib/ 目录
   - 当前目录包含 pubspec.yaml 文件

[使用方法]
- 直接在项目根或任意目录执行本脚本。
- 若当前目录不是 Flutter 根，脚本会循环提示你输入路径（支持拖入目录后回车）。
- 回车确认后，脚本会切换到正确的项目根目录并结束校验流程。
DESC
}

# ================================== 等待用户回车 ==================================
wait_for_user_to_start() {
  echo ""
  read "?👉 按下回车开始执行（Ctrl+C 取消）"
  echo ""
}

# ================================== 判定是否为 Flutter 根目录 ==================================
# 标准：存在 lib/ 目录 + pubspec.yaml 文件
is_flutter_project_root() {
  local dir="$1"
  [[ -d "$dir/lib" && -f "$dir/pubspec.yaml" ]]
}

# ================================== 路径规范化（去引号、反斜杠空格、转绝对路径） ==================================
to_abs_path() {
  local in="$1"
  local p="$in"

  # 去掉首尾空白
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"

  # 去掉包裹引号
  p="${p%\"}"; p="${p#\"}"
  p="${p%\'}"; p="${p#\'}"

  # Finder 拖拽产生的空格转义（\ ）还原
  p="${p//\\ / }"

  # 处理 ~
  [[ "$p" = ~* ]] && p="${p/#\~/$HOME}"

  # 转绝对路径（存在才转）
  if [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd)
  else
    # 不存在则原样返回，后续让调用方给出错误提示
    printf "%s\n" "$p"
  fi
}

# ================================== 循环查找并切换到项目根 ==================================
detect_and_cd_to_flutter_root() {
  while true; do
    if is_flutter_project_root "$PWD"; then
      echo "✅ 已确认 Flutter 项目目录：$PWD"
      return 0
    fi

    echo "❌ 当前目录不是 Flutter 项目根：$PWD"
    echo "   需要同时存在：lib/ 与 pubspec.yaml"
    echo ""
    echo "提示：可以将项目根目录从 Finder 拖入到终端后按回车。"
    read "input_path?👉 请输入 Flutter 项目路径（或直接回车重新检测当前目录）： "

    # 直接回车：再次检测当前目录（允许你自己先 cd 后再回车）
    if [[ -z "$input_path" ]]; then
      continue
    fi

    local abs
    abs="$(to_abs_path "$input_path")"

    if [[ ! -d "$abs" ]]; then
      echo "❌ 路径不存在：$abs"
      echo ""
      continue
    fi

    if is_flutter_project_root "$abs"; then
      cd "$abs" || { echo "❌ 切换目录失败：$abs"; echo ""; continue; }
      echo "✅ 已切换到 Flutter 项目目录：$PWD"
      return 0
    else
      echo "❌ [$abs] 不是合法的 Flutter 项目根（缺少 lib/ 或 pubspec.yaml）"
      echo ""
    fi
  done
}

# ================================== 主函数 ==================================
main() {
  clear
  print_description
  wait_for_user_to_start
  detect_and_cd_to_flutter_root
  
  flutter clean
  # 后续的逻辑在这里继续写，比如：
  flutter pub get
  # —— 核心 —— #
  dart run build_runner build --delete-conflicting-outputs
  dart run build_runner watch --delete-conflicting-outputs
  # —— App Icon —— #
#  dart run run flutter_launcher_icons:main
  flutter pub run flutter_launcher_icons:main
  # —— Splash —— #
  dart run flutter_native_splash:create
  # —— L10n（官方） —— #
  flutter gen-l10n
  # —— ffigen —— #
  dart run ffigen
  # —— Pigeon —— #
  dart run pigeon --input pigeons/messages.dart --dart_out lib/pigeon/messages.g.dart
  # —— Protobuf/gRPC —— #
  protoc --dart_out=grpc:lib/generated -Iprotos protos/*.proto
}

main "$@"
