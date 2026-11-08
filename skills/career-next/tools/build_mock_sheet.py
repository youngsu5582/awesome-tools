#!/usr/bin/env python3
"""
모의고사 문제(markdown)를 시험 응시 화면(HTML 한 장)으로 바꾼다.

사용:
    python3 -I build_mock_sheet.py <mock.md> <출력.html> [--date 11/4] [--lang java] [--schedule "훑기:3,코딩:20,주관식:25,서술형:25,제출:2"]

- 문제 파일 형식: ../docs/MOCK_FORMAT.md (코딩 · 주관식 · 서술형 — 절마다 있어도 없어도 되고, 하나 이상)
- 화면: 구간 알림(배너 · 소리) · 문항 탭 · 깃발 · 시간이 끝나면 잠금 · 답안을 answers.md 형식으로 복사
- 응시자가 미리 보지 않게 문항 내용은 출력하지 않는다 (개수만)
"""
import argparse
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REL_LINK = re.compile(r"\[([^\]]+)\]\((?!https?://)[^)]*\)")
ABS_LINK = re.compile(r"\((https?://[^)\s]+)\)")
SECTION_LABELS = ("코딩", "주관식", "서술형")
DEFAULT_MINS = {"훑기": 3, "코딩": 20, "주관식": 25, "서술형": 25, "제출": 2}
TODO = {
    "훑기": "문제 제목을 전부 보고, 서술형을 머릿속에 굴리기 시작",
    "코딩": "시간이 되면 끊고 부분 점수로라도 제출",
    "주관식": "권장 시간을 넘는 문항은 깃발 꽂고 넘어가기",
    "서술형": "문항당 권장 시간을 지키고, 마지막 1분은 관측 한 줄",
    "제출": "깃발 확인 + 최종 제출",
}
TODO_SCAN_NO_ESSAY = "문제 제목을 전부 훑어 본다"
END_MSG = "시간 끝 — 제출하고 복기한다"


def default_schedule(present, headers):
    """문제 파일에 있는 절만 넣은 기본 구간표 문자열. 시간은 절 머리 (N분), 없으면 기본값."""
    labels = ["훑기"] + [x for x in SECTION_LABELS if x in present] + ["제출"]
    mins = {x: minutes(headers.get(x, ""), r"\((\d+)분", x, DEFAULT_MINS[x]) for x in labels}
    return ",".join(f"{x}:{mins[x]}" for x in labels)


def fail(msg):
    sys.exit(f"멈춤: {msg}")


def tidy(lines):
    out = list(lines)
    while out and (not out[-1].strip() or out[-1].strip() == "---"):
        out.pop()
    while out and not out[0].strip():
        out.pop(0)
    return REL_LINK.sub(r"\1", "\n".join(out)).strip()


def minutes(text, pattern, what, default):
    m = re.search(pattern, text or "")
    return int(m.group(1)) if m else default


def parse_schedule(text, present):
    """구간표를 읽는다. present = 문제 파일에 있는 절 이름들.
    문제 파일에 없는 절 이름은 경고하고 뺀다. 문제 파일에 있는 절이 구간표에 없으면 멈춘다."""
    schedule = []
    for part in text.split(","):
        label, _, mins = part.strip().partition(":")
        if not label or not mins.isdigit():
            fail(f"구간 형식이 이상하다: {part!r} (예: 코딩:20)")
        if label in SECTION_LABELS and label not in present:
            print(f"경고: 구간표의 '{label}' 은 문제 파일에 없는 절이라 뺀다", file=sys.stderr)
            continue
        schedule.append({"min": int(mins), "label": label, "todo": TODO.get(label, label)})
    labels = [x["label"] for x in schedule]
    for need in SECTION_LABELS:
        if need in present and need not in labels:
            fail(f"문제 파일에 '{need}' 절이 있는데 구간표에 없다: {labels}")
    if "서술형" not in present and schedule and schedule[0]["label"] == "훑기":
        schedule[0]["todo"] = TODO_SCAN_NO_ESSAY
    return schedule


