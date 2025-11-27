# [IP 확인] 로컬/퍼블릭 IP를 선택해서 확인하고, 클립보드에 복사합니다.
function fip() {
    local choice ip

    choice=$(
        printf "Local (primary)\nLocal (all)\nPublic" | \
        fzf --prompt="IP > " --height=10
    )

    if [[ -z "$choice" ]]; then
        echo "No selection."
        return 1
    fi

    case "$choice" in
        "Local (primary)")
            # macOS: en0 또는 가장 첫 번째 비-loopback inet
            ip=$(ipconfig getifaddr en0 2>/dev/null || \
                 ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')
            ;;
        "Local (all)")
            ip=$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2}')
            ;;
        "Public")
            ip=$(curl -s https://ifconfig.me)
            ;;
    esac

    if [[ -z "$ip" ]]; then
        echo "IP not found."
        return 1
    fi

    if command -v  >/dev/null 2>&1; then
        echo -n "$ip" | pbcopy
        echo "📋 Copied to clipboard: $ip"
    else
        echo "$ip"
    fi
}