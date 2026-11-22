#!/usr/bin/env bash
# _lib.sh — hook 공통 유틸. 각 hook 이 첫 줄에서 source 한다.
#
# 왜 있는가
#   기존 hook 8개는 CLAUDE_FILE_PATH 등 **환경변수**를 전제했는데
#   현재 Claude Code 는 **stdin JSON** 으로 넘긴다(다른 도구용 계약을 그대로 가져왔다).
#   그래서 전부 첫 가드에서 조용히 exit 0 했다 — 8개가 있는데 강제는 0이었다.
#
#   계약을 단정하지 않는다. **양쪽 다 읽고**, 실제로 무엇이 왔는지 trace 에 남긴다.
#   한 세션 뒤 trace 를 보면 어느 계약이 살아 있는지 확정된다.

# 판정 기록은 달마다 한 파일로 영구 보존한다 — $TMPDIR 는 재부팅·정리로 사라져
# 기간별 차단 추이를 볼 수 없었다(하루치만 남아 있었다)
HOOK_TRACE="${HOOK_TRACE:-$HOME/.harness-runs/hook-trace/$(date +%Y-%m).log}"   # selftest 는 /dev/null 로 돌린다
[ -d "${HOOK_TRACE%/*}" ] || mkdir -p "${HOOK_TRACE%/*}" 2>/dev/null

# stdin JSON 을 한 번만 읽어 캐시한다 (여러 번 읽을 수 없다)
#
# ⚠️ 실측(2026-08-05): Claude Code 는 hook stdin 을 **소켓**으로 넘긴다.
#    `[ -p /dev/stdin ] || [ -f /dev/stdin ]` 같은 사전 검사는 소켓을 통과시키지 못해
#    읽기를 건너뛴다 — hook 4개가 142회 발화하면서 전부 입력 없이 exit 0 했다.
#    perl alarm 이 이미 1초 상한을 걸므로 **사전 검사는 불필요하고 해롭다.**
#    (환경변수 CLAUDE_FILE_PATH / CLAUDE_BASH_COMMAND 는 아예 존재하지 않는다 — opencode 계약은 죽었다.
#     fallback 은 무해하므로 남겨둔다.)
_HOOK_INPUT=""
if [ ! -t 0 ]; then
  _HOOK_INPUT="$(perl -e 'eval{ local $SIG{ALRM}=sub{die}; alarm 1; local $/; my $d=<STDIN>; alarm 0; print $d if defined $d; }' 2>/dev/null || true)"
fi

# hook_field <jq경로> <환경변수명>  — stdin JSON 우선, 환경변수 fallback
hook_field() {
  local jqpath="$1" envname="$2" v=""
  if [ -n "$_HOOK_INPUT" ] && command -v jq >/dev/null 2>&1; then
    v="$(printf '%s' "$_HOOK_INPUT" | jq -r "$jqpath // empty" 2>/dev/null || true)"
  fi
  [ -z "$v" ] && v="$(eval "printf '%s' \"\${$envname:-}\"")"
  printf '%s' "$v"
}

hook_trace() {  # hook_trace <hook이름> <판정> <상세>  — 끝 칸 agent= 는 Claude·Codex 구분용
  # session= · wt= 는 입력에 있을 때만 붙인다 — 어느 대화 · 어느 워크트리의 판정인지 (2026-11-22).
  #   앞 칸 위치는 바뀌지 않는다. 브랜치는 판정마다 git 을 불러야 해서 넣지 않는다
  local extra=""
  [ -n "${HOOK_SESSION_ID:-}" ] && extra="${extra}"$'\t'"session=${HOOK_SESSION_ID}"
  [ -n "${HOOK_CWD:-}" ] && extra="${extra}"$'\t'"wt=${HOOK_CWD##*/}"
  printf '%s\t%s\t%s\t%s\tstdin=%s\tagent=%s%s\n' \
    "$(date +%FT%T)" "$1" "$2" "${3:-}" \
    "$([ -n "$_HOOK_INPUT" ] && echo yes || echo no)" "${HOOK_AGENT:-claude}" "$extra" >> "$HOOK_TRACE" 2>/dev/null || true
}

