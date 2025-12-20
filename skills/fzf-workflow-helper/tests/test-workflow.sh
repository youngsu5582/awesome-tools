#!/usr/bin/env zsh
# FZF 워크플로우 통합 테스트 스크립트
# 사용법: ./test-workflow.sh <your-script.sh>

# ========================================
# 색상 정의
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ========================================
# 유틸리티 함수
# ========================================
print_header() {
    echo "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${YELLOW}▶ $1${NC}"
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo "${GREEN}✅ $1${NC}"
}

print_fail() {
    echo "${RED}❌ $1${NC}"
}

print_warn() {
    echo "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo "${BLUE}ℹ️  $1${NC}"
}

# ========================================
# 1. INPUT Generator 테스트
# ========================================
test_input_generator() {
    print_header "1. INPUT Generator 테스트"

    print_info "generate_input_data 함수 실행 중..."

    # 출력 생성
    local output
    output=$(generate_input_data 2>&1)
    local status=$?

    if [[ $status -ne 0 ]]; then
        print_fail "함수 실행 실패 (exit code: $status)"
        return 1
    fi

    # 빈 출력 검증
    if [[ -z "$output" ]]; then
        print_fail "출력이 비어있습니다"
        return 1
    fi
    print_success "출력 생성 성공"

    # 라인 수 확인
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    print_info "생성된 라인 수: $line_count"

    # 필드 수 검증
    local expected_fields
    expected_fields=$(echo "$output" | head -1 | awk -F'\t' '{print NF}')
    print_info "예상 필드 수: $expected_fields"

    local invalid_lines
    invalid_lines=$(echo "$output" | awk -F'\t' -v exp="$expected_fields" 'NF != exp {print "  라인 "NR": "NF" 필드 (예상: "exp")"}')

    if [[ -n "$invalid_lines" ]]; then
        print_fail "필드 수 불일치"
        echo "$invalid_lines"
        return 1
    fi
    print_success "모든 라인이 $expected_fields 필드를 가짐"

    # 샘플 데이터 출력
    print_info "샘플 데이터 (처음 5줄):"
    echo "$output" | head -5 | awk -F'\t' '{printf "  %-20s %-20s %-30s\n", $1, $2, $3}'

    # TSV 형식 검증
    if echo "$output" | grep -q $'\t'; then
        print_success "TSV 형식 확인됨"
    else
        print_warn "TSV 구분자(\\t)가 감지되지 않음"
    fi

    print_success "INPUT Generator 테스트 완료"
    return 0
}

# ========================================
# 2. FZF 옵션 테스트
# ========================================
test_fzf_options() {
    print_header "2. FZF 옵션 테스트"

    # 함수 정의 추출
    local func_def
    func_def=$(declare -f select_item 2>/dev/null)

    if [[ -z "$func_def" ]]; then
        print_fail "select_item 함수를 찾을 수 없습니다"
        return 1
    fi

    print_success "select_item 함수 발견"

    # FZF 명령어 추출
    local fzf_command
    fzf_command=$(echo "$func_def" | grep -A 20 'fzf')

    if [[ -z "$fzf_command" ]]; then
        print_fail "FZF 명령어를 찾을 수 없습니다"
        return 1
    fi

    print_info "FZF 명령어:"
    echo "$fzf_command" | sed 's/^/  /'

    # 필수 옵션 검증
    local required_options=(
        "--delimiter"
        "--with-nth"
        "--prompt"
    )

    local all_passed=true
    for opt in "${required_options[@]}"; do
        if echo "$fzf_command" | grep -q -- "$opt"; then
            print_success "$opt 옵션 존재"
        else
            print_warn "$opt 옵션 누락 (권장)"
            all_passed=false
        fi
    done

    # delimiter 값 추출
    local delimiter_value
    delimiter_value=$(echo "$fzf_command" | grep -o "delimiter=[\"'].*[\"']" | head -1 | sed "s/delimiter=[\"']//;s/[\"']//")

    if [[ -n "$delimiter_value" ]]; then
        print_info "Delimiter 값: [$delimiter_value]"
    fi

    # 수동 테스트 안내
    print_info "수동 테스트 방법:"
    echo "  1. 스크립트를 실행하여 실제 FZF 인터페이스를 확인하세요"
    echo "  2. 선택 UI, 프롬프트, 헤더가 올바르게 표시되는지 확인하세요"

    if $all_passed; then
        print_success "FZF 옵션 테스트 완료"
        return 0
    else
        print_warn "FZF 옵션 테스트 완료 (일부 권장 옵션 누락)"
        return 0
    fi
}

# ========================================
# 3. OUTPUT Parser 테스트
# ========================================
test_output_parser() {
    print_header "3. OUTPUT Parser 테스트"

    # 모의 데이터 생성
    local mock_input
    mock_input=$(generate_input_data 2>/dev/null | head -1)

    if [[ -z "$mock_input" ]]; then
        print_fail "모의 입력 데이터 생성 실패"
        return 1
    fi

    print_info "모의 선택값: $mock_input"

    # 파싱 실행
    local parsed
    parsed=($(parse_selection "$mock_input" 2>&1))
    local status=$?

    if [[ $status -ne 0 ]]; then
        print_fail "파싱 실패 (exit code: $status)"
        return 1
    fi
    print_success "파싱 성공"

    # 필드 값 확인
    local field1="${parsed[1]}"
    local field2="${parsed[2]}"
    local field3="${parsed[3]}"

    print_info "파싱 결과:"
    echo "  Field 1: [$field1]"
    echo "  Field 2: [$field2]"
    echo "  Field 3: [$field3]"

    # 빈 값 확인
    local empty_count=0
    [[ -z "$field1" ]] && ((empty_count++))
    [[ -z "$field2" ]] && ((empty_count++))
    [[ -z "$field3" ]] && ((empty_count++))

    if [[ $empty_count -eq 0 ]]; then
        print_success "모든 필드에 값이 할당됨"
    else
        print_warn "$empty_count 개의 필드가 비어있음"
    fi

    # 엣지 케이스 테스트
    print_info "엣지 케이스 테스트:"

    # 빈 입력
    parse_selection "" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        print_success "빈 입력 처리 정상 (오류 반환)"
    else
        print_warn "빈 입력을 정상값으로 처리함"
    fi

    print_success "OUTPUT Parser 테스트 완료"
    return 0
}

