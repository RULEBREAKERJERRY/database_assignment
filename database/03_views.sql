USE short_video;

CREATE OR REPLACE VIEW v_video_statistics AS
SELECT v.id AS video_id,
       COALESCE(l.like_count, 0) AS current_like_count,
       COALESCE(f.favorite_count, 0) AS current_favorite_count,
       COALESCE(p.play_count, 0) AS play_count,
       COALESCE(p.unique_viewer_count, 0) AS unique_viewer_count,
       COALESCE(s.share_count, 0) AS share_count,
       COALESCE(c.comment_count, 0) AS valid_comment_count
FROM videos v
LEFT JOIN (
    SELECT video_id, COUNT(*) AS like_count FROM video_likes GROUP BY video_id
) l ON l.video_id = v.id
LEFT JOIN (
    SELECT video_id, COUNT(*) AS favorite_count FROM video_favorites GROUP BY video_id
) f ON f.video_id = v.id
LEFT JOIN (
    SELECT video_id, COUNT(*) AS play_count, COUNT(DISTINCT user_id) AS unique_viewer_count
    FROM play_records GROUP BY video_id
) p ON p.video_id = v.id
LEFT JOIN (
    SELECT video_id, COUNT(*) AS share_count FROM share_records GROUP BY video_id
) s ON s.video_id = v.id
LEFT JOIN (
    SELECT video_id, COUNT(*) AS comment_count
    FROM comments WHERE is_deleted = FALSE GROUP BY video_id
) c ON c.video_id = v.id;

