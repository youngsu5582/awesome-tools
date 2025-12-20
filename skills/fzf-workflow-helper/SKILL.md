---
name: fzf-workflow-helper
description: FZF 워크플로우(Input-Select-Output-Process) 구조화, 각 단계 검증, 템플릿 생성. FZF 스크립트 작성, 디버깅, 테스트 자동화 시 사용.
allowed-tools: Read, Write, Bash, Grep, Glob
---

# FZF 워크플로우 헬퍼

FZF 기반 인터랙티브 스크립트를 체계적으로 작성하고 검증하는 도구입니다.

## 🎯 핵심 개념

FZF 워크플로우는 4단계로 구성됩니다:

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│  1. INPUT   │───>│  2. SELECT   │───>│  3. OUTPUT  │───>│  4. PROCESS  │
│  Generator  │    │  (FZF)       │    │  Parser     │    │  Handler     │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
    ↓                     ↓                    ↓                   ↓
  데이터 준비         사용자 선택          선택값 파싱         후속 작업
```

### 1. INPUT Generator
**역할**: 데이터 소스(배열, JSON, API)를 FZF가 처리할 수 있는 형식(TSV/테이블)으로 변환

**검증 항목**:
- 데이터 소스 접근 가능 여부
- 출력 형식 일관성 (필드 수, 구분자)
- jq 파싱 정확도
- 빈 데이터/오류 처리

### 2. SELECT (FZF)
**역할**: 사용자가 항목을 선택할 수 있는 인터페이스 제공

**검증 항목**:
- FZF 옵션 정확도 (delimiter, with-nth, prompt 등)
- 취소 시 처리
- 다중 선택 처리

### 3. OUTPUT Parser
**역할**: 선택된 값을 파싱하여 변수에 할당

**검증 항목**:
- 필드 파싱 정확도
- IFS 설정 검증
- 기본값 처리

### 4. PROCESS Handler
**역할**: 파싱된 값으로 실제 작업 수행

**검증 항목**:
- 로직 정확도
- 오류 처리
- 종료 코드 검증

---

## 📐 워크플로우 구조화 패턴

### 기본 템플릿

```bash
#!/usr/bin/env zsh

# ========================================
# 1. INPUT Generator
# ========================================
generate_input_data() {
    # 목적: 선택 가능한 항목 목록을 TSV 형식으로 출력
    # 출력 형식: field1\tfield2\tfield3\t...

    local data_source="$1"

    # 예: 배열에서 생성
    local items=(
        'key1\tvalue1\tdescription1'
        'key2\tvalue2\tdescription2'
    )
    printf "%s\n" "${items[@]}"

    # 예: JSON에서 생성 (jq 사용)
    # jq -r '.[] | "\(.id)\t\(.name)\t\(.status)"' "$data_source"

    # 예: API에서 생성
    # curl -s "$api_url" | jq -r '.items[] | "\(.id)\t\(.name)"'
}

# ========================================
# 2. SELECT (FZF)
# ========================================
select_item() {
    local input_data="$1"

    echo "$input_data" | fzf \
        --delimiter='\t' \
        --with-nth=2,3 \
        --prompt="항목 선택 > " \
        --header="NAME        DESCRIPTION" \
        --height=50% \
        --layout=reverse \
        --border
}

# ========================================
# 3. OUTPUT Parser
# ========================================
parse_selection() {
    local selection="$1"

    [[ -z "$selection" ]] && return 1

    local key value description
    IFS=$'\t' read -r key value description <<< "$selection"

    # 파싱된 값을 환경에 export (호출자에서 사용 가능)
    echo "$key"
    echo "$value"
    echo "$description"
}

# ========================================
# 4. PROCESS Handler
# ========================================
process_action() {
    local key="$1"
    local value="$2"
    local description="$3"

    echo "처리 중: $description"

    # 실제 작업 수행
    case "$key" in
        key1)
            # 작업 1
            ;;
        key2)
            # 작업 2
            ;;
        *)
            echo "알 수 없는 키: $key"
            return 1
            ;;
    esac
}

# ========================================
# Main Workflow
# ========================================
main() {
    setopt pipefail

    # 1. INPUT
    local input_data
    input_data=$(generate_input_data) || {
        echo "데이터 생성 실패"
        return 1
    }

    # 2. SELECT
    local selection
    selection=$(select_item "$input_data") || {
        echo "선택 취소"
        return 0
    }

    # 3. OUTPUT
    local parsed
    parsed=($(parse_selection "$selection")) || {
        echo "파싱 실패"
        return 1
    }

    local key="${parsed[1]}"
    local value="${parsed[2]}"
    local description="${parsed[3]}"

    # 4. PROCESS
    process_action "$key" "$value" "$description"
}