# ========================================
# 4. PROCESS Handler 테스트
# ========================================
test_process_handler() {
    print_header "4. PROCESS Handler 테스트"

    # 모의 입력 데이터 생성
    local mock_input
    mock_input=$(generate_input_data 2>/dev/null | head -1)

    if [[ -z "$mock_input" ]]; then
        print_fail "모의 입력 데이터 생성 실패"
        return 1
    fi

    # 파싱
    local parsed
    parsed=($(parse_selection "$mock_input"))

    local field1="${parsed[1]}"
    local field2="${parsed[2]}"
    local field3="${parsed[3]}"

    print_info "테스트 데이터: $field1 / $field2 / $field3"

    # 프로세스 실행
    print_info "process_action 함수 실행 중..."

    local output
    output=$(process_action "$field1" "$field2" "$field3" 2>&1)
    local status=$?

    if [[ $status -eq 0 ]]; then
        print_success "프로세스 실행 성공 (exit code: 0)"
    else
        print_fail "프로세스 실행 실패 (exit code: $status)"
        return 1
    fi

    # 출력 확인
    if [[ -n "$output" ]]; then
        print_info "프로세스 출력:"
        echo "$output" | sed 's/^/  /'
    else
        print_warn "프로세스 출력이 비어있음"
    fi

    print_success "PROCESS Handler 테스트 완료"
    return 0
}

# ========================================
# 5. 통합 테스트
# ========================================
test_integration() {
    print_header "5. 통합 테스트 (dry-run)"

    print_info "전체 워크플로우를 시뮬레이션합니다 (FZF 선택 제외)"

    # 1. INPUT
    local input_data
    input_data=$(generate_input_data 2>&1)
    if [[ $? -ne 0 ]] || [[ -z "$input_data" ]]; then
        print_fail "INPUT 생성 실패"
        return 1
    fi
    print_success "1. INPUT 생성 성공"

    # 2. SELECT (첫 번째 항목 자동 선택)
    local selection
    selection=$(echo "$input_data" | head -1)
    if [[ -z "$selection" ]]; then
        print_fail "SELECT 실패"
        return 1
    fi
    print_success "2. SELECT 성공 (첫 항목 자동 선택)"
    print_info "   선택값: $selection"

    # 3. OUTPUT
    local parsed
    parsed=($(parse_selection "$selection"))
    if [[ $? -ne 0 ]]; then
        print_fail "OUTPUT 파싱 실패"
        return 1
    fi
    print_success "3. OUTPUT 파싱 성공"

    local field1="${parsed[1]}"
    local field2="${parsed[2]}"
    local field3="${parsed[3]}"
    print_info "   파싱 결과: [$field1] [$field2] [$field3]"

    # 4. PROCESS
    process_action "$field1" "$field2" "$field3" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        print_fail "PROCESS 실행 실패"
        return 1
    fi
    print_success "4. PROCESS 실행 성공"

    print_success "통합 테스트 완료 (모든 단계 정상)"
    return 0
}

# ========================================
# 메인 테스트 러너
# ========================================
main() {
    local script_file="${1}"

    if [[ -z "$script_file" ]]; then
        echo "사용법: $0 <script.sh>"
        echo ""
        echo "예제:"
        echo "  $0 my-workflow.sh"
        return 1
    fi

    if [[ ! -f "$script_file" ]]; then
        print_fail "파일을 찾을 수 없습니다: $script_file"
        return 1
    fi

    # 스크립트 소스
    print_info "스크립트 로드 중: $script_file"
    source "$script_file" || {
        print_fail "스크립트 로드 실패"
        return 1
    }
    print_success "스크립트 로드 완료"

    # 테스트 실행
    local passed=0
    local failed=0

    local tests=(
        "test_input_generator:1. INPUT Generator"
        "test_fzf_options:2. FZF Options"
        "test_output_parser:3. OUTPUT Parser"
        "test_process_handler:4. PROCESS Handler"
        "test_integration:5. Integration Test"
    )

    for test_entry in "${tests[@]}"; do
        local test_func="${test_entry%%:*}"
        local test_name="${test_entry#*:}"

        if $test_func; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    # 최종 결과
    print_header "📊 최종 결과"
    echo "${GREEN}통과: $passed${NC}"
    echo "${RED}실패: $failed${NC}"

    local total=$((passed + failed))
    echo "${BLUE}총: $total${NC}"

    if [[ $failed -eq 0 ]]; then
        echo ""
        print_success "✨ 모든 테스트 통과! 스크립트가 올바르게 구조화되었습니다."
        return 0
    else
        echo ""
        print_fail "일부 테스트 실패. 위의 오류를 확인하세요."
        return 1
    fi
}

# 스크립트 실행
main "$@"
