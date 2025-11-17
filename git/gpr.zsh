function gpr() {
    local pr_info
    # headRefName을 목록에 추가하여 fzf에서 선택하고 정보를 얻을 수 있도록 합니다.
    pr_info=$(gh pr list --json number,title,author,headRefName,createdAt,updatedAt \
      --template '{{range .}}{{.number}}{{"\t"}}{{.title}}{{"\t"}}{{.author.login}}{{"\t"}}{{.createdAt | timeago}}{{"\t"}}{{.headRefName}}{{"\n"}}{{end}}' | \
      fzf --ansi --prompt="Select PR > " \
            --header="NUM | TITLE | AUTHOR | CREATED | BRANCH" \
            --preview="gh pr diff --color=always {+1}")

    if [[ -n "$pr_info" ]]; then
        local pr_number
        local branch_name
        # awk를 사용하여 탭으로 구분된 출력에서 PR 번호와 브랜치 이름을 안정적으로 추출합니다.
        pr_number=$(echo "$pr_info" | awk -F'\t' '{print $1}')
        branch_name=$(echo "$pr_info" | awk -F'\t' '{print $5}')

        if [[ -z "$branch_name" ]]; then
            echo "오류: 브랜치 이름을 가져올 수 없습니다."
            return 1
        fi

        # --- Stash uncommitted changes ---
        # 브랜치 이동 전, 저장하지 않은 변경사항이 있는지 확인하고 스태시에 저장합니다.
        if [[ -n $(git status --porcelain) ]]; then
            local current_branch
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            local stash_message="gpr-stash: '$current_branch' -> '$branch_name' 이동으로 임시 저장"

            echo "현재 브랜치('$current_branch')에 저장하지 않은 변경사항이 있습니다. 스태시에 저장합니다."
            echo "스태시 메시지: \"$stash_message\""
            git stash -m "$stash_message"
            echo "변경사항이 성공적으로 스태시되었습니다. 나중에 'git stash pop'으로 복원할 수 있습니다."
        fi
        # --- End of Stash logic ---

        # 로컬에 브랜치가 이미 존재하는지 확인합니다.
        if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
            # 브랜치가 존재하면, 해당 브랜치로 이동하고 최신 변경사항을 pull 합니다.
            echo "브랜치 '$branch_name'이(가) 이미 존재합니다. 해당 브랜치로 이동합니다."
            git checkout "$branch_name"

            # git pull이 추적 브랜치를 찾을 수 있도록 설정합니다.
            echo "원격 브랜치(origin/$branch_name) 추적을 설정/업데이트합니다."
            if git branch --set-upstream-to="origin/$branch_name" "$branch_name"; then
                echo "'$branch_name' 브랜치의 최신 변경사항을 가져옵니다..."
                git pull
            else
                echo "오류: 원격 브랜치 'origin/$branch_name' 추적 설정에 실패했습니다."
                echo "PR이 포크(fork)된 저장소에서 온 경우, 원격(remote) 설정이 다를 수 있습니다."
            fi
        else
            # 브랜치가 존재하지 않으면, 'gh pr checkout'을 사용하여 새로 생성합니다.
            echo "PR #$pr_number 을(를) 체크아웃합니다..."
            gh pr checkout "$pr_number"
        fi
    fi
}