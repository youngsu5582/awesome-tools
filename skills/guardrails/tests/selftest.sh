#!/usr/bin/env bash
# selftest.sh — hook 판정부의 케이스 표. hook 을 고치기 전에 먼저 돌린다(hook 은 모든 세션에 바로 적용된다).
# 필요한 것: bash · perl · jq
#
# 사용: bash tests/selftest.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

HOOKS="hooks"
export HOOK_TRACE=/dev/null   # 케이스가 실제 판정 기록에 섞이지 않게 한다
SCAN="$HOOKS/_scan-branch-switch.pl"
pass=0; fail=0

ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n     %s\n' "$1" "$2"; }

# scan <BLOCK|PASS> <라벨> <명령>
scan() {
  local expect="$1" label="$2" cmd="$3" hit rc got
  hit="$(printf '%s' "$cmd" | perl "$SCAN" 2>&1)"; rc=$?
  [ "$rc" -eq 1 ] && got=BLOCK || got=PASS
  if [ "$got" = "$expect" ]; then ok "$label"
  else bad "$label" "기대 $expect / 실제 $got${hit:+ (매치: $hit)}"; fi
}

echo "── guard-worktree 판정부 ──────────────────────────────"

# 차단해야 하는 것 — 브랜치 전환
scan BLOCK 'git checkout <branch>'          'git checkout develop'
scan BLOCK 'git switch <branch>'            'git switch main'
scan BLOCK '-f 플래그와 함께'                'git checkout -f feature/x'
scan BLOCK 'git -C <dir> 전역옵션 뒤'        'git -C /tmp/wt checkout develop'
scan BLOCK '앞에 다른 명령이 있어도'          'cd /x && git checkout develop'
scan BLOCK '뒤에 --가 있어도 (구버전 홀)'     'git checkout develop && git log --oneline'
scan BLOCK '이전 브랜치(-)'                  'git switch -'
scan BLOCK 'HEAD 분리'                      'git checkout --detach'
scan BLOCK '환경변수 대입 뒤'                'GIT_TRACE=1 git checkout develop'

# 통과해야 하는 것 — 파일 복원 · 새 브랜치 · 읽기 전용 · 문서 문장
scan PASS  '파일 복원 (-- path)'             'git checkout -- module-api/src/main/java/Foo.java'
scan PASS  '커밋 지정 파일 복원'              'git checkout HEAD -- docs/README.md'
scan PASS  '새 브랜치 생성 (-b)'              'git checkout -b feature/PROJ-999'
scan PASS  '새 브랜치 생성 (switch -c)'       'git switch -c feature/PROJ-999'
scan PASS  '부분 복원 (-p)'                  'git checkout -p'
scan PASS  '충돌 해결 --ours <파일> (실제 오차단)' 'git checkout --ours module-api/src/main/java/Foo.java'
scan PASS  '충돌 해결 --theirs <파일>'          'git checkout --theirs .claude/settings.json'
scan PASS  '커밋의 파일 꺼내기 (-- 없이)'        'git checkout develop module-api/build.gradle'
scan BLOCK '원격 추적 전환 (--track)'           'git checkout --track origin/feature/x'
scan BLOCK '변경 합치며 전환 (-m)'               'git checkout -m develop'
scan PASS  'worktree 조회'                   "git worktree list --porcelain | awk '/^worktree /{print \$2}'"
scan PASS  '읽기 전용 조합'                   'git status --porcelain && git log --oneline -3'
scan PASS  '인용 안의 문장'                   "echo 'git checkout develop 은 차단된다'"
scan PASS  'grep 패턴 안의 문장'              'grep -rn "git checkout" .claude/'
scan PASS  'heredoc 문서 문장 (실제 오차단)'   'python3 - <<PY
s = """
   git checkout 이 hook 으로 차단된다는 사실
"""
print(s)
PY'
scan PASS  'heredoc 인용 구분자'              "cat <<'EOF'
git switch develop
EOF"

