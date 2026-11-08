# career-next

**A Claude Code plugin for job applications that starts from a single job posting.** It turns the posting into an applicant profile, reviews your resume against that profile (coldly, with evidence), and prepares you for the hiring test with a diagnosis, hidden mock exams, a timed exam screen, and strict grading. Skills are written in Korean; triggers work in Korean and English.

**공고 하나에서 시작하는 지원 준비 팩.** 공고에서 지원 프로필 한 장을 뽑고, 그 프로필을 기준으로 이력서를 냉정하게 고치고, 시험을 실제 형식 그대로 연습한다.

```
공고 ──▶ intake ──▶ profile.md ──┬──▶ resume  ──▶ 판정 · 수정안 · 면접 질문 후보
                                 └──▶ pretest ──▶ 진단 · 모의고사 · 채점 · 마지막 한 장
                                                         (다음: 면접 준비)
```

---

## 왜 필요한가

공고 분석 · 이력서 · 시험 준비를 따로 하면, 이력서는 공고와 맞물리지 않고, 자기 이력서는 후하게 읽히고, 시험은 문제만 많이 풀고 실제 형식 · 시간 연습 없이 들어가게 된다. 이 팩은 공고에서 뽑은 프로필 하나를 세 단계가 이어 쓰게 해서 셋을 같은 기준에 묶는다. → [docs/PROBLEM.md](docs/PROBLEM.md)

## 스킬

| 스킬 | 하는 일 | 남기는 것 |
|---|---|---|
| `career-next:guide` | 지금 가진 것(공고 · 이력서 · 시험 일정)과 폴더를 보고 어디서 시작 · 이어갈지 한 걸음 | — |
| `career-next:intake` | 공고 → 포지션 · 요구 역량 · 스택 · 절차 · **시험 형식**, 공식 출처 링크를 열어 확인 | `profile.md` · `links.md` |
| `career-next:resume` | 「실제 한 일」 압축 → 공고와 매칭 → 강점 · 방향 → Before/After → 면접관 시점 판정 | `resume/` match · draft · feedback |
| `career-next:pretest` | 형식 고정(구간표) → 진단 · 약점 지도 → 모의고사(숨겨서 출제) → 시험 화면 → 채점 → 마지막 한 장 | `pretest/` |

## 설치

Claude Code 안에서:

```text
/plugin marketplace add youngsu5582/awesome-tools
/plugin install career-next@awesome-tools
```

Claude Code 2.1.275 이상이면 한 줄로도 된다: `/plugin install career-next --marketplace youngsu5582/awesome-tools`

설치 없이 이번 세션에서만 써 보려면:

```bash
git clone https://github.com/youngsu5582/awesome-tools.git
claude --plugin-dir awesome-tools/skills/career-next
```

내려받은 폴더를 고쳐 쓰고 싶으면 그 폴더를 마켓플레이스로 더한다: `claude plugin marketplace add ./awesome-tools` → `claude plugin install career-next@awesome-tools`.

> `~/.claude/skills/` 아래에 이 폴더를 링크하는 방식은 쓰지 않는다 — 이 구조(스킬이 팩 바로 아래)에서는 스킬을 읽지 못한다.

시험 화면 · 채점 화면 생성기는 Python 3(표준 라이브러리만)과 브라우저가 있으면 된다.

## 써 보기

```text
이 공고 정리해줘 https://…                       → intake
이력서 피드백 냉정하게. 이 공고 기준으로          → resume  (PDF · Markdown · 링크)
시험이 2주 남았어. 75분, 코딩 1 · 주관식 5 · 서술형 2, 검색 불가   → pretest
지원 준비 어디서부터 하지? / 지난번에 이어서      → guide
```

결과물은 처음에 정한 폴더(예: `./career-next/<회사>/`)에 쌓인다 — 구조는 [docs/WORKSPACE.md](docs/WORKSPACE.md). 이력서 · 답안이 들어가니 **공개 저장소 밖**에 둔다.

## 지키는 것

- **확인 · 추정 · 미확인을 섞지 않는다.** 출처를 달고, 링크는 실제로 열어 본다.
- **지어내지 않는다.** 없는 경험 · 숫자를 넣지 않고, 모르는 값은 빈칸으로 남긴다.
- **냉정하게, 이 회사 기준으로.** 위로 · 완충 문장 없이 지적마다 근거를 단다. 판정 경계는 표로 정해 두었다 (resume §3).
- **푸는 사람이 문제를 미리 보지 않는다.** 모의고사는 별도 에이전트가 쓰고 보고에는 문항 수만 남긴다.
- **시험의 공정성.** 유출 문제 · 기출 공유 자료를 쓰지 않고, 시험 시간 중에는 돕지 않는다.
- **개인 정보는 밖으로 보내지 않는다.**

## 구조

```
career-next/
├── .claude-plugin/plugin.json   # "skills": "./" — 아래 네 폴더가 스킬
├── guide/SKILL.md
├── intake/SKILL.md
├── resume/SKILL.md
├── pretest/SKILL.md
├── tools/                       # 시험 화면 · 채점 화면 생성기 + 예시 → tools/README.md
└── docs/
    ├── PROBLEM.md               # 무엇을 닫는가
    ├── PERSONA.md               # 누구를 위해 + 입력 스키마
    ├── WORKSPACE.md             # 결과물 폴더
    ├── TEST_CASES.md            # 검증 가능한 입력과 판정
    ├── MOCK_FORMAT.md           # 모의고사 문제 파일 형식
    └── RUBRIC.md                # 채점 기준 · 채점 파일 형식
```

## 범위

- ✅ 공고 정리 · 회사 공식 정보, 이력서 방향 · 수정안 · 판정, 시험 대비(코딩 · 단답 · 서술형, 어느 조합이든)
- ❌ 이력서 대필 · 지원자 비교 · 합격 예측 · 연봉 같은 풍문 · 과제형(며칠짜리) 시험
- ⏭ 다음 단계: 면접 준비 — 지금은 `resume/feedback.md` 의 면접 질문 후보와 `pretest/weakness.md` 가 재료

## 출처

resume 단계의 기준 — 폭보다 깊이, 첫 10초, 모든 줄을 같은 틀에 억지로 맞추지 않기 — 은 글 「[수많은 이력서를 보며 느낀 것들](https://www.youngsu5582.today/posts/reviewing-resumes-as-a-backend-developer)」에서 왔다. 시험 대비 흐름은 실제 온라인 시험(코딩 · 단답 · 서술형) 하나를 준비하며 쓴 방법을 회사 · 시험 이름 없이 일반화했다.

## License

MIT
