# 헬퍼 함수: 타겟 Actuator 주소가 설정되었는지 확인
function _ensure_spring_target() {
    local actuator_target="$1" # 첫 번째 인수로 Actuator URL을 받음

    if [[ -z "$actuator_target" ]]; then
        echo "❌ 타겟 Actuator 주소가 설정되지 않았습니다."
        # Note: 이 함수를 직접 호출하지 않고, spring-loggers 내에서 target을 먼저 확인해야 합니다.
        return 1
    fi

    # 타겟 서버가 응답하는지 간단히 확인
    if ! curl -s -o /dev/null -m 3 "$actuator_target/actuator"; then
        echo "❌ 타겟 애플리케이션($actuator_target)에 연결할 수 없습니다. 애플리케이션이 실행 중인지, Actuator 설정이 올바른지 확인하세요."
        return 1
    fi
    return 0
}

# 헬퍼 함수: Actuator 엔드포인트를 호출하고 성공 여부를 확인
function _curl_actuator() {
    local actuator_target="$1" # 첫 번째 인수로 Actuator URL을 받음
    local endpoint="$2"        # 두 번째 인수로 엔드포인트 경로를 받음
    local response
    local http_status

    # curl로 응답 본문과 http 상태 코드를 함께 받아옵니다.
    # $SPRING_ACTUATOR_TARGET 대신 $actuator_target 로컬 변수 사용
    response=$(curl -s -w "\n%{http_code}" "$actuator_target/actuator/$endpoint")
    http_status=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')

    if [[ "$http_status" -ge 200 && "$http_status" -lt 300 ]]; then
        echo "$body" # 성공 시 본문만 출력
        return 0
    else
        # 실패 시 표준 에러(stderr)로 오류 메시지 출력
        echo "❌ 오류 발생! (Endpoint: /actuator/$endpoint, HTTP Status: $http_status)" >&2
        # 서버가 반환한 오류 본문이 있다면 보여줌
        echo "$body" | jq . >&2 2>/dev/null || echo "$body" >&2
        return 1
    fi
}

# 서버 설정후, 로그 레벨 변경하는 함수
function spring-loggers() {
    local actuator_target # 로컬 변수로 선언

    # 1. 타겟 주소 설정 (_prompt_spring_target이 URL을 반환한다고 가정)
    actuator_target=$(_prompt_spring_target) || return 1
    # **이전 코드의 export SPRING_ACTUATOR_TARGET 제거됨**

    # 2. 타겟 주소 확인: 로컬 변수 $actuator_target을 인수로 전달
    _ensure_spring_target "$actuator_target" || return 1

    local loggers_json
    # 3. 로거 목록 가져오기: $actuator_target을 인수로 전달
    loggers_json=$(_curl_actuator "$actuator_target" "loggers") || return 1

    # 4. 로그 설정할 클래스 추출
    local logger_info
    logger_info=$(echo "$loggers_json" \
        | jq -r '.loggers | to_entries[] | "\(.key)\t\(.value.effectiveLevel)"' \
        | fzf --prompt="Select Logger to Modify > " --header="LOGGER | CURRENT_LEVEL")

    if [[ -z "$logger_info" ]]; then echo "❌ 취소되었습니다."; return 1; fi

    local logger_name
    logger_name=$(echo "$logger_info" | awk -F'\t' '{print $1}')

    # 5. 로그 레벨 선택
    local levels="DEBUG\nINFO\nWARN\nERROR\nOFF\nNULL (reset to default)"
    local selected_level
    selected_level=$(echo "$levels" | fzf --prompt="Select New Level for '$logger_name' > ")

    if [[ -z "$selected_level" ]]; then echo "❌ 취소되었습니다."; return 1; fi

    local level_payload
    if [[ "$selected_level" == "NULL"* ]]; then
        level_payload="null"
    else
        level_payload="\"$selected_level\""
    fi

    echo "🔄 '$logger_name'의 로그 레벨을 '$selected_level'(으)로 변경합니다..."

    # 6. 로그 레벨 변경 POST 요청: $actuator_target 로컬 변수 직접 사용
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST -H "Content-Type: application/json" \
        -d "{\"configuredLevel\": $level_payload}" \
        "$actuator_target/actuator/loggers/$logger_name")

    if [[ "$http_status" -ge 200 && "$http_status" -lt 300 ]]; then
        echo "\n✅ 요청 성공 (HTTP $http_status). 변경된 로그 레벨을 확인합니다..."
        _curl_actuator "$actuator_target" "loggers/$logger_name" | jq . | bat -l json
    else
        echo "\n❌ 오류 발생! (HTTP $http_status)"
        echo "   - Actuator 엔드포인트가 활성화되어 있고, 쓰기 권한이 있는지 확인하세요."
    fi
}