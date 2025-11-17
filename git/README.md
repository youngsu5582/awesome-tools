# Git & GitHub Helpers

Git 브랜치/스태시 관리와 GitHub PR 워크플로우를 빠르게 처리하기 위한 zsh 함수 모음입니다. `fzf` 기반 UI를 사용해 키보드만으로 대부분의 작업을 수행할 수 있습니다.

## 필요 조건
- `git` 2.30+
- [`fzf`](https://github.com/junegunn/fzf)
- [`bat`](https://github.com/sharkdp/bat) (`gs`에서 stash diff 미리보기용)
- [`gh`](https://cli.github.com/) (GitHub PR 조회/체크아웃)

## 함수 개요
### `gb` (Git Branch)
- 최근 커밋 순으로 로컬 브랜치 목록을 보여줍니다.
- 선택 후 `(c)heckout`, `checkout & (p)ull`, `checkout & (r)ebase`, `(d)elete` 중 원하는 동작을 키 하나로 수행합니다.
- `git log --graph` 미리보기로 브랜치 상황을 확인할 수 있습니다.

```zsh
$ gb
```

### `gs` (Git Stash)
- `git stash` 목록을 ID/날짜/메시지로 보여주고 선택한 항목에 대해 `apply`, `pop`, `drop`, `rename`를 지원합니다.
- `bat`으로 diff를 컬러 프리뷰합니다.

```zsh
$ gs
```

### `gpr`
- `gh pr list` 결과를 fzf로 보여주고, 선택한 PR로 안전하게 전환합니다.
- 로컬 변경사항이 있으면 자동으로 stash 후 브랜치를 변경합니다.
- 이미 존재하는 브랜치면 `checkout + pull`, 없으면 `gh pr checkout`을 실행합니다.

```zsh
$ gpr
```

### `git-help`
현재 디렉터리에서 사용할 수 있는 Git/GitHub 관련 함수와 간단한 설명을 출력합니다.

```zsh
$ git-help
```

## 추천 워크플로우
1. `gpr`로 리뷰할 PR을 선택 → 자동으로 브랜치 체크아웃
2. 수정 중 다른 브랜치가 필요하면 `gb`로 전환
3. 임시 변경은 `gs`로 이름을 붙여 관리
4. 함수 목록이 헷갈릴 땐 `git-help`

## 확장 아이디어
- PR 목록에 라벨/리뷰 상태 표시
- 원격 브랜치 삭제/cleanup 도구 추가
- 커밋 템플릿/체크리스트 자동화 스크립트 작성