# 스크립트 실행
main "$@"
```

---

## 🧪 각 단계별 검증 방법

### 1. INPUT Generator 검증

**목표**: 데이터가 올바른 형식으로 생성되는지 확인

```bash
# test-input.sh
#!/usr/bin/env zsh

test_input_generator() {
    echo "=== INPUT Generator 테스트 ==="

    # 1. 출력 생성
    local output
    output=$(generate_input_data)

    # 2. 빈 출력 검증
    if [[ -z "$output" ]]; then
        echo "❌ FAIL: 출력이 비어있습니다"
        return 1
    fi
    echo "✅ PASS: 출력 생성 성공"

    # 3. 라인 수 검증
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    echo "📊 라인 수: $line_count"

    # 4. 필드 수 검증 (모든 라인이 동일한 필드 수를 가져야 함)
    local expected_fields=3
    local invalid_lines
    invalid_lines=$(echo "$output" | awk -F'\t' -v exp="$expected_fields" 'NF != exp {print NR": "NF" fields (expected "exp")"}')

    if [[ -n "$invalid_lines" ]]; then
        echo "❌ FAIL: 필드 수 불일치"
        echo "$invalid_lines"
        return 1
    fi
    echo "✅ PASS: 모든 라인이 $expected_fields 필드를 가짐"

    # 5. 샘플 출력
    echo "\n📋 샘플 데이터 (처음 5줄):"
    echo "$output" | head -5 | column -t -s $'\t'

    # 6. jq 파싱 검증 (JSON 소스인 경우)
    # local json_source="data.json"
    # if ! jq empty "$json_source" 2>/dev/null; then
    #     echo "❌ FAIL: JSON 파싱 오류"
    #     return 1
    # fi
    # echo "✅ PASS: JSON 파싱 성공"

    echo "\n✅ INPUT Generator 테스트 완료"
}

# 함수를 source한 후 테스트 실행
source your-script.sh
test_input_generator
```

### 2. SELECT (FZF) 검증

**목표**: FZF 옵션이 올바르게 설정되었는지 확인

```bash
# test-select.sh
#!/usr/bin/env zsh

test_fzf_options() {
    echo "=== FZF 옵션 테스트 ==="

    # 1. 모의 입력 데이터
    local mock_input='key1\tvalue1\tdescription1
key2\tvalue2\tdescription2
key3\tvalue3\tdescription3'

    # 2. FZF 명령어 추출 (실제로는 실행하지 않음)
    local fzf_command=$(declare -f select_item | grep -A 10 'fzf' | grep -v '^}')

    echo "📋 FZF 명령어:"
    echo "$fzf_command"

    # 3. 필수 옵션 검증
    local required_options=(
        "--delimiter"
        "--with-nth"
        "--prompt"
    )

    for opt in "${required_options[@]}"; do
        if echo "$fzf_command" | grep -q "$opt"; then
            echo "✅ PASS: $opt 옵션 존재"
        else
            echo "⚠️  WARN: $opt 옵션 누락"
        fi
    done

    # 4. delimiter와 with-nth 일관성 검증
    local delimiter_value
    delimiter_value=$(echo "$fzf_command" | grep -o "delimiter='[^']*'" | cut -d"'" -f2)
    echo "\n📊 Delimiter: [$delimiter_value]"

    # 5. 수동 테스트 가이드
    echo "\n📖 수동 테스트 방법:"
    echo "   echo '$mock_input' | select_item"
    echo "   (실제로 FZF 인터페이스를 확인해보세요)"
}

source your-script.sh
test_fzf_options
```

### 3. OUTPUT Parser 검증

**목표**: 선택값이 올바르게 파싱되는지 확인

```bash
# test-output.sh
#!/usr/bin/env zsh