def split_sections(lines):
    sections, cur = {}, None
    for line in lines:
        if line.startswith("## "):
            cur = line[3:].strip()
            sections[cur] = []
        elif cur is not None:
            sections[cur].append(line)
    return sections


def find(sections, prefix, required=True):
    hits = [k for k in sections if k.startswith(prefix)]
    if len(hits) > 1 or (required and not hits):
        fail(f"'{prefix}' 절이 {len(hits)}개다")
    return (hits[0], sections[hits[0]]) if hits else ("", [])


def clean_title(text):
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    m = re.search(r"「(.+?)」", text)
    return (m.group(1) if m else text).strip()


def parse_coding(c_lines):
    """코딩 절 → 문항 목록. '### 제목' 하위 제목이 있으면 문항 여러 개, 없으면 절 전체가 한 문항."""
    heads = [i for i, l in enumerate(c_lines) if re.match(r"^### \S", l)]
    if not heads:
        c_md = tidy(c_lines)
        t = re.search(r"「(.+?)」", c_md)
        link = ABS_LINK.search(c_md)
        return [{"id": "coding", "no": 1, "title": t.group(1) if t else "코딩", "md": c_md,
                 "url": link.group(1) if link else "", "urlChecked": bool(link)}]
    pre = tidy(c_lines[:heads[0]])
    items = []
    for n, i in enumerate(heads):
        end = heads[n + 1] if n + 1 < len(heads) else len(c_lines)
        head = c_lines[i][4:].strip()
        body = tidy(c_lines[i + 1:end])
        link = ABS_LINK.search(head + "\n" + body)
        title = clean_title(re.sub(r"^\d+[.)]\s*", "", head)) or f"코딩 {n + 1}"
        md = (pre + "\n\n" + body).strip() if pre else body
        items.append({"id": f"c{n + 1}", "no": n + 1, "title": title, "md": md,
                      "url": link.group(1) if link else "", "urlChecked": bool(link)})
    return items


def rec_minutes(header, count):
    """코딩 문항당 권장 시간: '문항당 N분' > 절 머리 (N분) ÷ 문항 수 > 기본 20분 ÷ 문항 수."""
    per = re.search(r"문항당 (\d+)분", header)
    if per:
        return int(per.group(1))
    total = minutes(header, r"\((\d+)분", "코딩", 20)
    v = total / count
    return int(v) if v == int(v) else round(v, 1)


def parse_short(lines):
    items, cur = [], None
    for line in lines:
        m = re.match(r"^### (\d+)\. (.+)$", line)
        if m:
            cur = {"no": int(m.group(1)), "title": REL_LINK.sub(r"\1", m.group(2).strip()), "body": []}
            items.append(cur)
        elif cur is not None:
            cur["body"].append(line)
    out = []
    for it in items:
        asks, inside = [], False
        for line in it["body"]:
            if line.strip() == "**묻는 것**":
                inside = True
                continue
            if inside:
                m = re.match(r"^\d+\.\s+(.+)$", line)
                if m:
                    asks.append(m.group(1).strip())
                elif line.strip() and asks:
                    break
        if not asks:
            fail(f"주관식 {it['no']} 에서 '묻는 것' 목록을 못 찾았다")
        out.append({"id": f"q{it['no']}", "no": it["no"], "title": it["title"], "md": tidy(it["body"]), "asks": asks})
    return out


def parse_essay(lines):
    body = []
    for line in lines:
        if line.strip() == "---":
            break
        body.append(line)
    items, cur = [], None
    for line in body:
        m = re.match(r"^\*\*서술형 (\d+)\.\s*(.+?)\.?\*\*\s*$", line)
        if m:
            cur = {"no": int(m.group(1)), "title": m.group(2).strip(), "body": []}
            items.append(cur)
        elif cur is not None:
            cur["body"].append(line)
    return [{"id": f"s{it['no']}", "no": it["no"], "title": it["title"], "md": tidy(it["body"])} for it in items]


