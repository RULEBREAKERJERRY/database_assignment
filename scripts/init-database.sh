#!/usr/bin/env bash
# 按顺序执行 database/ 下的全部脚本。
#
#   ./scripts/init-database.sh          结构 + 种子 + 演示脚本（01—06、10、11）
#   ./scripts/init-database.sh --perf   追加造数与性能/高级查询（07、08、09、12）
#
# 所有脚本都可重复执行，因此本脚本可以反复跑而不会破坏已有数据。
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$script_dir/.."

# 从 .env 读取 root 密码，缺失时用 compose 的默认值
if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    set -a; . ./.env; set +a
fi
ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root_dev}"

mysql_exec() {
    docker compose exec -T mysql \
        mysql -uroot -p"$ROOT_PASSWORD" --default-character-set=utf8mb4 "$@"
}

run_script() {
    local file="$1"
    echo "==> $file"
    mysql_exec < "$file"
}

echo "==> docker compose up -d mysql"
docker compose up -d mysql >/dev/null

printf '==> 等待 MySQL 就绪'
for _ in $(seq 1 60); do
    if docker compose exec -T mysql \
        mysqladmin ping -h 127.0.0.1 -uroot -p"$ROOT_PASSWORD" --silent >/dev/null 2>&1; then
        echo " ok"
        break
    fi
    printf '.'
    sleep 1
done

# 结构、约束、视图、种子、必做查询、事务演示
for n in 01 02 03 04 05 06; do
    run_script "database/${n}"*.sql
done

# 触发器脚本的最后一步故意制造 ERROR 1644 来演示「已删除作品不可恢复」，
# 因此这里单独处理：允许它以非零码退出，但要求输出里确实是这条预期错误。
echo "==> database/10_triggers.sql（末步预期报 ERROR 1644）"
set +e
out="$(mysql_exec < database/10_triggers.sql 2>&1)"
status=$?
set -e
printf '%s\n' "$out"
if [[ $status -ne 0 ]] && ! grep -q '1644' <<<"$out"; then
    echo "!! 10_triggers.sql 出现了预期之外的错误" >&2
    exit 1
fi

# 并发实验脚本只创建测试夹具，不依赖造数数据
run_script database/11_concurrency.sql

if [[ "${1:-}" == "--perf" ]]; then
    for n in 07 08 09 12; do
        run_script "database/${n}"*.sql
    done
else
    echo "==> 跳过 07/08/09/12（造数与性能实验），需要时执行：$0 --perf"
fi

echo "==> 完成"
