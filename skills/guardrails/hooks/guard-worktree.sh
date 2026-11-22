#!/usr/bin/env bash
# PreToolUse(Bash): 브랜치 전환을 **차단**한다. 다른 브랜치 작업은 worktree 로 한다.
# 실사고: 한 폴더를 여러 작업이 같이 쓰다가 작업 중이던 변경을 날렸다.
#
# 판정부는 `_scan-branch-switch.pl` 에 있다 (정규식 한 줄로는 오차단이 났다 — 그 파일 주석 참조).
source "$(dirname "$0")/_lib.sh"

CMD="$(hook_command)"
[ -z "$CMD" ] && { hook_trace guard-worktree skip "command 없음"; exit 0; }

HIT="$(printf '%s' "$CMD" | perl "$(dirname "$0")/_scan-branch-switch.pl" 2>/dev/null)"

if [ -n "$HIT" ]; then
  hook_trace guard-worktree BLOCK "$HIT"
  hook_block "차단: 브랜치 전환 대신 worktree 를 쓴다 — \`$HIT\`
  git worktree add ../{name} {branch}
  파일 복원 목적이면 'git checkout -- <path>' 형태로 쓰라 (통과한다)."
fi

hook_trace guard-worktree pass ""
exit 0