def build_data(md_path, date="", schedule_text=None, lang=""):
    """문제 파일을 읽어 시험 화면 데이터(dict)를 만든다. 채점 화면(build_review.py)도 이걸 쓴다."""
    md_path = pathlib.Path(md_path)
    md = md_path.read_text(encoding="utf-8").splitlines()
    title = md[0].lstrip("# ").strip()
    m = re.search(r"(\d+)\s*회", title)
    rnd = int(m.group(1)) if m else 1
    sections = split_sections(md[1:])

    c_name, c_lines = find(sections, "코딩", required=False)
    coding = parse_coding(c_lines) if c_name else []
    s_name, s_lines = find(sections, "주관식", required=False)
    short = parse_short(s_lines) if s_name else []
    e_name, e_lines = find(sections, "서술형", required=False)
    essay = parse_essay(e_lines) if e_name else []
    if c_name and not coding:
        fail("코딩 문항이 없다")
    if s_name and not short:
        fail("주관식 문항이 없다")
    if e_name and not essay:
        fail("서술형 문항이 없다")
    present = [n for n, items in (("코딩", coding), ("주관식", short), ("서술형", essay)) if items]
    if not present:
        fail("코딩 · 주관식 · 서술형 절이 하나도 없다")
    schedule = parse_schedule(schedule_text or default_schedule(present, {"코딩": c_name, "주관식": s_name, "서술형": e_name}), present)

    hint = re.search(r"\(([^)]*)\)", e_name)
    essay_hint = hint.group(1).split("·")[-1].strip() if hint and "·" in hint.group(1) else ""
    kinds = []
    if short:
        kinds.append("주관식은 문항별 ○ △ × 와 빠진 이유 한 줄")
    if essay:
        kinds.append("서술형은 채점 기준으로 항목별 점수")
    if coding and not kinds:
        kinds.append("코딩은 문항별로 결과와 개선점 한 줄")
    grade_prompt = (f"{md_path.name} 의 모의고사 답안이야. " + ", ".join(kinds) +
                    ", 모범답안은 틀린 문항만 3줄 이내로.")
    return {
        "round": rnd, "title": title, "dateLabel": date, "headingDate": date, "lang": lang,
        "schedule": schedule, "endMsg": END_MSG, "gradePrompt": grade_prompt, "essayHint": essay_hint,
        "rec": {
            "scan": next((seg["min"] for seg in schedule if seg["label"] == "훑기"), 0),
            "coding": rec_minutes(c_name, len(coding)) if coding else 0,
            "short": minutes(s_name, r"문항당 (\d+)분", "주관식", 5),
            "essay": minutes(e_name, r"문항당 (\d+)분", "서술형", 12),
        },
        "coding": coding, "short": short, "essay": essay,
    }


def main():
    ap = argparse.ArgumentParser(description="모의고사 문제(markdown) → 시험 응시 화면(HTML)")
    ap.add_argument("mock")
    ap.add_argument("out")
    ap.add_argument("--date", default="")
    ap.add_argument("--lang", default="", help="답 복사의 코드 블록 언어 (기본: 없음)")
    ap.add_argument("--schedule", default=None, help="예: 훑기:3,코딩:20,주관식:25,서술형:25,제출:2 (기본: 문제 파일에 있는 절만)")
    a = ap.parse_args()
    data = build_data(a.mock, a.date, a.schedule, a.lang)
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    template = (HERE / "mock_template.html").read_text(encoding="utf-8")
    if "/*__DATA__*/" not in template:
        fail("템플릿에 데이터 자리가 없다")
    pathlib.Path(a.out).write_text(template.replace("/*__DATA__*/", payload), encoding="utf-8")
    asks = ",".join(str(len(q["asks"])) for q in data["short"])
    total = sum(x["min"] for x in data["schedule"])
    links = sum(1 for c in data["coding"] if c["url"])
    link_txt = ("있음" if links else "없음") if len(data["coding"]) <= 1 else f"{links}개"
    print(f"{data['title']}: 코딩 {len(data['coding'])} · 주관식 {len(data['short'])}"
          f"{f' (묻는 것 {asks})' if asks else ''} · 서술형 {len(data['essay'])} · "
          f"{total}분 · 권장 {data['rec']} · 코딩 링크 {link_txt} → {a.out}")


if __name__ == "__main__":
    main()
