-- =============================================================================
-- 10_triggers.sql
-- 触发器与审计表（对应需求「选做：触发器」）
--
-- 设计要点：
--   1. video_audit 是一张只追加的旁路表，故意不加外键。若给它加
--      FOREIGN KEY ... ON DELETE RESTRICT，审计记录反而会阻止主表维护；
--      审计表的价值在于「主表怎么变它都记得」，不该被主表约束反向绑住。
--   2. 两个触发器分工不同：
--      - BEFORE UPDATE 负责「不许做什么」（逻辑删除不可逆）；
--      - AFTER  UPDATE 负责「发生了什么」（写入审计）。
--      顺序上 BEFORE 先执行，被它拦下的语句不会触发 AFTER，不会产生脏审计。
--   3. 触发器只在 videos 的 UPDATE 上，videos 的更新频率极低（上传、改标题、
--      删除），不会给播放/点赞这些高频路径增加任何开销。
--
-- 可重复执行：先 DROP 再 CREATE。
-- =============================================================================
USE short_video;

CREATE TABLE IF NOT EXISTS video_audit (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    video_id       BIGINT UNSIGNED NOT NULL,
    action         VARCHAR(16) NOT NULL,
    old_status     VARCHAR(16) NOT NULL,
    new_status     VARCHAR(16) NOT NULL,
    old_deleted_at DATETIME(3) NULL,
    new_deleted_at DATETIME(3) NULL,
    changed_at     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_audit_video_time (video_id, changed_at),
    KEY idx_audit_action_time (action, changed_at),
    CONSTRAINT ck_audit_action CHECK (action IN ('PUBLISH', 'DELETE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TRIGGER IF EXISTS trg_videos_prevent_restore;
DROP TRIGGER IF EXISTS trg_videos_audit_status;

DELIMITER $$

-- 逻辑删除不可逆：CHECK 约束只能保证 status 与 deleted_at 自洽，
-- 无法表达「DELETED 不能变回 PUBLISHED」这种跨行的状态迁移规则，交给触发器。
CREATE TRIGGER trg_videos_prevent_restore
BEFORE UPDATE ON videos
FOR EACH ROW
BEGIN
    IF OLD.status = 'DELETED' AND NEW.status = 'PUBLISHED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '已逻辑删除的作品不允许恢复为发布状态';
    END IF;
END$$

-- 记录每一次状态迁移，供审计与并发实验取证。
CREATE TRIGGER trg_videos_audit_status
AFTER UPDATE ON videos
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO video_audit(video_id, action, old_status, new_status, old_deleted_at, new_deleted_at)
        VALUES (NEW.id,
                CASE WHEN NEW.status = 'DELETED' THEN 'DELETE' ELSE 'PUBLISH' END,
                OLD.status, NEW.status, OLD.deleted_at, NEW.deleted_at);
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------- 验证
-- 取一条已发布作品做演示，整个过程放在事务里，最后回滚，不留下副作用。
-- 最后一步故意触发错误（验证「删除不可逆」），因此本脚本请用
--   mysql --force < 10_triggers.sql
-- 执行，或允许在最后一条语句处报错退出。
SET @demo_video = (SELECT id FROM videos WHERE status = 'PUBLISHED' ORDER BY id LIMIT 1);

SELECT '--- 1. 逻辑删除：触发器应写入一条 DELETE 审计 ---' AS step;
START TRANSACTION;
UPDATE videos SET status = 'DELETED', deleted_at = NOW(3) WHERE id = @demo_video;
SELECT video_id, action, old_status, new_status, changed_at FROM video_audit WHERE video_id = @demo_video;
ROLLBACK;

SELECT '--- 2. 回滚后审计同样回滚（触发器在同一事务内）---' AS step;
SELECT COUNT(*) AS audit_rows_after_rollback FROM video_audit WHERE video_id = @demo_video;

SELECT '--- 3. 只改标题不产生审计 ---' AS step;
START TRANSACTION;
UPDATE videos SET title = CONCAT(title, ' ') WHERE id = @demo_video;
SELECT COUNT(*) AS audit_rows_after_title_change FROM video_audit WHERE video_id = @demo_video;
ROLLBACK;

SELECT '--- 4. 触发器清单 ---' AS step;
SELECT trigger_name, action_timing, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'short_video'
ORDER BY trigger_name;

SELECT '--- 5. 已删除作品不允许恢复：最后一条语句，预期报 ERROR 1644 (45000) ---' AS step;
START TRANSACTION;
UPDATE videos SET status = 'DELETED', deleted_at = NOW(3) WHERE id = @demo_video;
UPDATE videos SET status = 'PUBLISHED', deleted_at = NULL WHERE id = @demo_video;
ROLLBACK;
