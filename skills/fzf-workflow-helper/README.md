# FZF 워크플로우 헬퍼

FZF 기반 인터랙티브 스크립트를 체계적으로 작성하고 검증하는 스킬입니다.

## 📁 구조

```
.claude/skills/fzf-workflow-helper/
├── SKILL.md                      # 스킬 상세 문서 (Claude가 참조)
├── README.md                     # 이 파일
├── templates/
│   └── basic-workflow.sh        # 기본 워크플로우 템플릿
├── tests/
│   └── test-workflow.sh         # 통합 테스트 스크립트
└── examples/
    └── example-api-caller.sh    # API 호출 예제
```

## 🚀 빠른 시작

### 1. 템플릿 복사

```bash
cp .claude/skills/fzf-workflow-helper/templates/basic-workflow.sh my-script.sh
chmod +x my-script.sh
```

### 2. 스크립트 수정

`my-script.sh` 파일을 열고 4가지 함수를 프로젝트에 맞게 수정:

- `generate_input_data()`: 데이터 소스에서 TSV 형식으로 변환
- `select_item()`: FZF 옵션 설정
- `parse_selection()`: 선택값 파싱
- `process_action()`: 실제 작업 로직

### 3. 테스트 실행

```bash
.claude/skills/fzf-workflow-helper/tests/test-workflow.sh my-script.sh
```

### 4. 실행

```bash
./my-script.sh
```

## 🎯 워크플로우 패턴

모든 FZF 스크립트는 4단계로 구조화됩니다:

```
1. INPUT Generator   → 데이터 소스를 TSV로 변환
2. SELECT (FZF)      → 사용자가 항목 선택
3. OUTPUT Parser     → 선택값을 변수로 파싱
4. PROCESS Handler   → 실제 작업 수행
```

각 단계는 독립된 함수로 분리되어 **개별 테스트**가 가능합니다.

## 📚 예제

### 예제 1: API 호출 워크플로우

```bash
# 예제 실행
.claude/skills/fzf-workflow-helper/examples/example-api-caller.sh
```

이 예제는 다음을 보여줍니다:
- JSON 파일에서 서버/엔드포인트 목록 로드
- jq를 사용한 데이터 파싱
- 2단계 선택 (서버 → 엔드포인트)
- HTTPie를 사용한 API 호출

### 예제 2: 사용자의 send-api 개선

사용자가 제공한 `send-api` 스크립트를 다음과 같이 개선할 수 있습니다:

**Before (단일 함수에 모든 로직)**:
```bash
function send-api() {
    # 300줄의 코드가 한 함수에...
    # 테스트 불가능
}
```

**After (단계별 함수 분리)**:
```bash
generate_server_list() { ... }      # INPUT - 테스트 가능
select_server() { ... }              # SELECT - 설정 검증 가능
parse_server() { ... }               # OUTPUT - 파싱 검증 가능
execute_api_request() { ... }       # PROCESS - 로직 검증 가능
```

## 🧪 테스트 방법

### 전체 테스트 실행

```bash
.claude/skills/fzf-workflow-helper/tests/test-workflow.sh my-script.sh
```

출력 예시:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ 1. INPUT Generator 테스트
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ️  generate_input_data 함수 실행 중...
✅ 출력 생성 성공
ℹ️  생성된 라인 수: 3
ℹ️  예상 필드 수: 3
✅ 모든 라인이 3 필드를 가짐
ℹ️  샘플 데이터 (처음 5줄):
  item1                value1               description1
  item2                value2               description2
  item3                value3               description3
✅ TSV 형식 확인됨
✅ INPUT Generator 테스트 완료

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 최종 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
통과: 5
실패: 0
총: 5

✅ ✨ 모든 테스트 통과! 스크립트가 올바르게 구조화되었습니다.
```

### 개별 단계 테스트

스크립트를 source한 후 각 함수를 직접 호출:

```bash
# 스크립트 로드
source my-script.sh

# INPUT 테스트
generate_input_data

# OUTPUT 테스트 (모의 데이터)
parse_selection "key1\tvalue1\tdescription1"

