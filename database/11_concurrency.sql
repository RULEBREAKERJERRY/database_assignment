-- =============================================================================
-- 11_concurrency.sql
-- 并发实验（对应需求「选做：并发控制」）
--
-- 为什么不能只用一个 SQL 文件：
--   行锁的阻塞现象只在「两个连接同时持有事务」时才出现。单个 mysql 会话里
--   顺序执行 BEGIN ... COMMIT 永远看不到等待，因此真正的双会话部分由
--   scripts/concurrency-test.sh 驱动，本文件负责：
--     1. 准备/清理实验数据（setup / teardown）
--     2. 演示单会话就能证明的部分（逻辑删除后直接 INSERT 仍成功）
--     3. 以注释形式给出双会话的原始语句，便于人工复现
--
-- 实验前提：隔离级别为 MySQL 默认的 REPEATABLE-READ。
-- =============================================================================
USE short_video;

-- ---------------------------------------------------------------- 实验数据
DROP PROCEDURE IF EXISTS concurrency_setup;
DROP PROCEDURE IF EXISTS concurrency_teardown;
DELIMITER $$

CREATE PROCEDURE concurrency_setup()
BEGIN
    DECLARE v_category BIGINT UNSIGNED;

    SELECT id INTO v_category FROM video_categories ORDER BY sort_order, id LIMIT 1;

    INSERT INTO users(username, password_hash, nickname, bio)
    VALUES ('concurrency_tester',
            '$2a$10$Fl.ir1bX0.4hVtSFwXSkhuwzrK0EZQdI5dud1MpEwpDz6SFpmHRCi',
            '并发实验账号', '仅用于锁实验')
    ON DUPLICATE KEY UPDATE nickname = VALUES(nickname);

    IF NOT EXISTS (SELECT 1 FROM videos WHERE title = '并发实验专用视频') THEN
        INSERT INTO videos(author_id, category_id, title, description, file_path)
        SELECT u.id, v_category, '并发实验专用视频', '仅用于锁实验', '/samples/concurrency.mp4'
        FROM users u WHERE u.username = 'concurrency_tester';
    END IF;
END$$

CREATE PROCEDURE concurrency_teardown()
BEGIN
    DECLARE v_video BIGINT UNSIGNED;
    DECLARE v_user BIGINT UNSIGNED;

    SELECT id INTO v_video FROM videos WHERE title = '并发实验专用视频' LIMIT 1;
    SELECT id INTO v_user FROM users WHERE username = 'concurrency_tester' LIMIT 1;

    IF v_video IS NOT NULL THEN
        DELETE FROM video_likes WHERE video_id = v_video;
        DELETE FROM video_favorites WHERE video_id = v_video;
        DELETE FROM like_events WHERE video_id = v_video;
        DELETE FROM favorite_events WHERE video_id = v_video;
        DELETE FROM play_records WHERE video_id = v_video;
        DELETE FROM share_records WHERE video_id = v_video;
        DELETE FROM comments WHERE video_id = v_video;
        DELETE FROM video_audit WHERE video_id = v_video;
        DELETE FROM videos WHERE id = v_video;
    END IF;
    IF v_user IS NOT NULL THEN
        DELETE FROM follow_relations WHERE follower_id = v_user OR followed_id = v_user;
        DELETE FROM follow_events WHERE follower_id = v_user OR followed_id = v_user;
        DELETE FROM users WHERE id = v_user;
    END IF;
END$$

DELIMITER ;

CALL concurrency_setup();

SELECT '--- 实验对象 ---' AS step;
SELECT v.id AS video_id, v.title, v.status, u.id AS author_id, u.username
FROM videos v JOIN users u ON u.id = v.author_id
WHERE v.title = '并发实验专用视频';

-- ---------------------------------------------------------------- 单会话演示
-- 结论：数据库层并不阻止「已逻辑删除的视频继续被点赞」。
-- videos 的 CHECK 只约束 status 与 deleted_at 自洽，video_likes 的外键只保证
-- 视频行存在，都不关心 status。因此「删除后不能新增互动」这条业务规则
-- 只能由应用层的「取锁 → 校验状态 → 写入」保证，这正是 InteractionService
-- 在写之前先 SELECT ... FOR SHARE 的原因。
SELECT '--- 1. 已删除视频上直接 INSERT 点赞：数据库层不会报错 ---' AS step;
START TRANSACTION;
UPDATE videos SET status = 'DELETED', deleted_at = NOW(3)
WHERE title = '并发实验专用视频';
INSERT INTO video_likes(user_id, video_id)
SELECT u.id, v.id FROM users u, videos v
WHERE u.username = 'concurrency_tester' AND v.title = '并发实验专用视频';
SELECT COUNT(*) AS like_rows_on_deleted_video
FROM video_likes l JOIN videos v ON v.id = l.video_id
WHERE v.title = '并发实验专用视频';
ROLLBACK;

SELECT '--- 2. 回滚后确认没有残留 ---' AS step;
SELECT COUNT(*) AS like_rows_after_rollback
FROM video_likes l JOIN videos v ON v.id = l.video_id
WHERE v.title = '并发实验专用视频';

-- ---------------------------------------------------------------- 双会话语句（人工复现用）
-- 会话 A：先拿排他锁，再删除，持锁 2 秒
--   mysql> USE short_video;
--   mysql> START TRANSACTION;
--   mysql> SELECT id FROM videos WHERE title='并发实验专用视频' FOR UPDATE;
--   mysql> SELECT SLEEP(2);
--   mysql> UPDATE videos SET status='DELETED', deleted_at=NOW(3) WHERE title='并发实验专用视频';
--   mysql> COMMIT;
--
-- 会话 B（在 A 执行 SLEEP 期间发起）：同样的行加共享锁，会被 A 的排他锁挡住
--   mysql> USE short_video;
--   mysql> START TRANSACTION;
--   mysql> SELECT id, status FROM videos WHERE title='并发实验专用视频' FOR SHARE;
--   mysql> COMMIT;
--
-- 预期：B 的 SELECT 阻塞约 2 秒，A 提交后返回 status='DELETED'，
-- 应用层据此抛出「视频不存在或已删除，不能新增互动」。
-- 完整计时结果见 scripts/concurrency-test.sh 与 docs/report/concurrency-log.txt。
