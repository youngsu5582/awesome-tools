#!/usr/bin/perl
# _scan-question.pl — 응답 본문에서 사용자에게 글로 묻는 문장을 찾는다. ask-via-tool.sh 의 판정부.
#
# stdin : 응답 본문(마지막 text 블록)
# stdout: 처음 걸린 문장 (최대 60자)
# exit  : 1 = 찾음, 0 = 없음
#
# 판정에서 빼는 곳 — 질문이 아니라 인용·예시·기록인 자리다
#   코드 블록 · 인라인 코드 · 인용(>) · 제목(#) · 표(|) · Uncertainty Map 절(끝까지)
#   따옴표 안("…" · “…” · ‘…’) — 면접 예상 질문 · 도구 출력을 옮겨 적은 자리다. 2026-11-22 차단 64건 중 7건이 여기서 났다
#   판정은 느슨하게 하지 않는다 — "…보이면 알려 주세요" 같은 확인 요청도 질문이다(사람 결정 2026-11-22)
# 케이스 표는 tests/selftest.sh "ask-via-tool 판정부" 에 있다.
use strict; use warnings; use utf8;
binmode STDIN, ':encoding(UTF-8)'; binmode STDOUT, ':encoding(UTF-8)';

local $/; my $t = <STDIN> // '';
$t =~ s/```.*?```//gs;
$t =~ s/^[ \t]*(?:#{1,6}[ \t]*|\*\*)Uncertainty Map.*\z//ims;
$t =~ s/`[^`\n]*`//g;
$t =~ s/"[^"\n]*"//g;
$t =~ s/“[^”\n]*”//g;
$t =~ s/‘[^’\n]*’//g;
$t = join "\n", grep { !/^\s*(?:>|#|\|)/ } split /\n/, $t;

my @patterns = (
  # 존댓말 의문형 + 물음표: 할까요? · 될까요? · 하실래요? · 괜찮으세요? · 맞나요? · 무엇인가요? · 하시겠어요?
  qr/[^\n.!?？]{0,40}(?:까요|래요|가요|나요|지요|세요|어요|습니까)\s*[?？]/,
  # 입력을 달라는 요청: 알려 주세요 · 골라 주시면 · 정해 주세요
  qr/[^\n.!?？]{0,40}(?:알려|말씀해|골라|정해|선택해|답해)\s?주(?:세요|시면|십시오)/,
  # 제안형: 원하시면 … 드릴게요 / 필요하면 … 하겠습니다
  qr/(?:원하시면|원하면|필요하시면|필요하면|괜찮으시면)[^\n]{0,80}?(?:드릴게요|드리겠습니다|드릴까요|할게요|하겠습니다)/,
  # 영어
  qr/(?i:\b(?:should i|shall i|do you want|would you like|want me to|let me know)\b)[^\n]{0,50}/,
);
for my $p (@patterns) {
  if ($t =~ $p) { (my $m = $&) =~ s/^\s+//; print substr($m, 0, 60); exit 1; }
}

# 반말·단답이라도 마지막 문단이 물음표로 끝나면 질문이다
my @paras = grep { /\S/ } split /\n\s*\n/, $t;
if (@paras && $paras[-1] =~ /([^\n.!?？]{0,60}[?？])\s*\z/) {
  (my $m = $1) =~ s/^\s+//; print $m; exit 1;
}
exit 0;