# PROCESS 테스트
process_action "key1" "value1" "description1"
```

## 🔧 디버그 모드

```bash
# 디버그 출력 활성화
DEBUG=true ./my-script.sh
```

디버그 모드에서는 각 단계의 실행 상태가 출력됩니다:
```
[DEBUG] 워크플로우 시작
[DEBUG] INPUT 데이터 생성 시작
[DEBUG] INPUT 데이터 생성 완료
[DEBUG] FZF 선택 시작
...
```

## 📖 주요 함수 시그니처

### generate_input_data()
```bash
# 입력: 없음 (또는 데이터 소스 경로)
# 출력: TSV 형식의 데이터 (stdout)
# 형식: field1\tfield2\tfield3\n...
generate_input_data() {
    # 예: JSON 파일
    jq -r '.[] | "\(.id)\t\(.name)\t\(.description)"' data.json

    # 예: API
    curl -s "$api_url" | jq -r '...'

    # 예: 배열
    local items=('key1\tval1\tdesc1' 'key2\tval2\tdesc2')
    printf "%s\n" "${items[@]}"
}
```

### select_item(input_data)
```bash
# 입력: TSV 형식의 데이터
# 출력: 선택된 라인 (stdout) 또는 취소 시 빈 문자열
select_item() {
    local input_data="$1"
    echo "$input_data" | fzf --delimiter='\t' --with-nth=2,3 ...
}
```

### parse_selection(selection)
```bash
# 입력: 선택된 TSV 라인
# 출력: 각 필드를 개별 라인으로 (stdout)
parse_selection() {
    local selection="$1"
    local field1 field2 field3
    IFS=$'\t' read -r field1 field2 field3 <<< "$selection"
    echo "$field1"
    echo "$field2"
    echo "$field3"
}
```

### process_action(field1, field2, field3)
```bash
# 입력: 파싱된 필드들
# 출력: 작업 결과 (stdout/stderr)
# 종료 코드: 0=성공, 1=실패
process_action() {
    local field1="$1"
    local field2="$2"
    local field3="$3"

    # 실제 작업 수행
    case "$field1" in
        action1) do_something ;;
        action2) do_something_else ;;
    esac
}
```

## 🎓 베스트 프랙티스

### 1. 함수 분리
각 단계를 독립된 함수로 분리하여 테스트 가능성을 높입니다.

### 2. 오류 처리
```bash
setopt pipefail  # 파이프 실패 감지

local data
data=$(generate_input) || {
    echo "❌ 데이터 생성 실패"
    return 1
}
```

### 3. 데이터 형식 일관성
모든 INPUT 데이터는 동일한 필드 수를 가져야 합니다.

### 4. FZF 옵션 최적화
- `--delimiter`: 필드 구분자 명시
- `--with-nth`: 표시할 필드 선택
- `--header`: 사용자에게 명확한 헤더 제공
- `--preview`: 복잡한 데이터는 미리보기 추가

### 5. 입력 검증
```bash
# 빈 데이터 체크
[[ -z "$input_data" ]] && { error_log "데이터 없음"; return 1; }

# 필드 수 검증
local field_count=$(echo "$line" | awk -F'\t' '{print NF}')
[[ $field_count -ne 3 ]] && { error_log "필드 수 불일치"; return 1; }
```

## 🐛 문제 해결

### INPUT 데이터가 생성되지 않음
```bash
# 디버그 모드로 실행
DEBUG=true ./my-script.sh

# 함수 직접 호출
source my-script.sh
generate_input_data

# jq 파싱 오류 확인 (JSON 소스인 경우)
jq empty data.json  # 유효성 검사
```

### FZF 선택이 제대로 표시되지 않음
```bash
# delimiter와 with-nth 확인
echo "field1\tfield2\tfield3" | fzf --delimiter='\t' --with-nth=2,3

# column으로 미리 포맷팅
generate_input_data | column -t -s $'\t' | fzf
```

### OUTPUT 파싱이 정확하지 않음
```bash
# 모의 데이터로 테스트
parse_selection "key1\tvalue1\tdescription1"

# IFS 설정 확인
echo "$IFS" | od -c  # \t가 포함되어야 함
```

## 📚 참고 자료

- [FZF GitHub](https://github.com/junegunn/fzf)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- 프로젝트 스킬 문서: `.claude/skills/fzf-workflow-helper/SKILL.md`

## 💡 활용 사례

이 스킬은 다음과 같은 경우에 유용합니다:

- ✅ API 테스트 스크립트
- ✅ 서버 관리 자동화
- ✅ 배포 스크립트
- ✅ 데이터베이스 쿼리 실행기
- ✅ Git 브랜치 관리
- ✅ Docker 컨테이너 관리
- ✅ Cloud 인스턴스 관리
- ✅ 로그 분석 도구

---

**Happy FZF Scripting! 🎉**
