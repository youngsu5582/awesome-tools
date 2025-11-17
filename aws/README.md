# AWS Utilities

EC2 인스턴스에 빠르게 접속하기 위한 zsh 함수 모음입니다. `awscli`, `fzf`, `ssh`를 조합해 인스턴스 목록을 검색하고 선택형 UI로 접속합니다.

## 필요 조건
- AWS CLI 자격 증명 (`~/.aws/credentials` 또는 SSO)
- `fzf` (대화형 선택), `ssh`
- 보안 키 파일(`.pem`)을 로컬에 저장하고 접근 권한을 600으로 제한

## 환경 변수
| 변수 | 설명 | 기본값 |
| --- | --- | --- |
| `AWS_EC2_PEM_KEY_PATH` | SSH 접속에 사용할 PEM 키 경로 | `~/.config/zsh/environment.zsh` |
| `PROFILE` | 사용할 AWS CLI 프로파일 이름 | `mfa` |

원하는 리소스 태그에 맞게 함수 내부의 `name_filter` 값을 수정하면 특정 프로젝트/서비스만 조회

## 함수 설명
### `ec2-ssh`
1. 미리 준비한 리전 목록을 `fzf`로 표시하고 선택
2. 선택한 리전에서 `aws ec2 describe-instances`로 `Name` 태그에 `name_filter`가 포함된 실행 중 인스턴스를 조회
3. fzf에서 원하는 인스턴스를 고르면 해당 퍼블릭 IP로 SSH 접속

```zsh
# 특정 리전에서 인스턴스를 골라 접속
$ ec2-ssh
```

### `ec2-ssh-all`
- 모든 리전을 병렬로 조회하여 조건에 맞는 인스턴스를 한 번에 보여줌.
- 리전에 상관없이 원하는 인스턴스를 골라 SSH 접속

```zsh
# 전체 리전을 대상으로 검색
$ ec2-ssh-all
```

### `aws-help`
터미널에서 사용 가능한 AWS 함수 목록과 간단한 예시를 출력합니다.

```zsh
$ aws-help
```

## 커스터마이징 팁
- 새로운 리전을 추가하려면 `ec2-ssh`의 `regions` 배열을 수정합니다.
- 기본 접속 사용자(`ec2-user`)나 SSH 옵션을 바꾸고 싶다면 `ssh` 명령 부분을 편집합니다.
- SSM Session Manager를 쓰고 싶다면 `ssh` 대신 `aws ssm start-session`으로 교체하세요.