test_output_parser() {
    echo "=== OUTPUT Parser 테스트 ==="

    # 1. 모의 선택값
    local mock_selection='key1\tvalue1\tdescription1'

    # 2. 파싱 실행
    local parsed
    parsed=($(parse_selection "$mock_selection"))
    local status=$?

    if [[ $status -ne 0 ]]; then
        echo "❌ FAIL: 파싱 실패 (exit code: $status)"
        return 1
    fi
    echo "✅ PASS: 파싱 성공"

    # 3. 필드 값 검증
    local key="${parsed[1]}"
    local value="${parsed[2]}"
    local description="${parsed[3]}"

    echo "📊 파싱 결과:"
    echo "   Key:         [$key]"
    echo "   Value:       [$value]"
    echo "   Description: [$description]"

    # 4. 예상값과 비교
    local expected_key="key1"
    local expected_value="value1"
    local expected_description="description1"

    local pass_count=0
    [[ "$key" == "$expected_key" ]] && {
        echo "✅ Key 일치"
        ((pass_count++))
    } || echo "❌ Key 불일치 (expected: $expected_key)"

    [[ "$value" == "$expected_value" ]] && {
        echo "✅ Value 일치"
        ((pass_count++))
    } || echo "❌ Value 불일치 (expected: $expected_value)"

    [[ "$description" == "$expected_description" ]] && {
        echo "✅ Description 일치"
        ((pass_count++))
    } || echo "❌ Description 불일치 (expected: $expected_description)"

    # 5. 엣지 케이스 테스트
    echo "\n🧪 엣지 케이스 테스트:"

    # 빈 입력
    parse_selection "" &>/dev/null
    [[ $? -ne 0 ]] && echo "✅ 빈 입력 처리 성공" || echo "❌ 빈 입력 처리 실패"

    # 필드 부족
    parse_selection "key1\tvalue1" &>/dev/null
    echo "⚠️  필드 부족 케이스: exit code $?"

    # 5. 종합 결과
    if [[ $pass_count -eq 3 ]]; then
        echo "\n✅ OUTPUT Parser 테스트 완료 (3/3)"
    else
        echo "\n⚠️  OUTPUT Parser 테스트 완료 ($pass_count/3)"
    fi
}

source your-script.sh
test_output_parser
```

### 4. PROCESS Handler 검증

**목표**: 후속 작업 로직이 올바르게 동작하는지 확인

```bash
# test-process.sh
#!/usr/bin/env zsh

test_process_handler() {
    echo "=== PROCESS Handler 테스트 ==="

    # 1. 테스트 케이스 정의
    local test_cases=(
        'key1\tvalue1\tdescription1\t0'  # key\tvalue\tdescription\texpected_exit_code
        'key2\tvalue2\tdescription2\t0'
        'invalid_key\tvalue\tdescription\t1'
    )

    local passed=0
    local failed=0

    for test_case in "${test_cases[@]}"; do
        IFS=$'\t' read -r key value description expected_exit <<< "$test_case"

        echo "\n📋 테스트: $description"

        # 2. 프로세스 실행
        local output
        output=$(process_action "$key" "$value" "$description" 2>&1)
        local actual_exit=$?

        # 3. 종료 코드 검증
        if [[ $actual_exit -eq $expected_exit ]]; then
            echo "✅ PASS: Exit code $actual_exit (expected $expected_exit)"
            ((passed++))
        else
            echo "❌ FAIL: Exit code $actual_exit (expected $expected_exit)"
            ((failed++))
        fi

        # 4. 출력 표시
        [[ -n "$output" ]] && echo "   출력: $output"
    done

    # 5. 종합 결과
    local total=$((passed + failed))
    echo "\n📊 테스트 결과: $passed/$total 통과"

    [[ $failed -eq 0 ]] && return 0 || return 1
}

source your-script.sh
test_process_handler
```

---

## 🔧 통합 검증 스크립트

모든 단계를 한 번에 검증하는 마스터 테스트 스크립트:

```bash
#!/usr/bin/env zsh
# test-all.sh

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_test() {
    local test_name="$1"
    local test_func="$2"

    echo "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${YELLOW}▶ $test_name${NC}"
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if $test_func; then
        echo "\n${GREEN}✓ $test_name 성공${NC}"
        return 0
    else
        echo "\n${RED}✗ $test_name 실패${NC}"
        return 1
    fi
}

main() {
    local passed=0
    local failed=0

    # 스크립트 소스
    source your-script.sh

    # 각 단계별 테스트 실행
    run_test "1. INPUT Generator" test_input_generator && ((passed++)) || ((failed++))
    run_test "2. FZF Options" test_fzf_options && ((passed++)) || ((failed++))
    run_test "3. OUTPUT Parser" test_output_parser && ((passed++)) || ((failed++))
    run_test "4. PROCESS Handler" test_process_handler && ((passed++)) || ((failed++))

    # 최종 결과
    echo "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${YELLOW}📊 최종 결과${NC}"
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${GREEN}통과: $passed${NC}"
    echo "${RED}실패: $failed${NC}"

    [[ $failed -eq 0 ]] && {
        echo "\n${GREEN}✅ 모든 테스트 통과!${NC}"
        return 0
    } || {
        echo "\n${RED}❌ 일부 테스트 실패${NC}"
        return 1
    }
}

