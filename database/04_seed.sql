USE short_video;

INSERT INTO video_categories(name, sort_order) VALUES
('生活', 10), ('美食', 20), ('旅行', 30), ('知识', 40),
('科技', 50), ('音乐', 60), ('运动', 70), ('其他', 99)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

-- 测试账号密码均为 password；必须仅用于本地课程演示。
INSERT INTO users(username, password_hash, nickname, bio, role) VALUES
('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.', '平台管理员', '课程设计管理员账号', 'ADMIN'),
('alice', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.', 'Alice', '喜欢旅行和摄影', 'USER'),
('bob', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.', 'Bob', '科技区创作者', 'USER')
ON DUPLICATE KEY UPDATE nickname = VALUES(nickname), bio = VALUES(bio), role = VALUES(role);

-- 可人工核验的少量业务样例；对应文件与许可说明见 storage/videos/README.md。
SET @alice_id = (SELECT id FROM users WHERE username = 'alice');
SET @bob_id = (SELECT id FROM users WHERE username = 'bob');
SET @life_category_id = (SELECT id FROM video_categories WHERE name = '生活');

INSERT INTO videos(author_id, category_id, title, description, file_path)
SELECT @alice_id, @life_category_id, '三秒渐变演示视频',
       '用于课程设计功能验收的本地示例视频', '/media/videos/sample-demo.mp4'
WHERE NOT EXISTS (
  SELECT 1 FROM videos WHERE author_id = @alice_id AND title = '三秒渐变演示视频'
);

INSERT INTO videos(author_id, category_id, title, description, file_path, status, deleted_at)
SELECT @alice_id, @life_category_id, '已删除作品样例',
       '用于验证逻辑删除后历史仍保留', '/media/videos/sample-demo.mp4', 'DELETED', NOW(3)
WHERE NOT EXISTS (
  SELECT 1 FROM videos WHERE author_id = @alice_id AND title = '已删除作品样例'
);

SET @sample_video_id = (
  SELECT id FROM videos WHERE author_id = @alice_id AND title = '三秒渐变演示视频' LIMIT 1
);
SET @deleted_video_id = (
  SELECT id FROM videos WHERE author_id = @alice_id AND title = '已删除作品样例' LIMIT 1
);

INSERT IGNORE INTO follow_relations(follower_id, followed_id) VALUES(@bob_id, @alice_id);
INSERT IGNORE INTO follow_events(follower_id, followed_id, event_type, occurred_at, request_id) VALUES
(@bob_id, @alice_id, 'FOLLOW', DATE_SUB(NOW(3), INTERVAL 10 MINUTE), 'seed-follow-1');

INSERT IGNORE INTO play_records(user_id, video_id, started_at, request_id) VALUES
(@bob_id, @sample_video_id, DATE_SUB(NOW(3), INTERVAL 9 MINUTE), 'seed-play-1'),
(@bob_id, @sample_video_id, DATE_SUB(NOW(3), INTERVAL 8 MINUTE), 'seed-play-2'),
(@bob_id, @deleted_video_id, DATE_SUB(NOW(3), INTERVAL 20 MINUTE), 'seed-deleted-play-1');

INSERT IGNORE INTO video_likes(user_id, video_id) VALUES(@bob_id, @sample_video_id);
INSERT IGNORE INTO like_events(user_id, video_id, event_type, occurred_at, request_id) VALUES
(@bob_id, @sample_video_id, 'LIKE', DATE_SUB(NOW(3), INTERVAL 7 MINUTE), 'seed-like-1'),
(@bob_id, @sample_video_id, 'UNLIKE', DATE_SUB(NOW(3), INTERVAL 6 MINUTE), 'seed-unlike-1'),
(@bob_id, @sample_video_id, 'LIKE', DATE_SUB(NOW(3), INTERVAL 5 MINUTE), 'seed-relike-1');

INSERT IGNORE INTO video_favorites(user_id, video_id) VALUES(@bob_id, @sample_video_id);
INSERT IGNORE INTO favorite_events(user_id, video_id, event_type, occurred_at, request_id) VALUES
(@bob_id, @sample_video_id, 'FAVORITE', DATE_SUB(NOW(3), INTERVAL 4 MINUTE), 'seed-favorite-1');

INSERT IGNORE INTO share_records(user_id, video_id, shared_at, request_id) VALUES
(@bob_id, @sample_video_id, DATE_SUB(NOW(3), INTERVAL 3 MINUTE), 'seed-share-1');

INSERT INTO comments(user_id, video_id, content, created_at)
SELECT @bob_id, @sample_video_id, '示例评论：视频播放正常。', DATE_SUB(NOW(3), INTERVAL 2 MINUTE)
WHERE NOT EXISTS (
  SELECT 1 FROM comments
  WHERE user_id = @bob_id AND video_id = @sample_video_id AND content = '示例评论：视频播放正常。'
);

INSERT INTO comments(user_id, video_id, content, created_at, is_deleted, deleted_at)
SELECT @bob_id, @sample_video_id, '示例评论：这条记录已逻辑删除。',
       DATE_SUB(NOW(3), INTERVAL 2 MINUTE), TRUE, DATE_SUB(NOW(3), INTERVAL 1 MINUTE)
WHERE NOT EXISTS (
  SELECT 1 FROM comments
  WHERE user_id = @bob_id AND video_id = @sample_video_id
    AND content = '示例评论：这条记录已逻辑删除。'
);

