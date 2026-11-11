-- =============================================================================
-- 09_scale_experiment.sql
-- 规模扩展实验数据（对应需求 2.3-4「提高实验」）
--   1000 个用户、5000 条视频元数据、合计 10 万条以上播放与互动记录
--
-- 与 07_generate_test_data.sql 的区别：
--   07 用 WHILE 循环逐行插入，适合小规模、可读性好；
--   09 用递归 CTE 集合插入，10 万行只需数秒，并且顺带演示 CTE 的用法。
--
-- 执行前提：已执行 01~04，且 07 已生成过 1 万条基线数据（可共存）。
-- 幂等：重复执行会先清理 perf2_ 前缀的规模数据再重建。
-- =============================================================================
USE short_video;

SET SESSION cte_max_recursion_depth = 300000;

-- ---------------------------------------------------------------- 清理旧数据
-- 注意：当前关系表 video_likes / video_favorites 必须先删，
-- 否则外键 fk_*_current_video 会阻止后面删除 videos 行。
DELETE l FROM video_likes l JOIN users u ON u.id = l.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE f FROM video_favorites f JOIN users u ON u.id = f.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE p FROM play_records p JOIN users u ON u.id = p.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE s FROM share_records s JOIN users u ON u.id = s.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE le FROM like_events le JOIN users u ON u.id = le.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE fe FROM favorite_events fe JOIN users u ON u.id = fe.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE c FROM comments c JOIN users u ON u.id = c.user_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE fr FROM follow_relations fr JOIN users u ON u.id = fr.follower_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE fo FROM follow_events fo JOIN users u ON u.id = fo.follower_id WHERE u.username LIKE 'perf2\_user\_%';
DELETE FROM videos WHERE title LIKE '规模测试视频%';
DELETE FROM users WHERE username LIKE 'perf2\_user\_%';

-- ---------------------------------------------------------------- 用户 1000
INSERT INTO users(username, password_hash, nickname, bio, role)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 1000)
SELECT CONCAT('perf2_user_', LPAD(n, 4, '0')),
       '$2a$10$Fl.ir1bX0.4hVtSFwXSkhuwzrK0EZQdI5dud1MpEwpDz6SFpmHRCi',
       CONCAT('规模用户', n), '规模扩展实验账号', 'USER'
FROM seq;

SET @user_base = (SELECT MIN(id) FROM users WHERE username LIKE 'perf2\_user\_%');
SET @cat_base = (SELECT MIN(id) FROM video_categories);
SET @cat_count = (SELECT COUNT(*) FROM video_categories);

-- ---------------------------------------------------------------- 视频 5000
INSERT INTO videos(author_id, category_id, title, description, file_path, published_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 5000)
SELECT @user_base + (n - 1) % 1000,
       -- 分类轮转，保证每个分类都有数据，否则「分类内 Top3」这类查询只有一行可看。
       @cat_base + (n - 1) % @cat_count,
       CONCAT('规模测试视频', LPAD(n, 5, '0')),
       '规模扩展实验生成',
       '/media/videos/sample-demo.mp4',
       DATE_SUB(NOW(), INTERVAL (n % 90) DAY)
FROM seq;

SET @video_base = (SELECT MIN(id) FROM videos WHERE title LIKE '规模测试视频%');

-- ---------------------------------------------------------------- 播放 80000
INSERT INTO play_records(user_id, video_id, started_at, request_id)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 80000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 37) % 5000,
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY) - INTERVAL (n % 86400) SECOND,
       CONCAT('perf2-play-', n)
FROM seq;

-- ---------------------------------------------------------------- 点赞 8000（当前关系 + 历史事件）
INSERT IGNORE INTO video_likes(user_id, video_id, liked_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 8000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 41) % 5000,
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY)
FROM seq;

INSERT IGNORE INTO like_events(user_id, video_id, event_type, occurred_at, request_id)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 8000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 41) % 5000,
       'LIKE',
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY),
       CONCAT('perf2-like-', n)
FROM seq;