echo
echo "── ask-via-tool 판정부 (_scan-question.pl) ────────────"
# 사용자 지시(2026-10-21): 글로 묻는 대부분의 형태를 AskUserQuestion 으로 유도한다.
# 오차단은 "인용·예시·기록" 자리에서 난다 — 그 자리를 PASS 케이스로 고정한다.
qscan() {  # qscan <BLOCK|PASS> <라벨> <본문>
  local expect="$1" label="$2" text="$3" hit got
  hit="$(printf '%s' "$text" | perl "$HOOKS/_scan-question.pl")"
  [ -n "$hit" ] && got=BLOCK || got=PASS
  if [ "$got" = "$expect" ]; then ok "$label"
  else bad "$label" "기대 $expect / 실제 $got${hit:+ (매치: $hit)}"; fi
}
qscan BLOCK '~할까요? 로 끝남'                 '1번 실측을 시작할까요?'
qscan BLOCK '~으세요? 존댓말 의문'              '이대로 진행해도 괜찮으세요?'
qscan BLOCK '입력 요청 (알려 주세요)'           '어느 쪽으로 할지 알려 주세요.'
qscan BLOCK '제안형 (원하시면 … 드릴게요)'      '원하시면 한 페이지로 정리해 드릴게요.'
qscan BLOCK '본문 중간의 질문'                  '설명이 있다. 이 방향이 맞나요? 설명이 이어진다.'
qscan BLOCK 'Uncertainty Map 앞의 질문'         $'정리했다.\n\n**0번을 시작해도 될까요?**\n\n## Uncertainty Map\n- 미확인'
qscan BLOCK '영어 질문'                         'Want me to run it now?'
qscan BLOCK '반말이라도 마지막 문단 물음표'     $'정리했다.\n\n이걸로 갈까?'
qscan PASS  '질문 없는 보고'                    '1번 실측을 시작했습니다.'
qscan PASS  '코드 블록 안의 물음표'             $'```\n할까요?\n```\n코드 안은 무시한다.'
qscan PASS  '인라인 코드 안의 물음표'           '`할까요?` 같은 형태를 잡는다.'
qscan PASS  '인용(>) 안의 사용자 질문'          $'> 무지성으로 만든 건 아닌가요?\n\n인용은 무시한다.'
qscan PASS  '제목의 물음표'                     $'## 왜 문서가 낡나?\n\n코드를 다시 적기 때문이다.'
qscan PASS  '표 안의 물음표'                    $'| 질문 | 결정 |\n|---|---|\n| 하네스 위치? | .harness |\n\n반영했다.'
qscan PASS  'Uncertainty Map 안의 열린 질문'    $'결과다.\n\n## Uncertainty Map\n- 클라우드에서 clone 이 되는가?'
# 2026-11-22: 따옴표 안 물음표는 옮겨 적은 말이다(차단 64건 중 7건 오탐). 확인 요청은 계속 질문으로 본다
qscan PASS  '따옴표 안의 면접 예상 질문'         '면접에서 "그래서 지금은 믿을 수 있나요?" 라고 물을 수 있다.'
qscan PASS  '둥근 따옴표 안의 도구 출력'         '설치 도구가 “다시 설치할까요?” 를 띄운다.'
qscan BLOCK '따옴표 밖의 질문은 그대로 잡는다'   '"설정" 값을 바꿔도 될까요?'
qscan BLOCK '조건부 확인 요청도 질문이다'        '그림이 안 보이면 알려 주세요.'

