USE short_video;

-- 参数示例；实际运行时可按需修改。
SET @user_id = (SELECT id FROM users WHERE username = 'bob');
SET @video_id = (SELECT id FROM videos WHERE title = '三秒渐变演示视频' LIMIT 1);
SET @start_time = DATE_SUB(NOW(), INTERVAL 30 DAY);
SET @end_time = NOW();

-- 1. 指定用户、指定时间范围的各类行为明细。
SELECT behavior_type, video_id, video_title, author_name, occurred_at, detail
FROM (
    SELECT 'PLAY' AS behavior_type, p.video_id, v.title AS video_title,
           u.nickname AS author_name, p.started_at AS occurred_at, NULL AS detail
    FROM play_records p
    JOIN videos v ON v.id = p.video_id
    JOIN users u ON u.id = v.author_id
    WHERE p.user_id = @user_id AND p.started_at >= @start_time AND p.started_at < @end_time
    UNION ALL
    SELECT le.event_type, le.video_id, v.title, u.nickname, le.occurred_at, NULL
    FROM like_events le
    JOIN videos v ON v.id = le.video_id
    JOIN users u ON u.id = v.author_id
    WHERE le.user_id = @user_id AND le.occurred_at >= @start_time AND le.occurred_at < @end_time
    UNION ALL
    SELECT fe.event_type, fe.video_id, v.title, u.nickname, fe.occurred_at, NULL
    FROM favorite_events fe
    JOIN videos v ON v.id = fe.video_id
    JOIN users u ON u.id = v.author_id
    WHERE fe.user_id = @user_id AND fe.occurred_at >= @start_time AND fe.occurred_at < @end_time
    UNION ALL
    SELECT 'SHARE', s.video_id, v.title, u.nickname, s.shared_at, NULL
    FROM share_records s
    JOIN videos v ON v.id = s.video_id
    JOIN users u ON u.id = v.author_id
    WHERE s.user_id = @user_id AND s.shared_at >= @start_time AND s.shared_at < @end_time
    UNION ALL
    SELECT IF(c.is_deleted, 'COMMENT_DELETED', 'COMMENT'), c.video_id, v.title,
           u.nickname, IF(c.is_deleted, c.deleted_at, c.created_at) AS occurred_at, c.content
    FROM comments c
    JOIN videos v ON v.id = c.video_id
    JOIN users u ON u.id = v.author_id
    WHERE c.user_id = @user_id AND c.created_at >= @start_time AND c.created_at < @end_time
) behavior_detail
ORDER BY occurred_at DESC;

-- 2. 指定视频的当前与累计统计。
SELECT v.id, v.title, s.current_like_count, s.current_favorite_count,
       s.valid_comment_count, s.play_count, s.share_count, s.unique_viewer_count
FROM videos v
JOIN v_video_statistics s ON s.video_id = v.id
WHERE v.id = @video_id;

-- 3. 时间范围内播放量最高的三个未删除视频。
SELECT v.id, v.title, COUNT(p.id) AS play_count
FROM videos v
LEFT JOIN play_records p
  ON p.video_id = v.id AND p.started_at >= @start_time AND p.started_at < @end_time
WHERE v.status = 'PUBLISHED'
GROUP BY v.id, v.title
ORDER BY play_count DESC, v.id ASC
LIMIT 3;

-- 4. 每日播放量与去重观看用户数。
SELECT DATE(started_at) AS play_date,
       COUNT(*) AS play_count,
       COUNT(DISTINCT user_id) AS unique_viewer_count
FROM play_records
WHERE started_at >= @start_time AND started_at < @end_time
GROUP BY DATE(started_at)
ORDER BY play_date;

-- 5. 近七天至少在三个不同日期观看过视频的用户。
SELECT u.id, u.username, u.nickname, COUNT(DISTINCT DATE(p.started_at)) AS watched_days
FROM users u
JOIN play_records p ON p.user_id = u.id
WHERE p.started_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY u.id, u.username, u.nickname
HAVING COUNT(DISTINCT DATE(p.started_at)) >= 3
ORDER BY watched_days DESC, u.id;

-- 6. 各作者近七天发布量，以及这些视频在该时间范围内的播放量；包含已删除作品。
SELECT u.id AS author_id, u.nickname,
       COUNT(DISTINCT v.id) AS published_video_count,
       COUNT(p.id) AS play_count
FROM users u
LEFT JOIN videos v
  ON v.author_id = u.id AND v.published_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
LEFT JOIN play_records p
  ON p.video_id = v.id AND p.started_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY u.id, u.nickname
ORDER BY published_video_count DESC, u.id;