main "$@"
```

---

## 📚 실전 예제

### 예제 1: API 호출 워크플로우

사용자의 `send-api` 스크립트를 개선한 버전:

```bash
#!/usr/bin/env zsh

# ========================================
# 설정
# ========================================
export SERVERS_JSON=".system/servers.json"
export ENDPOINTS_JSON=".system/endpoints.json"

# ========================================
# 1. INPUT: 서버 목록 생성
# ========================================
generate_server_list() {
    # JSON에서 서버 목록 생성
    jq -r '.servers[] | "\(.key)\t\(.url)\t\(.name)"' "$SERVERS_JSON"
}

# ========================================
# 2. SELECT: 서버 선택
# ========================================
select_server() {
    generate_server_list | fzf \
        --delimiter='\t' \
        --with-nth=3,2 \
        --prompt="서버 선택 > " \
        --header="NAME                URL" \
        --height=40%
}

# ========================================
# 3. OUTPUT: 서버 정보 파싱
# ========================================
parse_server() {
    local selection="$1"
    [[ -z "$selection" ]] && return 1

    local key url name
    IFS=$'\t' read -r key url name <<< "$selection"

    echo "$key"
    echo "$url"
    echo "$name"
}

# ========================================
# 1-2. INPUT: 엔드포인트 목록 생성
# ========================================
generate_endpoint_list() {
    local server_key="$1"

    jq -r --arg key "$server_key" \
        '.endpoints[] | select(.server == $key) | "\(.method)\t\(.path)\t\(.description)"' \
        "$ENDPOINTS_JSON"
}

# ========================================
# 2-2. SELECT: 엔드포인트 선택
# ========================================
select_endpoint() {
    local server_key="$1"

    generate_endpoint_list "$server_key" | fzf \
        --delimiter='\t' \
        --with-nth=1,2,3 \
        --prompt="엔드포인트 선택 > " \
        --header="METHOD  PATH                DESCRIPTION" \
        --height=60%
}

# ========================================
# 3-2. OUTPUT: 엔드포인트 정보 파싱
# ========================================
parse_endpoint() {
    local selection="$1"
    [[ -z "$selection" ]] && return 1

    local method path description
    IFS=$'\t' read -r method path description <<< "$selection"

    echo "$method"
    echo "$path"
    echo "$description"
}

# ========================================
# 4. PROCESS: API 요청 실행
# ========================================
execute_api_request() {
    local server_url="$1"
    local method="$2"
    local path="$3"

    local full_url="${server_url}${path}"

    echo "요청 실행 중: $method $full_url"

    http --print=hb "$method" "$full_url"
}

# ========================================
# Main Workflow
# ========================================
main() {
    setopt pipefail

    # 1. 서버 선택
    local server_selection
    server_selection=$(select_server) || {
        echo "서버 선택 취소"
        return 0
    }

    local server_info
    server_info=($(parse_server "$server_selection")) || {
        echo "서버 정보 파싱 실패"
        return 1
    }

    local server_key="${server_info[1]}"
    local server_url="${server_info[2]}"
    local server_name="${server_info[3]}"

    echo "선택된 서버: $server_name ($server_url)"

    # 2. 엔드포인트 선택
    local endpoint_selection
    endpoint_selection=$(select_endpoint "$server_key") || {
        echo "엔드포인트 선택 취소"
        return 0
    }

    local endpoint_info
    endpoint_info=($(parse_endpoint "$endpoint_selection")) || {
        echo "엔드포인트 정보 파싱 실패"
        return 1
    }

    local method="${endpoint_info[1]}"
    local path="${endpoint_info[2]}"
    local description="${endpoint_info[3]}"

    echo "선택된 엔드포인트: $description"

    # 3. API 요청 실행
    execute_api_request "$server_url" "$method" "$path"
}

main "$@"
```

**검증 스크립트** (`test-send-api.sh`):

```bash
#!/usr/bin/env zsh

