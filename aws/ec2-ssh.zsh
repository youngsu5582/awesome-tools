#!/usr/bin/env zsh

# ========================================
# AWS EC2 SSH 통합 스크립트
# ========================================

# 설정 파일 경로
EC2_CONFIG_JSON="${EC2_CONFIG_JSON:-.system/settings/ec2.json}"

# ========================================
# 설정 로드
# ========================================

load_ec2_config() {
    if [[ ! -f "$EC2_CONFIG_JSON" ]]; then
        echo "❌ EC2 설정 파일을 찾을 수 없습니다: $EC2_CONFIG_JSON" >&2
        return 1
    fi

    local jq_bin
    jq_bin="$(command -v jq)" || {
        echo "❌ jq가 필요합니다. brew install jq" >&2
        return 1
    }

    # JSON에서 값 읽기
    local pem_key_path=$(jq -r '.pem_key_path' "$EC2_CONFIG_JSON")
    local aws_profile=$(jq -r '.aws_profile' "$EC2_CONFIG_JSON")
    local ssh_user=$(jq -r '.ssh_user // "ec2-user"' "$EC2_CONFIG_JSON")
    local default_name_filter=$(jq -r '.default_name_filter // ""' "$EC2_CONFIG_JSON")

    # 틸드(~) 확장
    pem_key_path="${pem_key_path/#\~/$HOME}"

    # PEM 키 파일 존재 확인
    if [[ ! -f "$pem_key_path" ]]; then
        echo "⚠️  PEM 키 파일을 찾을 수 없습니다: $pem_key_path" >&2
        echo "   .system/settings/ec2.json 의 pem_key_path를 확인하세요." >&2
        # 계속 진행은 하되 경고만 표시
    fi

    echo "$pem_key_path"
    echo "$aws_profile"
    echo "$ssh_user"
    echo "$default_name_filter"
}

# ========================================
# 리전 선택
# ========================================

_select_aws_region() {
    local regions_display
    regions_display=$(jq -r '.regions[] | "\(.code) (\(.name), \(.name_en))"' "$EC2_CONFIG_JSON")

    if [[ -z "$regions_display" ]]; then
        echo "❌ 리전 목록이 비어있습니다. $EC2_CONFIG_JSON 을 확인하세요." >&2
        return 1
    fi

    local selected_region_display
    selected_region_display=$(echo "$regions_display" | \
        fzf --prompt="🌏 Select AWS Region > " \
            --height=50% \
            --layout=reverse)

    if [[ -z "$selected_region_display" ]]; then
        echo "❌ 리전 선택이 취소되었습니다." >&2
        return 1
    fi

    # 리전 코드 추출 (첫 번째 단어)
    local region_code="${selected_region_display%% *}"
    echo "$region_code"
}

# ========================================
# EC2 인스턴스 선택 및 SSH 연결
# ========================================

