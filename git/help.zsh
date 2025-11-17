function git-help() {
    cat <<EOF

🐙  Git & GitHub 워크플로우 유틸리티 도움말

  gb
    - (Git Branch) 대화형으로 브랜치를 선택하여 checkout, pull, drop 작업을 수행합니다.
    - Example:
      - gb
  gs
    - (Git Stash) 대화형으로 stash 목록을 보고 apply, pop, drop, rename 등의 작업을 수행합니다.
    - Example:
      - gs

  gpr
    - (GitHub PR) 현재 프로젝트의 GitHub PR 목록을 보고, 선택한 PR을 로컬 브랜치로 checkout 합니다.
    - Example:
      - gpr

EOF
}