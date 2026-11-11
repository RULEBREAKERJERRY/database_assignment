# 测试与验收清单

## 核心流程

1. 注册两个普通账号并登录。
2. 账号 A 上传测试视频，填写标题、简介和分类。
3. 账号 B 关注账号 A。
4. 账号 B 实际启动视频播放。
5. 完成点赞、收藏、两次独立转发和两条评论。
6. 在个人中心和行为查询页核对明细。
7. 核对视频统计：点赞 1、收藏 1、转发 2、评论 2，并检查播放量和去重人数。
8. 取消点赞和收藏、删除一条评论。
9. 核对当前统计已减少，但 LIKE/UNLIKE、FAVORITE/UNFAVORITE、COMMENT/COMMENT_DELETE 历史仍可查询。

## 边界验证

- 重复点击点赞：当前关系和历史不重复增加。
- 使用同一个 `Idempotency-Key` 重复提交播放或转发：只生成一条记录。
- 使用不同 `Idempotency-Key` 两次转发：累计两次。
- 取消后再次点赞：当前状态有效，历史存在三条事件。
- 用户关注自己：请求失败。
- 评论为空或只有空格：请求失败。
- 用户修改或删除他人的视频、评论：请求失败。
- 视频逻辑删除后：公共列表不可见，新增播放及互动失败，旧行为仍可在管理员查询中看到。
- 未登录访问 `/api/videos/{id}/interaction-state`：返回 `liked=false`、`favorited=false`，HTTP 200，不报 500。

## 事务回滚

执行 `database/06_transaction_demo.sql` 创建两个演示过程。在测试数据上分别调用：

```sql
CALL demo_like_success(<user_id>, <video_id>);
CALL demo_like_rollback(<尚未点赞的user_id>, <video_id>);
```

第二个过程故意写入非法事件类型触发 `CHECK` 约束。查询 `video_likes` 和 `like_events`，应确认失败事务的两处修改均不存在。

## 触发器与审计

执行 `database/10_triggers.sql`（最后一步会抛 `ERROR 1644`，属预期）。逐项核对：

| 步骤 | 操作 | 预期 |
|---|---|---|
| 1 | `UPDATE videos SET status='DELETED', deleted_at=NOW(3)` | `video_audit` 新增 1 条，`action='DELETE'`，`old_status='PUBLISHED'` |
| 2 | 在事务里做同样的删除，然后 `ROLLBACK` | 审计记录一并回滚，`COUNT(*)` 归零 |
| 3 | 只改标题 | 审计不新增任何行 |
| 4 | 查 `information_schema.TRIGGERS` | 存在 `trg_videos_audit_status`（AFTER UPDATE）与 `trg_videos_prevent_restore`（BEFORE UPDATE） |
| 5 | 把 `DELETED` 改回 `PUBLISHED` | 报 `ERROR 1644 (45000): 已逻辑删除的作品不允许恢复为发布状态` |

第 2 步是触发器的关键性质：触发器属于所在事务，业务回滚时审计也回滚，不会留下「业务没发生、审计却记了一笔」的记录。

接口层用管理员账号访问 `GET /api/admin/videos/{id}/audit` 应看到同一条记录；普通账号与未登录访问返回 403。

## 并发控制

`scripts/concurrency-test.sh` 用两个独立会话跑 5 组用例，会话 A 持锁 2 s、会话 B 在 0.4 s 后发起：

| 用例 | 会话 A | 会话 B | 预期 |
|---|---|---|---|
| 1 | `FOR UPDATE` | `FOR UPDATE` | B 阻塞约 1.6 s，`data_lock_waits` 有 1 行 |
| 2 | `FOR SHARE` | `FOR SHARE` | B 立即返回，锁等待 0 ms |
| 3 | `UPDATE ... DELETED` | `FOR SHARE` | B 阻塞后读到 `DELETED` |
| 4 | `FOR SHARE` | `UPDATE ... DELETED` | B 阻塞约 1.6 s |
| 5 | `UPDATE ... DELETED` | 普通 `SELECT` | B 立即读到旧值 `PUBLISHED` |

用例 5 是对照组，说明 `REPEATABLE-READ` 下的普通快照读不加锁，因此"先读状态再判断"的写法在并发下不安全，必须显式加锁。

