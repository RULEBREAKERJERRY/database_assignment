USE short_video;

-- =============================================================================
-- 02_indexes.sql —— 二级索引定义，脚本可重复执行
--
-- 两个细节：
-- 1) MySQL 8.0 的 CREATE INDEX 不支持 IF NOT EXISTS，用存储过程查
--    information_schema.statistics 判断后再建。
-- 2) videos 上的索引带 id DESC，而 author_id / category_id 被外键依赖，
--    直接 DROP INDEX 会报 ERROR 1553（Cannot drop index needed in a foreign key
--    constraint）。重建时先建一个单列临时索引顶住外键，删旧建新后再删临时索引。
-- =============================================================================

DROP PROCEDURE IF EXISTS ensure_index;
DELIMITER $$
CREATE PROCEDURE ensure_index(
    IN p_table_name VARCHAR(64),
    IN p_index_name VARCHAR(64),
    IN p_columns VARCHAR(255),
    IN p_column_count INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = p_table_name
          AND index_name = p_index_name
    ) THEN
        SET @index_ddl = CONCAT(
            'CREATE INDEX `', p_index_name, '` ON `', p_table_name, '` (', p_columns, ')'
        );
        PREPARE index_statement FROM @index_ddl;
        EXECUTE index_statement;
        DEALLOCATE PREPARE index_statement;
    END IF;
END$$
DELIMITER ;

-- 重建 videos 上的索引：列定义变化时先删后建，并用临时索引绕开外键依赖。
-- p_first_col 为 NULL 表示该索引的首列不被任何外键引用（如 status）。
DROP PROCEDURE IF EXISTS rebuild_videos_index;
DELIMITER $$
CREATE PROCEDURE rebuild_videos_index(
    IN p_index_name VARCHAR(64),
    IN p_columns VARCHAR(255),
    IN p_first_col VARCHAR(64),
    IN p_column_count INT
)
BEGIN
    DECLARE v_existing INT DEFAULT 0;
    DECLARE v_tmp_index VARCHAR(80);

    SELECT COALESCE(MAX(seq_in_index), 0) INTO v_existing
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'videos'
      AND index_name = p_index_name;

    IF v_existing <> p_column_count THEN
        IF p_first_col IS NOT NULL THEN
            SET v_tmp_index = CONCAT('idx_tmp_', p_first_col);
            IF EXISTS (
                SELECT 1 FROM information_schema.statistics
                WHERE table_schema = DATABASE() AND table_name = 'videos'
                  AND index_name = v_tmp_index
            ) THEN
                SET @ddl = CONCAT('DROP INDEX `', v_tmp_index, '` ON videos');
                PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;
            END IF;
            SET @ddl = CONCAT('CREATE INDEX `', v_tmp_index, '` ON videos (`', p_first_col, '`)');
            PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;
        END IF;

        IF v_existing > 0 THEN
            SET @ddl = CONCAT('DROP INDEX `', p_index_name, '` ON videos');
            PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;
        END IF;

        SET @ddl = CONCAT('CREATE INDEX `', p_index_name, '` ON videos (', p_columns, ')');
        PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

        IF p_first_col IS NOT NULL THEN
            SET @ddl = CONCAT('DROP INDEX `', v_tmp_index, '` ON videos');
            PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;
        END IF;
    END IF;
END$$
DELIMITER ;

-- videos 上的三个索引都带上 id DESC。
-- 列表查询统一是 `ORDER BY published_at DESC, id DESC`：如果索引只到 published_at，
-- 排序的第二列 id 仍需 filesort；把 id DESC 补进索引后排序完全由索引顺序提供，
-- 实测首页列表在 10 万规模下从 3.96 ms 降到 0.04 ms（见报告 9.3 节）。
CALL rebuild_videos_index('idx_videos_author_time', 'author_id, published_at DESC, id DESC', 'author_id', 3);
CALL rebuild_videos_index('idx_videos_category_time', 'category_id, published_at DESC, id DESC', 'category_id', 3);
CALL rebuild_videos_index('idx_videos_status_time', 'status, published_at DESC, id DESC', NULL, 3);

CALL ensure_index('follow_relations', 'idx_follow_followed_time', 'followed_id, followed_at DESC', 2);
CALL ensure_index('follow_events', 'idx_follow_events_user_time', 'follower_id, occurred_at DESC', 2);
CALL ensure_index('like_events', 'idx_like_events_user_time', 'user_id, occurred_at DESC', 2);
CALL ensure_index('like_events', 'idx_like_events_video_time', 'video_id, occurred_at DESC', 2);
CALL ensure_index('favorite_events', 'idx_favorite_events_user_time', 'user_id, occurred_at DESC', 2);
CALL ensure_index('favorite_events', 'idx_favorite_events_video_time', 'video_id, occurred_at DESC', 2);
CALL ensure_index('play_records', 'idx_play_user_time', 'user_id, started_at DESC', 2);
CALL ensure_index('play_records', 'idx_play_video_time', 'video_id, started_at DESC', 2);
CALL ensure_index('share_records', 'idx_share_user_time', 'user_id, shared_at DESC', 2);
CALL ensure_index('share_records', 'idx_share_video_time', 'video_id, shared_at DESC', 2);
CALL ensure_index('comments', 'idx_comment_video_state_time', 'video_id, is_deleted, created_at DESC', 3);
CALL ensure_index('comments', 'idx_comment_user_time', 'user_id, created_at DESC', 2);

-- 说明：video_likes / video_favorites 的主键是 (user_id, video_id)，以用户维度打头，
-- 「按视频统计点赞数」看似没有索引可用。但 InnoDB 会为每个外键自动创建以该列打头的索引，
-- fk_like_current_video / fk_favorite_current_video 已经提供了 (video_id) 索引
-- （可用 SHOW INDEX FROM video_likes 验证），因此这里刻意不再重复建 idx_*_video，
-- 避免同一列出现两个索引带来的写放大。

DROP PROCEDURE ensure_index;
DROP PROCEDURE rebuild_videos_index;
