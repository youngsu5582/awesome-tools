# tools — 시험 화면 · 채점 화면 생성기

`pretest` 단계가 쓰는 도구다. 표준 라이브러리 Python 3 만 쓰고, 화면은 HTML 한 장(브라우저로 연다)이다.

| 파일 | 하는 일 |
|---|---|
| `build_mock_sheet.py` + `mock_template.html` | 문제 파일 → **시험 응시 화면**: 구간 알림(배너 · 소리) · 문항 탭 · 깃발 · 시간이 끝나면 잠금 · 답안을 `answers.md` 형식으로 복사 |
| `build_review.py` + `review_template.html` | 문제 + 내 답 + 채점 → **채점 화면**: 문항 탭에 점수, 왼쪽 문제 / 오른쪽 ○△× · 코멘트 · 모범답안 · 서술형 5항목 |

## 쓰는 법

```bash
# 1. 시험 화면 — 문제 형식: ../docs/MOCK_FORMAT.md
python3 -I build_mock_sheet.py mock.md mock.html --lang java --schedule "훑기:3,코딩:20,주관식:25,서술형:25,제출:2"

# 2. 시험을 보고 「최종 제출 → 답안만 복사」 결과를 answers.md 로 저장

# 3. 채점 화면 — 채점 형식: ../docs/RUBRIC.md
python3 -I build_review.py mock.md answers.md review.py review.html --schedule "…(1과 같게)"
```

| 인자 | 기본값 | 뜻 |
|---|---|---|
| `--date` | 비어 있음 | 답 복사 머리에 붙는 날짜 표시 (예: `11/4`) |
| `--lang` | 비어 있음 | 답 복사의 코드 블록 언어. 비우면 언어 없는 펜스 (`build_review.py` 는 어떤 언어든 읽는다) |
| `--schedule` | 문제 파일에 있는 절만 (시간은 절 머리 `(N분)`) | 구간표. 문제 파일에 없는 절 이름은 경고 후 빼고, 있는 절이 빠지면 멈춘다. 채점 화면에도 같은 값을 준다 |

- 코딩 · 주관식 · 서술형은 절마다 있어도 없어도 된다(하나 이상). 코딩은 `### 제목` 으로 여러 문항을 쓸 수 있다 — [`MOCK_FORMAT.md`](../docs/MOCK_FORMAT.md).
- 응시자가 문제를 미리 보지 않도록 `build_mock_sheet.py` 는 문항 **개수만** 출력한다. 문제를 쓰는 쪽(사람 또는 서브에이전트)과 푸는 쪽을 나눈다.
- 답은 브라우저 저장소에 남아 새로 고침해도 이어진다.

## 예시로 돌려 보기

```bash
S="훑기:1,코딩:20,주관식:10,서술형:12,제출:2"
python3 -I build_mock_sheet.py examples/mock.md /tmp/sheet.html --lang java --schedule "$S"
python3 -I build_review.py examples/mock.md examples/answers.md examples/review.py /tmp/review.html --schedule "$S"
```

| 예시 | 모양 |
|---|---|
| `examples/mock.md` · `answers.md` · `review.py` | 코딩 1 + 주관식 2 + 서술형 1 |
| `examples/mock-coding-only.md` | 코딩 3문항만 (`### 1.` `### 2.` `### 3.`) |
| `examples/answers-coding-only.md` · `review-coding-only.py` | 코딩 여러 문항의 답(`### 코딩 1` …) · 채점(`coding` 리스트) |
| `examples/diagnostic.md` | 주관식 3문항만 |

```bash
python3 -I build_mock_sheet.py examples/mock-coding-only.md /tmp/coding.html --lang python
python3 -I build_review.py examples/mock-coding-only.md examples/answers-coding-only.md examples/review-coding-only.py /tmp/coding-review.html
python3 -I build_mock_sheet.py examples/diagnostic.md /tmp/diagnostic.html
```