# hook_block <메시지>  — 도구 실행을 차단한다.
#   Claude Code 는 PreToolUse hook 의 exit 2 를 차단으로 해석하고 stderr 를 모델에 전달한다.
hook_block() {
  echo "$1" >&2
  exit 2
}

hook_warn() { echo "$1" >&2; exit 0; }

HOOK_CWD="$(hook_field '.cwd' _HOOK_NONE)"   # 세션 cwd — 판정 기록의 wt=. 다른 hook 이 REPO_ROOT 를 바꿔도 이 값은 남는다
REPO_ROOT="${HOOK_CWD:-${CLAUDE_PROJECT_DIR:-}}"
[ -z "$REPO_ROOT" ] && REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# ── 도구 입력 정규화 — Claude Code · Codex 가 같은 hook 을 쓴다 ─────────────
#   Codex 훅은 Claude 와 같은 계약이다(tool_name · tool_input · exit 2 차단). 다른 것은 편집 하나다.
#     Claude: Edit/Write 의 tool_input.file_path 하나 + content/new_string
#     Codex : 편집이 apply_patch 한 번이고, 경로·내용이 tool_input.command 의 **패치 본문**에 있다
#             (`*** Add File:` · `*** Update File:` · `*** Delete File:` · `*** Move to:` 머리줄, `+` 줄이 새 내용)
#   file_path 만 읽던 가드 4개는 Codex 편집을 전부 "file_path 없음" 으로 통과시켰다.
#   HOOK_AGENT=codex 로 넘기면 Codex 로 본다. 그 밖은 Claude 다.
HOOK_AGENT="${HOOK_AGENT:-claude}"
HOOK_TOOL="$(hook_field '.tool_name' _HOOK_NONE)"

# Bash 명령. 배열로 오면 `["bash","-lc","<스크립트>"]` 는 스크립트만, 그 밖은 공백으로 잇는다
#   (통째로 이으면 git 이 명령 위치에 안 와서 _scan-branch-switch.pl 이 놓친다 — selftest 로 확인)
hook_command() {
  hook_field '.tool_input.command | if type=="array" then
      (if length >= 3 and (.[0] | test("(^|/)(ba|z)?sh$")) and (.[-2] | test("^-[a-z]*c$")) then .[-1] else join(" ") end)
    else . end' CLAUDE_BASH_COMMAND
}

# 편집 대상 경로 — 한 줄에 하나. 패치의 상대경로는 REPO_ROOT 기준으로 붙인다
hook_targets() {
  local f p
  f="$(hook_field '.tool_input.file_path' CLAUDE_FILE_PATH)"
  if [ -n "$f" ]; then printf '%s\n' "$f"; return 0; fi
  [ "$HOOK_TOOL" = apply_patch ] || return 0
  hook_command | sed -nE 's/^\*\*\* (Add File|Update File|Delete File|Move to): (.+)$/\2/p' \
    | while IFS= read -r p; do
        case "$p" in /*) printf '%s\n' "$p" ;; *) printf '%s\n' "$REPO_ROOT/$p" ;; esac
      done
}

# 새로 쓰는 내용 — Write content · Edit new_string · 패치의 + 줄
hook_new_text() {
  local c
  c="$(hook_field '.tool_input.content' CLAUDE_TOOL_CONTENT)"
  [ -z "$c" ] && c="$(hook_field '.tool_input.new_string' CLAUDE_NEW_STRING)"
  [ -z "$c" ] && [ "$HOOK_TOOL" = apply_patch ] && c="$(hook_command | sed -nE 's/^\+//p')"
  printf '%s' "$c"
}

# 세션 정체 — payload 가 알려준다 (추측하지 않는다). 판정 기록의 session= 과 ask-via-tool 이 쓴다
HOOK_SESSION_ID="$(hook_field '.session_id' CLAUDE_SESSION_ID)"
HOOK_TRANSCRIPT="$(hook_field '.transcript_path' CLAUDE_TRANSCRIPT_PATH)"
