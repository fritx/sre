#!/bin/sh

function install_cron() {
    local job="$1"
    # 检查是否存在该cron任务
    if ! crontab -l | grep -Fxq "$job"; then
        # 如果不存在则添加到crontab中
        (crontab -l; echo "$job") | crontab -
        echo "Cron job added: $job"
    else
        echo "Cron job already exists: $job"
    fi
}
install_cron "*/5 * * * * cd /app && ./health_check.sh >> data/health.log 2>&1"
install_cron "0 8 * * * cd /app && ./health_check.sh 1 >> data/health.log 2>&1"
