# Experience Tools

일상적으로 쓰는 zsh 함수와 회사 동료들과 공유하면 좋을만한 스크립트를 한곳에 모아 둔 레포지토리.
반복되는 작업을 단축키처럼 쓰고, 공통으로 쓰는 명령을 통일하기 위해 만든 툴킷

## 왜 만들었나요?
- 로컬 개발 환경에서 매번 타이핑하기 번거로운 명령을 간단한 함수로 재활용하기 위해
- 팀에서 함께 쓰는 스크립트를 문서화하고 버전 관리하기 위해
- AWS, GitHub, 위키 등 서로 다른 범주의 유틸리티를 한 저장소에서 관리하기 위해

## 저장소 구성
| 경로 | 설명 |
| --- | --- |
| `aws/` | EC2 접속을 간소화하는 AWS CLI 스크립트와 도움말 |
| `git/` | Git/GitHub 워크플로우를 돕는 zsh 함수 모음 |
| `wiki/` | 사내/개인 위키에 올릴 문서 템플릿이나 초안(추후 추가 예정) |

## 사전 세팅
1. **필수 도구**
   - `zsh` 5.8+
   - [`fzf`](https://github.com/junegunn/fzf) (대화형 선택 UI)
   - [`bat`](https://github.com/sharkdp/bat) (`gs`에서 stash diff 미리보기용)
   - [`awscli`](https://docs.aws.amazon.com/cli/) + 자격 증명 설정 (AWS 스크립트용)
   - [`gh`](https://cli.github.com/) (PR 관련 스크립트)
2. **환경 변수** (상세 설명은 각 폴더 README 참고)
   - `AWS_EC2_PEM_KEY_PATH`: EC2 SSH 접속에 사용할 PEM 키 경로
   - `PROFILE`: AWS CLI 프로파일 이름
3. **레포지토리 가져오기 및 스크립트 로드**

```bash
# 원하는 경로에 클론
$ git clone git@github.com:YOUR-ID/experience-tools.git
$ export TOOLS_HOME="$(pwd)/experience-tools"

# .zshrc 등에 아래 줄 추가 (aws, git 폴더 안의 zsh 파일 자동 로드)
for dir in aws git; do
  for file in "$TOOLS_HOME/$dir"/*.zsh; do
    source "$file"
  done
done
```

원하는 함수만 쓰고 싶다면 해당 파일만 `source` 하면 됩니다.

## 사용 방법 요약
- `aws-help`: AWS 관련 함수 목록과 사용법을 터미널에서 확인
- `ec2-ssh`: 특정 리전의 EC2 인스턴스를 fzf로 고르고 바로 SSH 접속
- `ec2-ssh-all`: 모든 리전에서 조건에 맞는 인스턴스를 모아서 선택 후 SSH 접속
- `git-help`: Git 함수 도움말
- `gb`: 최근 커밋 순으로 브랜치를 선택해 checkout/pull/rebase/delete
- `gs`: stash 목록을 미리 보기와 함께 관리 (apply/pop/drop/rename)
- `gpr`: GitHub PR 목록에서 선택한 PR 브랜치로 안전하게 전환

각 커맨드의 세부 옵션과 커스터마이징 포인트는 하위 README에서 설명합니다.

## 라이선스
이 레포지토리는 [MIT License](LICENSE)를 따릅니다. 필요한 부분은 자유롭게 수정/재사용하되, 사내 공유 시에는 민감한 자격 정보가 포함되지 않도록 주의해주세요.

## 앞으로 할 일 아이디어
- `wiki/`에 개발 가이드, 온보딩 노트를 추가
- 사내 공용 CLI 배포 스크립트 작성
- 테스트/검증 스크립트 추가