function ec2-ssh() {
    # AWS CLI 확인
    if ! command -v aws >/dev/null 2>&1; then
        echo "❌ AWS CLI가 설치되어 있지 않습니다." >&2
        echo "   설치: brew install awscli" >&2
        return 1
    fi

    # 필수 도구 확인
    for cmd in jq fzf; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ '$cmd' 명령어가 필요합니다." >&2
            return 1
        fi
    done

    # 설정 로드
    local config
    config=($(load_ec2_config)) || return 1

    local pem_key_path="${config[1]}"
    local aws_profile="${config[2]}"
    local ssh_user="${config[3]}"
    local default_name_filter="${config[4]}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔐 AWS EC2 SSH 접속"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 1. 리전 선택
    local selected_region_code
    selected_region_code=$(_select_aws_region) || return 1

    echo ""
    echo "선택된 리전: $selected_region_code"
    echo ""

    # 2. 인스턴스 이름 필터 입력
    local name_filter
    echo -n "🔍 인스턴스 이름 필터 (기본: $default_name_filter): "
    read name_filter
    name_filter="${name_filter:-$default_name_filter}"

    echo ""
    echo "🔍 '$selected_region_code' 리전에서 '$name_filter' 인스턴스 검색 중..."
    echo ""

    # 3. 인스턴스 목록 조회
    local instance_info
    instance_info=$( \
        aws ec2 describe-instances \
            --profile "$aws_profile" \
            --region "$selected_region_code" \
            --filters \
                "Name=tag:Name,Values=*${name_filter}*" \
                "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[].[InstanceId, PublicIpAddress, PrivateIpAddress, InstanceType, Tags[?Key==`Name`]|[0].Value, State.Name]' \
            --output text \
        | fzf --prompt="📦 Select EC2 Instance [$selected_region_code] > " \
              --header="ID                    | Public IP       | Private IP      | Type        | Name                 | State" \
              --delimiter=$'\t' \
              --height=80% \
              --layout=reverse
    )

    if [[ -z "$instance_info" ]]; then
        echo "❌ 인스턴스 선택이 취소되었습니다."
        return 0
    fi

    # 4. 인스턴스 정보 파싱
    local instance_id instance_ip private_ip instance_type instance_name instance_state
    instance_id=$(echo "$instance_info" | awk '{print $1}')
    instance_ip=$(echo "$instance_info" | awk '{print $2}')
    private_ip=$(echo "$instance_info" | awk '{print $3}')
    instance_type=$(echo "$instance_info" | awk '{print $4}')
    instance_name=$(echo "$instance_info" | awk '{print $5}')
    instance_state=$(echo "$instance_info" | awk '{print $6}')

    # Public IP 확인
    if [[ -z "$instance_ip" || "$instance_ip" == "None" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ 선택된 인스턴스에 Public IP가 없습니다."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "인스턴스 정보:"
        echo "  ID: $instance_id"
        echo "  Name: $instance_name"
        echo "  Private IP: $private_ip"
        echo ""
        echo "💡 Private IP로 접속하려면 VPN 또는 Bastion Host를 사용하세요."
        return 1
    fi

    # 5. SSH 연결
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 SSH 연결 정보"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "인스턴스: $instance_name ($instance_id)"
    echo "타입: $instance_type"
    echo "상태: $instance_state"
    echo "Public IP: $instance_ip"
    echo "Private IP: $private_ip"
    echo "사용자: $ssh_user"
    echo "PEM 키: $pem_key_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔌 연결 중..."
    echo ""

    # SSH 옵션 로드
    local ssh_options
    ssh_options=$(jq -r '.ssh_options | to_entries | map("-o \(.key | gsub("_"; ""))=\(.value)") | join(" ")' "$EC2_CONFIG_JSON" 2>/dev/null)

    # SSH 연결
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -i "$pem_key_path" \
        "${ssh_user}@${instance_ip}"
}

# ========================================
# 모든 리전에서 인스턴스 검색
# ========================================

function ec2-ssh-all() {
    # AWS CLI 확인
    if ! command -v aws >/dev/null 2>&1; then
        echo "❌ AWS CLI가 설치되어 있지 않습니다." >&2
        echo "   설치: brew install awscli" >&2
        return 1
    fi

    # 필수 도구 확인
    for cmd in jq fzf; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ '$cmd' 명령어가 필요합니다." >&2
            return 1
        fi
    done

    # 설정 로드
    local config
    config=($(load_ec2_config)) || return 1

    local pem_key_path="${config[1]}"
    local aws_profile="${config[2]}"
    local ssh_user="${config[3]}"
    local default_name_filter="${config[4]}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌍 AWS EC2 SSH 접속 (전체 리전)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 인스턴스 이름 필터 입력
    local name_filter
    echo -n "🔍 인스턴스 이름 필터 (기본: $default_name_filter): "
    read name_filter
    name_filter="${name_filter:-$default_name_filter}"

    echo ""
    echo "🌎 모든 AWS 리전에서 '$name_filter' 인스턴스 검색 중..."
    echo "⏱️  (10-20초 소요될 수 있습니다...)"
    echo ""

    # 모든 리전 목록 가져오기
    local all_regions
    all_regions=($(aws ec2 describe-regions \
        --query "Regions[].RegionName" \
        --output text \
        --profile "$aws_profile" | tr '\t' '\n'))

    if [[ ${#all_regions[@]} -eq 0 ]]; then
        echo "❌ AWS 리전 목록을 가져올 수 없습니다."
        return 1
    fi

    # 병렬로 모든 리전 검색
    local instance_list
    instance_list=$( \
        for region in "${all_regions[@]}"; do
            (
                aws ec2 describe-instances \
                    --profile "$aws_profile" \
                    --region "$region" \
                    --filters \
                        "Name=tag:Name,Values=*${name_filter}*" \
                        "Name=instance-state-name,Values=running" \
                    --query 'Reservations[].Instances[].[InstanceId, PublicIpAddress, PrivateIpAddress, InstanceType, Tags[?Key==`Name`]|[0].Value, State.Name, Placement.AvailabilityZone]' \
                    --output text
            ) &
        done
        wait
    )

    if [[ -z "$instance_list" ]]; then
        echo "❌ '$name_filter' 인스턴스를 찾을 수 없습니다."
        return 1
    fi

    # 리전 정보 추가
    local display_list
    display_list=$(echo "$instance_list" | awk -F'\t' '{
        az=$7;
        region=az; sub(/[a-z]$/, "", region);
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", region, $1, $2, $3, $4, $5, $6
    }')

    # fzf로 선택
    local selected_instance
    selected_instance=$(echo "$display_list" | \
        fzf --prompt="📦 Select EC2 Instance (All Regions) > " \
            --header="Region           | ID                   | Public IP       | Private IP      | Type        | Name                 | State" \
            --delimiter=$'\t' \
            --height=80% \
            --layout=reverse)

    if [[ -z "$selected_instance" ]]; then
        echo "❌ 인스턴스 선택이 취소되었습니다."
        return 0
    fi

    # 인스턴스 정보 파싱
    local region instance_id instance_ip private_ip instance_type instance_name instance_state
    region=$(echo "$selected_instance" | awk -F'\t' '{print $1}')
    instance_id=$(echo "$selected_instance" | awk -F'\t' '{print $2}')
    instance_ip=$(echo "$selected_instance" | awk -F'\t' '{print $3}')
    private_ip=$(echo "$selected_instance" | awk -F'\t' '{print $4}')
    instance_type=$(echo "$selected_instance" | awk -F'\t' '{print $5}')
    instance_name=$(echo "$selected_instance" | awk -F'\t' '{print $6}')
    instance_state=$(echo "$selected_instance" | awk -F'\t' '{print $7}')

    # Public IP 확인
    if [[ -z "$instance_ip" || "$instance_ip" == "None" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ 선택된 인스턴스에 Public IP가 없습니다."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "인스턴스 정보:"
        echo "  Region: $region"
        echo "  ID: $instance_id"
        echo "  Name: $instance_name"
        echo "  Private IP: $private_ip"
        echo ""
        echo "💡 Private IP로 접속하려면 VPN 또는 Bastion Host를 사용하세요."
        return 1
    fi

    # SSH 연결
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 SSH 연결 정보"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "리전: $region"
    echo "인스턴스: $instance_name ($instance_id)"
    echo "타입: $instance_type"
    echo "상태: $instance_state"
    echo "Public IP: $instance_ip"
    echo "Private IP: $private_ip"
    echo "사용자: $ssh_user"
    echo "PEM 키: $pem_key_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔌 연결 중..."
    echo ""

    # SSH 연결
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -i "$pem_key_path" \
        "${ssh_user}@${instance_ip}"
}

# ========================================
# EC2 인스턴스 목록 조회만
# ========================================

function ec2-list() {
    # AWS CLI 확인
    if ! command -v aws >/dev/null 2>&1; then
        echo "❌ AWS CLI가 설치되어 있지 않습니다." >&2
        return 1
    fi

    # 설정 로드
    local config
    config=($(load_ec2_config)) || return 1

    local aws_profile="${config[2]}"
    local default_name_filter="${config[4]}"

    # 리전 선택
    local selected_region_code
    selected_region_code=$(_select_aws_region) || return 1

    # 필터 입력
    local name_filter
    echo -n "🔍 인스턴스 이름 필터 (기본: $default_name_filter, 엔터=전체): "
    read name_filter
    name_filter="${name_filter:-$default_name_filter}"

    echo ""
    echo "📋 '$selected_region_code' 리전의 인스턴스 목록:"
    echo ""

    # 인스턴스 목록 조회 및 표시
    if [[ -n "$name_filter" ]]; then
        aws ec2 describe-instances \
            --profile "$aws_profile" \
            --region "$selected_region_code" \
            --filters \
                "Name=tag:Name,Values=*${name_filter}*" \
            --query 'Reservations[].Instances[].[InstanceId, State.Name, InstanceType, PublicIpAddress, PrivateIpAddress, Tags[?Key==`Name`]|[0].Value]' \
            --output table
    else
        aws ec2 describe-instances \
            --profile "$aws_profile" \
            --region "$selected_region_code" \
            --query 'Reservations[].Instances[].[InstanceId, State.Name, InstanceType, PublicIpAddress, PrivateIpAddress, Tags[?Key==`Name`]|[0].Value]' \
            --output table
    fi
}

# 도움말
function ec2-help() {
    cat <<'EOF'

🔐 AWS EC2 SSH 통합 스크립트 도움말

사용법:
  ec2-ssh           특정 리전의 EC2 인스턴스에 SSH 접속
  ec2-ssh-all       모든 리전에서 검색 후 SSH 접속
  ec2-list          EC2 인스턴스 목록만 조회

설정:
  설정 파일: .system/settings/ec2.json

  {
    "pem_key_path": "~/.ssh/your-ec2-key.pem",
    "aws_profile": "mfa",
    "ssh_user": "ec2-user",
    "default_name_filter": "project",
    "regions": [
      {"code": "ap-northeast-2", "name": "서울", "name_en": "Seoul"},
      ...
    ],
    "ssh_options": {
      "strict_host_key_checking": "no",
      "connection_timeout": 10
    }
  }

필수 도구:
  - AWS CLI: brew install awscli
  - jq: brew install jq
  - fzf: brew install fzf

환경 변수:
  EC2_CONFIG_JSON  설정 파일 경로 (기본: .system/settings/ec2.json)

워크플로우 (ec2-ssh):
  1. 명령어 실행
  2. 리전 선택 (fzf)
  3. 인스턴스 이름 필터 입력
  4. 인스턴스 선택 (fzf)
  5. SSH 연결!

워크플로우 (ec2-ssh-all):
  1. 명령어 실행
  2. 인스턴스 이름 필터 입력
  3. 모든 리전 검색 (병렬, 10-20초)
  4. 인스턴스 선택 (fzf)
  5. SSH 연결!

EOF
}