# 모의 데이터 생성
setup_mock_data() {
    mkdir -p .system

    cat > .system/servers.json <<'EOF'
{
  "servers": [
    {"key": "local", "url": "http://localhost:8080", "name": "Local Server"},
    {"key": "dev", "url": "https://dev.example.com", "name": "Dev Server"}
  ]
}
EOF

    cat > .system/endpoints.json <<'EOF'
{
  "endpoints": [
    {"server": "local", "method": "GET", "path": "/api/users", "description": "Get Users"},
    {"server": "local", "method": "POST", "path": "/api/users", "description": "Create User"},
    {"server": "dev", "method": "GET", "path": "/api/products", "description": "Get Products"}
  ]
}
EOF
}

# INPUT 테스트
test_server_list_generation() {
    echo "=== 서버 목록 생성 테스트 ==="

    local output
    output=$(generate_server_list)

    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    echo "생성된 서버 수: $line_count"
    echo "$output" | column -t -s $'\t'

    [[ $line_count -eq 2 ]] && echo "✅ PASS" || echo "❌ FAIL"
}

# OUTPUT 테스트
test_server_parsing() {
    echo "\n=== 서버 파싱 테스트 ==="

    local mock_selection='local\thttp://localhost:8080\tLocal Server'
    local parsed
    parsed=($(parse_server "$mock_selection"))

    local key="${parsed[1]}"
    local url="${parsed[2]}"
    local name="${parsed[3]}"

    echo "Key: [$key]"
    echo "URL: [$url]"
    echo "Name: [$name]"

    [[ "$key" == "local" ]] && echo "✅ PASS" || echo "❌ FAIL"
}

# PROCESS 테스트 (dry-run)
test_api_execution() {
    echo "\n=== API 실행 테스트 (dry-run) ==="

    local server_url="http://localhost:8080"
    local method="GET"
    local path="/api/users"

    local full_url="${server_url}${path}"

    echo "요청할 URL: $method $full_url"

    # 실제 요청 대신 curl 명령어만 출력
    echo "curl 명령어: curl -X $method $full_url"

    echo "✅ PASS (dry-run)"
}

main() {
    setup_mock_data
    source send-api.sh

    test_server_list_generation
    test_server_parsing
    test_api_execution
}

main "$@"
```

---

### 예제 2: Vast.ai SSH 워크플로우

사용자의 `vast-ssh` 스크립트를 개선한 버전:

```bash
#!/usr/bin/env zsh

# ========================================
# 설정
# ========================================
VAST_CONFIG_JSON="${VAST_CONFIG_JSON:-.system/settings/vast.json}"

# ========================================
# 설정 로드
# ========================================
load_vast_config() {
    [[ ! -f "$VAST_CONFIG_JSON" ]] && {
        echo "❌ Vast 설정 파일을 찾을 수 없습니다: $VAST_CONFIG_JSON"
        return 1
    }

    local api_key=$(jq -r '."api-key"' "$VAST_CONFIG_JSON")
    local key_path=$(jq -r '."ssh-key-path"' "$VAST_CONFIG_JSON")
    key_path="${key_path/#\~/$HOME}"

    echo "$api_key"
    echo "$key_path"
}

