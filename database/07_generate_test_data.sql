USE short_video;

DROP PROCEDURE IF EXISTS generate_performance_data;
DELIMITER $$
CREATE PROCEDURE generate_performance_data()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE uid BIGINT UNSIGNED;
    DECLARE vid BIGINT UNSIGNED;
    DECLARE default_category_id BIGINT UNSIGNED;
    DECLARE category_count INT DEFAULT 1;

    SELECT MIN(id), COUNT(*) INTO default_category_id, category_count FROM video_categories;

    WHILE i <= 100 DO
        INSERT INTO users(username, password_hash, nickname, bio, role)
        VALUES (
          CONCAT('perf_user_', LPAD(i, 3, '0')),
          '$2a$10$Fl.ir1bX0.4hVtSFwXSkhuwzrK0EZQdI5dud1MpEwpDz6SFpmHRCi',
          CONCAT('性能用户', i), '批量性能测试账号', 'USER'
        ) ON DUPLICATE KEY UPDATE nickname = VALUES(nickname);
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 500 DO
        IF NOT EXISTS (SELECT 1 FROM videos WHERE title = CONCAT('性能测试视频', LPAD(i, 4, '0'))) THEN
            SELECT id INTO uid FROM users
            WHERE username = CONCAT('perf_user_', LPAD(MOD(i - 1, 100) + 1, 3, '0'));
            -- 分类轮转，保证每个分类都有作品，避免「分类内排名」一类查询只命中一个分类。
            INSERT INTO videos(author_id, category_id, title, description, file_path, published_at)
            VALUES (uid, default_category_id + (i - 1) % category_count, CONCAT('性能测试视频', LPAD(i, 4, '0')),
                    '由可重复运行脚本生成', '/samples/performance.mp4',
                    DATE_SUB(NOW(), INTERVAL MOD(i, 30) DAY));
        END IF;
        SET i = i + 1;
    END WHILE;

    DROP TEMPORARY TABLE IF EXISTS perf_users;
    DROP TEMPORARY TABLE IF EXISTS perf_videos;
    CREATE TEMPORARY TABLE perf_users(seq INT PRIMARY KEY, id BIGINT UNSIGNED NOT NULL);
    CREATE TEMPORARY TABLE perf_videos(seq INT PRIMARY KEY, id BIGINT UNSIGNED NOT NULL);
    INSERT INTO perf_users
      SELECT CAST(RIGHT(username, 3) AS UNSIGNED), id FROM users WHERE username LIKE 'perf_user\_%';
    SET i = 1;
    WHILE i <= 500 DO
        SELECT id INTO vid FROM videos WHERE title = CONCAT('性能测试视频', LPAD(i, 4, '0')) LIMIT 1;
        INSERT INTO perf_videos VALUES (i, vid);
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 7000 DO
        SELECT id INTO uid FROM perf_users WHERE seq = MOD(i - 1, 100) + 1;
        SELECT id INTO vid FROM perf_videos WHERE seq = MOD(i * 37 - 1, 500) + 1;
        -- 时间分布：同一用户的第 k 条记录间隔 100，若直接用 MOD(i,30) 计算天数，
        -- 步长 100 与 30 的最大公约数为 10，用户只会落在 3 个日期上，
        -- 导致「近七天至少三天观看」一类查询恒为空集。
        -- 改用 MOD(i * 7 + FLOOR(i / 100), 30)，步长与 30 互质，可覆盖 30 天。
        INSERT IGNORE INTO play_records(user_id, video_id, started_at, request_id)
        VALUES (uid, vid, DATE_SUB(NOW(), INTERVAL MOD(i * 7 + FLOOR(i / 100), 30) DAY),
                CONCAT('perf-play-', i));
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 1000 DO
        SELECT id INTO uid FROM perf_users WHERE seq = MOD(i - 1, 100) + 1;
        SELECT id INTO vid FROM perf_videos WHERE seq = MOD(i * 41 - 1, 500) + 1;
        INSERT IGNORE INTO share_records(user_id, video_id, shared_at, request_id)
        VALUES (uid, vid, DATE_SUB(NOW(), INTERVAL MOD(i, 30) DAY), CONCAT('perf-share-', i));
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 1000 DO
        SELECT id INTO uid FROM perf_users WHERE seq = MOD(i - 1, 100) + 1;
        SELECT id INTO vid FROM perf_videos WHERE seq = MOD((i - 1) * 7 + FLOOR((i - 1) / 100), 500) + 1;
        INSERT IGNORE INTO video_likes(user_id, video_id) VALUES (uid, vid);
        INSERT IGNORE INTO like_events(user_id, video_id, event_type, request_id)
        VALUES (uid, vid, 'LIKE', CONCAT('perf-like-', i));
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 1000 DO
        SELECT id INTO uid FROM perf_users WHERE seq = MOD(i - 1, 100) + 1;
        SELECT id INTO vid FROM perf_videos WHERE seq = MOD((i - 1) * 11 + FLOOR((i - 1) / 100), 500) + 1;
        INSERT IGNORE INTO video_favorites(user_id, video_id) VALUES (uid, vid);
        INSERT IGNORE INTO favorite_events(user_id, video_id, event_type, request_id)
        VALUES (uid, vid, 'FAVORITE', CONCAT('perf-favorite-', i));
        SET i = i + 1;
    END WHILE;
    -- 评论 2000 条，其中 10% 已逻辑删除，用于验证评论统计与「删除后仍可追溯」。
    -- comments 没有业务唯一键，用内容前缀判断是否已生成，保证脚本可重复执行。
    IF NOT EXISTS (SELECT 1 FROM comments WHERE content LIKE '性能评论内容%') THEN
        SET i = 1;
        WHILE i <= 2000 DO
            SELECT id INTO uid FROM perf_users WHERE seq = MOD(i - 1, 100) + 1;
            SELECT id INTO vid FROM perf_videos WHERE seq = MOD(i * 13 - 1, 500) + 1;
            INSERT INTO comments(user_id, video_id, content, created_at, is_deleted, deleted_at)
            VALUES (uid, vid, CONCAT('性能评论内容 ', i),
                    DATE_SUB(NOW(), INTERVAL MOD(i, 30) DAY),
                    (MOD(i, 10) = 0),
                    IF(MOD(i, 10) = 0, DATE_SUB(NOW(), INTERVAL MOD(i, 30) DAY) + INTERVAL 1 HOUR, NULL));
            SET i = i + 1;
        END WHILE;
    END IF;

    -- 关注关系 2000 条，刻意造成「有中心但不完全是星型」的形状：
    --   2/3 的关注指向 20 个核心用户（保证人人有共同关注）；
    --   1/3 的关注指向全部 100 人里的随机对象（保证二度关注里能出现「非中心」的人）。
    -- 如果所有关注都指向同一批核心用户，二度关注的结果会与一度关注完全重合，
    -- 用 NOT EXISTS 排除已关注的人之后恒为空集。联合主键天然幂等，用 INSERT IGNORE。
    SET i = 1;
    WHILE i <= 2000 DO
        SELECT id INTO uid FROM perf_users WHERE seq = MOD(i - 1, 100) + 1;
        SELECT id INTO vid FROM perf_users
        WHERE seq = IF(MOD(i, 3) = 0,
                       1 + MOD(i * 13, 100),
                       1 + MOD(i * 7 + FLOOR((i - 1) / 100), 20));
        IF uid <> vid THEN
            INSERT IGNORE INTO follow_relations(follower_id, followed_id, followed_at)
            VALUES (uid, vid, DATE_SUB(NOW(), INTERVAL MOD(i, 60) DAY));
            INSERT IGNORE INTO follow_events(follower_id, followed_id, event_type, occurred_at, request_id)
            VALUES (uid, vid, 'FOLLOW', DATE_SUB(NOW(), INTERVAL MOD(i, 60) DAY), CONCAT('perf-follow-', i));
        END IF;
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL generate_performance_data();

