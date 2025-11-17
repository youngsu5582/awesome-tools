function gs() {
    local selected_stash
    selected_stash=$(git log -g refs/stash --pretty=format:'%gd%x09%ci%x09%x09%s' \
        | fzf --reverse --prompt="Select Stash > " --header="ID | Date | Message" \
               --preview="git stash show -p {1} | bat --color=always --paging=never")

    if [[ -n "$selected_stash" ]]; then
        local stash_id
        stash_id=$(echo "$selected_stash" | awk '{print $1}')
        echo "$stash_id is selected!!"
        read -k1 "action? (a)pply, (p)op, (d)rop, (r)ename or (c)ancel? "
        echo
        case "$action" in
            a|A) git stash apply "$stash_id" ;;
            p|P) git stash pop "$stash_id" ;;
            d|D) git stash drop "$stash_id" ;;
            r|R)
                local current_message new_message stash_commit stash_index drop_target
                current_message=$(echo "$selected_stash" | cut -f4-)
                echo "기존 제목: $current_message"
                read "new_message?변경할 제목을 입력해주세요: "
                if [[ -z "$new_message" ]]; then
                    echo "입력하지 않아 취소했습니다."
                    return
                fi
                if [[ "$stash_id" =~ \{([0-9]+)\} ]]; then
                    stash_index=${match[1]}
                else
                    echo "stash 인덱스 파싱에 실패했습니다."
                    return 1
                fi
                stash_commit=$(git rev-parse "$stash_id") || return 1
                if git stash store -m "$new_message" "$stash_commit"; then
                    drop_target=$((stash_index + 1))
                    git stash drop "stash@{$drop_target}"
                    echo "새 메시지로 업데이트했습니다: $new_message"
                else
                    echo "새 메시지를 저장하지 못했습니다."
                fi
                ;;
            *)   echo "Cancelled." ;;
        esac
    fi
}