计时由脚本在服务端用 `NOW(3)` 完成，不能用客户端墙钟——`mysql` 客户端启动本身就有几百毫秒，会淹没真实差异。脚本会自动重建被用例删除的夹具视频并重新读取 `id`（自增主键会变）。

另有一组单会话对照（`database/11_concurrency.sql`）：直接向一条 `DELETED` 视频插入点赞，`video_likes` 会插入成功。这说明"已删除作品不可互动"这条规则数据库层面挡不住，只能由应用层的锁保证。

## 性能实验

1. 执行 `database/07_generate_test_data.sql`。
2. 备份数据库或在专用实验库操作。
3. 临时移除 `idx_play_user_time`，保存目标查询的 `EXPLAIN ANALYZE`。
4. 恢复 `(user_id, started_at DESC)` 联合索引。
5. 执行 `database/08_performance_test.sql` 并保存结果。
6. 在报告中比较访问方式、扫描行数、排序方式和执行时间。

首页列表的改写对比单独执行，需确认两件事同时成立：

- `videos` 的三个联合索引以 `id DESC` 结尾（`SHOW INDEX FROM videos` 可见三列），否则 `ORDER BY published_at DESC, id DESC` 会留下 `Sort` 节点；
- 列表查询不再 `JOIN v_video_statistics`，`EXPLAIN` 里应出现 `Subquery in projection; dependent` 而不是 `Materialize`。

`08` 与 `EXPLAIN ANALYZE` 的输出分别留档在 `docs/report/perf-1w.log`、`perf-10w.log`、`list-query-log.txt`。

## 窗口函数与递归 CTE

执行 `database/12_advanced_queries.sql`，需要先跑过 `07` 与 `09`。五条查询的预期：

| 查询 | 预期结果 |
|---|---|
| 分类播放 Top3 | 8 个分类各 3 行，共 24 行 |
| 分类内占比 | 单条视频占分类约 0.15%、占全站约 0.02% |
| 每人最近一次播放 | 10 行，`play_times` 为该用户总播放次数 |
| 共同关注 | 最多 14 人，`common_targets` 列出交集对象 |
| 二度关注 | 10 行以上，`min_depth` 全为 2 |

二度关注返回空集通常不是 SQL 写错，而是关注数据拓扑问题：如果所有关注边都指向同一批核心用户，二度节点会被一度覆盖，`NOT EXISTS` 全部过滤掉。造数脚本因此采用「2/3 指向核心用户、1/3 指向随机用户」的混合拓扑。

## 单元测试

```bash
cd backend && mvn test
```

6 个用例，覆盖重复用户名、空评论、越权删评论、越权删视频、已删除视频不能播放、重复点赞不重复写事件。用例用 Mockito 校验「是否调用了 Mapper」，从而证明校验发生在数据库交互之前。

## 自动化验收

```bash
./scripts/e2e-acceptance.sh
```

49 项断言，覆盖核心流程、幂等、权限边界、逻辑删除与触发器审计。期望输出 `通过 49 项，失败 0 项`，日志见 `docs/report/e2e-log.txt`。

## 界面验收（必做功能补齐项）

1. **粉丝/关注列表**：登录后进入 `/users/{id}`，页签应显示「公开作品 / 关注 N / 粉丝 N」。切到「粉丝」应看到粉丝昵称、`@用户名`、简介与关注时间；点击整行可跳到该用户主页。点击「关注」按钮后按钮变为「已关注」，粉丝数与粉丝列表同步加一；再点一次应恢复。
2. **首页按作者筛选**：首页筛选区第三个下拉为「全部作者」，输入昵称片段即远程检索；选中后地址栏出现 `?authorId=`，列表只保留该作者作品，「共 N 个作品」随之变化；清空下拉恢复全部。
3. **行为查询分页**：进入 `/behaviors`，表格底部应显示「共 N 条 / 每页条数 / 页码 / 前往」。切换每页条数应回到第 1 页；翻页后数据不重复、时间保持倒序。管理员账号看到的是全平台行为，普通账号只看得到自己的。个人中心的「全部行为」页签同样应有分页。

以上三项均可由 `scripts/e2e-acceptance.sh` 的步骤 3b、3c、5b 自动核验。
