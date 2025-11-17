function aws-help() {
    cat <<EOF

☁️  AWS 유틸리티 스크립트 도움말

  ec2-ssh
    - fzf로 특정 리전의 EC2 인스턴스를 선택하여 SSH 접속합니다.
    - Example:
      - ec2-ssh

  ec2-ssh-all
    - 모든 리전에서 EC2 인스턴스를 찾아 SSH 접속합니다.
    - Example:
      - ec2-ssh-all

EOF
}