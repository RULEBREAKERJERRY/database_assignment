-- =============================================================================
-- 08_performance_test.sql
-- 一条完整的性能实验（需求 2.3-3）：索引对比 + SQL 改写对比
--
-- 【重要】原始脚本中「DROP INDEX idx_play_user_time 再重跑」的做法在本库无法执行：
--   ERROR 1553: Cannot drop index 'idx_play_user_time': needed in a foreign key constraint
-- 因为 (user_id, started_at) 联合索引的第一列 user_id 同时承担外键 fk_play_user 的支撑索引。
-- 因此本脚本改用「联合索引 → 单列索引 → 无索引」三组对照，
-- 并通过临时移除外键得到真正的全表扫描结果，末尾自动恢复原结构。
--
-- 实验环境：MySQL 8.0.40 / InnoDB / REPEATABLE-READ / buffer pool 128MB / macOS arm64
-- 数据规模：先执行 07（100 用户、500 视频、1 万条行为），
--           再执行 09（1000 用户、5000 视频、10 万条行为）观察扩展性。
--
-- 执行方式：mysql -uroot < 08_performance_test.sql
-- 每组查询连续执行三次取中位数，避免冷缓存干扰。
-- =============================================================================
USE short_video;

SET @u = (SELECT id FROM users WHERE username = 'perf_user_001');
SET @start_time = DATE_SUB(NOW(), INTERVAL 15 DAY);
SET @end_time = NOW();

-- 让优化器统计信息与数据量一致，否则 cardinality 仍是旧值，执行计划会失真。
ANALYZE TABLE play_records;

-- -----------------------------------------------------------------------------
-- 实验一：索引对「某用户某时间段的播放记录」的影响
-- 目标查询与后端 InteractionMapper.playHistory 一致
-- -----------------------------------------------------------------------------

-- A 组：联合索引 idx_play_user_time(user_id, started_at DESC)
-- 期望：Index range scan，两个条件都落在索引上，ORDER BY 由索引顺序直接满足，无 Sort 节点
EXPLAIN ANALYZE
SELECT id, video_id, started_at
FROM play_records
WHERE user_id = @u
  AND started_at >= @start_time
  AND started_at < @end_time
ORDER BY started_at DESC;

-- B 组：只有单列索引 idx_play_user(user_id)
-- 期望：Index lookup 取出该用户全部记录，再 Filter 时间条件，最后 Sort
-- 说明：单列索引能定位用户，但无法避免回表过滤与额外排序
-- 注意：必须先建单列索引再接替外键支撑，否则联合索引无法删除（ERROR 1553）
CREATE INDEX idx_play_user ON play_records(user_id);
DROP INDEX idx_play_user_time ON play_records;
ANALYZE TABLE play_records;

EXPLAIN ANALYZE
SELECT id, video_id, started_at
FROM play_records
WHERE user_id = @u
  AND started_at >= @start_time
  AND started_at < @end_time
ORDER BY started_at DESC;

-- C 组：完全没有任何以 user_id 开头的索引
-- 说明：此时只剩单列索引，必须先删除它并解除外键，才能得到真正的全表扫描
ALTER TABLE play_records DROP FOREIGN KEY fk_play_user;
DROP INDEX idx_play_user ON play_records;
ANALYZE TABLE play_records;

EXPLAIN ANALYZE
SELECT id, video_id, started_at
FROM play_records
WHERE user_id = @u
  AND started_at >= @start_time
  AND started_at < @end_time
ORDER BY started_at DESC;

-- 恢复原始结构（外键 + 联合索引），保证后续业务代码正常运行
ALTER TABLE play_records
  ADD CONSTRAINT fk_play_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;
CREATE INDEX idx_play_user_time ON play_records(user_id, started_at DESC);
ANALYZE TABLE play_records;

-- -----------------------------------------------------------------------------
-- 实验二：首页列表查询的 SQL 改写
-- 原写法直接 JOIN v_video_statistics 视图，视图内部对五张明细表全量 GROUP BY，
-- 即使只取 12 行也要先把全部聚合算完。
-- -----------------------------------------------------------------------------

-- D 组：原写法（VideoMapper.list 的等价语句）
EXPLAIN ANALYZE
SELECT v.id, v.title, s.current_like_count, s.play_count
FROM videos v
JOIN users u ON u.id = v.author_id
JOIN video_categories vc ON vc.id = v.category_id
JOIN v_video_statistics s ON s.video_id = v.id
WHERE v.status = 'PUBLISHED'
ORDER BY v.published_at DESC, v.id DESC
LIMIT 12;

-- D2 组：先分页再聚合的派生表写法
-- 实测无效：MySQL 会把派生表与外层合并，视图依旧被完整物化
EXPLAIN ANALYZE
SELECT v.id, v.title, s.current_like_count, s.play_count
FROM (SELECT id, author_id, category_id, title, published_at
      FROM videos WHERE status = 'PUBLISHED'
      ORDER BY published_at DESC, id DESC LIMIT 12) v
JOIN users u ON u.id = v.author_id
JOIN video_categories vc ON vc.id = v.category_id
JOIN v_video_statistics s ON s.video_id = v.id
ORDER BY v.published_at DESC, v.id DESC;

-- D3 组：改写为按 video_id 走索引的相关子查询
-- 期望：外层只扫索引取 12 行，子查询 loops=12，每行都是一次索引查找
EXPLAIN ANALYZE
SELECT v.id, v.title,
       (SELECT COUNT(*) FROM video_likes l WHERE l.video_id = v.id) AS like_count,
       (SELECT COUNT(*) FROM video_favorites f WHERE f.video_id = v.id) AS favorite_count,
       (SELECT COUNT(*) FROM play_records p WHERE p.video_id = v.id) AS play_count,
       (SELECT COUNT(DISTINCT p.user_id) FROM play_records p WHERE p.video_id = v.id) AS uv,
       (SELECT COUNT(*) FROM share_records s WHERE s.video_id = v.id) AS share_count,
       (SELECT COUNT(*) FROM comments c WHERE c.video_id = v.id AND c.is_deleted = FALSE) AS comment_count
FROM videos v
WHERE v.status = 'PUBLISHED'
ORDER BY v.published_at DESC, v.id DESC
LIMIT 12;
