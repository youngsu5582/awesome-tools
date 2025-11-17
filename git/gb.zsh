function gb() {
    local selected_branch_info
    selected_branch_info=$(git for-each-ref --sort=-committerdate refs/heads/ \
        --format='%(refname:short)%09%(committerdate:relative)%09%(authorname)%09%(subject)' \
        | fzf --ansi --prompt="Switch to Branch > " \
              --header="BRANCH | LAST COMMIT | AUTHOR | SUBJECT" \
              --preview="git log --color=always --oneline --graph --decorate -n 10 {1}")

    if [[ -n "$selected_branch_info" ]]; then
        local branch_name
        branch_name=$(echo "$selected_branch_info" | awk '{print $1}')
        echo
        read -k1 "action? (c)heckout, checkout & (p)ull, (d)elete, (r)ebase or (q)uit? "
        echo
        case "$action" in
            c|C) git checkout "$branch_name" ;;
            p|P) git checkout "$branch_name" && git pull ;;
            r|R) git checkout "$branch_name" && git pull --rebase origin develop;;
            d|D) git branch -D "$branch_name" ;;
            *)   echo "Cancelled." ;;
        esac
    fi
}