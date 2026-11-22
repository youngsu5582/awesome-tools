#!/usr/bin/env bash
# Stop: 응답이 글로 사용자에게 묻고 끝나면 한 번 돌려보내 AskUserQuestion 으로 다시 묻게 한다.
#
# 왜 있는가
#   글로 "~할까요?" 하고 끝내면 선택지·결과·추천이 빠지고 답이 대화에 흩어진다.
#   "~할까요?" 뿐 아니라 글로 묻는 대부분의 형태를 도구 질문으로 유도한다.
#   메모리 · 문서 규칙만으로는 지켜지지 않아 기계로 옮겼다.
#
# 판정 대상 = 이번 턴의 마지막 본문. AskUserQuestion 이 나오면 그 앞 본문은 버린다 —
#   질문 앞에 쓴 안내("아래에 답해 주세요")는 통과하고, 답을 받은 뒤 다시 글로 물으면 잡힌다.
# 이번 턴 = 마지막 사람 입력(도구 결과·메타가 아닌 user 항목) 뒤의 assistant 항목
# 통과: stop_hook_active(이미 한 번 돌려보냈다) · Codex · claude -p (AskUserQuestion 을 쓸 수 없다)
# 판정부는 _scan-question.pl, 케이스 표는 tests/selftest.sh
source "$(dirname "$0")/_lib.sh"

[ "$HOOK_AGENT" = claude ] || { hook_trace ask-via-tool skip "agent=$HOOK_AGENT"; exit 0; }
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in
  cli) ;;
  *) hook_trace ask-via-tool skip "entrypoint=${CLAUDE_CODE_ENTRYPOINT}"; exit 0 ;;
esac
if [ "$(hook_field '.stop_hook_active' _HOOK_NONE)" = true ]; then
  hook_trace ask-via-tool skip "재진입"; exit 0
fi
[ -f "$HOOK_TRANSCRIPT" ] || { hook_trace ask-via-tool skip "transcript 없음"; exit 0; }

# 줄마다 u(사람 입력) · ask(AskUserQuestion) · t(본문) 로 줄인 뒤, 마지막 u 이후만 접는다
turn="$(tail -n 1500 "$HOOK_TRANSCRIPT" | jq -c '
  if .type == "user" and ((.isMeta // false) | not)
     and (.message.content | if type == "string" then true
                             elif type == "array" then any(.[]; .type == "text") else false end)
  then {k: "u"}
  elif .type == "assistant" and (.message.content | type) == "array"
  then .message.content[]
       | if .type == "tool_use" and .name == "AskUserQuestion" then {k: "ask"}
         elif .type == "text" then {k: "t", x: .text} else empty end
  else empty end' 2>/dev/null \
  | jq -s -c 'reduce .[] as $r ({text: ""};
      if $r.k == "t" then .text = $r.x else {text: ""} end)' 2>/dev/null)"

[ -n "$turn" ] || { hook_trace ask-via-tool skip "턴 해석 실패"; exit 0; }

hit="$(printf '%s' "$turn" | jq -r '.text' | perl "$(dirname "$0")/_scan-question.pl")"
if [ -n "$hit" ]; then
  hook_trace ask-via-tool BLOCK "$hit"
  hook_block "응답이 글로 사용자에게 묻고 끝났다: «${hit}»
  → AskUserQuestion 으로 다시 물어라. 선택지 2~4개, 각 선택의 결과, 추천에는 (Recommended).
  → 의견을 묻는 말이었다면 질문하지 말고 이유를 붙여 추천하라.
  → '…보이면 알려 주세요' 같은 확인 · 보고 요청도 질문이다. 확인받을 게 있으면 AskUserQuestion(예: 확인함 / 문제 있음)으로, 없으면 그 문장을 빼고 끝내라.
  → 인용 · 예시라 사용자에게 묻는 말이 아니었을 때만 그대로 다시 끝내도 된다(한 번만 돌려보낸다). 문장을 감싸거나 바꿔 판정을 피하지 마라."
fi
hook_trace ask-via-tool pass "질문 없음"
exit 0
