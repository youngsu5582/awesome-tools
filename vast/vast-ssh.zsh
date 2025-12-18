#!/usr/bin/env zsh

# Vast.ai 설정 파일 경로 (기본값)
VAST_CONFIG_JSON="${VAST_CONFIG_JSON:-.system/settings/vast.json}"

function vast-ssh() {
    # 1. 설정 로드
    if [[ ! -f "$VAST_CONFIG_JSON" ]]; then
        echo "❌ Vast 설정 파일을 찾을 수 없습니다: $VAST_CONFIG_JSON"
        return 1
    fi

    local jq_bin
    jq_bin="$(command -v jq)" || { echo "❌ jq가 필요합니다."; return 1; }

    # JSON에서 값 읽기 (~ 경로 처리를 위해 eval 사용)
    local api_key=$("$jq_bin" -r '."api-key"' "$VAST_CONFIG_JSON")
    local key_path=$("$jq_bin" -r '."ssh-key-path"' "$VAST_CONFIG_JSON")
    local l_port=$("$jq_bin" -r '."l-port" // 8080' "$VAST_CONFIG_JSON")
    local r_port=$("$jq_bin" -r '."r-port" // 18188' "$VAST_CONFIG_JSON")

    # tilde(~) 확장 처리
    key_path="${key_path/#\~/$HOME}"

    if [[ -z "$api_key" || "$api_key" == "null" ]]; then
        echo "❌ JSON 파일에 api-key가 설정되지 않았습니다."
        return 1
    fi

    echo "🔍 Vast.ai에서 인스턴스 정보를 동기화하고 있습니다..."

    # 2. 인스턴스 목록 가져오기 및 fzf 선택
    local selected
    selected=$(curl -s -L -X GET 'https://console.vast.ai/api/v0/instances/' \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $api_key" | \
        tr -d '\000-\010\013-\037' | \
        "$jq_bin" -r '.instances[] | [
            (.label // "no-label"),
            .public_ipaddr,
            (.id | tostring),
            .actual_status,
            .gpu_name,
            ((.geolocation // "N/A") | sub("^, "; "")),
            (.ports["22/tcp"][0].HostPort // "N/A")
        ] | @tsv' | column -t -s $'\t' | \
        fzf --prompt="🖥️  Select Instance > " \
            --header="LABEL          IP_ADDR         INSTANCE_ID  STATUS       GPU_MODEL    LOCATION     PORT" \
            --layout=reverse --height=50% --border)

    if [[ -z "$selected" ]]; then
        echo "👋 취소되었습니다."
        return 0
    fi

    # 3. 데이터 파싱
    local label=$(echo "$selected" | awk '{print $1}')
    local public_ip=$(echo "$selected" | awk '{print $2}')
    local instance_id=$(echo "$selected" | awk '{print $3}')
    local inst_status=$(echo "$selected" | awk '{print $4}')
    local ssh_port=$(echo "$selected" | awk '{print $NF}')

    echo -e "\n──────────────────────────────────────────────────"
    echo -e "🏷️  Label: \033[1;32m$label\033[0m ($instance_id)"
    echo -e "🚥 Status: $inst_status"
    echo -e "🌐 Address: root@$public_ip:$ssh_port"
    echo -e "🔗 Tunnel: -L ${l_port}:localhost:${r_port}"
    echo -e "──────────────────────────────────────────────────"

    # 4. 동작 선택
    local action
    action=$(printf "🚀 SSH 접속 (Tunneling)\n📋 로그 확인 (Logs)\n🛑 인스턴스 중지 (Stop)\n❌ 취소" | fzf --prompt="Action for $label > " --height=15% --layout=reverse)

    case "$action" in
        "🚀 SSH 접속 (Tunneling)")
            echo -e "\n📡 연결 시도: ssh -p $ssh_port root@$public_ip -L ${l_port}:localhost:${r_port}"
            ssh -i "$key_path" -p "$ssh_port" -o StrictHostKeyChecking=no "root@$public_ip" -L "${l_port}:localhost:${r_port}"
            ;;
        "📋 로그 확인 (Logs)")
            echo -n "가져올 로그 라인 수 (기본 1000): "
            read log_tail
            log_tail=${log_tail:-1000}

            echo "⏳ 로그 생성 요청 중..."
            local log_res
            log_res=$(curl -s -L -X PUT "https://console.vast.ai/api/v0/instances/request_logs/${instance_id}/" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $api_key" \
                -d "{\"tail\": \"$log_tail\"}")

            local result_url=$(echo "$log_res" | "$jq_bin" -r '.result_url')
            if [[ "$result_url" != "null" ]]; then
                echo "⏳ S3 권한 승인을 대기합니다 (2s)..."
                sleep 2
                curl -sL "$result_url"
            else
                echo "❌ 로그 URL을 가져오지 못했습니다."
            fi
            ;;
    esac
}