# ========================================
# 1. INPUT: 인스턴스 목록 생성
# ========================================
generate_instance_list() {
    local api_key="$1"

    curl -s -L -X GET 'https://console.vast.ai/api/v0/instances/' \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $api_key" | \
        tr -d '\000-\010\013-\037' | \
        jq -r '.instances[] | [
            (.label // "no-label"),
            .public_ipaddr,
            (.id | tostring),
            .actual_status,
            .gpu_name,
            (.geolocation // "N/A"),
            (.ports["22/tcp"][0].HostPort // "N/A")
        ] | @tsv'
}

# ========================================
# 2. SELECT: 인스턴스 선택
# ========================================
select_instance() {
    local instance_data="$1"

    echo "$instance_data" | column -t -s $'\t' | fzf \
        --prompt="🖥️  인스턴스 선택 > " \
        --header="LABEL          IP              ID      STATUS       GPU          LOCATION     PORT" \
        --layout=reverse \
        --height=50% \
        --border
}

# ========================================
# 3. OUTPUT: 인스턴스 정보 파싱
# ========================================
parse_instance() {
    local selection="$1"

    # column으로 포맷된 출력을 파싱하기 위해 awk 사용
    local label=$(echo "$selection" | awk '{print $1}')
    local public_ip=$(echo "$selection" | awk '{print $2}')
    local instance_id=$(echo "$selection" | awk '{print $3}')
    local status=$(echo "$selection" | awk '{print $4}')
    local ssh_port=$(echo "$selection" | awk '{print $NF}')

    echo "$label"
    echo "$public_ip"
    echo "$instance_id"
    echo "$status"
    echo "$ssh_port"
}

# ========================================
# 4. PROCESS: 액션 선택 및 실행
# ========================================
select_action() {
    printf "🚀 SSH 접속 (Tunneling)\n📋 로그 확인 (Logs)\n🛑 인스턴스 중지 (Stop)\n❌ 취소" | \
        fzf --prompt="액션 선택 > " --height=15% --layout=reverse
}

execute_ssh() {
    local key_path="$1"
    local public_ip="$2"
    local ssh_port="$3"
    local l_port="${4:-8080}"
    local r_port="${5:-18188}"

    echo "📡 연결 중: ssh -p $ssh_port root@$public_ip -L ${l_port}:localhost:${r_port}"
    ssh -i "$key_path" -p "$ssh_port" -o StrictHostKeyChecking=no "root@$public_ip" -L "${l_port}:localhost:${r_port}"
}

execute_logs() {
    local api_key="$1"
    local instance_id="$2"
    local tail_lines="${3:-1000}"

    echo "⏳ 로그 생성 요청 중..."
    local log_res
    log_res=$(curl -s -L -X PUT "https://console.vast.ai/api/v0/instances/request_logs/${instance_id}/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{\"tail\": \"$tail_lines\"}")

    local result_url=$(echo "$log_res" | jq -r '.result_url')

    if [[ "$result_url" != "null" ]]; then
        echo "⏳ S3 권한 승인 대기 중 (2s)..."
        sleep 2
        curl -sL "$result_url"
    else
        echo "❌ 로그 URL을 가져오지 못했습니다."
        return 1
    fi
}

execute_stop() {
    local api_key="$1"
    local instance_id="$2"

    read "confirm?정말 중지하시겠습니까? (y/N): "

    if [[ "$confirm" == "y" ]]; then
        curl -s -X PUT "https://console.vast.ai/api/v0/instances/$instance_id/" \
            -H "Authorization: Bearer $api_key" \
            -d '{"state": "stopped"}' | jq .
    else
        echo "취소되었습니다."
    fi
}

# ========================================
# Main Workflow
# ========================================
main() {
    setopt pipefail

    # 1. 설정 로드
    local config
    config=($(load_vast_config)) || return 1

    local api_key="${config[1]}"
    local key_path="${config[2]}"

    # 2. 인스턴스 목록 생성
    echo "🔍 Vast.ai 인스턴스 동기화 중..."
    local instance_data
    instance_data=$(generate_instance_list "$api_key") || {
        echo "❌ 인스턴스 목록 가져오기 실패"
        return 1
    }

    # 3. 인스턴스 선택
    local instance_selection
    instance_selection=$(select_instance "$instance_data") || {
        echo "👋 취소되었습니다."
        return 0
    }

    # 4. 인스턴스 정보 파싱
    local instance_info
    instance_info=($(parse_instance "$instance_selection"))

    local label="${instance_info[1]}"
    local public_ip="${instance_info[2]}"
    local instance_id="${instance_info[3]}"
    local status="${instance_info[4]}"
    local ssh_port="${instance_info[5]}"

    echo "\n──────────────────────────────────────"
    echo "🏷️  Label: $label ($instance_id)"
    echo "🚥 Status: $status"
    echo "🌐 Address: root@$public_ip:$ssh_port"
    echo "──────────────────────────────────────"

    # 5. 액션 선택
    local action
    action=$(select_action) || {
        echo "취소되었습니다."
        return 0
    }

    # 6. 액션 실행
    case "$action" in
        "🚀 SSH 접속 (Tunneling)")
            execute_ssh "$key_path" "$public_ip" "$ssh_port"
            ;;
        "📋 로그 확인 (Logs)")
            execute_logs "$api_key" "$instance_id"
            ;;
        "🛑 인스턴스 중지 (Stop)")
            execute_stop "$api_key" "$instance_id"
            ;;
        *)
            echo "취소되었습니다."
            ;;
    esac
}

main "$@"
```

**검증 스크립트** (`test-vast-ssh.sh`):

```bash
#!/usr/bin/env zsh

