USE short_video;

SET @performance_user = (SELECT id FROM users WHERE username = 'perf_user_001');
SET @start_time = DATE_SUB(NOW(), INTERVAL 15 DAY);
SET @end_time = NOW();

-- 记录“使用联合索引”的执行计划。
EXPLAIN ANALYZE
SELECT id, video_id, started_at
FROM play_records
WHERE user_id = @performance_user
  AND started_at >= @start_time
  AND started_at < @end_time
ORDER BY started_at DESC;

-- 对比实验可在备份环境临时执行：
-- DROP INDEX idx_play_user_time ON play_records;
-- 再运行上面的 EXPLAIN ANALYZE 并截图，随后恢复索引：
-- CREATE INDEX idx_play_user_time ON play_records(user_id, started_at DESC);

