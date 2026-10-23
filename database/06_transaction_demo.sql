USE short_video;

-- 点赞业务的原子性演示。测试前请确保 alice 和 bob 存在，且 bob 至少有一个未删除视频。
-- 后端 InteractionService 使用同样的事务边界。
DROP PROCEDURE IF EXISTS demo_like_success;
DROP PROCEDURE IF EXISTS demo_like_rollback;

DELIMITER $$
CREATE PROCEDURE demo_like_success(IN p_user_id BIGINT UNSIGNED, IN p_video_id BIGINT UNSIGNED)
BEGIN
    START TRANSACTION;
    INSERT INTO video_likes(user_id, video_id) VALUES (p_user_id, p_video_id);
    INSERT INTO like_events(user_id, video_id, event_type, request_id)
    VALUES (p_user_id, p_video_id, 'LIKE', CONCAT('tx-success-', UUID()));
    COMMIT;
END$$

CREATE PROCEDURE demo_like_rollback(IN p_user_id BIGINT UNSIGNED, IN p_video_id BIGINT UNSIGNED)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;
    INSERT INTO video_likes(user_id, video_id) VALUES (p_user_id, p_video_id);
    -- 故意写入非法事件类型，触发 CHECK 约束。
    INSERT INTO like_events(user_id, video_id, event_type, request_id)
    VALUES (p_user_id, p_video_id, 'INVALID', CONCAT('tx-failure-', UUID()));
    COMMIT;
END$$
DELIMITER ;

-- 调用后分别查询 video_likes 与 like_events，即可验证成功时同时写入、失败时均未写入。
-- CALL demo_like_success(<user_id>, <video_id>);
-- CALL demo_like_rollback(<另一个尚未点赞的user_id>, <video_id>);

