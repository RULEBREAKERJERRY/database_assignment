USE short_video;

-- MySQL 8.0 的 CREATE INDEX 不支持 IF NOT EXISTS，使用临时过程保证脚本可重复执行。
DROP PROCEDURE IF EXISTS ensure_index;
DELIMITER $$
CREATE PROCEDURE ensure_index(
    IN p_table_name VARCHAR(64),
    IN p_index_name VARCHAR(64),
    IN p_columns VARCHAR(255)
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

CALL ensure_index('videos', 'idx_videos_author_time', 'author_id, published_at DESC');
CALL ensure_index('videos', 'idx_videos_category_time', 'category_id, published_at DESC');
CALL ensure_index('videos', 'idx_videos_status_time', 'status, published_at DESC');
CALL ensure_index('follow_relations', 'idx_follow_followed_time', 'followed_id, followed_at DESC');
CALL ensure_index('follow_events', 'idx_follow_events_user_time', 'follower_id, occurred_at DESC');
CALL ensure_index('like_events', 'idx_like_events_user_time', 'user_id, occurred_at DESC');
CALL ensure_index('like_events', 'idx_like_events_video_time', 'video_id, occurred_at DESC');
CALL ensure_index('favorite_events', 'idx_favorite_events_user_time', 'user_id, occurred_at DESC');
CALL ensure_index('favorite_events', 'idx_favorite_events_video_time', 'video_id, occurred_at DESC');
CALL ensure_index('play_records', 'idx_play_user_time', 'user_id, started_at DESC');
CALL ensure_index('play_records', 'idx_play_video_time', 'video_id, started_at DESC');
CALL ensure_index('share_records', 'idx_share_user_time', 'user_id, shared_at DESC');
CALL ensure_index('share_records', 'idx_share_video_time', 'video_id, shared_at DESC');
CALL ensure_index('comments', 'idx_comment_video_state_time', 'video_id, is_deleted, created_at DESC');
CALL ensure_index('comments', 'idx_comment_user_time', 'user_id, created_at DESC');

DROP PROCEDURE ensure_index;