-- ---------------------------------------------------------------- 收藏 6000
INSERT IGNORE INTO video_favorites(user_id, video_id, favorited_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 6000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 53) % 5000,
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY)
FROM seq;

INSERT IGNORE INTO favorite_events(user_id, video_id, event_type, occurred_at, request_id)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 6000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 53) % 5000,
       'FAVORITE',
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY),
       CONCAT('perf2-favorite-', n)
FROM seq;

-- ---------------------------------------------------------------- 转发 4000
INSERT IGNORE INTO share_records(user_id, video_id, shared_at, request_id)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 4000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 59) % 5000,
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY),
       CONCAT('perf2-share-', n)
FROM seq;

-- ---------------------------------------------------------------- 评论 4000（含 10% 逻辑删除）
INSERT INTO comments(user_id, video_id, content, created_at, is_deleted, deleted_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 4000)
SELECT @user_base + (n - 1) % 1000,
       @video_base + (n * 61) % 5000,
       CONCAT('规模测试评论内容 ', n),
       DATE_SUB(NOW(), INTERVAL (n % 30) DAY),
       (n % 10 = 0),
       IF(n % 10 = 0, DATE_SUB(NOW(), INTERVAL (n % 30) DAY) + INTERVAL 1 HOUR, NULL)
FROM seq;

-- ---------------------------------------------------------------- 关注 3000
-- 关注图刻意造成「有中心、但不完全是星型」的形状：
--   2/3 的关注指向 20 个核心用户 —— 保证任意两个用户之间都有共同关注；
--   1/3 的关注指向 1000 人里的随机对象 —— 保证二度关注里会出现非中心的人。
-- 若所有关注都指向同一批核心用户，二度关注会被 NOT EXISTS 过滤成空集。
INSERT IGNORE INTO follow_relations(follower_id, followed_id, followed_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 3000),
edges AS (
    SELECT n,
           @user_base + (n - 1) % 1000 AS follower_id,
           @user_base + IF(MOD(n, 3) = 0,
                           MOD(n * 13, 1000),
                           1 + MOD(n * 7 + FLOOR((n - 1) / 1000) * 13, 20)) AS followed_id
    FROM seq
)
SELECT follower_id, followed_id, DATE_SUB(NOW(), INTERVAL (n % 60) DAY)
FROM edges
WHERE follower_id <> followed_id;

INSERT IGNORE INTO follow_events(follower_id, followed_id, event_type, occurred_at, request_id)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 3000),
edges AS (
    SELECT n,
           @user_base + (n - 1) % 1000 AS follower_id,
           @user_base + IF(MOD(n, 3) = 0,
                           MOD(n * 13, 1000),
                           1 + MOD(n * 7 + FLOOR((n - 1) / 1000) * 13, 20)) AS followed_id
    FROM seq
)
SELECT follower_id, followed_id, 'FOLLOW',
       DATE_SUB(NOW(), INTERVAL (n % 60) DAY),
       CONCAT('perf2-follow-', n)
FROM edges
WHERE follower_id <> followed_id;

ANALYZE TABLE users, videos, play_records, video_likes, video_favorites,
              like_events, favorite_events, share_records, comments, follow_relations;

SELECT (SELECT COUNT(*) FROM users) AS users,
       (SELECT COUNT(*) FROM videos) AS videos,
       (SELECT COUNT(*) FROM play_records) AS plays,
       (SELECT COUNT(*) FROM video_likes) AS likes,
       (SELECT COUNT(*) FROM video_favorites) AS favorites,
       (SELECT COUNT(*) FROM share_records) AS shares,
       (SELECT COUNT(*) FROM comments) AS comments,
       (SELECT COUNT(*) FROM follow_relations) AS follows,
       (SELECT COUNT(*) FROM play_records) + (SELECT COUNT(*) FROM video_likes)
         + (SELECT COUNT(*) FROM video_favorites) + (SELECT COUNT(*) FROM share_records)
         + (SELECT COUNT(*) FROM comments) AS interaction_total;
