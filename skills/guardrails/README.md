# guardrails

말로 한 규칙은 잊힌다. `CLAUDE.md` 에 "브랜치 바꾸지 마라", "물을 땐 질문 도구로 물어라" 라고 적어도 Claude 는 가끔 잊는다.
이 플러그인은 그중 두 가지를 hook 으로 지키게 한다. 하나는 막고, 하나는 돌려보낸다.

| hook | 언제 | 하는 일 |
|---|---|---|
| `guard-worktree` | Bash 실행 전 | `git checkout <브랜치>` · `git switch <브랜치>` 를 막고 worktree 를 쓰라고 돌려준다. 파일 복원(`--`) · 새 브랜치(`-b`) · 충돌 해결(`--ours`)은 통과 |
| `ask-via-tool` | 턴을 끝낼 때 | 응답이 글로 묻고 끝나면("…할까요?", "…알려 주세요") 한 번 돌려보내 AskUserQuestion 으로 다시 묻게 한다 |

> 개인 하네스에서 쓰던 hook 의 **스냅샷**이다. 원본은 계속 바뀌고, 이 폴더는 다시 찍을 때만 바뀐다. 버전과 날짜는 `SNAPSHOT` 에 있다.

## 설치

```text
/plugin marketplace add youngsu5582/awesome-tools
/plugin install guardrails@awesome-tools
```

필요한 것: `bash` · `perl` · `jq` (macOS 기본 bash 3.2 에서도 돈다)

## 막는 모습

```
$ echo '{"tool_input":{"command":"git checkout develop && git log --oneline -3"}}' | bash hooks/guard-worktree.sh; echo "exit $?"
차단: 브랜치 전환 대신 worktree 를 쓴다 — `git checkout develop`
  git worktree add ../{name} {branch}
  파일 복원 목적이면 'git checkout -- <path>' 형태로 쓰라 (통과한다).
exit 2
```

`exit 2` 로 끝나면 Claude Code 는 그 도구를 실행하지 않고, stderr 를 Claude 에게 돌려준다. Claude 는 그걸 읽고 다른 방법을 찾는다.

판정은 정규식 한 줄로 하지 않는다.

1. heredoc 본문과 따옴표 안의 글자를 지운다 — 문서 문장이나 커밋 메시지 속 `git checkout` 을 명령으로 읽지 않는다
2. `;` `&&` `|` 로 명령을 조각내고, 조각의 첫 단어가 `git` 이고 다음이 `checkout` · `switch` 인 것만 본다
3. 브랜치를 안 바꾸는 경우는 통과시킨다 — 파일 복원(`--`), 충돌 해결(`--ours`), 커밋의 파일 꺼내기, 새 브랜치 만들기(`-b`)

## 판정 기록

모든 판정을 한 줄씩 남긴다. 기본 위치는 `~/.harness-runs/hook-trace/<년-월>.log` 이고, `HOOK_TRACE` 로 바꿀 수 있다.

```
2026-11-22T16:44:31	guard-worktree	pass		stdin=yes	agent=claude	session=…	wt=my-repo
2026-11-22T16:45:12	guard-worktree	BLOCK	git checkout develop	stdin=yes	agent=claude	session=…	wt=my-repo
```

- `stdin=yes` — hook 이 입력을 실제로 받았는지. 입력을 못 읽고 조용히 `exit 0` 하는 hook 은 있어도 없는 것이다
- `session=` · `wt=` — 어느 대화 · 어느 작업 폴더의 판정인지 (입력에 있을 때만)
- 차단 횟수를 효과로 읽지는 않는다. 같은 시도의 반복과 잘못 막은 것이 섞여 있다

## 자가 테스트

hook 은 고치는 즉시 모든 세션에 적용된다. 고치기 전에 먼저 돌린다.

```bash
bash tests/selftest.sh
```

## 못 잡는 것

- `bash -c "git checkout develop"` — 따옴표 안을 지우는 단계에서 같이 지워진다
- `echo $(git checkout develop)` — `$( )` 는 조각을 나누는 기준에 없다
- `ask-via-tool` 은 한 번만 돌려보낸다. Claude 가 안내를 무시하고 다시 끝내면 통과한다

## 라이선스

MIT
