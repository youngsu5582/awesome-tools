#!/usr/bin/env zsh
# ==============================================================================
# DB Sync Utilities (JSON 기반 설정 버전)
# 계정/호스트 정보는 .system/settings/database.json 에서 로드합니다.
# psql 을 통한 DB 작업
# ==============================================================================

setopt multios

DB_CONFIG_JSON=".system/settings/database.json"

typeset -gA DB_STAGE_HOSTS DB_STAGE_USERS DB_STAGE_PASSWORDS DB_STAGE_TELEPORT DB_STAGE_PORTS
typeset -g DB_DEFAULT_NAME DB_CONFIG_LOADED
DB_CONFIG_LOADED="false"

function _db_check_deps() {
  local missing=()
  local deps=(jq fzf psql pg_dump createdb dropdb)
  for dep in "${deps[@]}"; do
    command -v "$dep" >/dev/null || missing+=("$dep")
  done

  if (( ${#missing[@]} > 0 )); then
    echo "⚠️  DB Sync: 필수 명령어가 없습니다: ${missing[*]}"
    echo "    설치 후 다시 시도하세요. (예: brew install jq fzf postgresql)"
  fi
}

function _db_load_config() {
  setopt localoptions pipefail
  if [[ "$DB_CONFIG_LOADED" == "true" ]]; then return 0; fi

  local jq_bin
  jq_bin="$(command -v jq)" || { echo "❌ jq가 필요합니다."; return 1; }

  DB_DEFAULT_NAME=$("$jq_bin" -r '.defaults.db_name // "aicreation"' "$DB_CONFIG_JSON")

  DB_STAGE_HOSTS=()
  DB_STAGE_USERS=()
  DB_STAGE_PASSWORDS=()
  DB_STAGE_TELEPORT=()
  DB_STAGE_PORTS=()

  local stages=("${(@f)$("$jq_bin" -r '.stages | keys[]' "$DB_CONFIG_JSON")}")
  if (( ${#stages[@]} == 0 )); then
    echo "❌ stages 항목이 비어있습니다. $DB_CONFIG_JSON 를 확인하세요."
    return 1
  fi

  local stage
  for stage in "${stages[@]}"; do
    DB_STAGE_HOSTS[$stage]=$("$jq_bin" -r --arg s "$stage" '.stages[$s].host // ""' "$DB_CONFIG_JSON")
    DB_STAGE_USERS[$stage]=$("$jq_bin" -r --arg s "$stage" '.stages[$s].user // ""' "$DB_CONFIG_JSON")
    DB_STAGE_PASSWORDS[$stage]=$("$jq_bin" -r --arg s "$stage" '.stages[$s].password // ""' "$DB_CONFIG_JSON")
    DB_STAGE_PORTS[$stage]=$("$jq_bin" -r --arg s "$stage" '.stages[$s].port // 5432' "$DB_CONFIG_JSON")
  done

  DB_CONFIG_LOADED="true"
}

function db-config-reload() {
  DB_CONFIG_LOADED="false"
  _db_load_config
}

function db-config-show() {
  _db_load_config || return 1
  echo "🔧 DB 설정 파일: $DB_CONFIG_JSON"
  echo "   stages: ${(@k)DB_STAGE_HOSTS}"
  echo "   기본 DB 이름: $DB_DEFAULT_NAME"
}

# ------------------------------------------------------------------------------
# Stage helpers
# ------------------------------------------------------------------------------
function _db_remote_stages() {
  local stages=()
  for k in "${(@k)DB_STAGE_HOSTS}"; do
    stages+=("$k")
  done
  print -l "${stages[@]}"
}

# ------------------------------------------------------------------------------
# db-sync (전용 기능)
# ------------------------------------------------------------------------------
function db-sync() {
  setopt localoptions pipefail
  _db_load_config || return 1

  local remote_stages=("${(@f)$(_db_remote_stages)}")
  if (( ${#remote_stages[@]} == 0 )); then
    echo "❌ 원격 stage가 없습니다. $DB_CONFIG_JSON 의 stages를 확인하세요."
    return 1
  fi

  local stage
  stage=$(printf "%s\n" "${remote_stages[@]}" | fzf --prompt="[DB Sync] 동기화할 소스 환경 선택 > ")
  if [[ -z "$stage" ]]; then echo "❌ 취소되었습니다."; return 1; fi
  echo "✅ 소스 환경: $stage"

  local remote_host="${DB_STAGE_HOSTS[$stage]}"
  local remote_port="${DB_STAGE_PORTS[$stage]:-5432}"
  local remote_user="${DB_STAGE_USERS[$stage]}"
  local remote_pass="${DB_STAGE_PASSWORDS[$stage]:-}"

  echo "\n🔍 '$stage' 환경에서 데이터베이스 목록을 가져옵니다..."
  export PGPASSWORD=$remote_pass
  local db_list
  db_list=$(psql -h "$remote_host" -p "$remote_port" -U "$remote_user" -lqt | cut -d '|' -f 1 | grep -v -e 'template[01]' -e 'rdsadmin' | xargs)
  unset PGPASSWORD
  if [[ -z "$db_list" ]]; then echo "❌ DB 목록을 가져오지 못했습니다."; return 1; fi

  local source_db_name
  source_db_name=$(echo "$db_list" | tr ' ' '\n' | fzf --prompt="[DB Sync] 동기화할 소스 DB 선택 > ")
  if [[ -z "$source_db_name" ]]; then echo "❌ 소스 DB가 선택되지 않았습니다."; return 1; fi
  echo "✅ 소스 DB: $source_db_name"

  local local_host="${DB_STAGE_HOSTS[local]:-localhost}"
  local local_port="${DB_STAGE_PORTS[local]:-5432}"
  local local_user="${DB_STAGE_USERS[local]:-sd}"
  local local_pass="${DB_STAGE_PASSWORDS[local]:-sd}"
  local local_db_name="sync-${stage}-$(echo "$source_db_name" | tr '-' '_')"

  echo "\n🔄 로컬 DB '$local_db_name' 상태를 확인합니다..."
  export PGPASSWORD=$local_pass
  if psql -h "$local_host" -p "$local_port" -U "$local_user" -lqt | cut -d '|' -f 1 | grep -qw "$local_db_name"; then
    printf "\n⚠️  경고: 로컬 DB '%s'가 이미 존재합니다. 삭제 후 다시 만드시겠습니까?\n    (이 작업은 되돌릴 수 없습니다.)\n" "$local_db_name"
    read -k 1 "REPLY?정말로 진행하시겠습니까? (y/N): "
    printf "\n"
    if [[ "$REPLY" != "y" ]]; then unset PGPASSWORD; echo "❌ 취소되었습니다."; return 1; fi

    echo "  -> '$local_db_name'의 모든 연결을 종료합니다..."
    psql -h "$local_host" -p "$local_port" -U "$local_user" -d postgres -t -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$local_db_name' AND pid <> pg_backend_pid();" > /dev/null 2>&1
    echo "  -> '$local_db_name' DB를 삭제합니다..."
    dropdb -h "$local_host" -p "$local_port" -U "$local_user" "$local_db_name"
    if [[ $? -ne 0 ]]; then echo "❌ 기존 DB 삭제 실패."; unset PGPASSWORD; return 1; fi
  fi

  echo "✨ 로컬 DB '$local_db_name'를 생성합니다..."
  createdb -h "$local_host" -p "$local_port" -U "$local_user" "$local_db_name"
  if [[ $? -ne 0 ]]; then echo "❌ DB 생성 실패."; unset PGPASSWORD; return 1; fi
  echo "✅ '$local_db_name'가 성공적으로 생성되었습니다."
  unset PGPASSWORD

  echo "\n🚀 전체 DB 동기화를 시작합니다: '$source_db_name' -> '$local_db_name'"
  local dump_opts=(
    --clean
    --if-exists
    --no-owner
    --no-privileges
    "--exclude-table=pg_stat_statements"
    "--exclude-table=pg_stat_statements_info"
    "--exclude-table=public.pg_stat_statements"
    "--exclude-table=public.pg_stat_statements_info"
  )

  (export PGPASSWORD=$remote_pass; pg_dump -h "$remote_host" -p "$remote_port" -U "$remote_user" -d "$source_db_name" "${dump_opts[@]}") \
    | awk '
        BEGIN { skip = 0 }
        {
            if (skip) {
                if ($0 ~ /;/) { skip = 0 }
                next
            }
            if ($0 ~ /pg_stat_statements/) {
                if ($0 !~ /;/) { skip = 1 }
                next
            }
            print
        }
      ' \
    | (export PGPASSWORD=$local_pass; psql -h "$local_host" -p "$local_port" -U "$local_user" -d "$local_db_name" -q -v ON_ERROR_STOP=1)

  local dump_status=${pipestatus[1]}
  local filter_status=${pipestatus[2]}
  local psql_status=${pipestatus[3]}

  if [[ $dump_status -ne 0 || $filter_status -ne 0 || $psql_status -ne 0 ]]; then
    echo "❌ 동기화 실패. (pg_dump/psql exit codes: $dump_status/$filter_status/$psql_status)"
    echo "⚠️  실패로 인해 로컬 DB '$local_db_name'에는 일부 객체가 생성되었을 수 있습니다."
    return 1
  fi

  echo "✅ 동기화 성공."
  echo "🔧 'pg_stat_statements' 확장을 로컬 DB에 생성합니다..."
  export PGPASSWORD=$local_pass
  psql -h "$local_host" -p "$local_port" -U "$local_user" -d "$local_db_name" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
  if [[ $? -ne 0 ]]; then
    echo "⚠️ 'pg_stat_statements' 확장 기능 생성에 실패했습니다. 수동으로 생성하세요."
  else
    echo "✅ 'pg_stat_statements' 확장이 성공적으로 생성되었습니다."
  fi
  unset PGPASSWORD

  echo "\n🎉 DB '$source_db_name'의 전체 동기화 작업이 완료되었습니다. -> '$local_db_name'"
}