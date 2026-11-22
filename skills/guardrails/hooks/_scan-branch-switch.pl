#!/usr/bin/env perl
# guard-worktree.sh 의 판정부. stdin 으로 bash 명령 전문을 받아
#   - 차단 대상이면 해당 세그먼트를 출력하고 exit 1
#   - 아니면 아무것도 출력하지 않고 exit 0
#
# 왜 정규식 한 줄이 아닌가 (실측 2026-08-05)
#   `grep -qE '(^|[;&|]) *git +(checkout|switch)'` 는 heredoc 안의 **문서 문장**
#   ("git checkout 이 hook 으로 차단된다는 사실") 을 명령으로 오인해 읽기 전용 명령을 막았다.
#   또 `git +checkout +.*--` 예외는 `git checkout develop && git log --oneline` 을 통과시켰다.
#   그래서 heredoc·인용문을 걷어내고 **세그먼트의 첫 토큰**과 **인수 배열**로 판정한다.
use strict;
use warnings;

my $cmd = do { local $/; <STDIN> };
$cmd = '' unless defined $cmd;

# 1) heredoc 본문 제거 — 명령이 아니라 데이터다
my @lines = split /\n/, $cmd, -1;
my @kept;
my $i = 0;
while ( $i <= $#lines ) {
    my $line = $lines[ $i++ ];
    push @kept, $line;
    my @delims;
    while ( $line =~ /<<-?\s*(?:'([^']+)'|"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))/g ) {
        push @delims, ( defined $1 ? $1 : defined $2 ? $2 : $3 );
    }
    for my $d (@delims) {
        while ( $i <= $#lines ) {
            my $l = $lines[ $i++ ];
            last if $l =~ /^\s*\Q$d\E\s*$/;
        }
    }
}
my $s = join "\n", @kept;

# 2) 인용 문자열 제거 — 문서 문장·커밋 메시지가 명령으로 오해되는 것을 막는다
$s =~ s/\\.//gs;
$s =~ s/"(?:[^"\\]|\\.)*"/""/gs;
$s =~ s/'[^']*'/''/gs;

# 3) 세그먼트별로 첫 토큰이 git 인 것만 본다
for my $seg ( split /(?:\n|;|&&|\|\||\||&)/, $s ) {
    my @t = grep { length } split /\s+/, $seg;
    next unless @t;

    my $k = 0;
    $k++ while $k < @t && $t[$k] =~ /^[A-Za-z_][A-Za-z0-9_]*=/;    # FOO=bar git ...
    next unless $k < @t && ( $t[$k] eq 'git' || $t[$k] =~ m{/git$} );
    $k++;

    while ( $k < @t ) {                                            # git 전역 옵션
        if ( $t[$k] eq '-C' || $t[$k] eq '-c' ) { $k += 2 }
        elsif ($t[$k] =~ /^--(git-dir|work-tree|namespace|exec-path)=/
            || $t[$k] =~ /^(--no-pager|--paginate|-p|--bare|--no-optional-locks|--literal-pathspecs)$/ )
        {
            $k++;
        }
        else { last }
    }
    my $sub = $k < @t ? $t[$k] : '';
    next unless $sub eq 'checkout' || $sub eq 'switch';

    # checkout 만 파일 모드가 있다 — 이 둘은 브랜치를 바꾸지 않으므로 통과시킨다 (실측 2026-10-26 오차단)
    #   --ours / --theirs : 충돌 해결 중 파일 하나를 한쪽 판으로 되돌린다(경로 전용 옵션)
    #   인자 2개 이상    : `git checkout <커밋> <파일>…` 은 그 커밋의 파일을 꺼낼 뿐 전환이 아니다
    if ( $sub eq 'checkout' ) {
        my @args = @t[ $k + 1 .. $#t ];
        next if grep { $_ eq '--ours' || $_ eq '--theirs' } @args;
        next if ( grep { !/^-/ } @args ) >= 2;
    }

    my $target = '';
    for my $a ( @t[ $k + 1 .. $#t ] ) {
        # 허용: 파일 복원(--) · 새 브랜치 생성(-b/-B/-c/-C/--orphan) · 부분 복원(-p)
        if (   $a =~ /^(--|-b|-B|-c|-C|--create|--force-create|--orphan|-p|--patch)$/
            || $a =~ /^--pathspec-from-file=/ )
        {
            $target = '';
            last;
        }
        elsif ( $a eq '-' || $a eq '--detach' ) { $target = $a }    # 이전 브랜치 · HEAD 분리
        elsif ( $a =~ /^-/ )                    { next }           # 그 밖 플래그
        else { $target = $a unless length $target }
    }
    if ( length $target ) {
        $seg =~ s/^\s+|\s+$//g;
        print $seg;
        exit 1;
    }
}
exit 0;
