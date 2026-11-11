#!/usr/bin/env bash
# 并发实验驱动：两个（必要时三个）独立连接同时操作同一行，记录阻塞时间。
# 用法：./scripts/concurrency-test.sh
# 依赖：database/11_concurrency.sql 已执行（提供 concurrency_setup / teardown 过程）
#
# 为什么必须用脚本：行锁的阻塞只在「两个连接同时持有事务」时出现，
# 单个 mysql 会话里顺序执行 BEGIN...COMMIT 永远看不到等待。
set -uo pipefail

MY="${MY:-.local/bin/my}"
LOG="${LOG:-docs/report/concurrency-log.txt}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
HOLD_DELAY_MS=400

now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }
q() { "$MY" -N -B -e "USE short_video; $1"; }

VID=$(q "SELECT id FROM videos WHERE title='并发实验专用视频' LIMIT 1")
if [ -z "$VID" ]; then
  # 上次运行的收尾会清掉实验数据，这里自动补建，脚本可独立重复执行。
  q "CALL concurrency_setup();" > /dev/null 2>&1
  VID=$(q "SELECT id FROM videos WHERE title='并发实验专用视频' LIMIT 1")
fi
if [ -z "$VID" ]; then
  echo "找不到实验视频，请先执行 database/11_concurrency.sql" >&2
  exit 1
fi

# 逻辑删除不可逆（10_triggers.sql 的 BEFORE UPDATE 触发器会拦截 DELETED->PUBLISHED），
# 因此每个用例之间用「删行重建」而不是「改回状态」来复位。
reset_video() {
  q "DELETE FROM video_likes WHERE video_id=$VID;
     DELETE FROM video_favorites WHERE video_id=$VID;
     DELETE FROM like_events WHERE video_id=$VID;
     DELETE FROM favorite_events WHERE video_id=$VID;
     DELETE FROM play_records WHERE video_id=$VID;
     DELETE FROM share_records WHERE video_id=$VID;
     DELETE FROM comments WHERE video_id=$VID;
     DELETE FROM video_audit WHERE video_id=$VID;
     DELETE FROM videos WHERE id=$VID;" > /dev/null
  q "CALL concurrency_setup();" > /dev/null
  # 删行重建后自增 id 会变，必须重新取一次，否则后续用例会打到不存在的行上。
  VID=$(q "SELECT id FROM videos WHERE title='并发实验专用视频' LIMIT 1")
}

# run_case <标题> <会话A事务体> <会话B事务体> <期望>
# 会话 A 先开事务并持锁 SLEEP_SECONDS 秒，0.4 秒后会话 B 发起。
# 等待时长由 B 在服务端用 NOW(3) 自测，避免把 mysql 客户端启动时间算进去。
run_case() {
  local title="$1" a_body="$2" b_body="$3" expect="$4"
  printf '\n===== %s =====\n' "$title"
  printf '会话A: %s\n会话B: %s\n' "$a_body" "$b_body"

  ( "$MY" -N -B -e "USE short_video; START TRANSACTION; $a_body; SELECT SLEEP($SLEEP_SECONDS); COMMIT;" \
      > /tmp/conc-a.out 2>&1 ) &
  local a_pid=$!
  sleep 0.4

  ( "$MY" -N -B -e "USE short_video; START TRANSACTION; SET @t0=NOW(3); $b_body; SET @t1=NOW(3); \
      SELECT CONCAT('wait_ms=', TIMESTAMPDIFF(MICROSECOND, @t0, @t1) DIV 1000); COMMIT;" \
      > /tmp/conc-b.out 2>&1 ) &
  local b_pid=$!

  # 第三个连接观察锁等待队列（B 阻塞期间采样一次）
  sleep 0.6
  local waits
  waits=$(q "SELECT COUNT(*) FROM performance_schema.data_lock_waits" 2>/dev/null || echo "n/a")

  wait $b_pid
  wait $a_pid

  local wait_ms b_out
  wait_ms=$(grep -o 'wait_ms=[0-9]*' /tmp/conc-b.out | head -1 | cut -d= -f2)
  b_out=$(grep -v 'wait_ms=' /tmp/conc-b.out | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-140)
  printf '会话B 锁等待: %s ms\n' "${wait_ms:-未知}"
  printf '阻塞期间 data_lock_waits 行数: %s\n' "$waits"
  printf '会话B 结果: %s\n' "${b_out:-（无输出）}"
  printf '期望: %s\n' "$expect"
}

echo "实验对象 video_id=${VID}，会话A 持锁 ${SLEEP_SECONDS}s，会话B 在 0.4s 后发起"

# ---------------------------------------------------------------- 用例 1
run_case "用例1 排他锁 vs 排他锁：两个删除请求互相排队" \
  "SELECT id FROM videos WHERE id=$VID FOR UPDATE" \
  "SELECT id FROM videos WHERE id=$VID FOR UPDATE" \
  "会话B 阻塞约 1.6s，说明同一行的 X 锁互斥"

# ---------------------------------------------------------------- 用例 2
run_case "用例2 共享锁 vs 共享锁：并发互动不互相阻塞" \
  "SELECT id FROM videos WHERE id=$VID FOR SHARE" \
  "SELECT id FROM videos WHERE id=$VID FOR SHARE" \
  "会话B 几乎立即返回，说明 S 锁之间兼容，热门视频的点赞不会被串行化"

# ---------------------------------------------------------------- 用例 3
reset_video
run_case "用例3 删除(持X锁) vs 新增互动(取S锁)：互动被挡在删除之后" \
  "UPDATE videos SET status='DELETED', deleted_at=NOW(3) WHERE id=$VID" \
  "SELECT status FROM videos WHERE id=$VID FOR SHARE" \
  "会话B 阻塞约 1.6s，随后读到 DELETED，应用层据此拒绝新增互动"

# ---------------------------------------------------------------- 用例 4
reset_video
run_case "用例4 新增互动(持S锁) vs 删除(要X锁)：删除等待在途互动结束" \
  "SELECT id FROM videos WHERE id=$VID FOR SHARE" \
  "UPDATE videos SET status='DELETED', deleted_at=NOW(3) WHERE id=$VID" \
  "会话B 阻塞约 1.6s，说明删除不会插队到正在写入的互动之前"

# ---------------------------------------------------------------- 用例 5
reset_video
run_case "用例5 对照：删除(持X锁) vs 普通快照读(不加锁)" \
  "UPDATE videos SET status='DELETED', deleted_at=NOW(3) WHERE id=$VID" \
  "SELECT status FROM videos WHERE id=$VID" \
  "会话B 立即返回旧值 PUBLISHED，说明普通读挡不住删除，必须显式加锁"

# ---------------------------------------------------------------- 收尾
reset_video
printf '\n===== 清理 =====\n'
q "CALL concurrency_teardown();" > /dev/null
printf '实验数据已清理，video_audit 中与实验视频相关的记录同步删除\n'
