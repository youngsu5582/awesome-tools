#!/usr/bin/env zsh
# FZF 워크플로우 기본 템플릿
# 이 템플릿을 복사하여 프로젝트에 맞게 수정하세요.

# ========================================
# 설정
# ========================================
DEBUG="${DEBUG:-false}"

# 의존성 체크
command -v jq >/dev/null 2>&1 || { echo "jq가 필요합니다"; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf가 필요합니다"; exit 1; }

# ========================================
# 유틸리티 함수
# ========================================
debug_log() {
    [[ "$DEBUG" == "true" ]] && echo "[DEBUG] $*" >&2
}

error_log() {
    echo "[ERROR] $*" >&2
}

# ========================================
# 1. INPUT Generator
# ========================================
generate_input_data() {
    # 목적: 선택 가능한 항목 목록을 TSV 형식으로 출력
    # 출력 형식: field1\tfield2\tfield3

    debug_log "INPUT 데이터 생성 시작"

    # 예제: 정적 배열
    local items=(
        'item1\tvalue1\tdescription1'
        'item2\tvalue2\tdescription2'
        'item3\tvalue3\tdescription3'
    )

    printf "%s\n" "${items[@]}"

    # 예제: JSON 파일에서 읽기
    # local json_file="data.json"
    # [[ ! -f "$json_file" ]] && { error_log "파일 없음: $json_file"; return 1; }
    # jq -r '.items[] | "\(.id)\t\(.name)\t\(.description)"' "$json_file"

    # 예제: API 호출
    # local api_url="https://api.example.com/items"
    # curl -s "$api_url" | jq -r '.items[] | "\(.id)\t\(.name)\t\(.description)"'

    debug_log "INPUT 데이터 생성 완료"
}

# ========================================
# 2. SELECT (FZF)
# ========================================
select_item() {
    local input_data="$1"

    debug_log "FZF 선택 시작"

    echo "$input_data" | fzf \
        --delimiter='\t' \
        --with-nth=2,3 \
        --prompt="항목 선택 > " \
        --header="NAME              DESCRIPTION" \
        --height=50% \
        --layout=reverse \
        --border

    debug_log "FZF 선택 완료"
}

# ========================================
# 3. OUTPUT Parser
# ========================================
parse_selection() {
    local selection="$1"

    debug_log "선택값 파싱: $selection"

    [[ -z "$selection" ]] && {
        debug_log "선택값이 비어있음"
        return 1
    }

    local field1 field2 field3
    IFS=$'\t' read -r field1 field2 field3 <<< "$selection"

    debug_log "파싱 완료 - field1: $field1, field2: $field2, field3: $field3"

    # 파싱된 값을 배열로 반환
    echo "$field1"
    echo "$field2"
    echo "$field3"
}

# ========================================
# 4. PROCESS Handler
# ========================================
process_action() {
    local field1="$1"
    local field2="$2"
    local field3="$3"

    debug_log "액션 처리 시작 - field1: $field1"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "처리 중: $field3"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 실제 작업 수행
    case "$field1" in
        item1)
            echo "Item 1 처리 중..."
            # 작업 로직 추가
            ;;
        item2)
            echo "Item 2 처리 중..."
            # 작업 로직 추가
            ;;
        item3)
            echo "Item 3 처리 중..."
            # 작업 로직 추가
            ;;
        *)
            error_log "알 수 없는 항목: $field1"
            return 1
            ;;
    esac

    echo "✅ 처리 완료"
    debug_log "액션 처리 완료"
}

# ========================================
# Main Workflow
# ========================================
main() {
    setopt pipefail

    debug_log "워크플로우 시작"

    # 1. INPUT 생성
    local input_data
    input_data=$(generate_input_data) || {
        error_log "INPUT 생성 실패"
        return 1
    }

    [[ -z "$input_data" ]] && {
        error_log "INPUT 데이터가 비어있음"
        return 1
    }

    # 2. SELECT (FZF)
    local selection
    selection=$(select_item "$input_data") || {
        echo "선택 취소됨"
        return 0
    }

    # 3. OUTPUT 파싱
    local parsed_values
    parsed_values=($(parse_selection "$selection")) || {
        error_log "OUTPUT 파싱 실패"
        return 1
    }

    local field1="${parsed_values[1]}"
    local field2="${parsed_values[2]}"
    local field3="${parsed_values[3]}"

    # 4. PROCESS 실행
    process_action "$field1" "$field2" "$field3"

    debug_log "워크플로우 완료"
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${(%):-%x}" == "${0}" ]]; then
    main "$@"
fi
