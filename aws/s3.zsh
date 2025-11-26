#!/bin/zsh
#
# s3-download.zsh
#
# 간단한 S3 객체 다운로드 유틸 함수
# ---------------------------------
# 1) 인자로 S3 URI 를 주면 곧바로 해당 객체를 현재 디렉터리로 다운로드합니다.
#    - 예: s3 s3://my-bucket/path/to/file.txt
#
# 2) 인자가 없으면, fzf 로:
#    - S3 버킷 선택
#    - (선택) prefix 입력
#    - (선택) keyword 필터 입력
#    - 객체 키 선택
#    를 거쳐, 선택한 객체를 현재 디렉터리로 다운로드합니다.
#
# 의존성
#   - aws 또는 awsp (AWS CLI wrapper)
#   - fzf
#
# 환경 변수 (선택)
#   - AWS_S3_BUCKET_NAME_FILTER
#     버킷 목록에서 이 문자열을 포함하는 버킷만 후보로 보여줍니다.
#     사내 프로젝트 이름 등은 이 변수로 주입하고, 코드에는 하드코딩하지 마세요.
#     예)
#       export AWS_S3_BUCKET_NAME_FILTER="my-project"
#
# 사용 예시
#   # 1) 직접 URI 로 다운로드
#   s3 s3://my-bucket/path/to/file.txt
#
#   # 2) 대화형 모드로 버킷/객체 선택 후 다운로드
#   s3
#
# 필요하다면 아래와 같이 alias 를 추가해서, 외부에서는 s3-download 라는 이름으로만 쓰게 할 수도 있습니다.
#   alias s3-download=s3

: "${AWS_S3_BUCKET_NAME_FILTER:=}"

function s3() {
    emulate -L zsh
    setopt pipefail

    # ----------------------------------------------------------
    # 모드 1: 인자로 S3 URI 가 들어오면 즉시 다운로드
    # ----------------------------------------------------------
    if [[ -n "$1" ]]; then
        local s3_uri="$1"

        if [[ ! "$s3_uri" =~ ^s3:// ]]; then
            echo "❌ Invalid S3 URI. Must start with 's3://'."
            return 1
        fi

        local filename
        filename=$(basename "$s3_uri")

        echo "⬇️  Downloading $s3_uri to ./$filename..."
        awsp s3 cp "$s3_uri" "./$filename"

        if [[ $? -eq 0 ]]; then
            echo "✅ Download complete: ./$filename"
        else
            echo "❌ Download failed."
            return 1
        fi
        return 0
    fi

    # ----------------------------------------------------------
    # 모드 2: 대화형 검색 + 다운로드
    # ----------------------------------------------------------

    # 1. 버킷 목록 가져오기
    local bucket_list bucket
    bucket_list=$(awsp s3 ls | awk '{print $3}')

    if [[ -z "$bucket_list" ]]; then
        echo "❌ 표시할 S3 버킷이 없습니다."
        return 1
    fi

    # 2. 환경 변수 필터가 설정되어 있으면, 그 문자열을 포함하는 버킷만 남김
    if [[ -n "$AWS_S3_BUCKET_NAME_FILTER" ]]; then
        bucket_list=$(echo "$bucket_list" | grep "$AWS_S3_BUCKET_NAME_FILTER" || true)
    fi

    if [[ -z "$bucket_list" ]]; then
        echo "❌ 필터 조건에 맞는 S3 버킷이 없습니다. (AWS_S3_BUCKET_NAME_FILTER 값을 확인하세요)"
        return 1
    fi

    # 3. fzf 로 버킷 선택
    bucket=$(echo "$bucket_list" | fzf --prompt="Select S3 Bucket > ")
    if [[ -z "$bucket" ]]; then
        echo "No bucket selected."
        return 1
    fi

    # 4. prefix 입력(옵션)
    echo "💡 For faster searching, enter a prefix (e.g., path/to/folder/2025/06/18/)"
    local prefix
    read -r "prefix?Prefix (optional): "

    # 5. keyword 입력(옵션)
    local keyword
    read -r "keyword?Keyword to filter by (optional): "

    # 6. prefix 기준 객체 목록 조회
    echo "🔍 Fetching objects from s3://$bucket/$prefix..."

    local object_keys
    if [[ -n "$prefix" ]]; then
        object_keys=$(
            awsp s3api list-objects-v2 \
                --bucket "$bucket" \
                --prefix "$prefix" \
                --query 'Contents[].Key' \
                --output text \
            | tr '\t' '\n'
        )
    else
        echo "⚠️  No prefix entered. Listing all objects in the bucket. This might be very slow."
        object_keys=$(
            awsp s3api list-objects-v2 \
                --bucket "$bucket" \
                --query 'Contents[].Key' \
                --output text \
            | tr '\t' '\n'
        )
    fi

    # 7. keyword 로 2차 필터링(옵션)
    local filtered_keys="$object_keys"
    if [[ -n "$keyword" ]]; then
        filtered_keys=$(echo "$object_keys" | grep -i "$keyword" || true)
    fi

    if [[ -z "$filtered_keys" ]]; then
        echo "No objects found for the given prefix/keyword."
        return 1
    fi

    # 8. fzf 로 최종 객체 선택
    local object_key
    object_key=$(echo "$filtered_keys" | fzf --prompt="Select object to download > ")
    if [[ -z "$object_key" ]]; then
        echo "No object selected."
        return 1
    fi

    # 9. 다운로드
    local filename
    filename=$(basename "$object_key")
    echo "⬇️  Downloading s3://$bucket/$object_key to ./$filename..."
    awsp s3 cp "s3://$bucket/$object_key" "./$filename"

    if [[ $? -eq 0 ]]; then
        echo "✅ Download complete: ./$filename"
    else
        echo "❌ Download failed."
        return 1
    fi
}
