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

## 事务回滚

执行 `database/06_transaction_demo.sql` 创建两个演示过程。在测试数据上分别调用：

```sql
CALL demo_like_success(<user_id>, <video_id>);
CALL demo_like_rollback(<尚未点赞的user_id>, <video_id>);
```

第二个过程故意写入非法事件类型触发 `CHECK` 约束。查询 `video_likes` 和 `like_events`，应确认失败事务的两处修改均不存在。

## 性能实验

1. 执行 `database/07_generate_test_data.sql`。
2. 备份数据库或在专用实验库操作。
3. 临时移除 `idx_play_user_time`，保存目标查询的 `EXPLAIN ANALYZE`。
4. 恢复 `(user_id, started_at DESC)` 联合索引。
5. 执行 `database/08_performance_test.sql` 并保存结果。
6. 在报告中比较访问方式、扫描行数、排序方式和执行时间。

