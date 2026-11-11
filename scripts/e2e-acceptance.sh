#!/usr/bin/env bash
# 端到端验收脚本：按需求文档「三、验收演示」的顺序调用真实接口。
# 用法：BASE=http://localhost:8080 ./scripts/e2e-acceptance.sh
# 依赖：curl、jq
set -uo pipefail

BASE="${BASE:-http://localhost:8080}"
SUFFIX="${SUFFIX:-$(date +%H%M%S)}"
A="e2e_alice_${SUFFIX}"
B="e2e_bob_${SUFFIX}"
PASS="password123"
VIDEO_FILE="${VIDEO_FILE:-storage/videos/sample-demo.mp4}"

ok=0
fail=0

step() { printf '\n===== %s =====\n' "$*"; }
check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf '  [PASS] %s  ->  %s\n' "$desc" "$actual"; ok=$((ok + 1))
  else
    printf '  [FAIL] %s  ->  期望 %s，实际 %s\n' "$desc" "$expected" "$actual"; fail=$((fail + 1))
  fi
}

api() { curl -s -H 'Content-Type: application/json' "$@"; }

# ---------------------------------------------------------------- 注册与登录
step "1. 注册两个普通账号"
RA=$(api -X POST "$BASE/api/auth/register" \
  -d "{\"username\":\"$A\",\"password\":\"$PASS\",\"nickname\":\"验收用户A\",\"bio\":\"发布者\"}")
RB=$(api -X POST "$BASE/api/auth/register" \
  -d "{\"username\":\"$B\",\"password\":\"$PASS\",\"nickname\":\"验收用户B\",\"bio\":\"互动者\"}")
TA=$(echo "$RA" | jq -r '.data.token')
TB=$(echo "$RB" | jq -r '.data.token')
IDA=$(echo "$RA" | jq -r '.data.userId')
IDB=$(echo "$RB" | jq -r '.data.userId')
echo "  A: id=$IDA  B: id=$IDB"
check "A 注册返回 token" "true" "$([ -n "$TA" ] && [ "$TA" != null ] && echo true || echo false)"

# 重复注册应失败
DUP=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/auth/register" \
  -d "{\"username\":\"$A\",\"password\":\"$PASS\",\"nickname\":\"重复\"}")
check "重复账号注册被拒绝(HTTP)" "400" "$DUP"

# ---------------------------------------------------------------- 上传发布
step "2. A 上传并发布作品"
UP=$(curl -s -X POST "$BASE/api/videos" \
  -H "Authorization: Bearer $TA" \
  -F "title=验收测试视频 $SUFFIX" -F "description=端到端验收用" \
  -F "categoryId=1" -F "file=@$VIDEO_FILE")
VID=$(echo "$UP" | jq -r '.data')
echo "  新视频 id=$VID"
check "上传返回视频编号" "true" "$([ -n "$VID" ] && [ "$VID" != null ] && echo true || echo false)"

# 非视频文件应被拒绝
BAD=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/videos" \
  -H "Authorization: Bearer $TA" \
  -F "title=非法文件" -F "categoryId=1" -F "file=@README.md;type=text/markdown")
check "上传非视频文件被拒绝(HTTP)" "400" "$BAD"

# ---------------------------------------------------------------- 关注
step "3. B 关注 A"
F1=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/follows/$IDA" \
  -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)")
check "关注成功(HTTP)" "200" "$F1"

SELF=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/follows/$IDB" \
  -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)")
check "关注自己被拒绝(HTTP)" "400" "$SELF"

FL=$(api "$BASE/api/users/$IDA/followers")
check "A 的粉丝数" "1" "$(echo "$FL" | jq '.data | length')"

# ---------------------------------------------------------------- 粉丝/关注列表
step "3b. 粉丝列表与关注列表字段"
F0=$(echo "$FL" | jq -r '.data[0] | "\(.nickname)|\(.username)|\(.followed_at != null)"')
check "粉丝行含昵称/用户名/关注时间" "验收用户B|$B|true" "$F0"
FWL=$(api "$BASE/api/users/$IDB/following")
check "B 的关注列表含 A" "1" "$(echo "$FWL" | jq --argjson a "$IDA" '[.data[] | select(.id==$a)] | length')"
check "关注行含 followed_at" "true" "$(echo "$FWL" | jq '[.data[] | select(.followed_at != null)] | length > 0')"
check "A 的关注列表为空" "0" "$(api "$BASE/api/users/$IDA/following" | jq '.data | length')"

# ---------------------------------------------------------------- 作者筛选与用户检索
step "3c. 首页按作者筛选与用户检索"
US=$(api "$BASE/api/users?keyword=$B&limit=20")
check "用户检索命中该用户" "$IDB" "$(echo "$US" | jq -r '.data[0].id')"
AV=$(api "$BASE/api/videos?authorId=$IDA&size=50")
check "作者筛选结果全部属于该作者" "true" \
  "$(echo "$AV" | jq --argjson a "$IDA" '[.data.items[] | select(.author_id != $a)] | length == 0')"
