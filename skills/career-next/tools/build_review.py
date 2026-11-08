#!/usr/bin/env python3
"""
모의고사 채점 화면(HTML 한 장)을 만든다 — 시험 화면과 같은 틀에 문제 · 내 답 · 채점을 나란히.

사용:
    python3 -I build_review.py <mock.md> <answers.md> <review.py|review.json> <출력.html> [--date 11/4] [--schedule ...]

읽는 곳:
    mock.md       문제 (build_mock_sheet.build_data 를 그대로 쓴다)
    answers.md    내 답 — 시험 화면의 「답안만 복사」 결과를 그대로 저장한 파일 (손으로 옮기지 않는다)
    review.*      채점 — 형식은 ../docs/RUBRIC.md 와 examples/review.py
"""
import argparse
import importlib.util
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_mock_sheet as B  # noqa: E402


def fail(msg):
    sys.exit(f"멈춤: {msg}")


def parse_answers(text):
    subs, cur = {}, None
    for line in text.splitlines():
        if line.startswith("### "):
            cur = line[4:].strip()
            subs[cur] = []
        elif cur is not None:
            subs[cur].append(line)

    # 코딩: `### 코딩` (한 문항 → 1번) 또는 `### 코딩 N`. 코드 블록은 펜스 언어가 무엇이든(없어도) 읽는다
    coding = {}
    for name, coding_lines in subs.items():
        mc = re.match(r"^코딩(?: (\d+))?$", name)
        if not mc:
            continue
        pick = lambda prefix: next((l[len(prefix):].strip() for l in coding_lines if l.startswith(prefix)), "")
        code = re.search(r"^```[^\n]*\n(.*?)\n```", "\n".join(coding_lines), re.S | re.M)
        coding[int(mc.group(1) or 1)] = {"result": pick("- 결과: "), "memo": pick("- 메모: "), "code": code.group(1) if code else ""}

    short, q = {}, None
    for line in subs.get("주관식", []):
        m = re.match(r"^(\d+)\.\s*$", line)
        if m:
            q = f"q{m.group(1)}"
            short[q] = []
            continue
        m = re.match(r"^   - [①②③④⑤⑥]\s?(.*)$", line)
        if m and q:
            short[q].append([m.group(1)])
            continue
        if q and short[q]:
            if line.startswith("     "):
                short[q][-1].append(line[5:])
            elif not line.strip():
                short[q][-1].append("")
    short = {k: ["\n".join(v).strip() for v in asks] for k, asks in short.items()}

    essay = {}
    for name, lines in subs.items():
        m = re.match(r"^서술형 (\d+)$", name)
        if m:
            essay[f"s{m.group(1)}"] = "\n".join(lines).strip()
    return {"coding": coding, "short": short, "essay": essay}


def load_review(path):
    path = pathlib.Path(path)
    if path.suffix == ".json":
        return json.loads(path.read_text(encoding="utf-8"))
    spec = importlib.util.spec_from_file_location("review_data", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.REVIEW


def main():
    ap = argparse.ArgumentParser(description="문제 + 내 답 + 채점 → 채점 화면(HTML)")
    ap.add_argument("mock")
    ap.add_argument("answers")
    ap.add_argument("review")
    ap.add_argument("out")
    ap.add_argument("--date", default="")
    ap.add_argument("--schedule", default=None, help="시험 화면을 만들 때 쓴 구간표와 같게 (기본: 문제 파일에 있는 절만)")
    a = ap.parse_args()

    problem = B.build_data(a.mock, a.date, a.schedule)
    answers = parse_answers(pathlib.Path(a.answers).read_text(encoding="utf-8"))
    review = load_review(a.review)

    # 코딩: 채점 `coding` 은 객체(한 문항) 또는 리스트(여러 문항, 순서 = 문항 번호)
    codes = problem["coding"]
    rc = review.get("coding")
    rc = [] if rc is None else (rc if isinstance(rc, list) else [rc])
    if not codes:
        rc = []
    elif len(rc) != len(codes):
        fail(f"코딩 문항은 {len(codes)}개인데 채점 coding 은 {len(rc)}개다 (여러 문항이면 리스트)")
    review["coding"] = rc
    review.setdefault("short", {})
    review.setdefault("essay", {})
    review.setdefault("totals", {})
    answers["coding"] = [answers["coding"].get(c["no"], {"result": "", "memo": "", "code": ""}) for c in codes]

    # 맞춰 보기: 문항 · 묻는 것 개수가 채점 · 답과 같아야 한다
    for q in problem["short"]:
        n = len(q["asks"])
        if len(review["short"].get(q["id"], [])) != n:
            fail(f"주관식 {q['no']} 채점 칸 수가 묻는 것({n})과 다르다")
        if len(answers["short"].get(q["id"], [])) != n:
            fail(f"주관식 {q['no']} 답 칸 수가 묻는 것({n})과 다르다")
    for s in problem["essay"]:
        if s["id"] not in review["essay"] or s["id"] not in answers["essay"]:
            fail(f"서술형 {s['no']} 의 채점 또는 답이 없다")

    data = {"problem": problem, "answers": answers, "review": review}
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    template = (HERE / "review_template.html").read_text(encoding="utf-8")
    pathlib.Path(a.out).write_text(template.replace("/*__DATA__*/", payload), encoding="utf-8")
    filled = sum(1 for v in answers["short"].values() for x in v if x)
    lines = sum(len(c["code"].splitlines()) for c in answers["coding"])
    print(f"{problem['title']} 채점 화면: 코딩 {len(codes)} · 주관식 답 {filled}칸 · 서술형 답 {len(answers['essay'])} · "
          f"코드 {lines}줄 → {a.out}")


if __name__ == "__main__":
    main()
