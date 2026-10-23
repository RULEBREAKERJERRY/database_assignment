USE short_video;

DROP PROCEDURE IF EXISTS generate_performance_data;
DELIMITER $$
CREATE PROCEDURE generate_performance_data()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE uid BIGINT UNSIGNED;
    DECLARE vid BIGINT UNSIGNED;
    DECLARE default_category_id BIGINT UNSIGNED;

    SELECT id INTO default_category_id
    FROM video_categories ORDER BY sort_order, id LIMIT 1;

    WHILE i <= 100 DO
        INSERT INTO users(username, password_hash, nickname, bio, role)
        VALUES (
          CONCAT('perf_user_', LPAD(i, 3, '0')),
          '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.',
          CONCAT('性能用户', i), '批量性能测试账号', 'USER'
        ) ON DUPLICATE KEY UPDATE nickname = VALUES(nickname);
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 500 DO
        IF NOT EXISTS (SELECT 1 FROM videos WHERE title = CONCAT('性能测试视频', LPAD(i, 4, '0'))) THEN
            SELECT id INTO uid FROM users
            WHERE username = CONCAT('perf_user_', LPAD(MOD(i - 1, 100) + 1, 3, '0'));
            INSERT INTO videos(author_id, category_id, title, description, file_path, published_at)
            VALUES (uid, default_category_id, CONCAT('性能测试视频', LPAD(i, 4, '0')),
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
        INSERT IGNORE INTO play_records(user_id, video_id, started_at, request_id)
        VALUES (uid, vid, DATE_SUB(NOW(), INTERVAL MOD(i, 30) DAY), CONCAT('perf-play-', i));
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
END$$
DELIMITER ;

CALL generate_performance_data();