check "作者筛选命中该作者的 1 个作品" "1" "$(echo "$AV" | jq -r '.data.total')"

# ---------------------------------------------------------------- 播放与幂等
step "4. B 播放视频，并验证重复提交"
KEY1="play-$(uuidgen)"
P1=$(api -X POST "$BASE/api/videos/$VID/play" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $KEY1")
P2=$(api -X POST "$BASE/api/videos/$VID/play" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $KEY1")
P3=$(api -X POST "$BASE/api/videos/$VID/play" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)")
check "首次播放新增记录" "true" "$(echo "$P1" | jq -r '.data')"
check "同一 Idempotency-Key 重试不新增" "false" "$(echo "$P2" | jq -r '.data')"
check "换 Key 再次播放新增" "true" "$(echo "$P3" | jq -r '.data')"

# ---------------------------------------------------------------- 点赞收藏转发评论
step "5. B 点赞 / 收藏 / 转发两次 / 评论两条"
api -X POST "$BASE/api/videos/$VID/like" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)" > /dev/null
api -X POST "$BASE/api/videos/$VID/favorite" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)" > /dev/null
api -X POST "$BASE/api/videos/$VID/share" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)" > /dev/null
api -X POST "$BASE/api/videos/$VID/share" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)" > /dev/null
C1=$(api -X POST "$BASE/api/videos/$VID/comments" -H "Authorization: Bearer $TB" \
  -H 'Content-Type: application/json' -d '{"content":"第一条验收评论"}')
C2=$(api -X POST "$BASE/api/videos/$VID/comments" -H "Authorization: Bearer $TB" \
  -H 'Content-Type: application/json' -d '{"content":"第二条验收评论"}')
CID1=$(echo "$C1" | jq -r '.data')
CID2=$(echo "$C2" | jq -r '.data')

EMPTY=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/videos/$VID/comments" \
  -H "Authorization: Bearer $TB" -H 'Content-Type: application/json' -d '{"content":"   "}')
check "空评论被拒绝(HTTP)" "400" "$EMPTY"

# ---------------------------------------------------------------- 行为分页
step "5b. 行为查询分页与总数"
PG1=$(api "$BASE/api/me/behaviors?videoId=$VID&size=2&page=1" -H "Authorization: Bearer $TB")
PG2=$(api "$BASE/api/me/behaviors?videoId=$VID&size=2&page=2" -H "Authorization: Bearer $TB")
PG9=$(api "$BASE/api/me/behaviors?videoId=$VID&size=50&page=1" -H "Authorization: Bearer $TB")
T2=$(echo "$PG1" | jq -r '.data.total')
check "返回结构为 PageResult" "true" \
  "$(echo "$PG1" | jq '(.data|has("items")) and (.data|has("total")) and (.data|has("page")) and (.data|has("size"))')"
check "total 覆盖本视频全部行为" "8" "$T2"
check "每页条数受 size 限制" "2" "$(echo "$PG1" | jq '.data.items | length')"
check "换 size 后 total 不变" "$T2" "$(echo "$PG9" | jq -r '.data.total')"
check "size=50 一次取全且等于 total" "$T2" "$(echo "$PG9" | jq '.data.items | length')"
LAST1=$(echo "$PG1" | jq -r '.data.items[-1].occurred_at')
FIRST2=$(echo "$PG2" | jq -r '.data.items[0].occurred_at')
ORDER=true; [[ "$LAST1" > "$FIRST2" || "$LAST1" == "$FIRST2" ]] || ORDER=false
check "第 2 页紧接第 1 页（时间倒序连续）" "true" "$ORDER"

# ---------------------------------------------------------------- 统计核验
step "6. 统计与明细一致（点赞1 收藏1 转发2 评论2 播放2 去重观众1）"
S=$(api "$BASE/api/videos/$VID/statistics")
echo "$S" | jq -c '.data'
check "当前点赞数" "1" "$(echo "$S" | jq -r '.data.current_like_count')"
check "当前收藏数" "1" "$(echo "$S" | jq -r '.data.current_favorite_count')"
check "累计转发次数" "2" "$(echo "$S" | jq -r '.data.share_count')"
check "有效评论数" "2" "$(echo "$S" | jq -r '.data.valid_comment_count')"
check "播放次数" "2" "$(echo "$S" | jq -r '.data.play_count')"
check "去重观看人数" "1" "$(echo "$S" | jq -r '.data.unique_viewer_count')"

# ---------------------------------------------------------------- 取消与删除
step "7. 取消点赞、取消收藏、删除一条评论"
api -X DELETE "$BASE/api/videos/$VID/like" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)" > /dev/null
api -X DELETE "$BASE/api/videos/$VID/favorite" -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)" > /dev/null
api -X DELETE "$BASE/api/comments/$CID1" -H "Authorization: Bearer $TB" > /dev/null

