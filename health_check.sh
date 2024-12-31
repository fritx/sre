#!/bin/sh

# ======= util =======
function load_env() {
    local file="$1"
    if [ -f "$file" ]; then
        set -a  # 自动导出所有变量
        source "$file"
        set +a
    else
        echo "Error: $file not found."
        return 1
    fi
}
function is_executed_directly() {
    # 如果不支持 BASH_SOURCE 或者 BASH_SOURCE 是空，则假定是在 sh 下执行
    if [ "${BASH_SOURCE+defined}" != "defined" ] || [ -z "${BASH_SOURCE:-}" ]; then
        # 对于 /bin/sh 或其他非 bash shell
        if [ "$0" = "${0##*/}" ]; then
            # 脚本被 sourced
            return 1
        else
            # 脚本被直接执行
            return 0
        fi
    else
        # 对于 bash shell
        if [ "${BASH_SOURCE[0]}" = "$0" ]; then
            # 脚本被直接执行
            return 0
        else
            # 脚本被 sourced
            return 1
        fi
    fi
}
function on_status() {
    local url="$1"
    local up=$2
    local msg="$3"
    local cache_file="data/cache.$(echo "$url" | sed 's/[^a-zA-Z0-9.-]/_/g')"
    if [ ! -f "$cache_file" ] || [ $(cat "$cache_file") != $up ]; then
        echo $up > $cache_file
        wxpush "$msg"
    fi
}
# ======= /util =======

function health_check() {
    local url="$1"
    # mode={0:默认, 1:reverse, 2:all}
    local mode=$2
    # 使用curl进行健康检查
    # HTTP_CODE=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' $url)
    local result=$(curl -sS --head "$url" 2>&1 | head -n 1)
    # 检查返回的状态码是否为200 (OK)
    # if [ "$HTTP_CODE" != "200" ] && [ "$mode" != "1" ]; then
    # if ! expr "$result" : ".* 200 OK$" >/dev/null && [ "$mode" != "1" ]; then
    local ok=$(echo "$result" | grep -E -q '200 OK|302 Found' && echo true || echo false)
    if [ "$ok" = false ] && [ "$mode" != "1" ]; then
        # 如果不是200，则执行特定命令
        echo "$(date '+%Y-%m-%d %H:%M:%S') [error] [$url] down: $result"
        on_status "$url" 0 "[error] [$url] $result"
    fi
    if [ "$ok" = true ] && [ -n "$mode" ] && [ "$mode" != "0" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [info] [$url] up: $result"
        on_status "$url" 1 "[info] [$url] $(echo $result | sed 's/^HTTP\/[^ ]* //')"
    fi
}
# 判断当前脚本是否是作为一个独立的程序运行，而不是被其他脚本源入（source）或别名调用。
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
if is_executed_directly; then
    # 使用函数加载 .env 文件
    load_env .env
    # 保存原始 IFS 并设置为逗号
    OLD_IFS=$IFS
    IFS=','
    # 使用 for 循环遍历 MY_VAR 中的每个元素
    for url in $CHECK_URLS; do
        if [ "$CHECK_SELF" = "1" ] || [ "$url" != "$SELF_URL" ]; then
            health_check "$url" "$@"
        fi
    done
    # 恢复原始 IFS
    IFS=$OLD_IFS
fi
