-- =============================================================================
-- 12_advanced_queries.sql
-- 窗口函数与递归 CTE（对应需求「选做：高级 SQL」）
--
-- 四个场景：
--   1. 分类内播放量 Top3          —— ROW_NUMBER() OVER (PARTITION BY ...)
--   2. 分类内播放量占比            —— SUM() OVER (PARTITION BY ...) 做分母
--   3. 每个用户最近一次播放        —— ROW_NUMBER() 取分组内第一行
--   4. 共同关注                    —— CTE 求交集
--   5. 二度关注（好友的好友）      —— WITH RECURSIVE
--
-- 数据来源：07 造的 1 万基线数据 + 09 造的 10 万规模数据。
-- =============================================================================
USE short_video;

SET SESSION cte_max_recursion_depth = 1000;

-- 取一个关注关系较多的用户做 4、5 两个场景的主角
SET @uid = (SELECT follower_id FROM follow_relations
            GROUP BY follower_id ORDER BY COUNT(*) DESC LIMIT 1);
SELECT CONCAT('示例用户 id=', @uid,
              '（', (SELECT nickname FROM users WHERE id = @uid), '）') AS note;

-- ---------------------------------------------------------------- 1. 分类内 Top3
SELECT '--- 1. 每个分类播放量 Top3（ROW_NUMBER OVER PARTITION BY）---' AS step;
WITH category_rank AS (
    SELECT vc.name AS category_name,
           v.title,
           COUNT(p.video_id) AS play_count,
           ROW_NUMBER() OVER (
               PARTITION BY v.category_id
               ORDER BY COUNT(p.video_id) DESC, v.id
           ) AS rn
    FROM videos v
    JOIN video_categories vc ON vc.id = v.category_id
    LEFT JOIN play_records p ON p.video_id = v.id
    WHERE v.status = 'PUBLISHED'
    GROUP BY v.category_id, vc.name, v.id, v.title
)
SELECT category_name, rn, title, play_count
FROM category_rank
WHERE rn <= 3
ORDER BY category_name, rn;

-- ---------------------------------------------------------------- 2. 分类内占比
SELECT '--- 2. 分类内播放量占比（SUM() OVER 做分母）---' AS step;
WITH per_video AS (
    SELECT vc.name AS category_name,
           v.title,
           COUNT(p.video_id) AS play_count
    FROM videos v
    JOIN video_categories vc ON vc.id = v.category_id
    LEFT JOIN play_records p ON p.video_id = v.id
    WHERE v.status = 'PUBLISHED'
    GROUP BY v.category_id, vc.name, v.id, v.title
),
with_total AS (
    SELECT category_name, title, play_count,
           SUM(play_count) OVER (PARTITION BY category_name) AS category_total,
           SUM(play_count) OVER () AS grand_total
    FROM per_video
)
SELECT category_name, title, play_count, category_total, grand_total,
       ROUND(play_count * 100.0 / NULLIF(category_total, 0), 2) AS pct_in_category,
       ROUND(play_count * 100.0 / NULLIF(grand_total, 0), 2) AS pct_overall
FROM with_total
ORDER BY play_count DESC
LIMIT 8;

-- ---------------------------------------------------------------- 3. 最近一次播放
SELECT '--- 3. 每个用户最近一次播放（分组内取第一行）---' AS step;
WITH last_play AS (
    SELECT p.user_id, u.nickname, p.video_id, v.title, p.started_at,
           ROW_NUMBER() OVER (PARTITION BY p.user_id ORDER BY p.started_at DESC, p.id DESC) AS rn,
           COUNT(*) OVER (PARTITION BY p.user_id) AS play_times
    FROM play_records p
    JOIN users u ON u.id = p.user_id
    JOIN videos v ON v.id = p.video_id
)
SELECT nickname, title, started_at, play_times
FROM last_play
WHERE rn = 1
ORDER BY started_at DESC
LIMIT 10;

-- ---------------------------------------------------------------- 4. 共同关注
SELECT '--- 4. 与示例用户共同关注最多的人（CTE 求交集）---' AS step;
WITH my_follows AS (
    SELECT followed_id FROM follow_relations WHERE follower_id = @uid
)
SELECT u.nickname AS other_user,
       COUNT(*) AS common_follows,
       GROUP_CONCAT(DISTINCT target.nickname ORDER BY target.nickname SEPARATOR '、') AS common_targets
FROM follow_relations f
JOIN my_follows mf ON mf.followed_id = f.followed_id
JOIN users u ON u.id = f.follower_id
JOIN users target ON target.id = f.followed_id
WHERE f.follower_id <> @uid
GROUP BY f.follower_id, u.nickname
ORDER BY common_follows DESC, other_user
LIMIT 5;

-- ---------------------------------------------------------------- 5. 二度关注
SELECT '--- 5. 二度关注：好友的好友，排除自己与已关注的人（WITH RECURSIVE）---' AS step;
WITH RECURSIVE reach AS (
    SELECT follower_id AS origin, followed_id AS node, 1 AS depth
    FROM follow_relations
    WHERE follower_id = @uid
    UNION
    SELECT r.origin, f.followed_id, r.depth + 1
    FROM reach r
    JOIN follow_relations f ON f.follower_id = r.node
    WHERE r.depth < 2
)
SELECT u.nickname AS second_degree_user,
       COUNT(*) AS paths,
       MIN(r.depth) AS min_depth
FROM reach r
JOIN users u ON u.id = r.node
WHERE r.depth = 2
  AND r.node <> @uid
  AND NOT EXISTS (
      SELECT 1 FROM follow_relations direct
      WHERE direct.follower_id = @uid AND direct.followed_id = r.node
  )
GROUP BY r.node, u.nickname
ORDER BY paths DESC, second_degree_user
LIMIT 10;
