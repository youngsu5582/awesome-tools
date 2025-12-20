#!/usr/bin/env zsh
# API 호출 워크플로우 예제
# send-api 스크립트의 개선된 버전

# ========================================
# 설정
# ========================================
export SERVERS_JSON="${SERVERS_JSON:-.system/servers.json}"
export ENDPOINTS_JSON="${ENDPOINTS_JSON:-.system/endpoints.json}"
export AUTH_JSON="${AUTH_JSON:-.system/auth.json}"

DEBUG="${DEBUG:-false}"

# ========================================
# 의존성 체크
# ========================================
command -v jq >/dev/null 2>&1 || { echo "❌ jq가 필요합니다"; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "❌ fzf가 필요합니다"; exit 1; }
command -v http >/dev/null 2>&1 || { echo "❌ httpie가 필요합니다 (brew install httpie)"; exit 1; }

# ========================================
# 1-1. INPUT: 서버 목록 생성
# ========================================
generate_server_list() {
    [[ ! -f "$SERVERS_JSON" ]] && {
        echo "❌ 서버 설정 파일이 없습니다: $SERVERS_JSON" >&2
        return 1
    }

    jq -r '.servers[] | "\(.key)\t\(.url)\t\(.name)"' "$SERVERS_JSON"
}

# ========================================
# 2-1. SELECT: 서버 선택
# ========================================
select_server() {
    generate_server_list | fzf \
        --delimiter='\t' \
        --with-nth=3,2 \
        --prompt="🖥️  서버 선택 > " \
        --header="NAME                      URL" \
        --height=40% \
        --layout=reverse
}

# ========================================
# 3-1. OUTPUT: 서버 정보 파싱
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

    [[ ! -f "$ENDPOINTS_JSON" ]] && {
        echo "❌ 엔드포인트 설정 파일이 없습니다: $ENDPOINTS_JSON" >&2
        return 1
    }

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
        --prompt="🌐 엔드포인트 선택 > " \
        --header="METHOD    PATH                        DESCRIPTION" \
        --height=60% \
        --layout=reverse
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
# 1-3. INPUT: 인증 정보 로드
# ========================================
get_auth_header() {
    local server_key="$1"

    [[ ! -f "$AUTH_JSON" ]] && return 0

    local entries
    entries=($(jq -r --arg key "$server_key" \
        '.[$key] // empty | to_entries[] | "\(.key)\t\(.value)"' \
        "$AUTH_JSON" 2>/dev/null))

    [[ ${#entries[@]} -eq 0 ]] && return 0

    # 하나의 인증 정보만 있으면 자동 선택
    if [[ ${#entries[@]} -eq 1 ]]; then
        local scheme value
        IFS=$'\t' read -r scheme value <<< "${entries[1]}"
        scheme="${(C)scheme}"  # Capitalize
        echo "Authorization:${scheme} ${value}"
    else
        # 여러 인증 정보가 있으면 선택
        local selected
        selected=$(printf "%s\n" "${entries[@]}" | fzf \
            --delimiter=$'\t' \
            --with-nth=1 \
            --prompt="🔑 인증 방식 선택 > " \
            --height=30%)

        [[ -z "$selected" ]] && return 0

        local scheme value
        IFS=$'\t' read -r scheme value <<< "$selected"
        scheme="${(C)scheme}"
        echo "Authorization:${scheme} ${value}"
    fi
}

# ========================================
# 4. PROCESS: API 요청 실행
# ========================================
execute_api_request() {
    local server_url="$1"
    local method="$2"
    local path="$3"
    local auth_header="$4"

    local full_url="${server_url%/}${path}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "요청: $method $full_url"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local http_args=("$method" "$full_url")
    [[ -n "$auth_header" ]] && http_args+=("$auth_header")

    # 요청 실행
    http --print=hb --pretty=format "${http_args[@]}"
}

# ========================================
# Main Workflow
# ========================================
main() {
    setopt pipefail

    # 1. 서버 선택
    echo "🔍 서버 목록 로딩 중..."
    local server_selection
    server_selection=$(select_server) || {
        echo "👋 서버 선택 취소"
        return 0
    }

    local server_info
    server_info=($(parse_server "$server_selection")) || {
        echo "❌ 서버 정보 파싱 실패"
        return 1
    }

    local server_key="${server_info[1]}"
    local server_url="${server_info[2]}"
    local server_name="${server_info[3]}"

    echo "✅ 선택된 서버: ${server_name} (${server_url})"

    # 2. 엔드포인트 선택
    echo "\n🔍 엔드포인트 목록 로딩 중..."
    local endpoint_selection
    endpoint_selection=$(select_endpoint "$server_key") || {
        echo "👋 엔드포인트 선택 취소"
        return 0
    }

    local endpoint_info
    endpoint_info=($(parse_endpoint "$endpoint_selection")) || {
        echo "❌ 엔드포인트 정보 파싱 실패"
        return 1
    }

    local method="${endpoint_info[1]}"
    local path="${endpoint_info[2]}"
    local description="${endpoint_info[3]}"

    echo "✅ 선택된 엔드포인트: ${description}"

    # 3. 인증 정보 로드
    local auth_header
    auth_header=$(get_auth_header "$server_key")
    [[ -n "$auth_header" ]] && echo "🔑 인증 정보 로드됨"

    # 4. API 요청 실행
    echo ""
    execute_api_request "$server_url" "$method" "$path" "$auth_header"
}

main "$@"