S2=$(api "$BASE/api/videos/$VID/statistics")
check "取消后点赞数归零" "0" "$(echo "$S2" | jq -r '.data.current_like_count')"
check "取消后收藏数归零" "0" "$(echo "$S2" | jq -r '.data.current_favorite_count')"
check "删除后有效评论数" "1" "$(echo "$S2" | jq -r '.data.valid_comment_count')"
check "播放与转发不受影响" "2" "$(echo "$S2" | jq -r '.data.share_count')"

# ---------------------------------------------------------------- 历史保留
step "8. 历史仍可追溯"
H=$(api "$BASE/api/me/behaviors?videoId=$VID&size=100" -H "Authorization: Bearer $TB")
echo "$H" | jq -r '.data.items[] | "  \(.behavior_type)\t\(.occurred_at)"' | sort
LIKE_N=$(echo "$H" | jq '[.data.items[] | select(.behavior_type=="LIKE")] | length')
UNLIKE_N=$(echo "$H" | jq '[.data.items[] | select(.behavior_type=="UNLIKE")] | length')
CDEL_N=$(echo "$H" | jq '[.data.items[] | select(.behavior_type=="COMMENT_DELETE")] | length')
check "LIKE 历史事件数" "1" "$LIKE_N"
check "UNLIKE 历史事件数" "1" "$UNLIKE_N"
check "COMMENT_DELETE 历史事件数" "1" "$CDEL_N"

# ---------------------------------------------------------------- 权限
step "9. 权限边界"
DEL_OTHER=$(api -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/videos/$VID" \
  -H "Authorization: Bearer $TB")
check "B 删除他人作品被拒绝(HTTP)" "403" "$DEL_OTHER"

ADMIN_TOKEN=$(api -X POST "$BASE/api/auth/login" \
  -d '{"username":"admin","password":"password"}' | jq -r '.data.token')
ADM=$(api -o /dev/null -w '%{http_code}' "$BASE/api/admin/behaviors?videoId=$VID&size=100" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
check "管理员查询全局行为(HTTP)" "200" "$ADM"

USER_ADMIN=$(api -o /dev/null -w '%{http_code}' "$BASE/api/admin/behaviors" \
  -H "Authorization: Bearer $TB")
check "普通用户访问管理接口被拒绝(HTTP)" "403" "$USER_ADMIN"

# ---------------------------------------------------------------- 删除后不可互动
step "10. 作品逻辑删除后不能新增互动，历史保留"
api -X DELETE "$BASE/api/videos/$VID" -H "Authorization: Bearer $TA" > /dev/null
AFTER_PLAY=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/videos/$VID/play" \
  -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)")
AFTER_LIKE=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/videos/$VID/like" \
  -H "Authorization: Bearer $TB" -H "Idempotency-Key: $(uuidgen)")
AFTER_COMMENT=$(api -o /dev/null -w '%{http_code}' -X POST "$BASE/api/videos/$VID/comments" \
  -H "Authorization: Bearer $TB" -H 'Content-Type: application/json' -d '{"content":"删除后评论"}')
check "删除后播放被拒绝(HTTP)" "400" "$AFTER_PLAY"
check "删除后点赞被拒绝(HTTP)" "400" "$AFTER_LIKE"
check "删除后评论被拒绝(HTTP)" "400" "$AFTER_COMMENT"

LIST=$(api "$BASE/api/videos?size=50")
check "已删除作品不出现在公共列表" "0" \
  "$(echo "$LIST" | jq --argjson v "$VID" '[.data.items[] | select(.id==$v)] | length')"

HIST=$(api "$BASE/api/admin/behaviors?videoId=$VID&size=100" -H "Authorization: Bearer $ADMIN_TOKEN")
check "删除后历史仍可查(总数>0)" "true" \
  "$([ "$(echo "$HIST" | jq -r '.data.total')" -gt 0 ] && echo true || echo false)"

# 触发器 trg_videos_audit_status 应在 status 变化时写入审计（见 database/10_triggers.sql）
AUDIT=$(api "$BASE/api/admin/videos/$VID/audit" -H "Authorization: Bearer $ADMIN_TOKEN")
check "触发器记录删除动作" "DELETE" "$(echo "$AUDIT" | jq -r '.data[0].action')"
check "审计保留状态迁移前后值" "PUBLISHED->DELETED" \
  "$(echo "$AUDIT" | jq -r '"\(.data[0].old_status)->\(.data[0].new_status)"')"
check "审计仅 1 条（只改标题不触发）" "1" "$(echo "$AUDIT" | jq '.data | length')"
AUDIT_ANON=$(api -o /dev/null -w '%{http_code}' "$BASE/api/admin/videos/$VID/audit")
check "未登录查看审计被拒绝(HTTP)" "403" "$AUDIT_ANON"

# ---------------------------------------------------------------- 汇总
printf '\n===== 汇总 =====\n通过 %d 项，失败 %d 项\n' "$ok" "$fail"
[ "$fail" -eq 0 ] || exit 1
