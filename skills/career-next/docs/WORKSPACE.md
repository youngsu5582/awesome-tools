# WORKSPACE — 결과물 폴더

네 단계가 같은 폴더에 쌓고, 다음 단계는 앞 단계의 파일을 읽어서 시작한다.

```
<결과물 폴더>/                      # 예: ./career-next/acme/  또는  <회사 폴더>/career-next/
├── profile.md                     # intake — 이후 모든 단계가 읽는다
├── links.md                       # intake · resume — 연 링크 / 안 연 링크
├── resume/
│   ├── match.md                   # 실제 한 일 · 매칭표 · 갭 · 강점 · 한 줄 소개
│   ├── draft.md                   # 방향 · Before/After
│   └── feedback.md                # 판정 · 다섯 질문 · 고칠 것 · 면접 질문 후보 (회차마다 위에 쌓는다)
├── pretest/
│   ├── plan.md                    # 형식 · 구간표 · 날짜별 계획 · 「시험 뒤로」
│   ├── diagnostic.md              # 진단 문항 · 답 · 채점
│   ├── weakness.md                # 약점 지도 (회차마다 고친다)
│   ├── mock-1.md · mock-1-key.md  # 출제 에이전트가 씀 — 풀기 전에 열지 않는다
│   ├── mock-1.html                # 시험 화면
│   ├── answers-1.md               # 시험 화면의 「답안만 복사」
│   ├── review-1.py · review-1.html  # 채점 · 채점 화면
│   ├── scores.md                  # 회차 기록 (아래로 쌓는다)
│   └── final.md                   # 마지막 한 장
└── interview/
    ├── plan.md                    # 면접 형식 한 줄 · 계획
    ├── stories.md                 # 대표 경험 3개 — 30초 · 2분 답(지원자) · 비는 단(Claude)
    ├── bank.md                    # 질문 은행 (경험 · 기초 · 설계)
    ├── brief-1.md                 # 음성 AI 에 붙일 면접관 준비물 — 이력서 요약만
    ├── transcript-1.md            # 붙여 받은 대화 기록 원문
    ├── mock-1.md                  # 채점
    ├── scores.md                  # 회차 기록
    ├── final.md                   # 면접 전날 한 장
    └── retro-<날짜>.md            # 면접 뒤 회고 (공개되지 않는 자리에만)
```

## 누가 쓰고 누가 읽나

| 파일 | 쓰는 단계 | 읽는 단계 |
|---|---|---|
| `profile.md` | intake | resume · pretest · guide |
| `links.md` | intake (회사) · resume (지원자 링크) | resume |
| `resume/feedback.md` | resume | guide · interview |
| `pretest/weakness.md` · `scores.md` | pretest | pretest 다음 회차 · guide |
| `pretest/mock-N-key.md` | 출제 에이전트 | 채점할 때만 |
| `interview/brief-N.md` | interview | 지원자가 음성 AI 에 붙인다 (외부 서비스로 나가는 유일한 파일) |
| `interview/scores.md` · `retro-*.md` | interview | interview 다음 회차 · guide |

## 규칙

- **공개 저장소 밖에 둔다.** 이력서 · 연락처 · 답안 · 시험 기록이 들어간다. 저장소 안에 둬야 하면 `.gitignore` 에 넣는다.
- **파일 · 폴더 이름은 ASCII.** 일부 노트 앱 · 동기화 도구는 한글 파일 이름을 다른 정규화 형태로 저장해 링크가 깨진다. 내용은 한국어여도 된다.
- **회사 하나 = 폴더 하나.** 같은 회사의 다른 포지션은 같은 폴더 안 `profile-<포지션>.md`.
- **덮어쓰지 않고 쌓는다.** feedback 은 새 회차를 위에, scores 는 아래 줄에, 모의고사는 번호를 올린다 — 고친 게 반영됐는지 비교하려고.
- **시험 뒤 실제 문항을 남기려면** 시험 보안 서약부터 확인하고, 공개되지 않는 자리에만.