# 모의 API 응답 생성
generate_mock_api_response() {
    cat <<'EOF'
{
  "instances": [
    {
      "label": "gpu-instance-1",
      "public_ipaddr": "192.168.1.100",
      "id": 12345,
      "actual_status": "running",
      "gpu_name": "RTX 3090",
      "geolocation": "US, California",
      "ports": {
        "22/tcp": [{"HostPort": "23456"}]
      }
    },
    {
      "label": "gpu-instance-2",
      "public_ipaddr": "192.168.1.101",
      "id": 67890,
      "actual_status": "stopped",
      "gpu_name": "RTX 4090",
      "geolocation": "US, Texas",
      "ports": {
        "22/tcp": [{"HostPort": "34567"}]
      }
    }
  ]
}
EOF
}

# INPUT 테스트 (API 파싱)
test_instance_list_generation() {
    echo "=== 인스턴스 목록 생성 테스트 ==="

    local mock_response
    mock_response=$(generate_mock_api_response)

    # jq 파싱 테스트
    local output
    output=$(echo "$mock_response" | jq -r '.instances[] | [
        (.label // "no-label"),
        .public_ipaddr,
        (.id | tostring),
        .actual_status,
        .gpu_name,
        (.geolocation // "N/A"),
        (.ports["22/tcp"][0].HostPort // "N/A")
    ] | @tsv')

    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')

    echo "생성된 인스턴스 수: $line_count"
    echo "\n샘플 출력:"
    echo "$output" | column -t -s $'\t'

    # 필드 수 검증 (7개 필드 예상)
    local invalid_lines
    invalid_lines=$(echo "$output" | awk -F'\t' 'NF != 7 {print NR": "NF" fields"}')

    if [[ -z "$invalid_lines" ]]; then
        echo "\n✅ PASS: 모든 라인이 7개 필드를 가짐"
    else
        echo "\n❌ FAIL: 필드 수 불일치"
        echo "$invalid_lines"
    fi
}

# OUTPUT 테스트
test_instance_parsing() {
    echo "\n=== 인스턴스 정보 파싱 테스트 ==="

    local mock_selection='gpu-instance-1 192.168.1.100 12345 running RTX-3090 US,California 23456'

    local label=$(echo "$mock_selection" | awk '{print $1}')
    local public_ip=$(echo "$mock_selection" | awk '{print $2}')
    local instance_id=$(echo "$mock_selection" | awk '{print $3}')
    local status=$(echo "$mock_selection" | awk '{print $4}')
    local ssh_port=$(echo "$mock_selection" | awk '{print $NF}')

    echo "Label:       [$label]"
    echo "Public IP:   [$public_ip]"
    echo "Instance ID: [$instance_id]"
    echo "Status:      [$status]"
    echo "SSH Port:    [$ssh_port]"

    # 검증
    [[ "$label" == "gpu-instance-1" ]] && \
    [[ "$public_ip" == "192.168.1.100" ]] && \
    [[ "$instance_id" == "12345" ]] && \
    [[ "$ssh_port" == "23456" ]] && \
        echo "\n✅ PASS: 파싱 정확" || echo "\n❌ FAIL: 파싱 오류"
}

# PROCESS 테스트 (SSH 명령어 생성)
test_ssh_command_generation() {
    echo "\n=== SSH 명령어 생성 테스트 ==="

    local key_path="~/.ssh/id_rsa"
    local public_ip="192.168.1.100"
    local ssh_port="23456"
    local l_port="8080"
    local r_port="18188"

    local ssh_command="ssh -i $key_path -p $ssh_port -o StrictHostKeyChecking=no root@$public_ip -L ${l_port}:localhost:${r_port}"

    echo "생성된 SSH 명령어:"
    echo "$ssh_command"

    # 필수 요소 검증
    echo "$ssh_command" | grep -q -- "-i $key_path" && echo "✅ Key path 포함"
    echo "$ssh_command" | grep -q -- "-p $ssh_port" && echo "✅ Port 포함"
    echo "$ssh_command" | grep -q -- "root@$public_ip" && echo "✅ User@Host 포함"
    echo "$ssh_command" | grep -q -- "-L ${l_port}:localhost:${r_port}" && echo "✅ Tunnel 포함"
}

main() {
    test_instance_list_generation
    test_instance_parsing
    test_ssh_command_generation
}

main "$@"
```

---

## 🎓 베스트 프랙티스

### 1. 함수 분리 원칙
각 단계를 독립된 함수로 분리하여 테스트 가능성을 높입니다.

```bash
# ❌ 나쁜 예: 모든 로직이 한 함수에
function workflow() {
    local data=$(curl ... | jq ... | fzf ...)
    # 테스트 불가능!
}

# ✅ 좋은 예: 각 단계 분리
function generate_input() { ... }
function select_with_fzf() { ... }
function parse_output() { ... }
function process_data() { ... }
```

### 2. 오류 처리
모든 단계에서 오류를 명확히 처리합니다.

```bash
# 파이프 실패 감지
setopt pipefail

# 각 단계에서 오류 검증
local data
data=$(generate_input) || {
    echo "❌ 데이터 생성 실패"
    return 1
}
```

### 3. 데이터 형식 일관성
TSV 구분자와 필드 순서를 일관되게 유지합니다.

```bash
# 모든 입력 데이터는 동일한 필드 수를 가져야 함
# 예: 항상 3개 필드 (key\tvalue\tdescription)

# jq 출력
jq -r '.[] | "\(.id)\t\(.name)\t\(.status)"'

# 배열 출력
printf "%s\n" "id1\tname1\tstatus1" "id2\tname2\tstatus2"
```

### 4. FZF 옵션 최적화
사용자 경험을 고려한 FZF 옵션을 설정합니다.

```bash
fzf \
    --delimiter='\t' \          # 구분자
    --with-nth=2,3 \            # 표시할 필드
    --prompt="선택 > " \        # 프롬프트
    --header="FIELD1  FIELD2" \ # 헤더
    --height=50% \              # 높이
    --layout=reverse \          # 레이아웃
    --border \                  # 테두리
    --preview='...' \           # 미리보기
    --preview-window=right:50%  # 미리보기 창
```

### 5. 디버그 모드
디버그 출력을 쉽게 활성화할 수 있도록 합니다.

```bash
DEBUG="${DEBUG:-false}"

debug_log() {
    [[ "$DEBUG" == "true" ]] && echo "[DEBUG] $*" >&2
}

# 사용
debug_log "서버 선택: $server_key"

# 활성화
# DEBUG=true ./script.sh
```

---

## 🚀 빠른 시작 가이드

### 1단계: 스크립트 템플릿 생성

```bash
# 새 스크립트 생성
cp /path/to/template/basic-workflow.sh my-workflow.sh
chmod +x my-workflow.sh
```

### 2단계: INPUT 함수 작성

```bash
# 데이터 소스에 맞게 수정
generate_input_data() {
    # 여기에 데이터 생성 로직 추가
}
```

### 3단계: INPUT 검증

```bash
# 테스트 스크립트 실행
./test-input.sh

# 출력 확인
# - 라인 수 확인
# - 필드 수 일관성 확인
# - 샘플 데이터 확인
```

### 4단계: SELECT/OUTPUT/PROCESS 구현 및 검증

```bash
# 각 단계별로 구현 후 테스트
./test-select.sh
./test-output.sh
./test-process.sh
```

### 5단계: 통합 테스트

```bash
# 전체 워크플로우 테스트
./test-all.sh

# 실제 실행
./my-workflow.sh
```

---

## 📖 참고 자료

### FZF 주요 옵션

| 옵션 | 설명 | 예제 |
|------|------|------|
| `--delimiter` | 필드 구분자 | `--delimiter='\t'` |
| `--with-nth` | 표시할 필드 | `--with-nth=1,2` |
| `--prompt` | 프롬프트 텍스트 | `--prompt="선택 > "` |
| `--header` | 헤더 텍스트 | `--header="NAME  VALUE"` |
| `--height` | 높이 | `--height=50%` |
| `--layout` | 레이아웃 | `--layout=reverse` |
| `--preview` | 미리보기 명령 | `--preview='cat {}'` |
| `--multi` | 다중 선택 | `--multi` |
| `--query` | 초기 쿼리 | `--query="search"` |

### jq 주요 패턴

```bash
# 배열 -> TSV
jq -r '.[] | "\(.field1)\t\(.field2)"'

# 조건 필터링
jq -r '.[] | select(.status == "active") | "\(.id)\t\(.name)"'

# 기본값 처리
jq -r '.[] | "\(.id)\t(.name // "no-name")"'

# 중첩 필드 접근
jq -r '.[] | "\(.id)\t\(.user.name)"'
```

---

## ✨ 마무리

이 스킬을 사용하면:

✅ FZF 워크플로우를 **체계적으로** 구조화할 수 있습니다.
✅ 각 단계를 **독립적으로 테스트**할 수 있습니다.
✅ jq 파싱 오류를 **사전에 발견**할 수 있습니다.
✅ 로직 오류를 **빠르게 디버깅**할 수 있습니다.
✅ **재사용 가능한** 스크립트를 작성할 수 있습니다.

**Happy FZF Scripting! 🎉**
