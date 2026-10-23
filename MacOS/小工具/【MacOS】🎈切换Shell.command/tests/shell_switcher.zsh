#!/bin/zsh
# 用替身验证账户修改分支；不会调用真实 chsh。
set -eu
source "${0:A:h:h}/【MacOS】🎈切换Shell.command"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/jobs-shell-tests.XXXXXX")"
trap 'rm -rf -- "$test_dir"' EXIT
LOG_FILE="$test_dir/log"
test_calls="$test_dir/calls"
touch "$test_calls"
test_current='/not-the-selected-shell'
test_failure=0
test_verify_failure=0
test_picker_result=0
test_selection=''

# 使用真实的选择流程，把 fzf 替换为“直接回车，返回第一项”的程序。
# 分别模拟不同的账户默认值，确保没有写死 zsh，也不会误入 chsh。
cat > "$test_dir/fzf" <<'FZF'
#!/bin/zsh
print -rl -- "$@" > "$JOBS_TEST_FZF_DIR/args"
/bin/cat > "$JOBS_TEST_FZF_DIR/input"
/usr/bin/head -n 1 "$JOBS_TEST_FZF_DIR/input"
FZF
chmod +x "$test_dir/fzf"
(
  export JOBS_TEST_FZF_DIR="$test_dir"
  find_fzf() { print -r -- "$test_dir/fzf"; }
  require_terminal() { return 0; }
  current_login_shell() { print -r -- "$test_default"; }
  change_login_shell() { print -r -- unexpected >> "$test_calls"; return 1; }
  for test_default in /bin/zsh /bin/bash; do
    switch_shell < /dev/null > "$test_dir/enter" 2>&1
    [[ "$(head -n 1 "$test_dir/input")" == "$test_default" ]]
    [[ "$(grep -Fxc -- "$test_default" "$test_dir/input")" == 1 ]]
    grep -Fxq -- '--no-sort' "$test_dir/args"
    grep -q '无需修改' "$test_dir/enter"
    [[ ! -s "$test_calls" ]]
  done
  # 未知 / 不可选默认值不能继续展示其它 Shell 作为默认选项。
  rm "$test_dir/input"
  for test_default in '' /tmp/not-an-available-shell; do
    if switch_shell < /dev/null > "$test_dir/unknown-default" 2>&1; then
      print -u2 '错误：未确认当前默认 Shell 仍继续选择'; exit 1
    fi
    [[ ! -e "$test_dir/input" && ! -s "$test_calls" ]]
  done
)

current_login_shell() { print -r -- "$test_current"; }
change_login_shell() {
  print -r -- "$1" >> "$test_calls"
  (( test_failure == 0 )) || return 1
  if (( ! test_verify_failure )); then test_current="$1"; fi
  return 0
}
require_terminal() { return 0; }
select_shell_with_fzf() {
  (( test_picker_result == 0 )) || return "$test_picker_result"
  print -r -- "$test_selection"
}
assert_calls() {
  [[ "$(wc -l < "$test_calls" | tr -d ' ')" == "$1" ]] || {
    print -u2 -r -- "错误：预期 $1 次 chsh 调用"; exit 1
  }
}

read_available_shells
selected="${available_shells[1]}"
test_selection="$selected"
[[ "$selected" == /* && -x "$selected" ]]

# 无效目标不得进入 chsh。
if apply_selected_shell '/tmp/not-a-login-shell' > "$test_dir/invalid" 2>&1; then
  print -u2 '错误：非法 Shell 被接受'; exit 1
fi
assert_calls 0

# 已是默认值时无需修改。
test_current="$selected"
apply_selected_shell "$selected" > "$test_dir/same" 2>&1
assert_calls 0

# fzf 取消、无匹配、确认时 EOF / 非 YES 均无账户副作用。
test_current='/not-the-selected-shell'
test_picker_result=130
switch_shell < /dev/null > "$test_dir/cancel" 2>&1
test_picker_result=1
switch_shell < /dev/null > "$test_dir/cancel" 2>&1
test_picker_result=0
switch_shell < /dev/null > "$test_dir/cancel" 2>&1
switch_shell <<< 'no' > "$test_dir/cancel" 2>&1
test_selection=''
switch_shell < /dev/null > "$test_dir/cancel" 2>&1
test_selection='/tmp/not-a-login-shell'
if switch_shell <<< 'YES' > "$test_dir/invalid-selection" 2>&1; then
  print -u2 '错误：fzf 返回的非法目标被接受'; exit 1
fi
test_selection="$selected"
test_picker_result=2
if switch_shell < /dev/null > "$test_dir/picker-error" 2>&1; then
  print -u2 '错误：fzf 故障被当作成功'; exit 1
fi
test_picker_result=0
assert_calls 0

# chsh 失败必须向上传播，不能打印成功。
test_failure=1
if apply_selected_shell "$selected" > "$test_dir/failed" 2>&1; then
  print -u2 '错误：chsh 失败被当作成功'; exit 1
fi
! /usr/bin/grep -q '默认 Shell 已更新' "$test_dir/failed"
assert_calls 1

# chsh 返回成功但目录服务未反映结果，也不能报告成功。
test_failure=0
test_verify_failure=1
if apply_selected_shell "$selected" > "$test_dir/mismatch" 2>&1; then
  print -u2 '错误：未检查修改结果'; exit 1
fi
assert_calls 2

# 只有合法选择 + YES + 成功核验才能报告完成。
test_verify_failure=0
switch_shell <<< 'YES' > "$test_dir/success" 2>&1
assert_calls 3
[[ "$test_current" == "$selected" ]]
/usr/bin/grep -q '默认 Shell 已更新' "$test_dir/success"
print -r -- 'PASS：默认 Shell 置顶 / 去重 / 回车无修改、未知默认值阻止选择、fzf 取消 / 故障 / 非法输出、确认取消 / EOF、chsh 失败、结果核验及确认成功。'
