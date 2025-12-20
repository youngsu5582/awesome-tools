# [프로세스 종료] fzf로 포트를 사용하는 프로세스를 찾아 종료합니다.
function fkill() {
    local pid
    pid=$(lsof -i -P -n | grep LISTEN | fzf --prompt="Kill Process > " --accept-nth=2)

    if [ -n "$pid" ]; then
        echo "Killing process with PID: $pid"
        kill -9 "$pid"
        if [[ $? -eq 0 ]]; then
            echo "✅ Process $pid killed successfully."
        else
            echo "❌ Failed to kill process $pid."
        fi
    else
        echo "No process selected."
    fi
}