echo
echo "── ask-via-tool 훅 (턴 경계 · 통과 조건) ─────────────"
_Q="$(mktemp -d)"
tx_user() { jq -nc --arg t "$1" '{type:"user", message:{role:"user", content:$t}}'; }
tx_text() { jq -nc --arg t "$1" '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:$t}]}}'; }
tx_ask()  { jq -nc '{type:"assistant", message:{role:"assistant", content:[{type:"tool_use", name:"AskUserQuestion", input:{}}]}}'; }
tx_res()  { jq -nc '{type:"user", message:{role:"user", content:[{type:"tool_result", content:"답"}]}}'; }
# stopq <기대 exit> <라벨> <stop_hook_active> <entrypoint> <transcript 줄들…>
stopq() {
  local expect="$1" label="$2" active="$3" ep="$4" rc; shift 4
  printf '%s\n' "$@" > "$_Q/t.jsonl"
  jq -nc --arg p "$_Q/t.jsonl" --argjson a "$active" '{transcript_path:$p, stop_hook_active:$a, cwd:"/tmp"}' \
    | CLAUDE_CODE_ENTRYPOINT="$ep" bash "$HOOKS/ask-via-tool.sh" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq "$expect" ]; then ok "$label (exit $rc)"; else bad "$label" "기대 exit $expect / 실제 $rc"; fi
}
stopq 2 '글로 묻고 끝난 턴 → 돌려보냄'            false cli "$(tx_user '하자')" "$(tx_text '1번부터 시작할까요?')"
stopq 0 '도구로 묻고 답 받은 뒤 보고 → 통과'       false cli "$(tx_user '하자')" "$(tx_text '아래에 답해 주세요.')" "$(tx_ask)" "$(tx_res)" "$(tx_text '답을 반영했습니다.')"
stopq 2 '답 받은 뒤 다시 글로 물음 → 돌려보냄'     false cli "$(tx_user '하자')" "$(tx_ask)" "$(tx_res)" "$(tx_text '그럼 2번도 할까요?')"
stopq 0 '질문 직전 안내 후 도구로 끝남 → 통과'     false cli "$(tx_user '하자')" "$(tx_text '아래에 답해 주세요.')" "$(tx_ask)"
stopq 0 '지난 턴의 질문은 보지 않는다'             false cli "$(tx_user '하자')" "$(tx_text '시작할까요?')" "$(tx_user '응')" "$(tx_text '완료했습니다.')"
stopq 0 '이미 한 번 돌려보냄(stop_hook_active)'    true  cli "$(tx_user '하자')" "$(tx_text '1번부터 시작할까요?')"
stopq 0 'claude -p 는 통과(도구를 못 쓴다)'        false sdk-cli "$(tx_user '하자')" "$(tx_text '1번부터 시작할까요?')"
rm -rf "$_Q"

echo
echo "── 판정 기록 칸 (session= · wt=) ─────────────────────"
# 입력에 세션 id · cwd 가 있으면 줄 끝에 붙고, 없으면 예전 형식 그대로다. 앞 칸 위치는 바뀌지 않는다.
# TMPDIR 을 바꾸는 이유 — _lib.sh 가 세션 id 를 $TMPDIR/claude-session-current 에 적는다. 실제 파일을 덮지 않게 한다
_TR="$(mktemp)"; _TD="$(mktemp -d)"
printf '{"session_id":"11111111-2222-3333-4444-555555555555","cwd":"/tmp/wt/feature-x","tool_name":"Bash","tool_input":{"command":"git status"}}' \
  | HOOK_TRACE="$_TR" TMPDIR="$_TD" bash "$HOOKS/guard-worktree.sh" >/dev/null 2>&1
line="$(tail -1 "$_TR")"
case "$line" in
  *$'\tguard-worktree\tpass\t\tstdin=yes\tagent=claude\tsession=11111111-2222-3333-4444-555555555555\twt=feature-x') ok '세션 id · cwd 가 있으면 줄 끝에 session= · wt=' ;;
  *) bad '세션 id · cwd 가 있으면 줄 끝에 session= · wt=' "$line" ;;
esac
printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
  | env -u CLAUDE_PROJECT_DIR HOOK_TRACE="$_TR" TMPDIR="$_TD" bash "$HOOKS/guard-worktree.sh" >/dev/null 2>&1
line="$(tail -1 "$_TR")"
case "$line" in
  *$'\tstdin=yes\tagent=claude') ok '  └ 없으면 예전 형식 그대로' ;;
  *) bad '  └ 없으면 예전 형식 그대로' "$line" ;;
esac
rm -rf "$_TR" "$_TD"

echo
echo "── 구문 검사 ─────────────────────────────────────────"
for f in "$HOOKS"/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n $(basename "$f")"; else bad "bash -n $(basename "$f")" "구문 오류"; fi
done
for f in "$HOOKS"/*.pl; do
  if perl -c "$f" >/dev/null 2>&1; then ok "perl -c $(basename "$f")"; else bad "perl -c $(basename "$f")" "구문 오류"; fi
done

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32mPASS\033[0m  %d건 통과\n' "$pass"; exit 0
else
  printf '\033[31mFAIL\033[0m  %d건 통과 / %d건 실패\n' "$pass" "$fail"; exit 1
fi
